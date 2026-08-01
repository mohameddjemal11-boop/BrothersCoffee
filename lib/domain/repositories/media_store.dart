import 'dart:typed_data';

abstract interface class PickedImage {
  String get sourcePath;
  String? get mimeType;
  Future<int> get length;
}

abstract interface class ImagePickerService {
  Future<PickedImage?> pickImage();
}

abstract interface class MediaStore {
  Future<String> importImage(PickedImage image);
  Future<void> delete(String imageRef);
  Future<Uint8List?> read(String imageRef);
}

class NoopMediaStore implements MediaStore {
  const NoopMediaStore();

  @override
  Future<String> importImage(PickedImage image) =>
      throw UnsupportedError('Media is unavailable in this host.');

  @override
  Future<void> delete(String imageRef) async {}

  @override
  Future<Uint8List?> read(String imageRef) async => null;
}

class NoopImagePickerService implements ImagePickerService {
  const NoopImagePickerService();

  @override
  Future<PickedImage?> pickImage() async => null;
}
