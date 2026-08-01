import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/media_store.dart';

enum MediaImportFailureCode {
  missingSource,
  unsupportedType,
  tooLarge,
  invalidContent,
  copyFailed,
}

class MediaImportFailure implements Exception {
  const MediaImportFailure(this.code);
  final MediaImportFailureCode code;
}

class LocalMediaStore implements MediaStore {
  LocalMediaStore({
    Future<Directory> Function()? documentsDirectory,
    Uuid? uuid,
    this.maximumBytes = 10 * 1024 * 1024,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _uuid = uuid ?? const Uuid();

  static const directoryName = 'media';
  static const supportedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  final Future<Directory> Function() _documentsDirectory;
  final Uuid _uuid;
  final int maximumBytes;

  @override
  Future<String> importImage(PickedImage image) async {
    final source = File(image.sourcePath);
    if (!await source.exists()) {
      throw const MediaImportFailure(MediaImportFailureCode.missingSource);
    }
    final extension = _extensionFor(image.sourcePath, image.mimeType);
    if (extension == null) {
      throw const MediaImportFailure(MediaImportFailureCode.unsupportedType);
    }
    if (await image.length > maximumBytes) {
      throw const MediaImportFailure(MediaImportFailureCode.tooLarge);
    }

    late final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } catch (_) {
      throw const MediaImportFailure(MediaImportFailureCode.copyFailed);
    }
    final detectedExtension = _detectExtension(bytes);
    if (detectedExtension == null || detectedExtension != extension) {
      throw const MediaImportFailure(MediaImportFailureCode.invalidContent);
    }

    final reference = p.posix.join(directoryName, '${_uuid.v4()}$extension');
    final target = await _fileFor(reference, createDirectory: true);
    try {
      await target.writeAsBytes(bytes, flush: true);
      return reference;
    } catch (_) {
      if (await target.exists()) await target.delete();
      throw const MediaImportFailure(MediaImportFailureCode.copyFailed);
    }
  }

  @override
  Future<void> delete(String imageRef) async {
    final file = await _fileFor(imageRef);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Uint8List?> read(String imageRef) async {
    final file = await _fileFor(imageRef);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String? _validReference(String imageRef) {
    final normalized = p.posix.normalize(imageRef.replaceAll('\\', '/'));
    if (!p.posix.isWithin(directoryName, normalized)) return null;
    return normalized;
  }

  Future<File> _fileFor(String imageRef, {bool createDirectory = false}) async {
    final relativePath = _validReference(imageRef);
    if (relativePath == null) throw ArgumentError.value(imageRef, 'imageRef');
    final root = await _documentsDirectory();
    final mediaDirectory = Directory(p.join(root.path, directoryName));
    if (createDirectory) await mediaDirectory.create(recursive: true);
    return File(p.joinAll([root.path, ...p.posix.split(relativePath)]));
  }
}

String? _extensionFor(String sourcePath, String? mimeType) {
  final extension = p.extension(sourcePath).toLowerCase();
  final normalizedExtension = extension == '.jpeg' ? '.jpg' : extension;
  final mimeExtension = switch (mimeType?.toLowerCase()) {
    null => null,
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '',
  };
  if (LocalMediaStore.supportedExtensions.contains(extension) &&
      mimeExtension != null &&
      mimeExtension != normalizedExtension) {
    return null;
  }
  if (LocalMediaStore.supportedExtensions.contains(extension)) {
    return normalizedExtension;
  }
  return mimeExtension == '' ? null : mimeExtension;
}

String? _detectExtension(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return '.jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return '.png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return '.webp';
  }
  return null;
}
