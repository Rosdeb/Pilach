import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/news_repository.dart';
import '../../domain/models/article.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return InMemoryNewsRepository();
});

final latestNewsProvider = FutureProvider<List<Article>>((ref) async {
  return ref.watch(newsRepositoryProvider).fetchLatestNews();
});
