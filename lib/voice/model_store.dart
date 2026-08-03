import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'speech_engine.dart';

/// One file a model is made of, and how to know it arrived intact.
class ModelFile {
  final String name;
  final Uri source;
  final int bytes;

  /// Lowercase hex SHA-256. A truncated or corrupted model does not fail
  /// loudly — it loads and transcribes nonsense — so this is checked rather
  /// than trusted.
  final String sha256;

  const ModelFile({
    required this.name,
    required this.source,
    required this.bytes,
    required this.sha256,
  });
}

/// Everything one engine needs on disk.
class ModelSpec {
  final VoiceEngine engine;

  /// Bumped whenever the artefacts change. It is also the install directory's
  /// name, so an older version is simply a directory nothing looks in.
  final String version;
  final List<ModelFile> files;

  const ModelSpec({
    required this.engine,
    required this.version,
    required this.files,
  });

  /// What the download will cost, for the sheet that asks permission to spend
  /// it. Shown before anything is fetched.
  int get downloadBytes =>
      files.fold(0, (total, file) => total + file.bytes);
}

/// Downloading, verifying and deleting the speech models.
///
/// Models live outside the app bundle because they are far larger than the app
/// and only some users want voice mode at all. Nothing is fetched until the
/// mic is switched on for the first time.
class ModelStore {
  Future<Directory> directoryFor(ModelSpec spec) async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}/voice-models/${spec.engine.name}-${spec.version}',
    );
  }

  /// Whether every file is present at its full length. Cheap enough to call on
  /// the way into a session; the hashes are only checked while downloading.
  Future<bool> isInstalled(ModelSpec spec) async {
    final directory = await directoryFor(spec);
    for (final file in spec.files) {
      final target = File('${directory.path}/${file.name}');
      if (!target.existsSync() || await target.length() != file.bytes) {
        return false;
      }
    }
    return true;
  }

  /// Fetches whatever is missing, yielding progress in 0..1 across the whole
  /// spec. Throws if a file arrives corrupt, leaving nothing half-installed
  /// under its real name.
  Stream<double> install(ModelSpec spec) async* {
    final directory = await directoryFor(spec);
    await directory.create(recursive: true);
    final total = spec.downloadBytes;
    var done = 0;

    final client = HttpClient();
    try {
      for (final file in spec.files) {
        final target = File('${directory.path}/${file.name}');
        if (target.existsSync() && await target.length() == file.bytes) {
          done += file.bytes;
          yield done / total;
          continue;
        }
        // Downloaded beside the real name so an interrupted fetch can never be
        // mistaken for a working model.
        final partial = File('${target.path}.part');
        final sink = partial.openWrite();
        final digest = AccumulatorSink<Digest>();
        final hasher = sha256.startChunkedConversion(digest);
        try {
          final request = await client.getUrl(file.source);
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw HttpException(
              'HTTP ${response.statusCode} for ${file.source}',
            );
          }
          await for (final chunk in response) {
            sink.add(chunk);
            hasher.add(chunk);
            done += chunk.length;
            yield (done / total).clamp(0, 1);
          }
        } finally {
          await sink.close();
        }
        hasher.close();
        if (digest.events.single.toString() != file.sha256) {
          await partial.delete();
          throw const FileSystemException('downloaded model failed its hash');
        }
        await partial.rename(target.path);
      }
    } finally {
      client.close();
    }
    yield 1;
  }

  Future<void> remove(ModelSpec spec) async {
    final directory = await directoryFor(spec);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  /// Bytes currently held on disk by [spec], for the settings entry that
  /// offers to reclaim them.
  Future<int> installedBytes(ModelSpec spec) async {
    final directory = await directoryFor(spec);
    if (!directory.existsSync()) return 0;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
