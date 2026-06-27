import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/usecases/get_events.dart';

// Repository provider – replace with real implementation later
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return InMemoryEventRepository();
});

final getEventsUseCaseProvider = Provider<GetEvents>((ref) {
  return GetEvents(ref.read(eventRepositoryProvider));
});

// UI layer consumes this FutureProvider
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  return ref.read(getEventsUseCaseProvider)();
});
