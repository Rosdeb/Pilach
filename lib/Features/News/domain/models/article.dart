class Article {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String imageUrl;
  final String reporter;
  final String category;
  final DateTime publishedAt;
  final List<String> galleryImages;

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.imageUrl,
    required this.reporter,
    required this.category,
    required this.publishedAt,
    required this.galleryImages,
  });
}
