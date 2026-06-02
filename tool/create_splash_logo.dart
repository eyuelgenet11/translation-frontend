import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  // Load the original logo
  final originalFile = File('assets/icon/TERGUM.png');
  if (!originalFile.existsSync()) {
    print('Error: assets/icon/TERGUM.png not found.');
    return;
  }
  
  final originalBytes = originalFile.readAsBytesSync();
  final original = img.decodeImage(originalBytes)!;

  // Dimensions
  const canvasSize = 1024;
  const rectSize = 512;
  const borderRadius = 61; // 24 * 512 / 200 = 61.44
  const padding = 41; // 16 * 512 / 200 = 40.96
  const logoArea = rectSize - (padding * 2); // 430

  // Create canvas (transparent background)
  final canvas = img.Image(width: canvasSize, height: canvasSize);
  
  // Fill the white rounded rect on the canvas
  final cx = canvasSize ~/ 2;
  final cy = canvasSize ~/ 2;
  final halfRect = rectSize ~/ 2;
  final startX = cx - halfRect;
  final startY = cy - halfRect;

  for (int y = 0; y < canvasSize; y++) {
    for (int x = 0; x < canvasSize; x++) {
      // Local coordinates relative to the top-left of the rounded rect
      final lx = x - startX;
      final ly = y - startY;

      if (lx >= 0 && lx < rectSize && ly >= 0 && ly < rectSize) {
        bool inside = true;
        // Check corners
        if (lx < borderRadius && ly < borderRadius) {
          // Top-left
          final dx = lx - borderRadius;
          final dy = ly - borderRadius;
          if (dx * dx + dy * dy > borderRadius * borderRadius) inside = false;
        } else if (lx >= rectSize - borderRadius && ly < borderRadius) {
          // Top-right
          final dx = lx - (rectSize - borderRadius - 1);
          final dy = ly - borderRadius;
          if (dx * dx + dy * dy > borderRadius * borderRadius) inside = false;
        } else if (lx < borderRadius && ly >= rectSize - borderRadius) {
          // Bottom-left
          final dx = lx - borderRadius;
          final dy = ly - (rectSize - borderRadius - 1);
          if (dx * dx + dy * dy > borderRadius * borderRadius) inside = false;
        } else if (lx >= rectSize - borderRadius && ly >= rectSize - borderRadius) {
          // Bottom-right
          final dx = lx - (rectSize - borderRadius - 1);
          final dy = ly - (rectSize - borderRadius - 1);
          if (dx * dx + dy * dy > borderRadius * borderRadius) inside = false;
        }

        if (inside) {
          canvas.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
  }

  // Scale the logo to fit in logoArea x logoArea
  final scaleX = logoArea / original.width;
  final scaleY = logoArea / original.height;
  final scale = min(scaleX, scaleY);

  final scaledW = (original.width * scale).round();
  final scaledH = (original.height * scale).round();

  final resizedLogo = img.copyResize(
    original,
    width: scaledW,
    height: scaledH,
    interpolation: img.Interpolation.cubic,
  );

  // Composite the logo in the center of the rounded rect
  final offsetX = startX + (rectSize - scaledW) ~/ 2;
  final offsetY = startY + (rectSize - scaledH) ~/ 2;
  
  img.compositeImage(canvas, resizedLogo, dstX: offsetX, dstY: offsetY);

  // Save the result
  final outFile = File('assets/icon/TERGUM_splash.png');
  outFile.writeAsBytesSync(img.encodePng(canvas));
  print('Saved: assets/icon/TERGUM_splash.png (1024x1024 with rounded rect and padding)');
}
