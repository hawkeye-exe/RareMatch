import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rarematch/features/timeline/timeline_builder.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _userId = Supabase.instance.client.auth.currentUser?.id;
  late final Stream<List<Map<String, dynamic>>> _timelinesStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (_userId != null) {
      setState(() {
        _timelinesStream = Supabase.instance.client
            .from('timelines')
            .stream(primaryKey: ['id'])
            .eq('user_id', _userId)
            .order('created_at', ascending: false);
      });
    } else {
      // Demo Mode: Return mock stream
      setState(() {
        _timelinesStream = Stream.value([
          {
            'id': 'demo-1',
            'title': 'Demo Timeline 1',
            'description': 'This is a demo timeline for visualization.',
            'created_at': DateTime.now().toIso8601String(),
            'symptoms': [
              {'symptom_name': 'Headache', 'severity': 8}
            ]
          },
        ]);
      });
    }
  }

  Future<void> _refreshTimelines() async {
    // Re-initialize the stream to force a refresh
    _initStream();
    // Wait a bit to show the loading indicator
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _loadManually() async {
    try {
      if (_userId != null) {
        final data = await Supabase.instance.client
            .from('timelines')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: false);

        setState(() {
          _timelinesStream =
              Stream.value(List<Map<String, dynamic>>.from(data));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timelines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _timelinesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Check if it's a Realtime error
            final error = snapshot.error.toString();
            final isRealtimeError =
                error.contains('RealtimeSubscribeException') ||
                    error.contains('RealtimeCloseEvent');

            if (isRealtimeError) {
              // Fallback UI for Realtime errors
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Realtime Connection Issue',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We couldn\'t connect to live updates.\nTap below to load your data manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _refreshTimelines,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _loadManually,
                          icon: const Icon(Icons.download),
                          label: const Text('Load Manually'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final timelines = snapshot.data!;
          if (timelines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_edu, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No timelines yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const TimelineBuilder()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First Timeline'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refreshTimelines,
            child: ListView.builder(
              itemCount: timelines.length,
              itemBuilder: (context, index) {
                final timeline = timelines[index];
                final symptoms = timeline['symptoms'] as List<dynamic>? ?? [];
                final symptomCount = symptoms.length;
                final firstSymptom = symptoms.isNotEmpty
                    ? symptoms[0]['symptom_name']
                    : 'No symptoms';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(timeline['title'] ?? 'Untitled',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeline['description'] ?? 'No description'),
                        const SizedBox(height: 4),
                        Text('$symptomCount symptoms • Primary: $firstSymptom',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/timeline/results/${timeline['id']}');
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TimelineBuilder()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
