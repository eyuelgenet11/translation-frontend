import 'dart:io';

void main() async {
  final dir = Directory('assets/ss');
  final files = dir.listSync().whereType<File>().toList();
  for (var file in files) {
    if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
      final bytes = await file.readAsBytes();
      print('${file.path}: ${bytes.length} bytes');
    }
  }
}
