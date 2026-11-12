#ifndef RUNNER_PDF_RENDER_BUDGET_H_
#define RUNNER_PDF_RENDER_BUDGET_H_

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace pagesage {

inline void ComputeOutputSize(double page_width, double page_height,
                              int32_t dpi, int32_t max_edge, int32_t max_pixels,
                              uint32_t* out_width, uint32_t* out_height) {
  if (dpi <= 0 || max_edge <= 0 || max_pixels <= 0 || page_width <= 0 ||
      page_height <= 0 || !std::isfinite(page_width) ||
      !std::isfinite(page_height)) {
    throw std::runtime_error("invalid render budget");
  }
  const double longest = (std::max)(page_width, page_height);
  const double scale = (std::min)(static_cast<double>(dpi) / 72.0,
                                  static_cast<double>(max_edge) / longest);
  double width = page_width * scale;
  double height = page_height * scale;
  const auto budget = static_cast<uint32_t>((std::min)(max_pixels, 5000000));
  if (width * height > budget) {
    const double factor = std::sqrt(budget / (width * height));
    width *= factor;
    height *= factor;
  }
  *out_width =
      (std::min)(budget, static_cast<uint32_t>((std::max)(1.0, width)));
  *out_height = (std::min)(budget / *out_width,
                           static_cast<uint32_t>((std::max)(1.0, height)));
}

}  // namespace pagesage

#endif
