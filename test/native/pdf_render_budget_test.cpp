#include "../../windows/runner/pdf_render_budget.h"

#include <cassert>
#include <limits>

int main() {
  uint32_t width = 0;
  uint32_t height = 0;
  pagesage::ComputeOutputSize(612, 792, 200, 2200, 5000000, &width, &height);
  assert(width == 1700 && height == 2200);
  pagesage::ComputeOutputSize(1000, 1000, 300, 10000, 1000000, &width, &height);
  assert(width == 1000 && height == 1000);
  pagesage::ComputeOutputSize(1, 1000000, 300, 1000000, 3, &width, &height);
  assert(width >= 1 && height >= 1 && width * height <= 3);
  pagesage::ComputeOutputSize(10000, 10000, 600, 10000, 100000000, &width,
                              &height);
  assert(static_cast<uint64_t>(width) * height <= 5000000);
  bool rejected = false;
  try {
    pagesage::ComputeOutputSize(612, 792, 0, 2200, 5000000, &width, &height);
  } catch (const std::runtime_error&) {
    rejected = true;
  }
  assert(rejected);
  rejected = false;
  try {
    pagesage::ComputeOutputSize(std::numeric_limits<double>::infinity(), 792,
                                200, 2200, 5000000, &width, &height);
  } catch (const std::runtime_error&) {
    rejected = true;
  }
  assert(rejected);
}
