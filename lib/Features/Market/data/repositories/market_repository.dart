import 'package:app/Features/Market/domain/models/market_item.dart';

abstract class MarketRepository {
  Future<List<MarketItem>> fetchMarketItems();
  Future<List<MarketItem>> searchMarketItems(String query);
}

class InMemoryMarketRepository implements MarketRepository {
  final List<MarketItem> _dummyItems = [
    const MarketItem(
      id: '1',
      title: 'Traditional Koch Bag',
      price: 650.0,
      rating: 5.0,
      location: 'Rangamati',
      image: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?q=80&w=300&auto=format&fit=crop',
      category: 'Clothing',
      description: 'Beautiful traditional Koch bag woven by local artisans with high-quality regional threads and traditional patterns.',
      sellerName: 'Monira Dewan',
      sellerDistance: '2.5 km away',
    ),
    const MarketItem(
      id: '2',
      title: 'Bamboo Basket',
      price: 450.0,
      rating: 4.8,
      location: 'Bandarban',
      image: 'https://images.unsplash.com/photo-1544816155-12df9643f363?q=80&w=300&auto=format&fit=crop',
      category: 'Handmade',
      description: 'Extremely durable eco-friendly bamboo basket suitable for storage, home decor, and shopping.',
      sellerName: 'Uthwai Marma',
      sellerDistance: '1.8 km away',
    ),
    const MarketItem(
      id: '3',
      title: 'Hill Tracts Organic Honey',
      price: 800.0,
      rating: 4.9,
      location: 'Khagrachari',
      image: 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?q=80&w=300&auto=format&fit=crop',
      category: 'Food',
      description: 'Pure, organic wild honey harvested directly from the deep forests of the Chittagong Hill Tracts.',
      sellerName: 'Subir Chakma',
      sellerDistance: '4.2 km away',
    ),
  ];

  @override
  Future<List<MarketItem>> fetchMarketItems() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _dummyItems;
  }

  @override
  Future<List<MarketItem>> searchMarketItems(String query) async {
    if (query.isEmpty) return _dummyItems;
    return _dummyItems
        .where((item) =>
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            item.category.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
