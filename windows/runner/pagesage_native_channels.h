#ifndef RUNNER_PAGESAGE_NATIVE_CHANNELS_H_
#define RUNNER_PAGESAGE_NATIVE_CHANNELS_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>

#include <memory>

#include <flutter/binary_messenger.h>

// Registers pagesage/pdf_raster and pagesage/ocr MethodChannels (Windows).
void RegisterPagesageNativeChannels(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_PAGESAGE_NATIVE_CHANNELS_H_
