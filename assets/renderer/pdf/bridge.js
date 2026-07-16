(function () {
  let pdfDoc = null;
  let pageNumber = 1;
  let zoom = 1.2;
  let zoomMode = "custom";
  let displayMode = "continuous";
  let settings = {};
  let documentTextLayerAvailable = false;
  let lastSearchResults = [];
  let annotations = [];
  let renderVersion = 0;
  let scrollReportTimer = null;
  let lazyRenderTimer = null;
  /** @type {Map<number, {pageView: HTMLElement, scale: number, rendered: boolean, rendering: boolean}>} */
  const pageRenderState = new Map();

  const pageLabel = document.getElementById("pageLabel");
  const stage = document.getElementById("stage");
  const toolbar = document.getElementById("toolbar");
  const zoomPreset = document.getElementById("zoomPreset");
  const displayModeSelect = document.getElementById("displayMode");
  const textLayerStatus = document.getElementById("textLayerStatus");

  function send(type, payload) {
    const event = { type, payload: payload || {} };
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler("PageSageBridge", event);
    }
  }

  function reportError(error) {
    send("renderError", { message: readablePdfError(error) });
  }

  function readablePdfError(error) {
    const name = error && error.name ? String(error.name) : "";
    const message = error && error.message ? String(error.message) : String(error || "PDF render error");
    const lower = `${name} ${message}`.toLocaleLowerCase();
    if (name === "PasswordException" || lower.includes("password")) {
      return "此 PDF 已加密，当前版本暂不支持输入密码打开";
    }
    if (name === "InvalidPDFException" || name === "FormatError" || lower.includes("invalid pdf")) {
      return "PDF 文件损坏或格式不受支持";
    }
    if (name === "MissingPDFException") {
      return "PDF 文件不存在或已被移除";
    }
    if (name === "UnexpectedResponseException") {
      return "无法读取 PDF 文件内容";
    }
    return message || "PDF 渲染失败";
  }

  function applySettings(nextSettings) {
    settings = Object.assign({}, settings || {}, nextSettings || {});
    const root = document.documentElement;
    if (settings.background) {
      root.style.setProperty("--reader-bg", settings.background);
    }
    if (settings.foreground) {
      root.style.setProperty("--reader-fg", settings.foreground);
    }
    if (settings.pageMargin) {
      root.style.setProperty("--page-margin", `${Number(settings.pageMargin)}px`);
    }
    // Theme id drives CSS filters for paper canvas (night invert / eye-care tint).
    const themeId = String(settings.themePreset || settings.theme || "day")
      .trim()
      .toLowerCase();
    root.dataset.theme = themeId || "day";
    root.dataset.reduceMotion = settings.reduceMotion ? "true" : "false";

    if (!displayModeSelect.dataset.userSelected) {
      displayMode = preferredDisplayMode();
      displayModeSelect.value = displayMode;
      updateDisplayMode();
    }

    const nextZoomMode = normalizeZoomMode(settings.pdfZoomMode || zoomMode);
    const nextZoom = Number(settings.pdfScale || zoom);
    const zoomModeChanged = nextZoomMode !== zoomMode;
    const zoomChanged = Number.isFinite(nextZoom) && Math.abs(nextZoom - zoom) > 0.001;
    if (pdfDoc && (zoomModeChanged || zoomChanged)) {
      zoomMode = nextZoomMode;
      if (zoomMode === "actual") {
        zoom = 1;
      } else if (Number.isFinite(nextZoom)) {
        zoom = Math.min(3, Math.max(0.5, nextZoom));
      }
      renderDocument({ restorePage: pageNumber });
    }
  }

  function normalizeZoomMode(value) {
    if (value === "fit-width" || value === "fit-page" || value === "actual") {
      return value;
    }
    return "custom";
  }

  function preferredDisplayMode() {
    // Phones: continuous scroll is the least friction. Paged single without
    // swipe feels broken; double-page never fits narrow widths.
    if (isNarrowViewport()) {
      return "continuous";
    }
    if (settings.readerMode === "paged") {
      return "double";
    }
    return "continuous";
  }

  function reportCapability() {
    send("capabilityChanged", {
      textSelection: documentTextLayerAvailable,
      search: documentTextLayerAvailable,
      reason: documentTextLayerAvailable ? null : "此 PDF 没有可选择文本",
    });
    textLayerStatus.hidden = documentTextLayerAvailable;
  }

  function currentProgress() {
    if (!pdfDoc) {
      return 0;
    }
    return pdfDoc.numPages <= 1 ? 1 : (pageNumber - 1) / (pdfDoc.numPages - 1);
  }

  function currentScrollOffset() {
    const pageView = pageViewFor(pageNumber);
    if (!pageView || displayMode !== "continuous") {
      return 0;
    }
    return Math.max(window.scrollY - pageView.offsetTop, 0);
  }

  function reportLocation() {
    if (!pdfDoc) {
      return;
    }
    const scale = Number(pageViewFor(pageNumber)?.dataset.scale || zoom);
    const excerpt = excerptNearViewport(pageNumber);
    send("locationChanged", {
      locator: {
        type: "pdf",
        page: pageNumber,
        scrollOffset: currentScrollOffset(),
        zoom: scale,
        progress: currentProgress(),
        excerpt: excerpt || undefined,
      },
      progress: currentProgress(),
      pageNumber,
      totalPages: pdfDoc.numPages,
    });
  }

  function excerptNearViewport(page) {
    try {
      const pageView = pageViewFor(page);
      if (!pageView) {
        return "";
      }
      const spans = pageView.querySelectorAll(".textLayer span");
      if (!spans.length) {
        return "";
      }
      const viewportTop = window.scrollY + Math.max(window.innerHeight * 0.18, 48);
      let best = "";
      let bestDistance = Number.POSITIVE_INFINITY;
      for (const span of spans) {
        const text = (span.textContent || "").replace(/\s+/g, " ").trim();
        if (!text) {
          continue;
        }
        const rect = span.getBoundingClientRect();
        const absoluteTop = window.scrollY + rect.top;
        const distance = Math.abs(absoluteTop - viewportTop);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = text;
        }
      }
      if (!best) {
        return "";
      }
      return best.length > 120 ? best.slice(0, 120).trim() : best;
    } catch (_) {
      return "";
    }
  }

  function yieldToMain() {
    return new Promise(function (resolve) {
      window.setTimeout(resolve, 0);
    });
  }

  function isNarrowViewport() {
    return window.innerWidth < 900;
  }

  function availablePageBox() {
    // On phones the Flutter chrome owns chrome; keep HTML page margins tight.
    const configured = Number(settings.pageMargin || 20);
    const margin = isNarrowViewport()
      ? Math.min(Math.max(configured * 0.4, 8), 12)
      : configured;
    const columns = displayMode === "double" && !isNarrowViewport() ? 2 : 1;
    const gap = columns === 2 ? 16 : 0;
    // Prefer stage width once laid out; fall back to window.
    const stageWidth = stage.clientWidth || window.innerWidth;
    const availableWidth = Math.max((stageWidth - margin * 2 - gap) / columns, 120);
    // Mobile hides the HTML toolbar; don't reserve a phantom 48px.
    const toolbarVisible = toolbar && window.getComputedStyle(toolbar).display !== "none";
    const toolbarHeight = toolbarVisible ? toolbar.getBoundingClientRect().height : 0;
    const availableHeight = Math.max(window.innerHeight - toolbarHeight - margin * 2, 180);
    return { availableWidth, availableHeight, columns, margin };
  }

  function canvasOutputScale(cssWidth, cssHeight) {
    // High-DPI phones (3x) + full-page PDF canvases easily OOM / jank.
    const dpr = Math.max(window.devicePixelRatio || 1, 1);
    const maxDpr = isNarrowViewport() ? 1.75 : 2.5;
    let outputScale = Math.min(dpr, maxDpr);
    const maxPixels = isNarrowViewport() ? 3.5e6 : 12e6;
    const pixels = Math.max(cssWidth, 1) * Math.max(cssHeight, 1) * outputScale * outputScale;
    if (pixels > maxPixels) {
      outputScale = Math.sqrt(maxPixels / (Math.max(cssWidth, 1) * Math.max(cssHeight, 1)));
    }
    return Math.max(outputScale, 1);
  }

  function continuousRenderRadius() {
    // Keep a small window of fully rasterized pages around the viewport.
    return isNarrowViewport() ? 1 : 2;
  }

  function releasePageRender(state) {
    if (!state || (!state.rendered && !state.rendering)) {
      return;
    }
    const canvas = state.pageView.querySelector(".pageCanvas");
    const textLayer = state.pageView.querySelector(".textLayer");
    if (canvas) {
      const context = canvas.getContext("2d");
      if (context) {
        context.clearRect(0, 0, canvas.width, canvas.height);
      }
      // Drop GPU/CPU pixel buffers; keep CSS box via pageContainer size.
      canvas.width = 1;
      canvas.height = 1;
      canvas.style.width = state.pageView.style.width;
      canvas.style.height = state.pageView.style.height;
    }
    if (textLayer) {
      textLayer.replaceChildren();
    }
    state.rendered = false;
    state.rendering = false;
  }

  function scheduleLazyRender() {
    if (lazyRenderTimer) {
      window.clearTimeout(lazyRenderTimer);
    }
    lazyRenderTimer = window.setTimeout(function () {
      lazyRenderTimer = null;
      ensurePagesAround(pageNumber, renderVersion);
    }, 60);
  }

  async function ensurePagesAround(centerPage, version) {
    if (!pdfDoc || version !== renderVersion) {
      return;
    }
    const center = normalizePageNumber(centerPage);
    let start;
    let end;
    if (displayMode === "continuous") {
      const radius = continuousRenderRadius();
      start = Math.max(1, center - radius);
      end = Math.min(pdfDoc.numPages, center + radius);
    } else if (displayMode === "double") {
      const spreadStart = spreadStartFor(center);
      start = Math.max(1, spreadStart);
      end = Math.min(pdfDoc.numPages, spreadStart === 1 ? 1 : spreadStart + 1);
    } else {
      start = center;
      end = center;
    }

    // Free far pages first so memory stays bounded while scrolling.
    const keepPad = displayMode === "continuous" ? continuousRenderRadius() + 1 : 1;
    for (const [number, state] of pageRenderState.entries()) {
      if (number < start - keepPad || number > end + keepPad) {
        releasePageRender(state);
      }
    }

    for (let number = start; number <= end; number += 1) {
      if (version !== renderVersion) {
        return;
      }
      await renderPageIfNeeded(number, version);
    }

    if (version === renderVersion) {
      highlightSearchResults();
      drawAnnotations();
    }
  }

  async function renderPageIfNeeded(number, version) {
    const state = pageRenderState.get(number);
    if (!state || !pdfDoc || version !== renderVersion) {
      return;
    }
    if (state.rendered || state.rendering) {
      return;
    }
    state.rendering = true;
    try {
      const page = await pdfDoc.getPage(number);
      if (version !== renderVersion) {
        return;
      }
      const scale = Number(state.pageView.dataset.scale) || resolveZoomForPage(page);
      const viewport = page.getViewport({ scale });
      await renderPageView(page, state.pageView, viewport, scale);
      if (version === renderVersion) {
        state.rendered = true;
      }
    } catch (error) {
      console.warn("PDF page render failed", number, error);
    } finally {
      if (state) {
        state.rendering = false;
      }
    }
  }

  async function renderDocument(options) {
    if (!pdfDoc) {
      return;
    }
    const version = ++renderVersion;
    const restorePage = Math.min(
      Math.max(Number(options && options.restorePage ? options.restorePage : pageNumber), 1),
      pdfDoc.numPages
    );
    const restoreOffset = Number(options && options.restoreOffset ? options.restoreOffset : 0);
    stage.replaceChildren();
    pageRenderState.clear();
    updateDisplayMode();

    // Phase 1: light page shells only (correct layout sizes, no full raster).
    // This keeps scroll metrics stable without freezing the phone on large PDFs.
    for (let number = 1; number <= pdfDoc.numPages; number += 1) {
      if (version !== renderVersion) {
        return;
      }
      const page = await pdfDoc.getPage(number);
      const scale = resolveZoomForPage(page);
      const viewport = page.getViewport({ scale });
      const pageView = createPageView(number, viewport, scale);
      stage.appendChild(pageView);
      pageRenderState.set(number, {
        pageView,
        scale,
        rendered: false,
        rendering: false,
      });
      if (number % 8 === 0) {
        await yieldToMain();
      }
    }

    if (version !== renderVersion) {
      return;
    }
    pageNumber = restorePage;
    updateVisiblePages();
    updateZoomPreset();
    reportCapability();
    // Phase 2: rasterize only the pages near the restore target.
    await ensurePagesAround(pageNumber, version);
    if (version !== renderVersion) {
      return;
    }
    scrollToPage(pageNumber, restoreOffset);
    setTimeout(reportLocation, 50);
  }

  function createPageView(number, viewport, scale) {
    const cssWidth = Math.max(Math.floor(viewport.width), 1);
    const cssHeight = Math.max(Math.floor(viewport.height), 1);
    const pageView = document.createElement("section");
    pageView.className = "pageContainer";
    pageView.dataset.page = String(number);
    pageView.dataset.scale = String(scale);
    // Fixed CSS box preserves aspect ratio; never rely on max-width-only shrink.
    pageView.style.width = `${cssWidth}px`;
    pageView.style.height = `${cssHeight}px`;
    pageView.setAttribute("aria-label", `PDF 第 ${number} 页`);

    const canvas = document.createElement("canvas");
    canvas.className = "pageCanvas";
    // Placeholder buffer until lazy render fills pixels.
    canvas.width = 1;
    canvas.height = 1;
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
    canvas.setAttribute("aria-label", `PDF 第 ${number} 页画布`);

    const textLayer = document.createElement("div");
    textLayer.className = "textLayer";
    textLayer.style.width = `${cssWidth}px`;
    textLayer.style.height = `${cssHeight}px`;
    textLayer.setAttribute("aria-label", `PDF 第 ${number} 页文本层`);
    textLayer.addEventListener("mouseup", reportTextSelection);
    textLayer.addEventListener("touchend", function () {
      setTimeout(reportTextSelection, 50);
    });

    pageView.appendChild(canvas);
    pageView.appendChild(textLayer);
    pageView.appendChild(createAnnotationLayer(cssWidth, cssHeight));
    return pageView;
  }

  function createAnnotationLayer(cssWidth, cssHeight) {
    const layer = document.createElement("div");
    layer.className = "annotationLayer";
    layer.style.width = `${cssWidth}px`;
    layer.style.height = `${cssHeight}px`;
    layer.setAttribute("aria-hidden", "true");
    return layer;
  }

  async function renderPageView(page, pageView, viewport, scale) {
    const canvas = pageView.querySelector(".pageCanvas");
    if (!canvas) {
      return;
    }
    const context = canvas.getContext("2d", { alpha: false });
    const cssWidth = Math.max(Math.floor(viewport.width), 1);
    const cssHeight = Math.max(Math.floor(viewport.height), 1);
    const outputScale = canvasOutputScale(cssWidth, cssHeight);
    canvas.width = Math.max(Math.floor(cssWidth * outputScale), 1);
    canvas.height = Math.max(Math.floor(cssHeight * outputScale), 1);
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
    // Keep container / text / annotation layers locked to the same CSS box.
    pageView.style.width = `${cssWidth}px`;
    pageView.style.height = `${cssHeight}px`;
    const textLayer = pageView.querySelector(".textLayer");
    const annotationLayer = pageView.querySelector(".annotationLayer");
    if (textLayer) {
      textLayer.style.width = `${cssWidth}px`;
      textLayer.style.height = `${cssHeight}px`;
    }
    if (annotationLayer) {
      annotationLayer.style.width = `${cssWidth}px`;
      annotationLayer.style.height = `${cssHeight}px`;
    }
    await page.render({
      canvasContext: context,
      viewport,
      transform: outputScale === 1 ? null : [outputScale, 0, 0, outputScale, 0, 0],
    }).promise;
    await renderTextLayer(page, textLayer, viewport, scale);
  }

  function resolveZoomForPage(page) {
    const baseViewport = page.getViewport({ scale: 1 });
    const box = availablePageBox();
    const widthScale = box.availableWidth / Math.max(baseViewport.width, 1);
    const heightScale = box.availableHeight / Math.max(baseViewport.height, 1);

    if (zoomMode === "actual") {
      // On phones, true 100% often overflows and used to look "squashed" under CSS max-width.
      // Cap to fit-width so the page stays fully visible and proportional.
      return Math.min(3, Math.max(0.5, Math.min(1, widthScale)));
    }
    if (zoomMode === "fit-width") {
      return Math.min(3, Math.max(0.5, widthScale));
    }
    if (zoomMode === "fit-page") {
      return Math.min(3, Math.max(0.5, Math.min(widthScale, heightScale)));
    }
    // custom: honor user zoom but never start wider than the viewport on narrow screens
    // when the chosen zoom would overflow (avoids horizontal mess + old max-width squash).
    let next = Math.min(3, Math.max(0.5, zoom));
    if (isNarrowViewport() && next > widthScale + 0.02) {
      // Allow intentional pinch/button zoom above fit-width; only clamp the initial
      // oversized defaults (e.g. 1.2 on a 360px phone with a 600css-wide page).
      if (next <= 1.25 && widthScale < 1.2) {
        next = widthScale;
      }
    }
    return next;
  }

  async function renderTextLayer(page, textLayer, viewport, scale) {
    try {
      const textContent = await page.getTextContent();
      textLayer.replaceChildren();
      // Keep the text layer box locked to the canvas CSS size so selection
      // rectangles and annotation marks share the same coordinate space.
      textLayer.style.width = `${Math.floor(viewport.width)}px`;
      textLayer.style.height = `${Math.floor(viewport.height)}px`;
      const fragment = document.createDocumentFragment();
      for (const item of textContent.items || []) {
        if (!item.str) {
          continue;
        }
        const tx = window.pdfjsLib.Util.transform(
          viewport.transform,
          item.transform,
        );
        // PDF.js text matrix: [a, b, c, d, e, f]. Font height ≈ |column 2|.
        const fontHeight = Math.max(Math.hypot(tx[2], tx[3]), 1);
        const angle = Math.atan2(tx[1], tx[0]);
        const left = tx[4];
        const top = tx[5] - fontHeight;
        const span = document.createElement("span");
        span.textContent = item.str;
        span.style.left = `${left}px`;
        span.style.top = `${top}px`;
        span.style.fontSize = `${fontHeight}px`;
        const transforms = [];
        if (Math.abs(angle) > 0.001) {
          transforms.push(`rotate(${angle}rad)`);
        }
        if (item.width && item.str.length > 0) {
          // Estimate natural width without DOM measure (CJK vs Latin).
          const mostlyCjk = /[　-鿿]/.test(item.str);
          const avgCharWidth = mostlyCjk ? fontHeight : fontHeight * 0.5;
          const naturalWidth = Math.max(item.str.length * avgCharWidth, 1);
          const targetWidth = Math.max(item.width * scale, 1);
          transforms.push(`scaleX(${targetWidth / naturalWidth})`);
        }
        if (transforms.length) {
          span.style.transform = transforms.join(" ");
        }
        fragment.appendChild(span);
      }
      textLayer.appendChild(fragment);
    } catch (error) {
      console.warn("PDF text layer unavailable", error);
    }
  }

  function updateDisplayMode() {
    document.documentElement.dataset.displayMode = displayMode;
    displayModeSelect.value = displayMode;
    // Paged modes should not free-scroll the whole document.
    // Continuous keeps native scroll; single/double use page turns.
    const paged = displayMode === "single" || displayMode === "double";
    document.documentElement.dataset.paged = paged ? "true" : "false";
    document.body.style.overflow = paged ? "hidden" : "";
    if (paged) {
      window.scrollTo(0, 0);
    }
  }

  function normalizePageNumber(number) {
    if (!pdfDoc) {
      return 1;
    }
    return Math.min(Math.max(Number(number) || 1, 1), pdfDoc.numPages);
  }

  function pageStep() {
    return displayMode === "double" ? 2 : 1;
  }

  /** Left page of the current double-page spread (1-based). */
  function spreadStartFor(number) {
    const page = normalizePageNumber(number);
    if (displayMode !== "double") {
      return page;
    }
    // Keep cover alone on the right of an empty left: page 1 stays 1.
    if (page <= 1) {
      return 1;
    }
    // Even page is left of the pair: 2-3, 4-5, ...
    return page % 2 === 0 ? page : page - 1;
  }

  function updateVisiblePages() {
    if (!pdfDoc) {
      return;
    }
    const spreadStart = spreadStartFor(pageNumber);
    if (displayMode === "double") {
      // Snap current page onto the left page of the spread for stable turns.
      pageNumber = spreadStart;
    }
    for (const pageView of stage.querySelectorAll(".pageContainer")) {
      const number = Number(pageView.dataset.page || 0);
      let visible = displayMode === "continuous";
      if (displayMode === "single") {
        visible = number === pageNumber;
      } else if (displayMode === "double") {
        if (spreadStart === 1) {
          // Cover: show only page 1, centered by CSS.
          visible = number === 1;
        } else {
          visible = number === spreadStart || number === spreadStart + 1;
        }
      }
      pageView.hidden = !visible;
    }
    if (displayMode === "double" && pageNumber > 1) {
      const right = Math.min(pageNumber + 1, pdfDoc.numPages);
      pageLabel.textContent =
        right === pageNumber
          ? `${pageNumber} / ${pdfDoc.numPages}`
          : `${pageNumber}-${right} / ${pdfDoc.numPages}`;
    } else {
      pageLabel.textContent = `${pageNumber} / ${pdfDoc.numPages}`;
    }
  }

  function pageViewFor(number) {
    return stage.querySelector(`.pageContainer[data-page="${number}"]`);
  }

  function scrollToPage(number, offset) {
    pageNumber = normalizePageNumber(number);
    updateVisiblePages();
    const pageView = pageViewFor(pageNumber);
    if (pageView && displayMode === "continuous") {
      window.scrollTo(0, pageView.offsetTop + Number(offset || 0));
    } else {
      // Single/double: pin to top so only the current spread is visible.
      window.scrollTo(0, 0);
    }
    scheduleLazyRender();
  }

  function turnPages(direction) {
    if (!pdfDoc) {
      return;
    }
    const step = pageStep();
    const next = normalizePageNumber(pageNumber + direction * step);
    if (next === pageNumber && displayMode === "double") {
      // At end of odd last page already snapped; nothing to do.
      return;
    }
    if (next === pageNumber && direction !== 0) {
      return;
    }
    scrollToPage(next, 0);
    reportLocation();
  }

  function updateCurrentPageFromScroll() {
    if (!pdfDoc || displayMode !== "continuous") {
      return;
    }
    const viewportAnchor = window.scrollY + Math.max(window.innerHeight * 0.35, 96);
    let closestPage = pageNumber;
    let closestDistance = Number.POSITIVE_INFINITY;
    for (const pageView of stage.querySelectorAll(".pageContainer")) {
      const number = Number(pageView.dataset.page || 0);
      const distance = Math.abs(pageView.offsetTop - viewportAnchor);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPage = number;
      }
    }
    if (closestPage !== pageNumber) {
      pageNumber = closestPage;
      updateVisiblePages();
      scheduleLazyRender();
    } else {
      scheduleLazyRender();
    }
  }

  function updateZoomPreset() {
    if (!zoomPreset) {
      return;
    }
    if (zoomMode !== "custom") {
      zoomPreset.value = zoomMode;
      return;
    }
    const fixed = ["1", "1.25", "1.5"].find((value) => Math.abs(Number(value) - zoom) < 0.001);
    zoomPreset.value = fixed || "custom";
  }

  function reportTextSelection() {
    if (!documentTextLayerAvailable) {
      return;
    }
    const selection = window.getSelection();
    const text = selection ? selection.toString().trim() : "";
    if (!text) {
      return;
    }
    const range = selection.rangeCount ? selection.getRangeAt(0) : null;
    if (!range || range.collapsed) {
      return;
    }
    const container = range.commonAncestorContainer;
    const element = container && container.nodeType === Node.TEXT_NODE ? container.parentElement : container;
    const pageView = element && element.closest ? element.closest(".pageContainer") : pageViewFor(pageNumber);
    const selectedPage = Number(pageView && pageView.dataset.page ? pageView.dataset.page : pageNumber);
    const selectionRects = normalizedSelectionRects(range, selectedPage);
    // Prefer the first real client rect over getBoundingClientRect so multi-line
    // selections anchor the action menu to the first line, not a tall union box.
    const firstClientRect = firstPositiveClientRect(range);
    const boundingRect = firstClientRect || (range ? range.getBoundingClientRect() : null);
    const sourceRect = boundingRect && boundingRect.width && boundingRect.height
      ? {
          x: boundingRect.left,
          y: boundingRect.top,
          width: boundingRect.width,
          height: boundingRect.height,
        }
      : null;
    pageNumber = selectedPage;
    send("textSelected", {
      text,
      locator: {
        type: "pdf",
        page: selectedPage,
        scrollOffset: currentScrollOffset(),
        zoom: Number(pageView && pageView.dataset.scale ? pageView.dataset.scale : zoom),
        progress: currentProgress(),
        excerpt: text,
        selectionRects,
      },
      sourceRect,
      selectionRects,
    });
  }

  function firstPositiveClientRect(range) {
    if (!range) {
      return null;
    }
    for (const rect of Array.from(range.getClientRects())) {
      if (rect.width > 0 && rect.height > 0) {
        return rect;
      }
    }
    return null;
  }

  function normalizedSelectionRects(range, fallbackPage) {
    if (!range) {
      return [];
    }
    const rects = [];
    for (const rect of Array.from(range.getClientRects())) {
      if (rect.width <= 0 || rect.height <= 0) {
        continue;
      }
      const pageView = pageViewForRect(rect) || pageViewFor(fallbackPage);
      if (!pageView) {
        continue;
      }
      const pageRect = pageView.getBoundingClientRect();
      if (pageRect.width <= 0 || pageRect.height <= 0) {
        continue;
      }
      const x = clamp((rect.left - pageRect.left) / pageRect.width, 0, 1);
      const y = clamp((rect.top - pageRect.top) / pageRect.height, 0, 1);
      const width = clamp(rect.width / pageRect.width, 0, 1 - x);
      const height = clamp(rect.height / pageRect.height, 0, 1 - y);
      const page = Number(pageView.dataset.page || fallbackPage);
      rects.push({ page, x, y, width, height });
    }
    return rects;
  }

  function pageViewForRect(rect) {
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    for (const pageView of stage.querySelectorAll(".pageContainer")) {
      const pageRect = pageView.getBoundingClientRect();
      if (
        centerX >= pageRect.left &&
        centerX <= pageRect.right &&
        centerY >= pageRect.top &&
        centerY <= pageRect.bottom
      ) {
        return pageView;
      }
    }
    return null;
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  async function goTo(locator) {
    if (!pdfDoc) {
      return;
    }
    const nextPage = Math.min(Math.max(Number(locator && locator.page ? locator.page : pageNumber), 1), pdfDoc.numPages);
    const nextZoom = Number(locator && locator.zoom ? locator.zoom : zoom);
    pageNumber = nextPage;
    if (Number.isFinite(nextZoom) && Math.abs(nextZoom - zoom) > 0.001) {
      zoomMode = "custom";
      zoom = Math.min(3, Math.max(0.5, nextZoom));
      await renderDocument({ restorePage: nextPage, restoreOffset: Number(locator && locator.scrollOffset ? locator.scrollOffset : 0) });
      flashLocator(locator);
      return;
    }
    scrollToPage(nextPage, Number(locator && locator.scrollOffset ? locator.scrollOffset : 0));
    flashLocator(locator);
    reportLocation();
  }

  function flashLocator(locator) {
    try {
      clearSearchHighlights();
      if (!locator) {
        return;
      }
      const page = Math.min(
        Math.max(Number(locator.page || pageNumber || 1), 1),
        pdfDoc ? pdfDoc.numPages : Number(locator.page || 1)
      );
      let needle = String(locator.excerpt || "").trim();
      if (!needle) {
        return;
      }
      needle = needle.replace(/\s+/g, " ");
      if (needle.length > 48) {
        needle = needle.slice(0, 48).trim();
      }
      const lower = needle.toLocaleLowerCase();
      const pageView = pageViewFor(page);
      if (!pageView) {
        // Page not mounted yet; retry shortly after continuous layout settles.
        window.setTimeout(function () {
          flashLocator(locator);
        }, 120);
        return;
      }
      let matched = false;
      for (const span of pageView.querySelectorAll(".textLayer span")) {
        const text = (span.textContent || "").toLocaleLowerCase();
        if (!text) {
          continue;
        }
        if (text.includes(lower) || lower.includes(text) || shareToken(text, lower)) {
          span.classList.add("searchHit");
          span.classList.add("focusHit");
          matched = true;
        }
      }
      if (matched) {
        window.setTimeout(function () {
          for (const span of stage.querySelectorAll(".focusHit")) {
            span.classList.remove("focusHit");
            // Keep searchHit if a real search session is active.
            if (!lastSearchResults.length) {
              span.classList.remove("searchHit");
            }
          }
        }, 2200);
      }
    } catch (_) {
      // Flash is best-effort and must never break navigation.
    }
  }

  function shareToken(haystack, needle) {
    if (!haystack || !needle) {
      return false;
    }
    const token = needle.split(" ").find((part) => part.length >= 4);
    return Boolean(token && haystack.includes(token));
  }

  async function search(query) {
    try {
      const trimmed = String(query || "").trim();
      lastSearchResults = [];
      clearSearchHighlights();
      if (!trimmed) {
        send("searchResults", { query: trimmed, total: 0, results: [] });
        return;
      }
      if (!pdfDoc || !documentTextLayerAvailable) {
        send("renderNotice", { message: "此 PDF 没有可搜索文本" });
        send("searchResults", { query: trimmed, total: 0, results: [] });
        return;
      }
      const lower = trimmed.toLocaleLowerCase();
      const results = [];
      for (let page = 1; page <= pdfDoc.numPages; page += 1) {
        const pdfPage = await pdfDoc.getPage(page);
        const textContent = await pdfPage.getTextContent();
        const text = (textContent.items || []).map((item) => item.str || "").join(" ").trim();
        const lowerText = text.toLocaleLowerCase();
        let index = 0;
        let hit = 0;
        while (results.length < 200) {
          index = lowerText.indexOf(lower, index);
          if (index < 0) {
            break;
          }
          const start = Math.max(index - 48, 0);
          const end = Math.min(index + trimmed.length + 72, text.length);
          const snippet = text.substring(start, end);
          const progress = pdfDoc.numPages <= 1 ? 1 : (page - 1) / (pdfDoc.numPages - 1);
          results.push({
            title: `第 ${page} 页`,
            snippet,
            page,
            locator: {
              type: "pdf",
              page,
              scrollOffset: 0,
              zoom,
              progress,
              excerpt: snippet,
            },
            sortOrder: page * 10000 + hit,
          });
          index += Math.max(trimmed.length, 1);
          hit += 1;
        }
        if (results.length >= 200) {
          break;
        }
      }
      lastSearchResults = results;
      highlightSearchResults();
      send("searchResults", { query: trimmed, total: results.length, results });
    } catch (error) {
      reportError(error);
    }
  }

  function clearSearchHighlights() {
    for (const span of stage.querySelectorAll(".searchHit")) {
      span.classList.remove("searchHit");
    }
  }

  function highlightSearchResults() {
    clearSearchHighlights();
    if (!lastSearchResults.length) {
      return;
    }
    for (const hit of lastSearchResults) {
      const pageView = pageViewFor(hit.page);
      if (!pageView) {
        continue;
      }
      const needle = String(hit.locator && hit.locator.excerpt ? hit.locator.excerpt : hit.snippet || "")
        .trim()
        .slice(0, 24)
        .toLocaleLowerCase();
      if (!needle) {
        continue;
      }
      for (const span of pageView.querySelectorAll(".textLayer span")) {
        const text = span.textContent.toLocaleLowerCase();
        if (text && (text.includes(needle) || needle.includes(text))) {
          span.classList.add("searchHit");
        }
      }
    }
  }

  function applyAnnotations(payload) {
    annotations = Array.isArray(payload) ? payload : [];
    drawAnnotations();
  }

  function clearAnnotations() {
    annotations = [];
    drawAnnotations();
  }

  function drawAnnotations() {
    for (const layer of stage.querySelectorAll(".annotationLayer")) {
      layer.replaceChildren();
    }
    for (const annotation of annotations) {
      const rects = Array.isArray(annotation.rects) && annotation.rects.length
        ? annotation.rects
        : annotation.locator && Array.isArray(annotation.locator.selectionRects)
          ? annotation.locator.selectionRects
          : [];
      for (const rect of rects) {
        const page = Number(rect.page || (annotation.locator && annotation.locator.page) || 0);
        if (!page) {
          continue;
        }
        const pageView = pageViewFor(page);
        const layer = pageView && pageView.querySelector(".annotationLayer");
        if (!layer) {
          continue;
        }
        const mark = document.createElement("button");
        mark.type = "button";
        mark.className = `annotationMark ${annotation.style === "underline" ? "underline" : "highlight"}`;
        mark.dataset.annotationId = String(annotation.id || "");
        mark.style.left = `${Number(rect.x || 0) * 100}%`;
        mark.style.top = `${Number(rect.y || 0) * 100}%`;
        mark.style.width = `${Number(rect.width || 0) * 100}%`;
        mark.style.height = `${Number(rect.height || 0) * 100}%`;
        mark.style.setProperty("--annotation-color", annotationColor(annotation.color));
        mark.setAttribute("aria-label", "标注");
        mark.addEventListener("click", function (event) {
          event.preventDefault();
          event.stopPropagation();
          // Debounce multi-fire from WebView / double-handlers.
          const now = Date.now();
          if (
            mark.dataset.lastClickAt &&
            now - Number(mark.dataset.lastClickAt) < 350
          ) {
            return;
          }
          mark.dataset.lastClickAt = String(now);
          const client = mark.getBoundingClientRect();
          send("annotationSelected", {
            annotationId: annotation.id,
            sourceRect: {
              x: client.left,
              y: client.top,
              width: client.width,
              height: client.height,
            },
          });
        });
        layer.appendChild(mark);
      }
    }
  }

  function annotationColor(color) {
    if (color === "blue") {
      return "rgba(185, 215, 255, 0.58)";
    }
    if (color === "green") {
      return "rgba(189, 236, 203, 0.58)";
    }
    if (color === "red") {
      return "rgba(255, 184, 184, 0.58)";
    }
    if (color === "purple") {
      return "rgba(216, 199, 255, 0.58)";
    }
    return "rgba(255, 229, 138, 0.62)";
  }

  async function open(payload) {
    try {
      if (!window.pdfjsLib) {
        throw new Error("PDF.js 未加载");
      }

      applySettings(payload.settings || {});
      window.pdfjsLib.GlobalWorkerOptions.workerSrc = "pdf.worker.min.js";
      pdfDoc = await window.pdfjsLib.getDocument(payload.fileUrl).promise;
      documentTextLayerAvailable = await detectDocumentTextLayer();
      reportCapability();
      const locator = payload.locator || {};
      pageNumber = Math.min(Math.max(Number(locator.page || 1), 1), pdfDoc.numPages);
      const hasSavedZoom = Number.isFinite(Number(locator.zoom)) && Number(locator.zoom) > 0;
      zoomMode = normalizeZoomMode(settings.pdfZoomMode || "fit-width");
      // Narrow screens: desktop "custom" scales (e.g. 1.2) overflow and used to
      // look deformed. Prefer fit-width unless the user already picked fit-page.
      if (isNarrowViewport() && zoomMode === "custom") {
        zoomMode = "fit-width";
      }
      if (zoomMode === "actual") {
        zoom = 1;
      } else if (hasSavedZoom && zoomMode === "custom" && !isNarrowViewport()) {
        zoom = Number(locator.zoom);
      } else {
        zoom = Number(settings.pdfScale || zoom);
      }
      // Force continuous on phones even if settings say paged/double.
      if (!displayModeSelect.dataset.userSelected) {
        displayMode = preferredDisplayMode();
        displayModeSelect.value = displayMode;
        updateDisplayMode();
      }
      await reportOutline();
      await renderDocument({ restorePage: pageNumber, restoreOffset: Number(locator.scrollOffset || 0) });
      send("ready");
    } catch (error) {
      reportError(error);
    }
  }

  async function detectDocumentTextLayer() {
    if (!pdfDoc) {
      return false;
    }
    // Sample first pages only — scanning every page freezes large books on phones.
    const limit = Math.min(pdfDoc.numPages, 8);
    for (let page = 1; page <= limit; page += 1) {
      const pdfPage = await pdfDoc.getPage(page);
      const textContent = await pdfPage.getTextContent();
      if ((textContent.items || []).some((item) => Boolean(item.str && item.str.trim()))) {
        return true;
      }
    }
    // Heuristic fallback: middle page for scanned-front-matter books.
    if (pdfDoc.numPages > limit) {
      const mid = Math.max(1, Math.floor(pdfDoc.numPages / 2));
      const pdfPage = await pdfDoc.getPage(mid);
      const textContent = await pdfPage.getTextContent();
      if ((textContent.items || []).some((item) => Boolean(item.str && item.str.trim()))) {
        return true;
      }
    }
    return false;
  }

  async function reportOutline() {
    if (!pdfDoc) {
      send("outlineChanged", { items: [] });
      return;
    }
    try {
      const outline = await pdfDoc.getOutline();
      if (!outline || !outline.length) {
        send("outlineChanged", { items: [] });
        return;
      }
      const items = [];
      await appendOutlineItems(outline, 0, items);
      send("outlineChanged", { items });
    } catch (error) {
      console.warn("PDF outline unavailable", error);
      send("outlineChanged", { items: [] });
    }
  }

  async function appendOutlineItems(outlineItems, level, output) {
    for (const item of outlineItems || []) {
      const page = await pageNumberForDestination(item.dest);
      if (page) {
        output.push({
          title: item.title || `第 ${page} 页`,
          page,
          level,
        });
      }
      if (item.items && item.items.length) {
        await appendOutlineItems(item.items, level + 1, output);
      }
    }
  }

  async function pageNumberForDestination(destination) {
    if (!destination || !pdfDoc) {
      return null;
    }
    let resolved = destination;
    if (typeof destination === "string") {
      resolved = await pdfDoc.getDestination(destination);
    }
    if (!Array.isArray(resolved) || !resolved.length) {
      return null;
    }
    const reference = resolved[0];
    const pageIndex = await pdfDoc.getPageIndex(reference);
    return pageIndex + 1;
  }

  document.getElementById("prev").addEventListener("click", function () {
    turnPages(-1);
  });

  document.getElementById("next").addEventListener("click", function () {
    turnPages(1);
  });

  document.getElementById("zoomOut").addEventListener("click", async function () {
    zoomMode = "custom";
    zoom = Math.max(0.5, zoom - 0.1);
    await renderDocument({ restorePage: pageNumber });
  });

  document.getElementById("zoomIn").addEventListener("click", async function () {
    zoomMode = "custom";
    zoom = Math.min(3, zoom + 0.1);
    await renderDocument({ restorePage: pageNumber });
  });

  zoomPreset.addEventListener("change", async function () {
    const value = zoomPreset.value;
    if (value === "fit-width" || value === "fit-page" || value === "actual") {
      zoomMode = value;
    } else {
      const nextZoom = Number(value);
      if (Number.isFinite(nextZoom)) {
        zoomMode = "custom";
        zoom = Math.min(3, Math.max(0.5, nextZoom));
      }
    }
    await renderDocument({ restorePage: pageNumber });
  });

  displayModeSelect.addEventListener("change", function () {
    displayModeSelect.dataset.userSelected = "true";
    displayMode = displayModeSelect.value;
    updateDisplayMode();
    // Entering single/double: fit the spread so users don't need to scroll a tall page.
    if (displayMode === "single" || displayMode === "double") {
      if (zoomMode === "custom" || zoomMode === "fit-width" || zoomMode === "actual") {
        zoomMode = "fit-page";
      }
      renderDocument({ restorePage: pageNumber });
      return;
    }
    // Back to continuous: keep current page and allow scroll again.
    if (zoomMode === "fit-width" || zoomMode === "fit-page") {
      renderDocument({ restorePage: pageNumber });
    } else {
      scrollToPage(pageNumber, 0);
      reportLocation();
    }
  });

  window.addEventListener("scroll", function () {
    window.clearTimeout(scrollReportTimer);
    scrollReportTimer = window.setTimeout(function () {
      updateCurrentPageFromScroll();
      reportLocation();
    }, 60);
  });

  let resizeTimer = null;
  window.addEventListener("resize", function () {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(function () {
      if (!displayModeSelect.dataset.userSelected) {
        const nextMode = preferredDisplayMode();
        if (nextMode !== displayMode) {
          displayMode = nextMode;
          updateDisplayMode();
          updateVisiblePages();
        }
      }
      // After orientation / Flutter inset changes, re-fit pages on phones.
      if (pdfDoc && (zoomMode === "fit-width" || zoomMode === "fit-page" || isNarrowViewport())) {
        if (isNarrowViewport() && zoomMode === "custom") {
          zoomMode = "fit-width";
        }
        renderDocument({ restorePage: pageNumber, restoreOffset: currentScrollOffset() });
      } else {
        scheduleLazyRender();
      }
    }, 120);
  });

  // Horizontal swipe turns pages in single/double mode (mobile paged fallback).
  let touchStartX = 0;
  let touchStartY = 0;
  let touchStartAt = 0;
  stage.addEventListener(
    "touchstart",
    function (event) {
      if (!event.touches || event.touches.length !== 1) {
        return;
      }
      touchStartX = event.touches[0].clientX;
      touchStartY = event.touches[0].clientY;
      touchStartAt = Date.now();
    },
    { passive: true }
  );
  stage.addEventListener(
    "touchend",
    function (event) {
      if (!pdfDoc || !event.changedTouches || event.changedTouches.length !== 1) {
        return;
      }
      if (displayMode !== "single" && displayMode !== "double") {
        return;
      }
      const dx = event.changedTouches[0].clientX - touchStartX;
      const dy = event.changedTouches[0].clientY - touchStartY;
      const dt = Date.now() - touchStartAt;
      if (dt > 600) {
        return;
      }
      if (Math.abs(dx) < 56 || Math.abs(dx) < Math.abs(dy) * 1.4) {
        return;
      }
      turnPages(dx < 0 ? 1 : -1);
    },
    { passive: true }
  );

  stage.addEventListener("dblclick", async function () {
    if (!pdfDoc) {
      return;
    }
    if (zoomMode === "fit-width") {
      zoomMode = "actual";
      zoom = 1;
    } else {
      zoomMode = "fit-width";
    }
    await renderDocument({ restorePage: pageNumber });
  });

  window.addEventListener("wheel", function (event) {
    // Ctrl/Cmd + wheel: zoom (all modes).
    if (event.ctrlKey || event.metaKey) {
      event.preventDefault();
      zoomMode = "custom";
      const delta = event.deltaY < 0 ? 0.1 : -0.1;
      zoom = Math.min(3, Math.max(0.5, zoom + delta));
      renderDocument({ restorePage: pageNumber });
      return;
    }

    // Single/double: wheel turns pages (no free document scroll).
    if (displayMode === "single" || displayMode === "double") {
      // Ignore tiny trackpad jitter.
      if (Math.abs(event.deltaY) < 4 && Math.abs(event.deltaX) < 4) {
        return;
      }
      event.preventDefault();
      const vertical = Math.abs(event.deltaY) >= Math.abs(event.deltaX)
        ? event.deltaY
        : event.deltaX;
      if (vertical === 0) {
        return;
      }
      // Debounce rapid wheel bursts into one page turn.
      const now = Date.now();
      if (!window.__pageSageWheelAt) {
        window.__pageSageWheelAt = 0;
      }
      if (now - window.__pageSageWheelAt < 180) {
        return;
      }
      window.__pageSageWheelAt = now;
      turnPages(vertical > 0 ? 1 : -1);
    }
  }, { passive: false });

  window.addEventListener("keydown", function (event) {
    if (!pdfDoc) {
      return;
    }
    // Don't steal keys from form controls in the toolbar.
    const tag = (event.target && event.target.tagName) || "";
    if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") {
      return;
    }
    if (displayMode !== "single" && displayMode !== "double") {
      // Continuous: still allow PageUp/PageDown as viewport jumps via browser default.
      return;
    }
    switch (event.key) {
      case "ArrowRight":
      case "PageDown":
      case " ":
        event.preventDefault();
        turnPages(1);
        break;
      case "ArrowLeft":
      case "PageUp":
      case "Backspace":
        event.preventDefault();
        turnPages(-1);
        break;
      case "Home":
        event.preventDefault();
        scrollToPage(1, 0);
        reportLocation();
        break;
      case "End":
        event.preventDefault();
        scrollToPage(pdfDoc.numPages, 0);
        reportLocation();
        break;
      default:
        break;
    }
  });

  window.PageSageRenderer = {
    open,
    applySettings,
    goTo,
    search,
    clearSearchHighlights,
    applyAnnotations,
    clearAnnotations,
  };
})();
