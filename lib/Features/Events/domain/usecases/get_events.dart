import '../../data/repositories/event_repository.dart';
import '../../domain/models/event.dart';

class GetEvents {
  final EventRepository repository;

  GetEvents(this.repository);

  Future<List<Event>> call() => repository.fetchEvents();
}
