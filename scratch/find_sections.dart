import 'dart:io';

void main() {
  final file = File('web_admin/index.html');
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.contains('<section id="view-')) {
      print('Line ${i + 1}: $l');
    }
  }
}
