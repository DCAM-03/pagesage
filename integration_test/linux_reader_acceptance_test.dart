import 'reader_markdown_test.dart' as markdown;
import 'reader_ocr_workflow_test.dart' as ocr;
import 'reader_s0_test.dart' as pdf;
import 'settings_window_test.dart' as settings;

void main() {
  pdf.main();
  ocr.main();
  markdown.main();
  settings.main();
}
