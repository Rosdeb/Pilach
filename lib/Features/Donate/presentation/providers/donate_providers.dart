import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/donate_repository.dart';
import '../../domain/models/donation.dart';

final donateRepositoryProvider = Provider<DonateRepository>((ref) {
  return InMemoryDonateRepository();
});

final donationCampaignsProvider = FutureProvider<List<Donation>>((ref) async {
  return ref.watch(donateRepositoryProvider).fetchDonationCampaigns();
});
