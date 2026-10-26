class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.host,
    required this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.isFallback = false,
  });

  final String url;
  final String host;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final bool isFallback;

  factory LinkPreview.fromSqlite(Map<String, dynamic> row) {
    return LinkPreview(
      url: row['url']?.toString() ?? '',
      host: row['host']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString(),
      imageUrl: row['image_url']?.toString(),
      siteName: row['site_name']?.toString(),
      isFallback: row['is_fallback'] == 1 || row['is_fallback'] == true,
    );
  }

  Map<String, dynamic> toSqlite() => {
    'url': url,
    'host': host,
    'title': title,
    'description': description,
    'image_url': imageUrl,
    'site_name': siteName,
    'is_fallback': isFallback ? 1 : 0,
    'fetched_at': DateTime.now().toUtc().toIso8601String(),
  };
}
