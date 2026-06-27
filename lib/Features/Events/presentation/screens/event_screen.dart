import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_providers.dart';
import '../../domain/models/event.dart';

class EventScreen extends ConsumerWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: asyncEvents.when(
        data: (events) => ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: events.length,
          itemBuilder: (context, index) => _EventCard(event: events[index]),
        ),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('❌ $e')),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool isInterested = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateString = '${widget.event.date.day} ${months[widget.event.date.month - 1]}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.event.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isInterested = !isInterested;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isInterested
                              ? 'Marked as interested in ${widget.event.title}'
                              : 'Removed interest from ${widget.event.title}',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isInterested ? Colors.green.withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest.withOpacity(.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isInterested ? '✓ Interested' : 'Interested',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isInterested ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(CupertinoIcons.location_solid, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  widget.event.location,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(CupertinoIcons.calendar, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateString,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
