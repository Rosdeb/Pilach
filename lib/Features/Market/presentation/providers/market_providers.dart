import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/repositories/market_repository.dart';
import '../../domain/models/market_item.dart';

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return InMemoryMarketRepository();
});

final marketSearchQueryProvider = StateProvider<String>((ref) => '');

final marketItemsProvider = FutureProvider<List<MarketItem>>((ref) async {
  final repo = ref.watch(marketRepositoryProvider);
  final query = ref.watch(marketSearchQueryProvider);
  return repo.searchMarketItems(query);
});
