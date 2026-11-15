#include <glib.h>

#include "../../linux/runner/window_drop_paths.h"

int main() {
  const auto paths = LocalPathsFromUriList(
      "# copied files\r\n"
      "file:///tmp/%E7%BA%BF%E6%80%A7%E4%BB%A3%E6%95%B0%20%237.pdf\r\n"
      "file://localhost/tmp/100%25.pdf\r\n");
  g_assert_cmpuint(paths.size(), ==, 2);
  g_assert_cmpstr(paths[0].c_str(), ==, "/tmp/线性代数 #7.pdf");
  g_assert_cmpstr(paths[1].c_str(), ==, "/tmp/100%.pdf");

  const auto rejected = LocalPathsFromUriList(
      "https://example.org/book.pdf\r\n"
      "file://remote-server/tmp/book.pdf\r\n"
      "not a file\r\n"
      "file:///tmp/invalid%ZZ.pdf\r\n");
  g_assert_true(rejected.empty());
  g_assert_true(LocalPathsFromUriList("").empty());
  g_assert_true(LocalPathsFromUriList("# no files\n\n").empty());
  g_assert_true(
      LocalPathsFromUriList(std::string("file:///tmp/a.pdf\0ignored", 25))
          .empty());
  g_assert_true(
      LocalPathsFromUriList(std::string("file:///tmp/\xff.pdf")).empty());

  const auto newline = LocalPathsFromUriList("file:///tmp/line%0Abreak.pdf\n");
  g_assert_cmpuint(newline.size(), ==, 1);
  g_assert_cmpstr(newline[0].c_str(), ==, "/tmp/line\nbreak.pdf");
  return 0;
}
