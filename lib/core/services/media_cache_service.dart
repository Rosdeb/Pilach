import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database/daos/media_cache_dao.dart';

class MediaCacheService {
  final MediaCacheDao _mediaCacheDao;
  final Dio _dio;

  MediaCacheService(this._mediaCacheDao, this._dio);

  Future<String?> getCachedOrDownload(String url) async {
    // 1. Check local cache
    final cached = await _mediaCacheDao.getMediaByUrl(url);
    if (cached != null) {
      final String localPath = cached['local_path'];
      if (await File(localPath).exists()) {
        return localPath; // Cache hit
      } else {
        // File was deleted outside the app, remove from DB
        await _mediaCacheDao.deleteMedia(url);
      }
    }

    // 2. Not cached, download it
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(join(dir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final hash = md5.convert(utf8.encode(url)).toString();
      final ext = extension(url).isNotEmpty ? extension(url) : '.bin';
      final localPath = join(mediaDir.path, '$hash$ext');

      await _dio.download(url, localPath);

      final file = File(localPath);
      final sizeBytes = await file.length();

      await _mediaCacheDao.insertMedia({
        'url': url,
        'local_path': localPath,
        'mime_type': 'application/octet-stream', // Can be refined using lookupMimeType
        'size_bytes': sizeBytes,
        'downloaded_at': DateTime.now().toIso8601String(),
      });

      return localPath;
    } catch (e) {
      // Download failed
      return null;
    }
  }

  // Optionally add a cleanup routine (LRU eviction) for old files if size > threshold
}
