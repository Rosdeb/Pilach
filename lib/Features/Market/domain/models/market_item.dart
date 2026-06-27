import 'package:flutter/material.dart';

class MarketItem {
  final String id;
  final String title;
  final double price;
  final double rating;
  final String location;
  final String image;
  final String category;
  final String description;
  final String sellerName;
  final String sellerDistance;

  const MarketItem({
    required this.id,
    required this.title,
    required this.price,
    required this.rating,
    required this.location,
    required this.image,
    required this.category,
    required this.description,
    required this.sellerName,
    required this.sellerDistance,
  });
}
