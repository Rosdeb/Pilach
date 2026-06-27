class Donation {
  final String id;
  final String title;
  final String category;
  final double goalAmount;
  final double raisedAmount;
  final String organizer;
  final String coverImage;
  final String description;
  final List<String> updates;
  final List<String> donors;

  const Donation({
    required this.id,
    required this.title,
    required this.category,
    required this.goalAmount,
    required this.raisedAmount,
    required this.organizer,
    required this.coverImage,
    required this.description,
    required this.updates,
    required this.donors,
  });

  double get progressPercentage => (raisedAmount / goalAmount).clamp(0.0, 1.0);
}
