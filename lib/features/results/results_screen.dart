import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rarematch/core/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultsScreen extends StatefulWidget {
  final String timelineId;
  const ResultsScreen({super.key, required this.timelineId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  List<dynamic> _matches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final matches = await apiService.findMatches(widget.timelineId,
          forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _matches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );
      final url = await apiService.generatePdf(widget.timelineId);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error generating PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitFeedback(String matchId, bool isHelpful) async {
    try {
      await apiService.submitFeedback(widget.timelineId, matchId, isHelpful);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHelpful
                ? 'Thanks for the positive feedback! 👍'
                : 'Thanks for the feedback. We will improve. 🔧'),
            backgroundColor: isHelpful ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Timeline',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Timeline?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;
              if (!context.mounted) return;

              try {
                await Supabase.instance.client
                    .from('timelines')
                    .delete()
                    .eq('id', widget.timelineId);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Timeline deleted')),
                );
                Navigator.of(context).pop(); // Go back to list
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error deleting timeline: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Redo Analysis',
            onPressed: () => _fetchMatches(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _matches.isNotEmpty ? _exportPdf : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Analyzing Patient Data...',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please hang in there! This may take up to 10 minutes\nwhile we run our advanced ML models.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _fetchMatches,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Found ${_matches.length} Similar Cases! 🎯',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Timeline Comparison',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 1.0,
                              barGroups: _matches
                                  .take(3)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((e) {
                                final similarity =
                                    (e.value['similarity'] as num).toDouble();
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: similarity,
                                      color: similarity > 0.8
                                          ? Colors.green
                                          : similarity > 0.5
                                              ? Colors.orange
                                              : Colors.red,
                                      width: 20,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() < 3 &&
                                          value.toInt() < _matches.length) {
                                        final diagnosis =
                                            _matches[value.toInt()]['diagnosis']
                                                as String;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            diagnosis.split(' ')[0],
                                            style:
                                                const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Top Matches',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        ..._matches.take(3).map((m) {
                          final similarity =
                              (m['similarity'] as num).toDouble();
                          final percentage = (similarity * 100).toInt();
                          final symptoms =
                              (m['symptoms'] as List<dynamic>).join(', ');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: similarity > 0.8
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                                child: Text(
                                  '$percentage%',
                                  style: TextStyle(
                                    color: similarity > 0.8
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                m['diagnosis'] ?? 'Unknown Diagnosis',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Symptoms: $symptoms'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Found in verified patients',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up_outlined),
                                    tooltip: 'Helpful',
                                    onPressed: () =>
                                        _submitFeedback(m['match_id'], true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_down_outlined),
                                    tooltip: 'Not Helpful',
                                    onPressed: () =>
                                        _submitFeedback(m['match_id'], false),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () {
                                      // View details
                                    },
                                    child: const Text('Details'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (_matches.length > 3) ...[
                          const SizedBox(height: 32),
                          Text(
                            'Similar Matches Found',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          ..._matches.skip(3).map((m) {
                            final similarity =
                                (m['similarity'] as num).toDouble();
                            final percentage = (similarity * 100).toInt();
                            final symptoms =
                                (m['symptoms'] as List<dynamic>).join(', ');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.2),
                                  child: Text(
                                    '$percentage%',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  m['diagnosis'] ?? 'Unknown Diagnosis',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Symptoms: $symptoms'),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
