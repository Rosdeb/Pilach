import '../../domain/models/event.dart';

abstract class EventRepository {
  Future<List<Event>> fetchEvents();
}

class InMemoryEventRepository implements EventRepository {
  @override
  Future<List<Event>> fetchEvents() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Event(
        id: '1',
        title: 'Traditional Dance Festival',
        date: DateTime(2026, 8, 22),
        location: 'Mymensingh',
      ),
      Event(
        id: '2',
        title: 'Football Tournament Championship',
        date: DateTime(2026, 9, 5),
        location: 'Rangamati Stadium',
      ),
      Event(
        id: '3',
        title: 'Community Wedding Ceremony',
        date: DateTime(2026, 10, 12),
        location: 'Pilach Community Hall',
      ),
      Event(
        id: '4',
        title: 'Monthly Townhall Planning Meeting',
        date: DateTime(2026, 10, 20),
        location: 'Bandarban Center',
      ),
    ];
  }
}
