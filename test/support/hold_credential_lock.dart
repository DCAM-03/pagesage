import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final file = await File(arguments.single).open(mode: FileMode.append);
  try {
    await file.lock(FileLock.exclusive);
    stdout.writeln('locked');
    await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  } finally {
    await file.close();
  }
}
