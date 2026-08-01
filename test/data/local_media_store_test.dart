import 'dart:io';

import 'package:brothers_coffee_pos/data/media/local_media_store.dart';
import 'package:brothers_coffee_pos/domain/repositories/media_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('brothers-coffee-media-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copies an image to a stable managed relative reference', () async {
    final source = File('${root.path}${Platform.pathSeparator}source.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 0x00]);
    final store = LocalMediaStore(documentsDirectory: () async => root);

    final reference = await store.importImage(_Picked(source.path));

    expect(reference, matches(r'^media/[0-9a-f-]+\.jpg$'));
    expect(reference, isNot(contains(root.path)));
    expect(await store.read(reference), [0xff, 0xd8, 0xff, 0x00]);
  });

  test(
    'uses a supported MIME type when the picker path has no extension',
    () async {
      final source = File('${root.path}${Platform.pathSeparator}picker-file');
      await source.writeAsBytes([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final store = LocalMediaStore(documentsDirectory: () async => root);

      final reference = await store.importImage(
        _Picked(source.path, mimeType: 'image/png'),
      );

      expect(reference, endsWith('.png'));
    },
  );

  test('rejects missing, unsupported, and oversized sources safely', () async {
    final store = LocalMediaStore(
      documentsDirectory: () async => root,
      maximumBytes: 2,
    );
    final unsupported = File('${root.path}${Platform.pathSeparator}photo.gif');
    await unsupported.writeAsBytes([1]);
    final oversized = File('${root.path}${Platform.pathSeparator}photo.png');
    await oversized.writeAsBytes([0x89, 0x50, 0x4e]);

    await expectLater(
      store.importImage(_Picked('${root.path}/missing.jpg')),
      throwsA(_failure(MediaImportFailureCode.missingSource)),
    );
    await expectLater(
      store.importImage(_Picked(unsupported.path)),
      throwsA(_failure(MediaImportFailureCode.unsupportedType)),
    );
    await expectLater(
      store.importImage(_Picked(oversized.path)),
      throwsA(_failure(MediaImportFailureCode.tooLarge)),
    );
    expect(await Directory('${root.path}/media').exists(), isFalse);
  });

  test('rejects valid extensions with invalid content', () async {
    final source = File('${root.path}${Platform.pathSeparator}fake.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final store = LocalMediaStore(documentsDirectory: () async => root);

    await expectLater(
      store.importImage(_Picked(source.path)),
      throwsA(_failure(MediaImportFailureCode.invalidContent)),
    );
  });

  test('rejects conflicting extension, MIME type, and content', () async {
    final source = File('${root.path}${Platform.pathSeparator}photo.jpg');
    await source.writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    final store = LocalMediaStore(documentsDirectory: () async => root);

    await expectLater(
      store.importImage(_Picked(source.path, mimeType: 'image/png')),
      throwsA(_failure(MediaImportFailureCode.unsupportedType)),
    );
    await expectLater(
      store.importImage(_Picked(source.path)),
      throwsA(_failure(MediaImportFailureCode.invalidContent)),
    );
  });

  test('managed references cannot escape the media directory', () async {
    final store = LocalMediaStore(documentsDirectory: () async => root);

    await expectLater(store.read('../outside.jpg'), throwsArgumentError);
    await expectLater(store.delete('/outside.jpg'), throwsArgumentError);
  });
}

class _Picked implements PickedImage {
  const _Picked(this.sourcePath, {this.mimeType});

  @override
  final String sourcePath;
  @override
  final String? mimeType;
  @override
  Future<int> get length => File(sourcePath).length();
}

Matcher _failure(MediaImportFailureCode code) =>
    isA<MediaImportFailure>().having((failure) => failure.code, 'code', code);
