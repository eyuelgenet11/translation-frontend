import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  var bytes = File('assets/icon/fffinal logo.png').readAsBytesSync();
  var image = img.decodeImage(bytes);
  if (image != null) {
    var newWidth = (image.width * 1.3).toInt();
    var newHeight = (image.height * 1.3).toInt();
    var paddedImage = img.Image(width: newWidth, height: newHeight);
    img.fill(paddedImage, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(paddedImage, image, dstX: ((newWidth - image.width) / 2).toInt(), dstY: ((newHeight - image.height) / 2).toInt());
    File('assets/icon/fffinal_logo_padded.png').writeAsBytesSync(img.encodePng(paddedImage));
    print('Padding complete!');
  }
}
