cmake_minimum_required(VERSION 3.20)
project(pagesage_native_tests LANGUAGES CXX)
enable_testing()

add_executable(pdf_render_budget_test pdf_render_budget_test.cpp)
target_compile_features(pdf_render_budget_test PRIVATE cxx_std_17)
# The existing budget test uses assert, including in Release builds.
if(MSVC)
  target_compile_options(pdf_render_budget_test PRIVATE /UNDEBUG)
else()
  target_compile_options(pdf_render_budget_test PRIVATE -UNDEBUG)
endif()
add_test(NAME pdf_render_budget COMMAND pdf_render_budget_test)

if(WIN32)
  # Run `flutter build windows --release` first. Reuse its wrapper and engine
  # without creating a Flutter window or opening the user's library.
  get_filename_component(REPO_ROOT "../.." ABSOLUTE)
  set(FLUTTER_EPHEMERAL "${REPO_ROOT}/windows/flutter/ephemeral")
  set(WRAPPER_LIBRARY "${REPO_ROOT}/build/windows/x64/flutter/Release/flutter_wrapper_app.lib")
  if(NOT EXISTS "${WRAPPER_LIBRARY}")
    message(FATAL_ERROR "Run flutter build windows --release before native tests")
  endif()
  add_executable(windows_native_channels_test windows_native_channels_test.cpp)
  target_compile_features(windows_native_channels_test PRIVATE cxx_std_17)
  target_compile_definitions(windows_native_channels_test PRIVATE NOMINMAX)
  target_compile_options(windows_native_channels_test PRIVATE /utf-8 /await /EHsc)
  target_include_directories(windows_native_channels_test PRIVATE
    "${FLUTTER_EPHEMERAL}/cpp_client_wrapper/include" "${FLUTTER_EPHEMERAL}")
  target_link_libraries(windows_native_channels_test PRIVATE
    "${WRAPPER_LIBRARY}" "${FLUTTER_EPHEMERAL}/flutter_windows.dll.lib" windowsapp)
  add_custom_command(TARGET windows_native_channels_test POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${FLUTTER_EPHEMERAL}/flutter_windows.dll"
      "$<TARGET_FILE_DIR:windows_native_channels_test>")
  foreach(SCENARIO errors raster ocr)
    add_test(NAME windows_${SCENARIO} COMMAND windows_native_channels_test
      "${SCENARIO}" "${REPO_ROOT}/poc_pdf_canvas/samples/standard-text.pdf")
    set_tests_properties(windows_${SCENARIO} PROPERTIES TIMEOUT 90
      PASS_REGULAR_EXPRESSION "${SCENARIO} PASS")
  endforeach()
endif()
