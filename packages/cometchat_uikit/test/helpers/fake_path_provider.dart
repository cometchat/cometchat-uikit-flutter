/// A real, writable app-directory layout for tests, plus an in-process SQLite.
///
/// Two Kit paths are otherwise untestable on a desktop host:
///
/// * `platform_file_utils.getDownloadedFilePath` / `downloadFileToLocal` ask
///   `path_provider` for the documents / external-storage directory. With no
///   plugin registered those throw, so every "this attachment is already on
///   the device" branch collapses onto "not downloaded" and can never be
///   reached from a test.
/// * `CachedNetworkImage` (built by the Kit with no injectable cache manager)
///   goes through `DefaultCacheManager`, which needs both a directory from
///   `path_provider` AND an sqflite database. Without them it throws before it
///   ever produces an image or an error, so neither its `imageBuilder` nor its
///   `errorWidget` can be exercised.
///
/// [installFakePathProvider] points `path_provider` at a real temp directory
/// and [installInProcessSqlite] swaps sqflite's factory for the FFI one, which
/// runs the same SQLite the plugin runs, in-process. Together they let those
/// branches execute for real rather than being faked away.
library;

import 'dart:io';

// Neither package is a new dependency: both are already resolved transitively
// (path_provider and sqflite/flutter_cache_manager pull them in), and they are
// the only seams either library exposes.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers every `path_provider` query with one real directory.
class FakePathProviderPlatform extends PathProviderPlatform {
  /// Creates a provider rooted at [root].
  FakePathProviderPlatform(this.root);

  /// The directory every getter resolves to.
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;

  @override
  Future<String?> getLibraryPath() async => root;

  @override
  Future<String?> getExternalStoragePath() async => root;

  @override
  Future<List<String>?> getExternalCachePaths() async => <String>[root];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => <String>[root];

  @override
  Future<String?> getDownloadsPath() async => root;
}

/// Creates a temp directory, points `path_provider` at it, and returns it.
///
/// Call from `setUpAll` when a cache manager is involved: the Kit's cache
/// manager is a process-wide singleton that latches onto the first directory
/// it is given, so moving the directory between tests would be ignored.
/// Remove the directory yourself when the suite ends.
Directory installFakePathProvider({String prefix = 'cc_path_provider'}) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  PathProviderPlatform.instance = FakePathProviderPlatform(dir.path);
  return dir;
}

/// Gives `sqflite` a real, in-process SQLite implementation.
///
/// `flutter_cache_manager` stores its cache index in sqflite; on a VM test
/// host the plugin channel is absent and the global `databaseFactory` throws a
/// `StateError` that escapes as an unhandled async error, taking the test with
/// it. The FFI factory is the package's own supported substitute.
void installInProcessSqlite() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
