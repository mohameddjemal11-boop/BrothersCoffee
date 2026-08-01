import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/media_store.dart';

class DeviceImagePickerService implements ImagePickerService {
  DeviceImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImage?> pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return image == null ? null : XFilePickedImage(image);
  }
}

class XFilePickedImage implements PickedImage {
  const XFilePickedImage(this.file);
  final XFile file;

  @override
  Future<int> get length => file.length();

  @override
  String? get mimeType => file.mimeType;

  @override
  String get sourcePath => file.path;
}
