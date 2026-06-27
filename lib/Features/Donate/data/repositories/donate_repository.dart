import 'package:app/Features/Donate/domain/models/donation.dart';

abstract class DonateRepository {
  Future<List<Donation>> fetchDonationCampaigns();
  Future<void> makeDonation(String campaignId, double amount, String donorName);
}

class InMemoryDonateRepository implements DonateRepository {
  final List<Donation> _campaigns = [
    const Donation(
      id: '1',
      title: 'Medical Help for Rahima',
      category: 'Medical Help',
      goalAmount: 100000,
      raisedAmount: 65000,
      organizer: 'Rangamati Social Club',
      coverImage: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?q=80&w=400&auto=format&fit=crop',
      description: 'Rahima is suffering from a complex cardiac illness and needs urgent open heart surgery. All collected funds go directly to the hospital billing department.',
      updates: [
        'June 20: First medical consultation completed.',
        'June 25: Hospital booking confirmed, scheduled for surgery soon.',
      ],
      donors: ['Anisur R.', 'Sultana K.', 'Imran H.', 'Anonymous'],
    ),
    const Donation(
      id: '2',
      title: 'Student Scholarship for Indigenous Kids',
      category: 'Student Scholarship',
      goalAmount: 50000,
      raisedAmount: 32000,
      organizer: 'Hill Education Society',
      coverImage: 'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?q=80&w=400&auto=format&fit=crop',
      description: 'Supporting 10 bright students from remote hill villages with their educational expenses, books, and uniforms for the year.',
      updates: [
        'June 10: 5 students successfully enrolled and provided with primary resources.'
      ],
      donors: ['Tanvir M.', 'Rumana T.'],
    ),
    const Donation(
      id: '3',
      title: 'House Repair for Flood Affected Families',
      category: 'House Repair',
      goalAmount: 150000,
      raisedAmount: 90000,
      organizer: 'Pilach Welfare Foundation',
      coverImage: 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=400&auto=format&fit=crop',
      description: 'Helping reconstruct housing structures destroyed during the recent flash floods in low lying community regions.',
      updates: [],
      donors: ['Farhan Z.', 'Ayesha B.', 'Tasnim R.'],
    ),
  ];

  @override
  Future<List<Donation>> fetchDonationCampaigns() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _campaigns;
  }

  @override
  Future<void> makeDonation(String campaignId, double amount, String donorName) async {
    // Mock simulation
    return;
  }
}
