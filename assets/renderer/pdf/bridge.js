(function () {
  let pdfDoc = null;
  let pageNumber = 1;
  let zoom = 1.2;
  let zoomMode = "custom";
  let displayMode = "continuous";
  let settings = {};
  /** PDF-native text layer (not OCR). */
  let nativeTextLayerAvailable = false;
  /** At least one OCR overlay is active in this viewer session. */
  let ocrTextLayerAvailable = false;
  /** Selection/search available via native text or OCR overlay. */
  let documentTextLayerAvailable = false;
  let lastSearchResults = [];
  let annotations = [];
  /** @type {Map<number, Array<{text:string,left:number,top:number,width:number,height:number}>>} */
  const ocrLayers = new Map();
  let renderVersion = 0;
  let scrollReportTimer = null;
  let lazyRenderTimer = null;
  let locationReportTimer = null;
  /** Active PDF.js render tasks, keyed by page number — cancelled when pages leave the window. */
  const pageRenderTasks = new Map();
  /** @type {Map<number, {pageView: HTMLElement, scale: number, rendered: boolean, rendering: boolean, width: number, height: number, top: number}>} */
  const pageRenderState = new Map();
  /** Uniform/sampled page metrics for virtual continuous layout on phones. */
  let pageMetrics = [];
  let virtualTotalHeight = 0;
  let useVirtualContinuous = false;
  let lastReportedPage = 0;

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

    const previousMode = displayMode;
    // Flutter readerMode drives continuous vs paged. Prefer it unless the user
    // explicitly picked a display mode this session (legacy HTML toolbar hook).
    if (!displayModeSelect || !displayModeSelect.dataset.userSelected) {
      displayMode = preferredDisplayMode();
      if (displayModeSelect) {
        displayModeSelect.value = displayMode;
      }
    }

    const nextZoomMode = normalizeZoomMode(settings.pdfZoomMode || zoomMode);
    const nextZoom = Number(settings.pdfScale || zoom);
    const zoomModeChanged = nextZoomMode !== zoomMode;
    const zoomChanged = Number.isFinite(nextZoom) && Math.abs(nextZoom - zoom) > 0.001;
    if (zoomModeChanged || zoomChanged) {
      zoomMode = nextZoomMode;
      if (zoomMode === "actual") {
        zoom = 1;
      } else if (Number.isFinite(nextZoom)) {
        zoom = Math.min(3, Math.max(0.5, nextZoom));
      }
    }

    if (!pdfDoc) {
      updateDisplayMode();
      return;
    }

    // Zoom/size geometry changed → full rebuild. Display mode alone → cheap path.
    if (zoomModeChanged || zoomChanged) {
      renderDocument({ restorePage: pageNumber, restoreOffset: currentScrollOffset() });
      return;
    }
    if (previousMode !== displayMode) {
      switchDisplayMode(displayMode, { restorePage: pageNumber });
      return;
    }
    updateDisplayMode();
  }

  function normalizeZoomMode(value) {
    if (value === "fit-width" || value === "fit-page" || value === "actual") {
      return value;
    }
    return "custom";
  }

  function preferredDisplayMode() {
    // Phones: continuous for scroll reading; map Flutter "paged" to single
    // (never double — spreads do not fit narrow widths).
    if (isNarrowViewport()) {
      return settings.readerMode === "paged" ? "single" : "continuous";
    }
    if (settings.readerMode === "paged") {
      return "double";
    }
    return "continuous";
  }

  function reportCapability() {
    documentTextLayerAvailable =
      nativeTextLayerAvailable || ocrTextLayerAvailable;
    send("capabilityChanged", {
      // Selection/search work with either native PDF text or OCR overlay.
      textSelection: documentTextLayerAvailable,
      search: documentTextLayerAvailable,
      // Native-only flag: Flutter uses this to keep the OCR entry visible on
      // scan PDFs even after OCR overlays make textSelection true.
      nativeTextLayer: nativeTextLayerAvailable,
      ocrTextLayer: ocrTextLayerAvailable,
      // Keep reason for Flutter tooltips/disabled states only — do not surface
      // as a floating toast. Persistent copy lives in menus/toolbars.
      reason: nativeTextLayerAvailable
        ? null
        : ocrTextLayerAvailable
          ? "已叠加 OCR 文本层，可划词。可再次「识别可见页」更新。"
          : "此 PDF 没有文本层，划词、高亮与搜索不可用。可使用「识别可见页」提取文字。",
    });
    // Hide the in-viewer banner permanently — it competes with Flutter chrome
    // and feels like a sticky warning during reading.
    if (textLayerStatus) {
      textLayerStatus.hidden = true;
    }
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
    if (useVirtualContinuous && pageMetrics[pageNumber - 1]) {
      return Math.max(window.scrollY - pageMetrics[pageNumber - 1].top, 0);
    }
    return Math.max(window.scrollY - pageView.offsetTop, 0);
  }

  function pageNumberFromScroll() {
    if (!pdfDoc) {
      return 1;
    }
    if (useVirtualContinuous && pageMetrics.length) {
      const y = window.scrollY + Math.max(window.innerHeight * 0.28, 48);
      // Binary search metrics tops.
      let lo = 0;
      let hi = pageMetrics.length - 1;
      while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        const top = pageMetrics[mid].top;
        const bottom = top + pageMetrics[mid].height;
        if (y < top) {
          hi = mid - 1;
        } else if (y > bottom) {
          lo = mid + 1;
        } else {
          return mid + 1;
        }
      }
      return Math.min(Math.max(lo + 1, 1), pdfDoc.numPages);
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
    return closestPage;
  }

  function updateCurrentPageFromScroll() {
    if (!pdfDoc || displayMode !== "continuous") {
      return;
    }
    const closestPage = pageNumberFromScroll();
    if (closestPage === pageNumber) {
      // Same page: do not re-enter ensure/highlight on every scroll tick.
      return;
    }
    pageNumber = closestPage;
    updateVisiblePages();
    scheduleLazyRender();
    if (closestPage !== lastReportedPage) {
      scheduleLocationReport(false);
    }
  }

  function scrollToPage(number, offset) {
    pageNumber = normalizePageNumber(number);
    updateVisiblePages();
    if (displayMode === "continuous") {
      if (useVirtualContinuous && pageMetrics[pageNumber - 1]) {
        window.scrollTo(0, pageMetrics[pageNumber - 1].top + Number(offset || 0));
      } else {
        const pageView = pageViewFor(pageNumber);
        if (pageView) {
          window.scrollTo(0, pageView.offsetTop + Number(offset || 0));
        }
      }
    } else {
      // Single/double: pin to top so only the current spread is visible.
      window.scrollTo(0, 0);
    }
    scheduleLazyRender();
  }


  function reportLocation(options) {
    if (!pdfDoc) {
      return;
    }
    // Excerpt scanning walks every text span with layout reads — too hot for
    // mobile scroll ticks. Only compute on explicit idle reports.
    const includeExcerpt =
      options && options.includeExcerpt === true && !isNarrowViewport();
    const scale = Number(pageViewFor(pageNumber)?.dataset.scale || zoom);
    const excerpt = includeExcerpt ? excerptNearViewport(pageNumber) : "";
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
    lastReportedPage = pageNumber;
  }

  function scheduleLocationReport(includeExcerpt) {
    if (locationReportTimer) {
      window.clearTimeout(locationReportTimer);
    }
    // Phones: report far less often; desktop keeps snappier progress saves.
    const delay = isNarrowViewport() ? 420 : 120;
    locationReportTimer = window.setTimeout(function () {
      locationReportTimer = null;
      reportLocation({ includeExcerpt: Boolean(includeExcerpt) });
    }, delay);
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
      // Cap work: only inspect a few spans near the top of the page box.
      const limit = Math.min(spans.length, 24);
      let best = "";
      for (let i = 0; i < limit; i += 1) {
        const text = (spans[i].textContent || "").replace(/\s+/g, " ").trim();
        if (text) {
          best = text;
          break;
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
    // Phones: prefer 1x raster. Reading does not need retina PDF bitmaps, and
    // 2–3x canvases are a primary heat source on mid-range Android.
    const dpr = Math.max(window.devicePixelRatio || 1, 1);
    const maxDpr = isNarrowViewport() ? 1.15 : 2.5;
    let outputScale = Math.min(dpr, maxDpr);
    if (isNarrowViewport()) {
      // Hard cap pixel budget roughly to one 1080p frame per page.
      const maxPixels = 2.0e6;
      const pixels = Math.max(cssWidth, 1) * Math.max(cssHeight, 1) * outputScale * outputScale;
      if (pixels > maxPixels) {
        outputScale = Math.sqrt(maxPixels / (Math.max(cssWidth, 1) * Math.max(cssHeight, 1)));
      }
      return Math.max(Math.min(outputScale, 1.15), 1);
    }
    const maxPixels = 12e6;
    const pixels = Math.max(cssWidth, 1) * Math.max(cssHeight, 1) * outputScale * outputScale;
    if (pixels > maxPixels) {
      outputScale = Math.sqrt(maxPixels / (Math.max(cssWidth, 1) * Math.max(cssHeight, 1)));
    }
    return Math.max(outputScale, 1);
  }

  function continuousRenderRadius() {
    // Prefetch neighbors so fling/scroll does not wait for idle settle.
    // Mobile stays tight for heat; desktop can keep a wider window.
    return isNarrowViewport() ? 1 : 2;
  }

  function cancelPageRenderTask(number) {
    const task = pageRenderTasks.get(number);
    if (task && typeof task.cancel === "function") {
      try {
        task.cancel();
      } catch (_) {
        // ignore cancel races
      }
    }
    pageRenderTasks.delete(number);
  }

  function releasePageRender(state, number) {
    if (!state) {
      return;
    }
    if (number) {
      cancelPageRenderTask(number);
    }
    if (!state.rendered && !state.rendering) {
      // Still drop empty layers if the node will be removed.
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
      canvas.style.width = `${state.width || 1}px`;
      canvas.style.height = `${state.height || 1}px`;
    }
    if (textLayer) {
      textLayer.replaceChildren();
    }
    if (state.pageView && state.pageView.dataset.page) {
      invalidateGlyphIndex(Number(state.pageView.dataset.page));
    }
    const annotationLayer = state.pageView.querySelector(".annotationLayer");
    if (annotationLayer) {
      annotationLayer.replaceChildren();
    }
    state.rendered = false;
    state.rendering = false;
  }

  function destroyPageState(number) {
    const state = pageRenderState.get(number);
    if (!state) {
      return;
    }
    releasePageRender(state, number);
    if (state.pageView && state.pageView.parentNode) {
      state.pageView.parentNode.removeChild(state.pageView);
    }
    pageRenderState.delete(number);
  }

  function scheduleLazyRender() {
    if (lazyRenderTimer) {
      window.clearTimeout(lazyRenderTimer);
    }
    // Wait until scrolling settles before spending CPU on rasterization.
    // Keep mobile short so the next page is ready before the next fling.
    const delay = isNarrowViewport() ? 90 : 48;
    lazyRenderTimer = window.setTimeout(function () {
      lazyRenderTimer = null;
      ensurePagesAround(pageNumber, renderVersion);
    }, delay);
  }

  function windowRangeFor(centerPage) {
    const center = normalizePageNumber(centerPage);
    if (displayMode === "continuous") {
      const radius = continuousRenderRadius();
      return {
        start: Math.max(1, center - radius),
        end: Math.min(pdfDoc.numPages, center + radius),
      };
    }
    if (displayMode === "double") {
      const spreadStart = spreadStartFor(center);
      // Prefetch next spread so double-page turns feel instant.
      const end = Math.min(
        pdfDoc.numPages,
        spreadStart === 1 ? 2 : spreadStart + 3
      );
      return {
        start: Math.max(1, spreadStart),
        end: end,
      };
    }
    // Single: current + next page prefetch.
    return {
      start: center,
      end: Math.min(pdfDoc.numPages, center + 1),
    };
  }

  let lastEnsuredRangeKey = "";

  async function ensurePagesAround(centerPage, version) {
    if (!pdfDoc || version !== renderVersion) {
      return;
    }
    if (useVirtualContinuous) {
      await syncVirtualWindow(centerPage, version);
      return;
    }

    const range = windowRangeFor(centerPage);
    const rangeKey = `${displayMode}:${range.start}-${range.end}:${version}`;
    const keepPad = isNarrowViewport() ? 1 : continuousRenderRadius() + 1;
    for (const [number, state] of pageRenderState.entries()) {
      if (number < range.start - keepPad || number > range.end + keepPad) {
        // In paged modes we can drop far shells entirely to cut DOM cost.
        if (displayMode === "single" || displayMode === "double") {
          destroyPageState(number);
        } else {
          releasePageRender(state, number);
        }
      }
    }

    // Render current page first, then neighbors. Create light shells on demand.
    const order = [];
    const center = normalizePageNumber(centerPage);
    order.push(center);
    for (let number = range.start; number <= range.end; number += 1) {
      if (number !== center) {
        order.push(number);
      }
    }
    for (const number of order) {
      if (version !== renderVersion) {
        return;
      }
      if (!pageRenderState.has(number)) {
        const metric = pageMetrics[number - 1] || pageMetrics[0];
        if (!metric) {
          continue;
        }
        const pageView = createPageViewBox(
          number,
          metric.width,
          metric.height,
          metric.scale
        );
        stage.appendChild(pageView);
        pageRenderState.set(number, {
          pageView,
          scale: metric.scale,
          rendered: false,
          rendering: false,
          width: metric.width,
          height: metric.height,
          top: 0,
        });
      }
      await renderPageIfNeeded(number, version);
    }

    if (version === renderVersion && rangeKey !== lastEnsuredRangeKey) {
      lastEnsuredRangeKey = rangeKey;
      // Only repaint overlays when the visible page set actually changed.
      highlightSearchResults();
      drawAnnotations();
    }
  }

  async function syncVirtualWindow(centerPage, version) {
    if (!pdfDoc || version !== renderVersion || !pageMetrics.length) {
      return;
    }
    const range = windowRangeFor(centerPage);
    // Drop pages outside a tight keep set.
    const keepPad = 1;
    for (const number of Array.from(pageRenderState.keys())) {
      if (number < range.start - keepPad || number > range.end + keepPad) {
        destroyPageState(number);
      }
    }

    const center = normalizePageNumber(centerPage);
    const order = [center];
    for (let number = range.start; number <= range.end; number += 1) {
      if (number !== center) {
        order.push(number);
      }
    }

    for (const number of order) {
      if (version !== renderVersion) {
        return;
      }
      const metric = pageMetrics[number - 1];
      if (!metric) {
        continue;
      }
      let state = pageRenderState.get(number);
      if (!state) {
        const pageView = createPageViewFromMetric(number, metric);
        if (useVirtualContinuous) {
          pageView.style.position = "absolute";
          pageView.style.left = "50%";
          pageView.style.top = `${metric.top}px`;
          pageView.style.transform = "translateX(-50%)";
        }
        stage.appendChild(pageView);
        state = {
          pageView,
          scale: metric.scale,
          rendered: false,
          rendering: false,
          width: metric.width,
          height: metric.height,
          top: metric.top,
        };
        pageRenderState.set(number, state);
      }
      await renderPageIfNeeded(number, version);
    }

    if (version === renderVersion) {
      const rangeKey = `v:${displayMode}:${range.start}-${range.end}:${version}`;
      if (rangeKey !== lastEnsuredRangeKey) {
        lastEnsuredRangeKey = rangeKey;
        highlightSearchResults();
        drawAnnotations();
      }
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
      await renderPageView(page, state.pageView, viewport, scale, number, version);
      if (version === renderVersion && pageRenderState.get(number) === state) {
        state.rendered = true;
      }
    } catch (error) {
      if (error && (error.name === "RenderingCancelledException" || /cancel/i.test(String(error.message || error)))) {
        return;
      }
      console.warn("PDF page render failed", number, error);
    } finally {
      if (state) {
        state.rendering = false;
      }
    }
  }

  async function buildPageMetrics(version) {
    pageMetrics = [];
    virtualTotalHeight = 0;
    if (!pdfDoc) {
      return;
    }
    const gap = isNarrowViewport() ? 10 : 16;
    // Sample page 1 for size. Most books share a single page size; this avoids
    // walking every page just to build spacers (major open-time heat).
    const first = await pdfDoc.getPage(1);
    if (version !== renderVersion) {
      return;
    }
    const baseScale = resolveZoomForPage(first);
    const baseViewport = first.getViewport({ scale: baseScale });
    const width = Math.max(Math.floor(baseViewport.width), 1);
    const height = Math.max(Math.floor(baseViewport.height), 1);
    let top = 0;
    for (let number = 1; number <= pdfDoc.numPages; number += 1) {
      pageMetrics.push({
        width,
        height,
        scale: baseScale,
        top,
      });
      top += height + gap;
    }
    // Remove trailing gap for total height.
    virtualTotalHeight = Math.max(top - gap, height);
  }

  function shouldVirtualizeContinuous() {
    // Virtual continuous is for long continuous scroll. Keep paged modes on
    // simple shells. Threshold: more than a few pages.
    return displayMode === "continuous" && !!pdfDoc && pdfDoc.numPages > 6;
  }

  function setStageLayoutMode(virtual) {
    useVirtualContinuous = !!virtual;
    stage.classList.toggle("virtual-continuous", useVirtualContinuous);
    if (useVirtualContinuous) {
      stage.style.position = "relative";
      stage.style.display = "block";
    } else {
      stage.style.position = "";
      stage.style.display = "";
      stage.style.height = "";
    }
  }

  /**
   * Cheap display-mode switch: keep already-rasterized pages when possible.
   * Only tears down shells when entering/leaving virtual continuous geometry.
   */
  async function switchDisplayMode(nextMode, options) {
    if (!pdfDoc) {
      displayMode = nextMode;
      updateDisplayMode();
      return;
    }
    const previousMode = displayMode;
    const previousVirtual = useVirtualContinuous;
    displayMode = nextMode;
    const nextVirtual = shouldVirtualizeContinuous();
    const restorePage = Math.min(
      Math.max(Number(options && options.restorePage ? options.restorePage : pageNumber), 1),
      pdfDoc.numPages
    );

    // Geometry model differs between virtual continuous and page shells.
    if (previousVirtual !== nextVirtual) {
      await renderDocument({ restorePage: restorePage });
      return;
    }

    updateDisplayMode();
    pageNumber = restorePage;
    if (displayMode === "double") {
      pageNumber = spreadStartFor(pageNumber);
    }

    // Entering single/double: prefer fit-page so a tall page doesn't force scroll.
    if (
      (displayMode === "single" || displayMode === "double") &&
      (zoomMode === "custom" || zoomMode === "fit-width" || zoomMode === "actual")
    ) {
      // Fit-page changes viewport scale → must rebuild metrics/shells.
      zoomMode = "fit-page";
      await renderDocument({ restorePage: pageNumber });
      return;
    }

    updateVisiblePages();
    updateZoomPreset();
    await ensurePagesAround(pageNumber, renderVersion);
    if (displayMode === "continuous") {
      scrollToPage(pageNumber, 0);
    } else {
      window.scrollTo(0, 0);
    }
    scheduleLocationReport(false);
    if (previousMode !== displayMode) {
      // no-op: kept for readability / future analytics
    }
  }

  async function renderDocument(options) {
    if (!pdfDoc) {
      return;
    }
    // Cancel any in-flight page renders from the previous layout.
    for (const number of Array.from(pageRenderTasks.keys())) {
      cancelPageRenderTask(number);
    }
    const version = ++renderVersion;
    const restorePage = Math.min(
      Math.max(Number(options && options.restorePage ? options.restorePage : pageNumber), 1),
      pdfDoc.numPages
    );
    const restoreOffset = Number(options && options.restoreOffset ? options.restoreOffset : 0);
    stage.replaceChildren();
    pageRenderState.clear();
    invalidateGlyphIndex();
    pageMetrics = [];
    virtualTotalHeight = 0;
    lastEnsuredRangeKey = "";
    // Continuous mode: virtualize for books with more than a few pages.
    // Never mount hundreds of page shells (major open/mode-switch heat).
    setStageLayoutMode(shouldVirtualizeContinuous());
    updateDisplayMode();

    if (useVirtualContinuous) {
      await buildPageMetrics(version);
      if (version !== renderVersion) {
        return;
      }
      stage.style.height = `${virtualTotalHeight}px`;
      pageNumber = restorePage;
      updateVisiblePages();
      updateZoomPreset();
      reportCapability();
      await ensurePagesAround(pageNumber, version);
      if (version !== renderVersion) {
        return;
      }
      scrollToPage(pageNumber, restoreOffset);
      scheduleLocationReport(false);
      return;
    }

    // Paged (single/double) or tiny continuous docs: light shells for nearby pages only.
    // Still avoid walking every page for scale — sample page 1 then clone metrics.
    await buildPageMetrics(version);
    if (version !== renderVersion) {
      return;
    }
    const metric = pageMetrics[0];
    if (!metric) {
      return;
    }
    // Always create the restore page shell immediately so open is never blank.
    const initialRangeStart = Math.max(1, restorePage - (displayMode === "double" ? 1 : 0));
    const initialRangeEnd = Math.min(
      pdfDoc.numPages,
      restorePage + (displayMode === "continuous" ? pdfDoc.numPages : displayMode === "double" ? 2 : 1)
    );
    if (displayMode === "continuous") {
      for (let number = 1; number <= pdfDoc.numPages; number += 1) {
        if (version !== renderVersion) {
          return;
        }
        const pageView = createPageViewBox(
          number,
          metric.width,
          metric.height,
          metric.scale
        );
        stage.appendChild(pageView);
        pageRenderState.set(number, {
          pageView,
          scale: metric.scale,
          rendered: false,
          rendering: false,
          width: metric.width,
          height: metric.height,
          top: 0,
        });
        if (number % 24 === 0) {
          await yieldToMain();
        }
      }
    } else {
      for (let number = initialRangeStart; number <= initialRangeEnd; number += 1) {
        if (version !== renderVersion) {
          return;
        }
        const pageView = createPageViewBox(
          number,
          metric.width,
          metric.height,
          metric.scale
        );
        stage.appendChild(pageView);
        pageRenderState.set(number, {
          pageView,
          scale: metric.scale,
          rendered: false,
          rendering: false,
          width: metric.width,
          height: metric.height,
          top: 0,
        });
      }
    }

    if (version !== renderVersion) {
      return;
    }
    pageNumber = restorePage;
    updateVisiblePages();
    updateZoomPreset();
    reportCapability();
    await ensurePagesAround(pageNumber, version);
    if (version !== renderVersion) {
      return;
    }
    scrollToPage(pageNumber, restoreOffset);
    scheduleLocationReport(false);
  }

  function createPageView(number, viewport, scale) {
    const cssWidth = Math.max(Math.floor(viewport.width), 1);
    const cssHeight = Math.max(Math.floor(viewport.height), 1);
    return createPageViewBox(number, cssWidth, cssHeight, scale);
  }

  function createPageViewFromMetric(number, metric) {
    return createPageViewBox(number, metric.width, metric.height, metric.scale);
  }

  function createPageViewBox(number, cssWidth, cssHeight, scale) {
    const pageView = document.createElement("section");
    pageView.className = "pageContainer";
    pageView.dataset.page = String(number);
    pageView.dataset.scale = String(scale);
    pageView.style.width = `${cssWidth}px`;
    pageView.style.height = `${cssHeight}px`;
    pageView.setAttribute("aria-label", `PDF 第 ${number} 页`);

    const canvas = document.createElement("canvas");
    canvas.className = "pageCanvas";
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
    textLayer.addEventListener("mouseup", function () {
      reportTextSelection({ immediate: true });
    });
    textLayer.addEventListener("touchend", function () {
      // Wait a beat for the browser to finalize the touch selection range.
      reportTextSelection();
    });
    // Do not report on every keyup — that re-fires while the selection is
    // still being adjusted and makes the host menu thrash.

    pageView.appendChild(canvas);
    pageView.appendChild(textLayer);
    pageView.appendChild(createAnnotationLayer(cssWidth, cssHeight));
    return pageView;
  }

  function createAnnotationLayer(cssWidth, cssHeight) {
    const layer = document.createElement("div");
    layer.className = "annotationLayer";
    layer.style.position = "absolute";
    layer.style.left = "0";
    layer.style.top = "0";
    layer.style.width = `${cssWidth}px`;
    layer.style.height = `${cssHeight}px`;
    layer.setAttribute("aria-hidden", "true");
    return layer;
  }

  async function renderPageView(page, pageView, viewport, scale, pageNumberForTask, version) {
    const canvas = pageView.querySelector(".pageCanvas");
    if (!canvas) {
      return;
    }
    cancelPageRenderTask(pageNumberForTask);
    const context = canvas.getContext("2d", { alpha: false });
    const cssWidth = Math.max(Math.floor(viewport.width), 1);
    const cssHeight = Math.max(Math.floor(viewport.height), 1);
    const outputScale = canvasOutputScale(cssWidth, cssHeight);
    canvas.width = Math.max(Math.floor(cssWidth * outputScale), 1);
    canvas.height = Math.max(Math.floor(cssHeight * outputScale), 1);
    canvas.style.width = `${cssWidth}px`;
    canvas.style.height = `${cssHeight}px`;
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
    const renderTask = page.render({
      canvasContext: context,
      viewport,
      transform: outputScale === 1 ? null : [outputScale, 0, 0, outputScale, 0, 0],
    });
    if (pageNumberForTask) {
      pageRenderTasks.set(pageNumberForTask, renderTask);
    }
    try {
      await renderTask.promise;
    } finally {
      if (pageNumberForTask) {
        pageRenderTasks.delete(pageNumberForTask);
      }
    }
    if (version && version !== renderVersion) {
      return;
    }
    // Text layer is expensive (thousands of absolute spans). On phones skip it
    // unless search/selection needs it — reading-only path stays cool.
    // OCR overlay pages always need the text layer container for selectable spans.
    const hasOcr = ocrLayers.has(pageNumberForTask);
    const needTextLayer =
      hasOcr ||
      (documentTextLayerAvailable &&
        (!isNarrowViewport() || lastSearchResults.length > 0));
    if (needTextLayer && documentTextLayerAvailable && !hasOcr) {
      await renderTextLayer(page, textLayer, viewport, scale);
    } else if (textLayer) {
      textLayer.replaceChildren();
      if (hasOcr) {
        renderOcrLayerForPage(pageNumberForTask, textLayer, Math.floor(viewport.width), Math.floor(viewport.height));
      }
    }
    // Marks are % of the page box. Redraw only this page after text/OCR is ready.
    if (version === renderVersion) {
      drawAnnotations({ page: pageNumberForTask });
    }
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
        // Baseline at tx[5]; box top = baseline - ascent (≈ fontHeight).
        const top = tx[5] - fontHeight;
        const span = document.createElement("span");
        span.textContent = item.str;
        span.style.left = `${left}px`;
        span.style.top = `${top}px`;
        span.style.fontSize = `${fontHeight}px`;
        // Explicit height keeps getClientRects() near glyph size (anti cross-line bleed).
        span.style.lineHeight = `${fontHeight}px`;
        span.style.height = `${fontHeight}px`;
        span.dataset.fontHeight = String(fontHeight);
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
      // Client rects change after layout; drop stale spatial index for this page.
      const pageNum = Number(
        textLayer.closest(".pageContainer") &&
          textLayer.closest(".pageContainer").dataset.page
      );
      if (pageNum) {
        invalidateGlyphIndex(pageNum);
      }
    } catch (error) {
      console.warn("PDF text layer unavailable", error);
    }
  }

  function updateDisplayMode() {
    document.documentElement.dataset.displayMode = displayMode;
    if (displayModeSelect) {
      displayModeSelect.value = displayMode;
    }
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

  /**
   * Pages currently on screen for OCR / selection actions.
   * continuous/single → [current]; double → [left] or [left, right].
   */
  function getVisiblePages() {
    if (!pdfDoc) {
      return [];
    }
    if (displayMode === "double") {
      const start = spreadStartFor(pageNumber);
      if (start <= 1) {
        return [1];
      }
      const right = Math.min(start + 1, pdfDoc.numPages);
      return right > start ? [start, right] : [start];
    }
    return [normalizePageNumber(pageNumber)];
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
    if (pageLabel) {
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
  }

  function pageViewFor(number) {
    return stage.querySelector(`.pageContainer[data-page="${number}"]`);
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
    // Raster the destination immediately so paged turns do not flash blank.
    pageNumber = next;
    updateVisiblePages();
    ensurePagesAround(next, renderVersion);
    scrollToPage(next, 0);
    scheduleLocationReport(false);
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

  let lastReportedSelectionKey = "";
  let selectionReportTimer = null;

  function reportTextSelection(options) {
    if (!documentTextLayerAvailable) {
      return;
    }
    const immediate = !!(options && options.immediate);
    // Coalesce bursty mouseup/touchend/keyup so the host is not flooded and
    // the native ::selection paint is not interrupted by Flutter rebuilds.
    window.clearTimeout(selectionReportTimer);
    if (!immediate) {
      selectionReportTimer = window.setTimeout(function () {
        reportTextSelection({ immediate: true });
      }, 80);
      return;
    }
    const selection = window.getSelection();
    const text = selection ? selection.toString().replace(/\s+/g, " ").trim() : "";
    if (!text) {
      lastReportedSelectionKey = "";
      return;
    }
    const range = selection.rangeCount ? selection.getRangeAt(0) : null;
    if (!range || range.collapsed) {
      lastReportedSelectionKey = "";
      return;
    }
    const container = range.commonAncestorContainer;
    const element =
      container && container.nodeType === Node.TEXT_NODE
        ? container.parentElement
        : container;
    const pageView =
      element && element.closest
        ? element.closest(".pageContainer")
        : pageViewFor(pageNumber);
    const selectedPage = Number(
      pageView && pageView.dataset.page ? pageView.dataset.page : pageNumber
    );
    // Selection geometry must match temporary ::selection (selected chars only).
    const selectionRects = normalizedSelectionRects(range, selectedPage);
    const firstClientRect = firstPositiveClientRect(range);
    const boundingRect =
      firstClientRect || (range ? range.getBoundingClientRect() : null);
    const sourceRect =
      boundingRect && boundingRect.width && boundingRect.height
        ? {
            x: boundingRect.left,
            y: boundingRect.top,
            width: boundingRect.width,
            height: boundingRect.height,
          }
        : null;
    // Deduplicate identical logical selections (same page + text).
    const selectionKey = `${selectedPage}\n${text}`;
    if (selectionKey === lastReportedSelectionKey) {
      return;
    }
    lastReportedSelectionKey = selectionKey;
    pageNumber = selectedPage;
    send("textSelected", {
      text,
      locator: {
        type: "pdf",
        page: selectedPage,
        scrollOffset: currentScrollOffset(),
        zoom: Number(
          pageView && pageView.dataset.scale ? pageView.dataset.scale : zoom
        ),
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

  /**
   * Mature PDF overlay approach (Hypothesis / PDF.js-style):
   * 1) Capture browser selection client rects (one strip per visual line).
   * 2) Store as page-normalized 0..1 boxes (scales with zoom automatically).
   * 3) Highlight paints the line box (slight inset).
   * 4) Underline paints a thin bar on the BOTTOM of that same box
   *    (y + height - thickness) — never invent a mid-line baseline.
   *
   * Avoid complex "glyph snap" rewrites of y/height: they drift across fonts.
   */

  /**
   * Permanent annotation geometry (Hypothesis / PDF.js overlay style):
   * 1) Capture selection via Range.getClientRects() (one strip per visual line).
   * 2) Clamp each strip against overlapping text-layer glyph boxes (anti-bleed).
   * 3) Store page-normalized 0..1 rects so marks scale with zoom/window.
   * 4) Highlight fills the line strip; underline is a thin bar on its BOTTOM edge.
   * Never invent mid-line baselines from font metrics alone.
   */

  function sortRectsTopLeft(items) {
    items.sort(function (a, b) {
      if (a.page !== b.page) {
        return a.page - b.page;
      }
      if (Math.abs(a.y - b.y) > 0.0005) {
        return a.y - b.y;
      }
      if (Math.abs((a.cy || a.y) - (b.cy || b.y)) > 0.0005) {
        return (a.cy || a.y) - (b.cy || b.y);
      }
      return a.x - b.x;
    });
    return items;
  }

  function pageBoxSize(pageView) {
    return {
      width: Math.max(
        pageView.clientWidth || 0,
        Number(String(pageView.style.width || "").replace("px", "")) || 0,
        1
      ),
      height: Math.max(
        pageView.clientHeight || 0,
        Number(String(pageView.style.height || "").replace("px", "")) || 0,
        1
      ),
    };
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

  /**
   * Spatial index of text-layer spans for a page.
   * Buckets by Y so selection clamping is O(nearby lines), not O(all spans).
   */
  const glyphIndexByPage = new Map(); // page -> { pageTop, bucketH, buckets: Map }

  function invalidateGlyphIndex(pageNumber) {
    if (pageNumber) {
      glyphIndexByPage.delete(Number(pageNumber));
      return;
    }
    glyphIndexByPage.clear();
  }

  function buildGlyphIndex(pageView) {
    const page = Number(pageView.dataset.page || 0);
    if (!page) {
      return null;
    }
    const textLayer = pageView.querySelector(".textLayer");
    if (!textLayer) {
      return null;
    }
    const pageRect = pageView.getBoundingClientRect();
    if (!(pageRect.height > 0)) {
      return null;
    }
    // ~3% of page height per bucket (≈ one line band on typical text pages).
    const bucketH = Math.max(pageRect.height * 0.03, 8);
    const buckets = new Map();
    const spans = textLayer.querySelectorAll("span");
    for (let i = 0; i < spans.length; i += 1) {
      const span = spans[i];
      const sr = span.getBoundingClientRect();
      if (!(sr.width > 0.5) || !(sr.height > 0.5)) {
        continue;
      }
      const fh = Number(span.dataset.fontHeight) || sr.height;
      const top = sr.top;
      const bottom = sr.top + fh;
      const entry = {
        left: sr.left,
        right: sr.right,
        top: top,
        bottom: bottom,
        width: sr.width,
        height: fh,
      };
      const startBucket = Math.floor((top - pageRect.top) / bucketH);
      const endBucket = Math.floor((bottom - pageRect.top) / bucketH);
      for (let b = startBucket; b <= endBucket; b += 1) {
        let list = buckets.get(b);
        if (!list) {
          list = [];
          buckets.set(b, list);
        }
        list.push(entry);
      }
    }
    const index = {
      pageTop: pageRect.top,
      pageBottom: pageRect.bottom,
      bucketH: bucketH,
      buckets: buckets,
      builtAt: Date.now(),
    };
    glyphIndexByPage.set(page, index);
    return index;
  }

  function glyphIndexForPageView(pageView) {
    const page = Number(pageView.dataset.page || 0);
    if (!page) {
      return null;
    }
    let index = glyphIndexByPage.get(page);
    // Rebuild when page moves (scroll) enough that client Y coordinates drift.
    if (index) {
      const pageRect = pageView.getBoundingClientRect();
      if (Math.abs(pageRect.top - index.pageTop) > 0.5) {
        index = null;
      }
    }
    if (!index) {
      index = buildGlyphIndex(pageView);
    }
    return index;
  }

  function forEachNearbyGlyphs(index, rect, visit) {
    if (!index || !index.buckets.size) {
      return;
    }
    const startBucket = Math.floor((rect.top - 2 - index.pageTop) / index.bucketH) - 1;
    const endBucket = Math.floor((rect.bottom + 2 - index.pageTop) / index.bucketH) + 1;
    const seen = new Set();
    for (let b = startBucket; b <= endBucket; b += 1) {
      const list = index.buckets.get(b);
      if (!list) {
        continue;
      }
      for (let i = 0; i < list.length; i += 1) {
        const entry = list[i];
        if (seen.has(entry)) {
          continue;
        }
        seen.add(entry);
        visit(entry);
      }
    }
  }

  /**
   * Intersect a browser selection client rect with live text-layer glyph boxes.
   * PDF text layers often return inflated selection heights that bleed into the
   * next line; clamping to overlapping spans matches Hypothesis-style overlays.
   */
  function clampClientRectToGlyphs(rect, pageView) {
    if (!rect || !pageView || !(rect.width > 0) || !(rect.height > 0)) {
      return rect;
    }
    const index = glyphIndexForPageView(pageView);
    if (!index) {
      return rect;
    }
    let glyphTop = null;
    let glyphBottom = null;
    forEachNearbyGlyphs(index, rect, function (sr) {
      // Require meaningful horizontal overlap with the selection strip.
      const overlapW =
        Math.min(rect.right, sr.right) - Math.max(rect.left, sr.left);
      if (overlapW < Math.min(rect.width, sr.width) * 0.12) {
        return;
      }
      // Vertical proximity: span intersects selection or sits inside inflated box.
      if (sr.bottom < rect.top - 1 || sr.top > rect.bottom + 1) {
        return;
      }
      if (glyphTop === null || sr.top < glyphTop) {
        glyphTop = sr.top;
      }
      if (glyphBottom === null || sr.bottom > glyphBottom) {
        glyphBottom = sr.bottom;
      }
    });
    if (glyphTop === null || glyphBottom === null || glyphBottom <= glyphTop) {
      return rect;
    }
    const glyphH = glyphBottom - glyphTop;
    // If selection is clearly taller than glyphs, snap to the glyph band.
    if (rect.height > glyphH * 1.12) {
      return {
        left: rect.left,
        top: glyphTop,
        width: rect.width,
        height: glyphH,
        right: rect.left + rect.width,
        bottom: glyphTop + glyphH,
      };
    }
    // Otherwise keep selection, but never extend past glyph band.
    const top = Math.max(rect.top, glyphTop);
    const bottom = Math.min(rect.bottom, glyphBottom);
    if (bottom - top < glyphH * 0.35) {
      return {
        left: rect.left,
        top: glyphTop,
        width: rect.width,
        height: glyphH,
        right: rect.left + rect.width,
        bottom: glyphTop + glyphH,
      };
    }
    return {
      left: rect.left,
      top: top,
      width: rect.width,
      height: bottom - top,
      right: rect.left + rect.width,
      bottom: bottom,
    };
  }

  function pageNormFromClientRect(rect, fallbackPage) {
    if (!rect || !(rect.width > 0) || !(rect.height > 0)) {
      return null;
    }
    const pageView = pageViewForRect(rect) || pageViewFor(fallbackPage);
    if (!pageView) {
      return null;
    }
    const clamped = clampClientRectToGlyphs(rect, pageView);
    const pageRect = pageView.getBoundingClientRect();
    if (!(pageRect.width > 0) || !(pageRect.height > 0)) {
      return null;
    }
    const x = clamp((clamped.left - pageRect.left) / pageRect.width, 0, 1);
    const y = clamp((clamped.top - pageRect.top) / pageRect.height, 0, 1);
    const width = clamp(clamped.width / pageRect.width, 0, 1 - x);
    const height = clamp(clamped.height / pageRect.height, 0, 1 - y);
    // Drop full-page / multi-line artifacts.
    if (height > 0.065 || width > 0.98 || width < 0.001 || height < 0.001) {
      return null;
    }
    return {
      page: Number(pageView.dataset.page || fallbackPage),
      x: x,
      y: y,
      width: width,
      height: height,
      cy: y + height * 0.5,
    };
  }

  /**
   * Merge horizontal fragments on the same baseline.
   * Keep a representative height (median-ish), never union bottoms that inflate bleed.
   */
  function mergeSameLineRects(items) {
    if (!items.length) {
      return [];
    }
    // Cluster ALL rects of this annotation by visual line (cy proximity),
    // regardless of x order. Sequential x-merge left same-line clusters
    // unmerged (legacy word boxes interleave), which double-painted lines.
    const byPage = new Map();
    for (const item of items) {
      if (!byPage.has(item.page)) {
        byPage.set(item.page, []);
      }
      byPage.get(item.page).push(item);
    }
    const merged = [];
    for (const [page, list] of byPage.entries()) {
      list.sort(function (a, b) {
        return a.cy - b.cy;
      });
      const clusters = [];
      for (const item of list) {
        const last = clusters.length ? clusters[clusters.length - 1] : null;
        const refH = Math.max(item.height, 0.004);
        if (last && Math.abs(item.cy - last.cyRef) <= refH * 0.5) {
          last.members.push(item);
          continue;
        }
        clusters.push({ cyRef: item.cy, members: [item] });
      }
      for (const cluster of clusters) {
        const ms = cluster.members;
        const xs = ms.map(function (m) {
          return m.x;
        });
        const rights = ms.map(function (m) {
          return m.x + m.width;
        });
        const tops = ms
          .map(function (m) {
            return m.y;
          })
          .sort(function (a, b) {
            return a - b;
          });
        const heights = ms
          .map(function (m) {
            return m.height;
          })
          .sort(function (a, b) {
            return a - b;
          });
        // Median top/height is robust against legacy outlier boxes.
        const y = tops[Math.floor(tops.length / 2)];
        const h = heights[Math.floor(heights.length / 2)];
        const x = Math.min.apply(null, xs);
        const right = Math.max.apply(null, rights);
        merged.push({
          page: page,
          x: x,
          y: y,
          width: Math.max(right - x, 0.001),
          height: Math.max(h, 0.002),
          cy: y + h * 0.5,
        });
      }
    }
    return sortRectsTopLeft(merged);
  }

  /** OCR line bands (normalized y ranges) for a page, sorted top→bottom. */
  /**
   * Distinct text LINE bands for a page, clustered top→bottom.
   * Sources: OCR span dataset geometry, or native text-layer span client rects.
   * Clustering matters: several spans share one visual line; treating each span
   * as its own band made "next band" a same-line sibling and crushed heights.
   */
  function lineBandsForPage(page) {
    const pageView = pageViewFor(page);
    if (!pageView) {
      return null;
    }
    const raw = [];
    const ocrLayer = pageView.querySelector(".textLayer.ocrLayer");
    if (ocrLayer) {
      for (const span of ocrLayer.querySelectorAll(".ocrSpan")) {
        const top = Number(span.dataset.top);
        const height = Number(span.dataset.height);
        if (Number.isFinite(top) && Number.isFinite(height) && height > 0) {
          raw.push({ top: top, bottom: top + height });
        }
      }
    } else {
      const textLayer = pageView.querySelector(".textLayer");
      if (!textLayer) {
        return null;
      }
      const pageRect = pageView.getBoundingClientRect();
      if (!(pageRect.height > 0)) {
        return null;
      }
      for (const span of textLayer.querySelectorAll("span")) {
        const r = span.getBoundingClientRect();
        if (!(r.height > 0) || !(r.width > 0)) {
          continue;
        }
        const top = (r.top - pageRect.top) / pageRect.height;
        const height = r.height / pageRect.height;
        if (height > 0 && height < 0.06) {
          raw.push({ top: top, bottom: top + height });
        }
      }
    }
    if (!raw.length) {
      return null;
    }
    raw.sort(function (a, b) {
      return a.top - b.top;
    });
    // Cluster boxes whose tops fall within half a line height of the cluster.
    const bands = [];
    for (const box of raw) {
      const last = bands.length ? bands[bands.length - 1] : null;
      if (last && box.top - last.top < (last.bottom - last.top) * 0.55) {
        last.top = Math.min(last.top, box.top);
        last.bottom = Math.max(last.bottom, box.bottom);
        continue;
      }
      bands.push({ top: box.top, bottom: box.bottom });
    }
    for (const band of bands) {
      band.cy = (band.top + band.bottom) * 0.5;
    }
    return bands;
  }

  /**
   * Paint-time safety net: snap each stored rect onto the nearest text line
   * band, and cap height by the local line PITCH so a dense page (line box ≈
   * pitch) never paints into the next line. Works for legacy tall rects too.
   */
  function snapRectsToLineBands(items) {
    const bandsByPage = new Map();
    const out = [];
    for (const item of items) {
      let bands = bandsByPage.get(item.page);
      if (bands === undefined) {
        bands = lineBandsForPage(item.page);
        bandsByPage.set(item.page, bands);
      }
      if (!bands || !bands.length) {
        // No line reference at all: cap so a legacy union box can never paint
        // as a multi-line slab (single line is ≤ ~16‰ everywhere we've seen).
        if (item.height > 0.016) {
          item.height = 0.016;
          item.cy = item.y + item.height * 0.5;
        }
        out.push(item);
        continue;
      }
      // Legacy multi-line union rect: SPLIT into one strip per covered band.
      const covered = bands.filter(function (band) {
        const overlap =
          Math.min(item.y + item.height, band.bottom) -
          Math.max(item.y, band.top);
        return overlap > (band.bottom - band.top) * 0.35;
      });
      if (covered.length >= 2) {
        for (const band of covered) {
          out.push(
            clampStripToBand(
              {
                page: item.page,
                x: item.x,
                y: band.top,
                width: item.width,
                height: band.bottom - band.top,
                cy: (band.top + band.bottom) * 0.5,
              },
              bands,
              band
            )
          );
        }
        continue;
      }
      // Single line: snap tall/drifted rects onto the nearest band.
      let best = null;
      let bestDist = Infinity;
      for (let i = 0; i < bands.length; i += 1) {
        const dist = Math.abs(bands[i].cy - item.cy);
        if (dist < bestDist) {
          bestDist = dist;
          best = bands[i];
        }
      }
      if (!best) {
        out.push(item);
        continue;
      }
      const bandH = best.bottom - best.top;
      if (item.height > bandH * 1.15 || item.y < best.top - bandH * 0.5) {
        item.y = best.top;
        item.height = bandH;
      } else {
        item.y = Math.max(item.y, best.top);
        item.height = Math.min(item.height, best.bottom - item.y);
      }
      out.push(clampStripToBand(item, bands, best));
    }
    return out;
  }

  /** Pitch cap within a band: never paint past ~78% of the local line pitch. */
  function clampStripToBand(item, bands, band) {
    const bandH = band.bottom - band.top;
    const idx = bands.indexOf(band);
    const nextBand = idx >= 0 ? bands[idx + 1] : null;
    if (nextBand) {
      const pitch = nextBand.top - band.top;
      if (pitch > 0.002) {
        const maxH = Math.max(pitch * 0.78, bandH * 0.5);
        if (item.height > maxH) {
          item.height = maxH;
        }
        const maxBottom = nextBand.top - 0.0012;
        if (item.y + item.height > maxBottom) {
          item.height = Math.max(maxBottom - item.y, bandH * 0.5);
        }
      }
    }
    item.cy = item.y + item.height * 0.5;
    return item;
  }

  /** If two selected lines touch, shorten the upper strip from the bottom only. */
  function preventAdjacentBleed(items) {
    sortRectsTopLeft(items);
    for (let i = 0; i < items.length - 1; i += 1) {
      const cur = items[i];
      const next = items[i + 1];
      if (cur.page !== next.page) {
        continue;
      }
      // Only trim against a TRUE next line — sub-line jitter used to be treated
      // as "next line" and crushed marks into 2‰ slivers.
      const pitch = next.y - cur.y;
      if (pitch < Math.max(cur.height, next.height) * 0.7) {
        continue;
      }
      const seam = 0.0012;
      if (cur.y + cur.height > next.y - seam) {
        cur.height = Math.max(next.y - seam - cur.y, cur.height * 0.5);
        cur.cy = cur.y + cur.height * 0.5;
      }
    }
    return items;
  }

  /**
   * Geometry for permanent annotations = browser selection client rects,
   * glyph-clamped so temporary ::selection and permanent marks stay aligned.
   */
  function normalizedSelectionRects(range, fallbackPage) {
    if (!range) {
      return [];
    }
    const items = [];
    const rawDump = [];
    for (const rect of Array.from(range.getClientRects())) {
      rawDump.push(`${Math.round(rect.width)}x${Math.round(rect.height)}`);
      const norm = pageNormFromClientRect(rect, fallbackPage);
      if (norm) {
        items.push(norm);
      }
    }
    if (!items.length) {
      return [];
    }
    const out = preventAdjacentBleed(mergeSameLineRects(items)).map(function (
      item
    ) {
      return {
        page: item.page,
        x: item.x,
        y: item.y,
        width: item.width,
        height: item.height,
      };
    });
    console.log(
      `[sel] raw=[${rawDump.join(",")}] final=` +
        out
          .map(function (r) {
            return `p${r.page} y=${(r.y * 1000).toFixed(1)} h=${(r.height * 1000).toFixed(1)}`;
          })
          .join(" | ")
    );
    return out;
  }

  /**
   * Drawable marks from stored line boxes.
   * - Underline: thin bar on the bottom edge of each line box.
   * - Highlight: fills the line box, ending just above the underline.
   * - Coordinates stay page-relative % so they adapt to zoom/window size.
   */
  function prepareHighlightRects(rawRects, locatorPage, isUnderline) {
    const items = [];
    for (const rect of rawRects || []) {
      if (!rect) {
        continue;
      }
      const page = Number(rect.page || locatorPage || 0);
      if (!page) {
        continue;
      }
      let x = clamp(Number(rect.x || 0), 0, 1);
      let y = clamp(Number(rect.y || 0), 0, 1);
      let w = Number(rect.width || 0);
      let h = Number(rect.height || 0);
      if (!(w > 0) || !(h > 0) || w > 0.98) {
        continue;
      }
      w = clamp(w, 0, 1 - x);
      h = clamp(h, 0, 1 - y);
      // Legacy multi-line mega-box: collapse to a readable single-line band.
      if (h > 0.055) {
        h = Math.min(h, 0.022);
      }
      items.push({
        page: page,
        x: x,
        y: y,
        width: w,
        height: h,
        cy: y + h * 0.5,
      });
    }
    if (!items.length) {
      return [];
    }

    const lines = preventAdjacentBleed(
      snapRectsToLineBands(mergeSameLineRects(items))
    );
    console.log(
      `[annot] stored=` +
        items
          .map(function (r) {
            return `h=${(r.height * 1000).toFixed(1)}`;
          })
          .join(",") +
        ` -> lines=` +
        lines
          .map(function (r) {
            return `p${r.page} y=${(r.y * 1000).toFixed(1)} h=${(r.height * 1000).toFixed(1)}`;
          })
          .join(" | ") +
        ` bands=${lineBandsForPage(lines.length ? lines[0].page : 0) ? "yes" : "NO"}`
    );
    const prepared = [];

    for (let i = 0; i < lines.length; i += 1) {
      const item = lines[i];
      const lineTop = item.y;
      let lineBottom = item.y + item.height;

      // Never invade the next selected line.
      for (let j = i + 1; j < lines.length; j += 1) {
        if (lines[j].page !== item.page) {
          break;
        }
        if (lines[j].y > item.y + 0.0004) {
          lineBottom = Math.min(lineBottom, lines[j].y - 0.0009);
          break;
        }
      }
      lineBottom = Math.max(lineBottom, lineTop + 0.0025);
      const lineH = lineBottom - lineTop;

      // Underline thickness: ~8% of line box, ~1.5–2.6 CSS px.
      let uh = lineH * 0.08;
      const pageView = pageViewFor(item.page);
      if (pageView) {
        const box = pageBoxSize(pageView);
        const minH = 1.5 / Math.max(box.height, 1);
        const maxH = 2.6 / Math.max(box.height, 1);
        uh = clamp(uh, minH, maxH);
      } else {
        uh = clamp(uh, 0.0014, 0.0032);
      }

      if (isUnderline) {
        // Classic overlay underline: stroke on the selection bottom edge.
        prepared.push({
          page: item.page,
          x: item.x,
          y: clamp(lineBottom - uh, 0, 1 - uh),
          width: item.width,
          height: uh,
          kind: "underline",
        });
      } else {
        // Highlight covers most of the selection box; stop just above underline.
        // User preference: highlight bottom meets underline top.
        const topInset = Math.min(lineH * 0.08, 0.0015);
        const markY = lineTop + topInset;
        const markBottom = lineBottom - uh;
        const markH = Math.max(markBottom - markY, lineH * 0.45);
        prepared.push({
          page: item.page,
          x: item.x,
          y: clamp(markY, 0, 1),
          width: item.width,
          height: clamp(markH, 0.002, 1 - markY),
          kind: "highlight",
        });
      }
    }
    return prepared;
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
    scheduleLocationReport(false);
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
        send("renderNotice", {
          message: "此 PDF 没有可搜索文本",
        });
        send("searchResults", { query: trimmed, total: 0, results: [] });
        return;
      }
      const lower = trimmed.toLocaleLowerCase();
      const results = [];
      for (let page = 1; page <= pdfDoc.numPages; page += 1) {
        if (isNarrowViewport() && page % 4 === 0) {
          await yieldToMain();
        }
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
      // Pages may have been rasterized without a text layer on phones. Force a
      // cheap re-render of the nearby window so search hits can paint.
      for (const state of pageRenderState.values()) {
        state.rendered = false;
      }
      await ensurePagesAround(pageNumber, renderVersion);
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

  /**
   * Overlay OCR text with normalized geometry onto a page text layer.
   * payload: { page, replace?, blocks: [{text,left,top,width,height}] }
   * Geometry is normalized 0..1 relative to the OCR bitmap / page box.
   */
  function applyOcrLayer(payload) {
    if (!payload || !pdfDoc) {
      return;
    }
    const page = Math.min(
      Math.max(Number(payload.page || 0), 1),
      pdfDoc.numPages
    );
    const replace = payload.replace !== false;
    const incoming = Array.isArray(payload.blocks) ? payload.blocks : [];
    const normalized = [];
    for (const item of incoming) {
      if (!item || !item.text) {
        continue;
      }
      const text = String(item.text);
      const left = Number(item.left);
      const top = Number(item.top);
      const width = Number(item.width);
      const height = Number(item.height);
      if (
        !Number.isFinite(left) ||
        !Number.isFinite(top) ||
        !Number.isFinite(width) ||
        !Number.isFinite(height) ||
        width <= 0 ||
        height <= 0
      ) {
        // Keep plain text blocks without geometry as a fallback line later.
        continue;
      }
      normalized.push({
        text: text,
        left: Math.min(Math.max(left, 0), 1),
        top: Math.min(Math.max(top, 0), 1),
        width: Math.min(Math.max(width, 0), 1),
        height: Math.min(Math.max(height, 0), 1),
      });
    }
    if (replace || !ocrLayers.has(page)) {
      ocrLayers.set(page, normalized);
    } else {
      ocrLayers.set(page, (ocrLayers.get(page) || []).concat(normalized));
    }

    // Ensure the page shell exists and paint the layer immediately.
    // Prefer canvas CSS size (matches OCR export space) over clientWidth.
    function pageCssSize(view) {
      if (!view) {
        return { width: 1, height: 1 };
      }
      const canvas = view.querySelector(".pageCanvas");
      const width = Math.max(
        Number(String(view.style.width || "").replace("px", "")) || 0,
        canvas && canvas.clientWidth ? canvas.clientWidth : 0,
        view.clientWidth || 0,
        1
      );
      const height = Math.max(
        Number(String(view.style.height || "").replace("px", "")) || 0,
        canvas && canvas.clientHeight ? canvas.clientHeight : 0,
        view.clientHeight || 0,
        1
      );
      return { width: width, height: height };
    }

    const pageView = pageViewFor(page);
    if (pageView) {
      const textLayer = pageView.querySelector(".textLayer");
      if (textLayer) {
        const size = pageCssSize(pageView);
        renderOcrLayerForPage(page, textLayer, size.width, size.height);
        // Marks may have painted before OCR bands existed — repaint clamped.
        drawAnnotations({ page: page });
      }
    } else {
      // Virtual continuous: force the page into the window so overlay can attach.
      ensurePagesAround(page, renderVersion).then(function () {
        const ready = pageViewFor(page);
        const layer = ready && ready.querySelector(".textLayer");
        if (layer) {
          const size = pageCssSize(ready);
          renderOcrLayerForPage(page, layer, size.width, size.height);
          drawAnnotations({ page: page });
        }
      });
    }
    // OCR pages become selectable even if the PDF had no native text layer.
    // Do NOT pretend the PDF has a *native* text layer — Flutter still needs
    // the OCR entry for other pages / re-run.
    if (normalized.length > 0) {
      const wasOcr = ocrTextLayerAvailable;
      ocrTextLayerAvailable = true;
      documentTextLayerAvailable = true;
      if (!wasOcr || !nativeTextLayerAvailable) {
        reportCapability();
      }
    }
  }

  function clearOcrLayer(page) {
    if (page) {
      ocrLayers.delete(Number(page));
      const pageView = pageViewFor(Number(page));
      const textLayer = pageView && pageView.querySelector(".textLayer");
      if (textLayer) {
        textLayer.replaceChildren();
      }
      return;
    }
    ocrLayers.clear();
    for (const pageView of stage.querySelectorAll(".pageContainer")) {
      const textLayer = pageView.querySelector(".textLayer");
      if (textLayer) {
        textLayer.replaceChildren();
      }
    }
  }

  /**
   * Export the currently rendered page canvas as a JPEG data URL for OCR.
   * Using the *display* canvas (not a separate native re-render) keeps OCR
   * coordinates 1:1 with the on-screen page box.
   *
   * @param {number|object} pageOrPayload 1-based page number or {page, quality}
   * @returns {{page:number, width:number, height:number, dataUrl:string}|null}
   */
  function exportPageImage(pageOrPayload) {
    if (!pdfDoc) {
      return null;
    }
    const page = Math.min(
      Math.max(
        Number(
          pageOrPayload && typeof pageOrPayload === "object"
            ? pageOrPayload.page
            : pageOrPayload
        ) || pageNumber,
        1
      ),
      pdfDoc.numPages
    );
    const qualityRaw =
      pageOrPayload && typeof pageOrPayload === "object"
        ? Number(pageOrPayload.quality)
        : 0.86;
    const quality = Math.min(Math.max(Number.isFinite(qualityRaw) ? qualityRaw : 0.86, 0.5), 0.95);

    let pageView = pageViewFor(page);
    const state = pageRenderState.get(page);
    // If the page is not in the virtual window / not rasterized yet, force it.
    if (!pageView || !state || !state.rendered) {
      // Synchronous best-effort: kick ensure; caller may retry shortly.
      ensurePagesAround(page, renderVersion);
      pageView = pageViewFor(page);
    }
    if (!pageView) {
      return null;
    }
    const canvas = pageView.querySelector(".pageCanvas");
    if (!canvas || canvas.width <= 1 || canvas.height <= 1) {
      return null;
    }
    // Prefer the CSS box size (matches text layer / overlay coordinates).
    const cssWidth = Math.max(
      pageView.clientWidth ||
        Number(String(pageView.style.width || "").replace("px", "")) ||
        canvas.clientWidth ||
        1,
      1
    );
    const cssHeight = Math.max(
      pageView.clientHeight ||
        Number(String(pageView.style.height || "").replace("px", "")) ||
        canvas.clientHeight ||
        1,
      1
    );

    // Downscale very large retina canvases for OCR transfer while preserving
    // aspect ratio. Overlay still uses CSS box + normalized geometry.
    let exportCanvas = canvas;
    const maxEdge = 1800;
    const longest = Math.max(canvas.width, canvas.height);
    if (longest > maxEdge) {
      const factor = maxEdge / longest;
      const w = Math.max(Math.floor(canvas.width * factor), 1);
      const h = Math.max(Math.floor(canvas.height * factor), 1);
      const tmp = document.createElement("canvas");
      tmp.width = w;
      tmp.height = h;
      const ctx = tmp.getContext("2d");
      if (ctx) {
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = "high";
        ctx.drawImage(canvas, 0, 0, w, h);
        exportCanvas = tmp;
      }
    }

    let dataUrl = "";
    try {
      dataUrl = exportCanvas.toDataURL("image/jpeg", quality);
    } catch (error) {
      console.warn("exportPageImage failed", error);
      return null;
    }
    if (!dataUrl || dataUrl.length < 32) {
      return null;
    }
    return {
      page: page,
      width: cssWidth,
      height: cssHeight,
      // Bitmap pixel size used for OCR (may differ from CSS when downscaled).
      imageWidth: exportCanvas.width,
      imageHeight: exportCanvas.height,
      dataUrl: dataUrl,
    };
  }

  function renderOcrLayerForPage(pageNumber, textLayer, cssWidth, cssHeight) {
    if (!textLayer) {
      return;
    }
    const blocks = layoutOcrLines(
      ocrLayers.get(pageNumber) || [],
      cssWidth,
      cssHeight
    );
    textLayer.replaceChildren();
    textLayer.classList.add("ocrLayer");
    textLayer.style.width = `${cssWidth}px`;
    textLayer.style.height = `${cssHeight}px`;
    textLayer.style.color = "transparent";
    textLayer.style.opacity = "1";
    textLayer.style.background = "transparent";
    const fragment = document.createDocumentFragment();
    for (const block of blocks) {
      const span = document.createElement("span");
      span.className = "ocrSpan";
      span.textContent = block.text;
      span.dataset.left = String(block.left);
      span.dataset.top = String(block.top);
      span.dataset.width = String(block.width);
      span.dataset.height = String(block.height);
      span.style.left = `${block.leftPx}px`;
      span.style.top = `${block.topPx}px`;
      span.style.width = `${block.widthPx}px`;
      span.style.height = `${block.heightPx}px`;
      span.style.fontSize = `${block.fontSize}px`;
      span.style.lineHeight = `${block.heightPx}px`;
      span.style.letterSpacing = "0px";
      span.style.whiteSpace = "pre";
      span.style.overflow = "hidden";
      span.style.transform = "none";
      fragment.appendChild(span);
    }
    textLayer.appendChild(fragment);
    // Brief flash so users can tell OCR landed.
    textLayer.classList.remove("ocrLayerFresh");
    void textLayer.offsetWidth;
    textLayer.classList.add("ocrLayerFresh");
    window.setTimeout(function () {
      textLayer.classList.remove("ocrLayerFresh");
    }, 900);
  }

  /** Build selectable OCR line hit targets from raw OCR boxes. */
  function layoutOcrLines(rawBlocks, cssWidth, cssHeight) {
    const items = [];
    for (const block of rawBlocks || []) {
      if (!block || !block.text) {
        continue;
      }
      let left = Number(block.left);
      let top = Number(block.top);
      let width = Number(block.width);
      let height = Number(block.height);
      if (
        !Number.isFinite(left) ||
        !Number.isFinite(top) ||
        !Number.isFinite(width) ||
        !Number.isFinite(height) ||
        width <= 0 ||
        height <= 0
      ) {
        continue;
      }
      left = clamp(left, 0, 0.999);
      top = clamp(top, 0, 0.999);
      width = clamp(width, 0.001, 1 - left);
      height = clamp(height, 0.001, 1 - top);
      if (height > 0.12) {
        height = 0.04;
      }
      items.push({
        text: String(block.text),
        left: left,
        top: top,
        width: width,
        height: height,
      });
    }
    if (!items.length) {
      // Fallback plain lines if geometry is missing.
      const plain = [];
      let y = 0.06;
      for (const block of rawBlocks || []) {
        if (!block || !block.text) {
          continue;
        }
        plain.push({
          text: String(block.text),
          left: 0.06,
          top: y,
          width: 0.88,
          height: 0.03,
        });
        y += 0.04;
        if (y > 0.95) {
          break;
        }
      }
      return plain.map(function (line) {
        return toLaidOutLine(line, cssWidth, cssHeight);
      });
    }

    items.sort(function (a, b) {
      const ac = a.top + a.height * 0.5;
      const bc = b.top + b.height * 0.5;
      if (Math.abs(ac - bc) > 0.006) {
        return ac - bc;
      }
      return a.left - b.left;
    });
    const lines = [];
    for (const item of items) {
      const last = lines.length ? lines[lines.length - 1] : null;
      if (!last) {
        lines.push(Object.assign({}, item));
        continue;
      }
      const refH = Math.max(Math.min(last.height, item.height), 0.004);
      const sameLine =
        Math.abs(
          last.top + last.height * 0.5 - (item.top + item.height * 0.5)
        ) <=
        refH * 0.4;
      const lastRight = last.left + last.width;
      const gap = item.left - lastRight;
      if (sameLine && gap >= -refH * 0.25 && gap <= refH * 1.2) {
        const needsSpace =
          !/\s$/.test(last.text) &&
          !/^\s/.test(item.text) &&
          !/[，。！？、；：,.!?;:)]$/.test(last.text) &&
          !/^[，。！？、；：,.!?;:(]/.test(item.text);
        last.text += (needsSpace ? " " : "") + item.text;
        const right = Math.max(lastRight, item.left + item.width);
        last.left = Math.min(last.left, item.left);
        last.top = Math.min(last.top, item.top);
        last.height = Math.max(last.height, item.height);
        last.width = Math.max(right - last.left, 0.001);
        continue;
      }
      lines.push(Object.assign({}, item));
    }

    lines.sort(function (a, b) {
      if (Math.abs(a.top - b.top) > 0.002) {
        return a.top - b.top;
      }
      return a.left - b.left;
    });
    return lines.map(function (line) {
      return toLaidOutLine(line, cssWidth, cssHeight);
    });
  }

  function toLaidOutLine(line, cssWidth, cssHeight) {
    const leftPx = line.left * cssWidth;
    let topPx = line.top * cssHeight;
    // Mature-reader rule (PDF.js text layer): the span line box must equal the
    // glyph box, so selection client rects — and thus annotations painted from
    // them — are automatically glyph-tight. Never inflate height here.
    let heightPx = Math.max(line.height * cssHeight, 6);
    heightPx = Math.min(heightPx, cssHeight * 0.06, 30);
    if (topPx + heightPx > cssHeight) {
      heightPx = Math.max(cssHeight - topPx, 6);
    }
    const widthPx = Math.max(line.width * cssWidth, 8);
    const fontSize = Math.max(Math.min(heightPx * 0.88, heightPx), 7);
    return {
      text: line.text,
      left: leftPx / cssWidth,
      top: topPx / cssHeight,
      width: widthPx / cssWidth,
      height: heightPx / cssHeight,
      leftPx: leftPx,
      topPx: topPx,
      widthPx: widthPx,
      heightPx: heightPx,
      fontSize: fontSize,
    };
  }

  function visibleAnnotationPages() {
    const pages = [];
    for (const [number, state] of pageRenderState.entries()) {
      if (state && state.pageView) {
        pages.push(Number(number));
      }
    }
    pages.sort(function (a, b) {
      return a - b;
    });
    return pages;
  }

  function annotationTouchesPages(annotation, pageSet) {
    const rawRects =
      Array.isArray(annotation.rects) && annotation.rects.length
        ? annotation.rects
        : annotation.locator && Array.isArray(annotation.locator.selectionRects)
          ? annotation.locator.selectionRects
          : [];
    for (const rect of rawRects) {
      const page = Number(rect && rect.page ? rect.page : 0);
      if (page && pageSet.has(page)) {
        return true;
      }
    }
    const locatorPage = Number(
      annotation.locator && annotation.locator.page
        ? annotation.locator.page
        : 0
    );
    return !!(locatorPage && pageSet.has(locatorPage));
  }

  /**
   * Draw permanent marks only for mounted page views (virtual window).
   * Avoid O(all annotations × all pages) work on every scroll/render tick.
   */
  // TEMP diagnostics: magenta outline on marks, cyan outline on line bands.
  const DEBUG_ANNOT_VISUAL = true;

  function drawAnnotations(options) {
    const onlyPage = options && Number(options.page) ? Number(options.page) : 0;
    const targetPages = onlyPage
      ? [onlyPage]
      : visibleAnnotationPages();
    if (!targetPages.length) {
      return;
    }
    const pageSet = new Set(targetPages);

    for (const page of targetPages) {
      const pageView = pageViewFor(page);
      const layer = pageView && pageView.querySelector(".annotationLayer");
      if (!layer) {
        continue;
      }
      layer.replaceChildren();
      const box = pageBoxSize(pageView);
      layer.style.width = `${box.width}px`;
      layer.style.height = `${box.height}px`;
      if (DEBUG_ANNOT_VISUAL) {
        const bands = lineBandsForPage(page);
        if (bands) {
          for (const band of bands) {
            const el = document.createElement("div");
            el.style.position = "absolute";
            el.style.left = "0";
            el.style.width = "100%";
            el.style.top = `${band.top * 100}%`;
            el.style.height = `${(band.bottom - band.top) * 100}%`;
            el.style.outline = "1px dashed rgba(0, 200, 220, 0.8)";
            el.style.pointerEvents = "none";
            layer.appendChild(el);
          }
        }
      }
    }

    for (const annotation of annotations) {
      if (!annotationTouchesPages(annotation, pageSet)) {
        continue;
      }
      const rawRects =
        Array.isArray(annotation.rects) && annotation.rects.length
          ? annotation.rects
          : annotation.locator && Array.isArray(annotation.locator.selectionRects)
            ? annotation.locator.selectionRects
            : [];
      const locatorPage = Number(
        annotation.locator && annotation.locator.page
          ? annotation.locator.page
          : 0
      );
      const isUnderline = annotation.style === "underline";
      const prepared = prepareHighlightRects(rawRects, locatorPage, isUnderline);
      for (const rect of prepared) {
        const page = Number(rect.page || locatorPage || 0);
        if (!page || !pageSet.has(page)) {
          continue;
        }
        const pageView = pageViewFor(page);
        const layer = pageView && pageView.querySelector(".annotationLayer");
        if (!layer) {
          continue;
        }
        const box = pageBoxSize(pageView);
        layer.style.width = `${box.width}px`;
        layer.style.height = `${box.height}px`;

        // Pure % of current page box → scales with zoom/window automatically.
        // Geometry already snapped to live text-layer glyph lines.
        const leftPct = Number(rect.x || 0) * 100;
        const topPct = Number(rect.y || 0) * 100;
        const widthPct = Number(rect.width || 0) * 100;
        let heightPct = Number(rect.height || 0) * 100;
        // Only a tiny visibility floor (~1.5px), proportional via page height.
        const minPct = (1.5 / Math.max(box.height, 1)) * 100;
        heightPct = Math.max(heightPct, minPct);

        const color = annotationColor(annotation.color);
        const mark = document.createElement("button");
        mark.type = "button";
        mark.className = `annotationMark ${isUnderline ? "underline" : "highlight"}`;
        mark.dataset.annotationId = String(annotation.id || "");
        mark.style.left = `${leftPct}%`;
        mark.style.top = `${topPct}%`;
        mark.style.width = `${widthPct}%`;
        mark.style.height = `${heightPct}%`;
        mark.style.setProperty("--annotation-color", color);
        if (isUnderline) {
          // Medium stroke: clear under the glyphs, not a solid marker pen.
          mark.style.background = underlineColor(annotation.color);
          mark.style.border = "0";
          mark.style.borderRadius = "1px";
          mark.style.opacity = "0.78";
          mark.style.mixBlendMode = "normal";
        } else {
          mark.style.background = color;
        }
        if (DEBUG_ANNOT_VISUAL) {
          mark.style.outline = "1px solid magenta";
        }
        mark.setAttribute("aria-label", "标注");
        mark.addEventListener("click", function (event) {
          event.preventDefault();
          event.stopPropagation();
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
      return "rgba(100, 170, 255, 0.34)";
    }
    if (color === "green") {
      return "rgba(96, 200, 130, 0.34)";
    }
    if (color === "red") {
      return "rgba(255, 120, 120, 0.32)";
    }
    if (color === "purple") {
      return "rgba(180, 140, 255, 0.34)";
    }
    return "rgba(255, 220, 90, 0.34)";
  }

  /** Medium underline stroke (clearer than highlight fill, softer than ink). */
  function underlineColor(color) {
    if (color === "blue") {
      return "rgba(55, 125, 220, 0.7)";
    }
    if (color === "green") {
      return "rgba(40, 150, 90, 0.7)";
    }
    if (color === "red") {
      return "rgba(215, 70, 70, 0.7)";
    }
    if (color === "purple") {
      return "rgba(140, 85, 215, 0.7)";
    }
    return "rgba(195, 145, 20, 0.7)";
  }

  async function open(payload) {
    try {
      if (!window.pdfjsLib) {
        throw new Error("PDF.js 未加载");
      }

      applySettings(payload.settings || {});
      window.pdfjsLib.GlobalWorkerOptions.workerSrc = "pdf.worker.min.js";
      pdfDoc = await window.pdfjsLib.getDocument(payload.fileUrl).promise;
      nativeTextLayerAvailable = await detectDocumentTextLayer();
      // Opening a document resets OCR overlays for this viewer session.
      ocrTextLayerAvailable = false;
      ocrLayers.clear();
      documentTextLayerAvailable = nativeTextLayerAvailable;
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
      if (!displayModeSelect || !displayModeSelect.dataset.userSelected) {
        displayMode = preferredDisplayMode();
        if (displayModeSelect) {
          displayModeSelect.value = displayMode;
        }
        updateDisplayMode();
      }
      // Outline can be slow on huge PDFs; don't block first paint.
      unawaitedOutline();
      await renderDocument({ restorePage: pageNumber, restoreOffset: Number(locator.scrollOffset || 0) });
      send("ready");
    } catch (error) {
      reportError(error);
    }
  }

  function unawaitedOutline() {
    Promise.resolve()
      .then(function () {
        return reportOutline();
      })
      .catch(function (error) {
        console.warn("PDF outline unavailable", error);
      });
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

  document.getElementById("prev")?.addEventListener("click", function () {
    turnPages(-1);
  });

  document.getElementById("next")?.addEventListener("click", function () {
    turnPages(1);
  });

  document.getElementById("zoomOut")?.addEventListener("click", async function () {
    zoomMode = "custom";
    zoom = Math.max(0.5, zoom - 0.1);
    await renderDocument({ restorePage: pageNumber });
  });

  document.getElementById("zoomIn")?.addEventListener("click", async function () {
    zoomMode = "custom";
    zoom = Math.min(3, zoom + 0.1);
    await renderDocument({ restorePage: pageNumber });
  });

  if (zoomPreset) {
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
  }

  if (displayModeSelect) {
    displayModeSelect.addEventListener("change", function () {
      displayModeSelect.dataset.userSelected = "true";
      // Cheap mode switch when possible; full rebuild only if geometry requires it.
      switchDisplayMode(displayModeSelect.value, { restorePage: pageNumber });
    });
  }

  window.addEventListener("scroll", function () {
    // While scrolling, only track page index. Heavy location/excerpt reports
    // wait until idle — critical for mobile heat.
    window.clearTimeout(scrollReportTimer);
    updateCurrentPageFromScroll();
    scrollReportTimer = window.setTimeout(function () {
      scheduleLocationReport(false);
    }, isNarrowViewport() ? 450 : 160);
  }, { passive: true });

  let resizeTimer = null;
  window.addEventListener("resize", function () {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(function () {
      if (!displayModeSelect || !displayModeSelect.dataset.userSelected) {
        const nextMode = preferredDisplayMode();
        if (nextMode !== displayMode) {
          displayMode = nextMode;
          updateDisplayMode();
          updateVisiblePages();
        }
      }
      // Re-fit only when viewport width changes meaningfully (rotation / split).
      // Flutter mobile chrome show/hide often fires resize with same width and
      // full re-render is a major heat source.
      const width = window.innerWidth || 0;
      const height = window.innerHeight || 0;
      if (!window.__pageSageLastSize) {
        window.__pageSageLastSize = { width: width, height: height };
      }
      const prev = window.__pageSageLastSize;
      const widthChanged = Math.abs(width - prev.width) >= 24;
      const heightChanged = Math.abs(height - prev.height) >= 96;
      window.__pageSageLastSize = { width: width, height: height };
      if (pdfDoc && (widthChanged || (heightChanged && (zoomMode === "fit-page")))) {
        if (isNarrowViewport() && zoomMode === "custom") {
          zoomMode = "fit-width";
        }
        if (zoomMode === "fit-width" || zoomMode === "fit-page" || widthChanged) {
          renderDocument({ restorePage: pageNumber, restoreOffset: currentScrollOffset() });
          return;
        }
      }
      scheduleLazyRender();
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
        scheduleLocationReport(false);
        break;
      case "End":
        event.preventDefault();
        scrollToPage(pdfDoc.numPages, 0);
        scheduleLocationReport(false);
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
    applyOcrLayer,
    clearOcrLayer,
    exportPageImage,
    getVisiblePages,
  };
})();
