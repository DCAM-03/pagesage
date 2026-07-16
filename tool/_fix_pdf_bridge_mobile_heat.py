from pathlib import Path
import re
import subprocess
import sys

path = Path("assets/renderer/pdf/bridge.js")
text = path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)


def find_line(pred, start=0):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return -1


# Remove legacy stub.
i = find_line(lambda l: "updateCurrentPageFromScrollLegacyRemoved" in l)
if i >= 0:
    del lines[i]
    print("removed legacy stub at", i + 1)

# Remove later duplicate scrollToPage (keep first definition).
first_scroll = find_line(lambda l: l.startswith("  function scrollToPage"))
second_scroll = find_line(
    lambda l: l.startswith("  function scrollToPage"), first_scroll + 1
)
print("scrollToPage defs", first_scroll + 1, second_scroll + 1)
if second_scroll >= 0:
    k = second_scroll + 1
    while k < len(lines):
        if lines[k].startswith("  function ") or lines[k].startswith(
            "  async function "
        ):
            break
        k += 1
    print("deleting second scrollToPage", second_scroll + 1, "to", k)
    del lines[second_scroll:k]

# Remove later duplicate updateCurrentPageFromScroll.
first_upd = find_line(lambda l: l.startswith("  function updateCurrentPageFromScroll"))
second_upd = find_line(
    lambda l: l.startswith("  function updateCurrentPageFromScroll"), first_upd + 1
)
print("updateCurrentPageFromScroll defs", first_upd + 1, second_upd + 1)
if second_upd >= 0:
    k = second_upd + 1
    while k < len(lines):
        if lines[k].startswith("  function ") or lines[k].startswith(
            "  async function "
        ):
            break
        k += 1
    print("deleting second updateCurrentPageFromScroll", second_upd + 1, "to", k)
    del lines[second_upd:k]

text = "".join(lines)

pat = re.compile(
    r"  function createPageView\(number, viewport, scale\) \{.*?\n"
    r"  async function renderPageView\(page, pageView, viewport, scale\) \{.*?\n"
    r"  \}\n\n  function resolveZoomForPage",
    re.S,
)
replacement = """  function createPageView(number, viewport, scale) {
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
    // Text layer is expensive. On phones only build when text is available.
    if (documentTextLayerAvailable) {
      await renderTextLayer(page, textLayer, viewport, scale);
    } else if (textLayer) {
      textLayer.replaceChildren();
    }
  }

  function resolveZoomForPage"""

new_text, n = pat.subn(replacement, text, count=1)
print("createPageView/renderPageView replaced", n)
if n != 1:
    sys.exit("failed to replace createPageView block")
text = new_text

text = text.replace(
    "    scrollToPage(next, 0);\n    reportLocation();\n  }\n\n  function updateZoomPreset",
    "    scrollToPage(next, 0);\n    scheduleLocationReport(false);\n  }\n\n  function updateZoomPreset",
)

old_scroll = """  window.addEventListener("scroll", function () {
    window.clearTimeout(scrollReportTimer);
    scrollReportTimer = window.setTimeout(function () {
      updateCurrentPageFromScroll();
      reportLocation();
    }, 60);
  });"""
new_scroll = """  window.addEventListener("scroll", function () {
    // While scrolling, only track page index. Heavy location/excerpt reports
    // wait until idle — critical for mobile heat.
    window.clearTimeout(scrollReportTimer);
    updateCurrentPageFromScroll();
    scrollReportTimer = window.setTimeout(function () {
      scheduleLocationReport(false);
    }, isNarrowViewport() ? 450 : 160);
  }, { passive: true });"""
if old_scroll not in text:
    sys.exit("scroll listener block not found")
text = text.replace(old_scroll, new_scroll)

old_resize_tail = """      // After orientation / Flutter inset changes, re-fit pages on phones.
      if (pdfDoc && (zoomMode === "fit-width" || zoomMode === "fit-page" || isNarrowViewport())) {
        if (isNarrowViewport() && zoomMode === "custom") {
          zoomMode = "fit-width";
        }
        renderDocument({ restorePage: pageNumber, restoreOffset: currentScrollOffset() });
      } else {
        scheduleLazyRender();
      }"""
new_resize_tail = """      // Re-fit only when viewport width changes meaningfully (rotation / split).
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
      scheduleLazyRender();"""
if old_resize_tail not in text:
    sys.exit("resize tail not found")
text = text.replace(old_resize_tail, new_resize_tail)

path.write_text(text, encoding="utf-8")
print("written", path)
print("lines", text.count("\n") + 1)

r = subprocess.run(
    ["node", "--check", str(path)], capture_output=True, text=True, check=False
)
print("node", r.returncode, (r.stderr or "ok")[:400])
if r.returncode != 0:
    sys.exit(r.returncode)
