import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Load the original logo
  final originalFile = File('assets/icon/TERGUM.png');
  final originalBytes = originalFile.readAsBytesSync();
  final original = img.decodeImage(originalBytes)!;

  // Target square size for icon generation (1024x1024 is ideal)
  const targetSize = 1024;
  // Padding: 15% on each side so logo occupies 70% of the square
  const paddingFraction = 0.15;
  final padding = (targetSize * paddingFraction).round();
  final logoArea = targetSize - (padding * 2);

  // Scale the original proportionally to fit within logoArea x logoArea
  final scaleX = logoArea / original.width;
  final scaleY = logoArea / original.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final scaledW = (original.width * scale).round();
  final scaledH = (original.height * scale).round();

  final resized = img.copyResize(original, width: scaledW, height: scaledH, interpolation: img.Interpolation.cubic);

  // Create square canvas with white background
  final canvas = img.Image(width: targetSize, height: targetSize);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

  // Center the resized logo on the canvas
  final offsetX = (targetSize - scaledW) ~/ 2;
  final offsetY = (targetSize - scaledH) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

  // Save as padded icon
  final outFile = File('assets/icon/TERGUM_padded.png');
  outFile.writeAsBytesSync(img.encodePng(canvas));
  print('Saved: assets/icon/TERGUM_padded.png (${targetSize}x${targetSize})');
}
