import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../database/daos/link_preview_dao.dart';
import '../models/link_preview.dart';

class LinkPreviewService {
  LinkPreviewService._()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 7),
          sendTimeout: const Duration(seconds: 5),
          maxRedirects: 5,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                'AppleWebKit/605.1.15 Mobile/15E148',
            'Accept': 'text/html,application/xhtml+xml,image/*;q=0.8,*/*;q=0.5',
          },
        ),
      );

  static final LinkPreviewService instance = LinkPreviewService._();

  static final RegExp _urlPattern = RegExp(
    r'https?:\/\/[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );
  static const int _maxHtmlBytes = 512 * 1024;
  static const Duration _cacheLifetime = Duration(days: 7);
  static const Duration _fallbackCacheLifetime = Duration(hours: 1);

  final Dio _dio;
  final LinkPreviewDao _dao = LinkPreviewDao();
  final Map<String, Future<LinkPreview?>> _inFlight = {};

  static String? firstUrl(String text) {
    final raw = _urlPattern.firstMatch(text)?.group(0);
    if (raw == null) return null;
    return raw.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
  }

  Future<LinkPreview?> previewForText(String text) {
    final url = firstUrl(text);
    if (url == null) return Future.value(null);
    return _inFlight.putIfAbsent(url, () async {
      try {
        return await _load(url);
      } finally {
        _inFlight.remove(url);
      }
    });
  }

  Future<LinkPreview?> _load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isSafePublicUrl(uri)) return null;

    final cached = await _dao.getByUrl(url);
    if (cached != null) {
      final fetchedAt = DateTime.tryParse(
        cached['fetched_at']?.toString() ?? '',
      );
      if (fetchedAt != null &&
          DateTime.now().toUtc().difference(fetchedAt.toUtc()) <
              (cached['is_fallback'] == 1
                  ? _fallbackCacheLifetime
                  : _cacheLifetime)) {
        final preview = LinkPreview.fromSqlite(cached);
        if (preview.imageUrl == null) {
          final fallback = _fallback(uri);
          final enriched = LinkPreview(
            url: preview.url,
            host: preview.host,
            title: preview.title,
            description: preview.description,
            imageUrl: fallback.imageUrl,
            siteName: preview.siteName,
            isFallback: preview.isFallback,
          );
          await _dao.save(enriched.toSqlite());
          return enriched;
        }
        return preview;
      }
    }

    final preview = await _fetch(uri) ?? _fallback(uri);
    await _dao.save(preview.toSqlite());
    return preview;
  }

  Future<LinkPreview?> _fetch(Uri uri, {int redirects = 0}) async {
    try {
      final response = await _dio.get<ResponseBody>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        if (redirects >= 5) return null;
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) return null;
        final nextUri = uri.resolve(location);
        if (!_isSafePublicUrl(nextUri)) return null;
        return await _fetch(nextUri, redirects: redirects + 1);
      }
      final body = response.data;
      if (body == null) return null;
      final contentType =
          response.headers.value(Headers.contentTypeHeader) ?? '';
      final resolvedUri = response.realUri;

      if (contentType.toLowerCase().startsWith('image/')) {
        return LinkPreview(
          url: uri.toString(),
          host: _displayHost(resolvedUri.host),
          title: 'Image',
          imageUrl: resolvedUri.toString(),
          siteName: _providerName(resolvedUri.host),
        );
      }
      if (!contentType.toLowerCase().contains('html')) return null;

      final bytes = <int>[];
      await for (final Uint8List chunk in body.stream) {
        final remaining = _maxHtmlBytes - bytes.length;
        if (remaining <= 0) break;
        bytes.addAll(
          chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
        );
        if (bytes.length >= _maxHtmlBytes) break;
      }
      final html = utf8.decode(bytes, allowMalformed: true);
      if (html.isEmpty) return null;

      final title =
          _meta(html, 'og:title') ??
          _meta(html, 'twitter:title') ??
          _tagTitle(html);
      final description =
          _meta(html, 'og:description') ??
          _meta(html, 'twitter:description') ??
          _namedMeta(html, 'description');
      final rawImage = _meta(html, 'og:image') ?? _meta(html, 'twitter:image');
      final image = rawImage == null
          ? _youtubeThumbnail(resolvedUri) ??
                _favicon(html, resolvedUri) ??
                _defaultFavicon(resolvedUri)
          : resolvedUri.resolve(_decodeEntities(rawImage)).toString();
      final siteName =
          _meta(html, 'og:site_name') ?? _providerName(resolvedUri.host);

      return LinkPreview(
        url: uri.toString(),
        host: _displayHost(resolvedUri.host),
        title: _decodeEntities(title ?? siteName),
        description: _clean(description),
        imageUrl: image,
        siteName: _clean(siteName),
      );
    } catch (_) {
      return null;
    }
  }

  LinkPreview _fallback(Uri uri) {
    final provider = _providerName(uri.host);
    return LinkPreview(
      url: uri.toString(),
      host: _displayHost(uri.host),
      title: switch (provider) {
        'Google Drive' => 'Google Drive link',
        'YouTube' => 'YouTube video',
        'Instagram' => 'Instagram post',
        'Facebook' => 'Facebook post',
        'TikTok' => 'TikTok video',
        _ => provider,
      },
      description: 'Open link to view content',
      imageUrl: _youtubeThumbnail(uri) ?? _defaultFavicon(uri),
      siteName: provider,
      isFallback: true,
    );
  }

  static bool _isSafePublicUrl(Uri uri) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.local')) return false;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length == 4 && parts.every((part) => part != null)) {
      final a = parts[0]!;
      final b = parts[1]!;
      if (a == 10 ||
          a == 127 ||
          a == 0 ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168)) {
        return false;
      }
    }
    return host != '::1';
  }

  static String? _meta(String html, String key) {
    for (final match in RegExp(
      r'<meta\s+[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final tag = match.group(0)!;
      final attributeKey =
          _attribute(tag, 'property') ?? _attribute(tag, 'name');
      if (attributeKey?.toLowerCase() != key.toLowerCase()) continue;
      final value = _attribute(tag, 'content');
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _attribute(String tag, String name) {
    final escaped = RegExp.escape(name);
    final match = RegExp(
      '$escaped\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1) ?? match?.group(2);
  }

  static String? _namedMeta(String html, String name) => _meta(html, name);

  static String? _tagTitle(String html) {
    final value = RegExp(
      r'<title[^>]*>([\s\S]*?)<\/title>',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    return _clean(value);
  }

  static String? _favicon(String html, Uri pageUri) {
    for (final match in RegExp(
      r'<link\s+[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final tag = match.group(0)!;
      final rel = _attribute(tag, 'rel')?.toLowerCase();
      if (rel == null || !rel.contains('icon')) continue;
      final href = _attribute(tag, 'href');
      if (href != null && href.trim().isNotEmpty) {
        return pageUri.resolve(_decodeEntities(href.trim())).toString();
      }
    }
    return null;
  }

  static String _defaultFavicon(Uri uri) =>
      Uri(scheme: uri.scheme, host: uri.host, path: '/favicon.ico').toString();

  static String? _clean(String? value) {
    if (value == null) return null;
    final cleaned = _decodeEntities(
      value.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' '),
    ).trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _decodeEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  static String _displayHost(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  static String _providerName(String host) {
    final value = _displayHost(host);
    if (value.contains('drive.google.com')) return 'Google Drive';
    if (value.contains('youtube.com') || value == 'youtu.be') return 'YouTube';
    if (value.contains('instagram.com')) return 'Instagram';
    if (value.contains('facebook.com') || value == 'fb.watch') {
      return 'Facebook';
    }
    if (value.contains('tiktok.com')) return 'TikTok';
    return value;
  }

  static String? _youtubeThumbnail(Uri uri) {
    String? id;
    if (_displayHost(uri.host) == 'youtu.be') {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.host.contains('youtube.com')) {
      id = uri.queryParameters['v'];
      if (id == null &&
          uri.pathSegments.length >= 2 &&
          {'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
        id = uri.pathSegments[1];
      }
    }
    return id == null || id.isEmpty
        ? null
        : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  }
}
