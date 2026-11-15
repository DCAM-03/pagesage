#include "window_drop_paths.h"

#include <glib.h>

std::vector<std::string> LocalPathsFromUriList(const std::string& payload) {
  std::vector<std::string> paths;
  if (payload.find('\0') != std::string::npos ||
      !g_utf8_validate(payload.data(), payload.size(), nullptr)) {
    return paths;
  }
  g_auto(GStrv) uris = g_uri_list_extract_uris(payload.c_str());
  for (gchar** uri = uris; uri != nullptr && *uri != nullptr; ++uri) {
    g_autofree gchar* hostname = nullptr;
    g_autofree gchar* filename = g_filename_from_uri(*uri, &hostname, nullptr);
    if (filename == nullptr ||
        (hostname != nullptr && *hostname != '\0' &&
         g_ascii_strcasecmp(hostname, "localhost") != 0)) {
      continue;
    }
    g_autofree gchar* utf8 =
        g_filename_to_utf8(filename, -1, nullptr, nullptr, nullptr);
    if (utf8 != nullptr) {
      paths.emplace_back(utf8);
    }
  }
  return paths;
}
