import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class TimelineBuilder extends StatefulWidget {
  const TimelineBuilder({super.key});

  @override
  State<TimelineBuilder> createState() => _TimelineBuilderState();
}

class _TimelineBuilderState extends State<TimelineBuilder> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _symptoms = [];
  bool _isSaving = false;

  // Options
  final List<String> _symptomNames = [
    'Joint pain',
    'Rash',
    'Fatigue',
    'Fever',
    'Headache',
    'GI issues',
    'Hair loss',
    'Muscle pain',
    'Cognitive issues',
    'Other'
  ];
  final List<String> _frequencies = [
    'Daily',
    'Weekly',
    'Monthly',
    'Occasional'
  ];
  final List<String> _bodyLocations = [
    'Head',
    'Neck',
    'Chest',
    'Abdomen',
    'Back',
    'Arms',
    'Hands',
    'Legs',
    'Feet',
    'Joints',
    'Skin',
    'General'
  ];
  final List<String> _triggers = [
    'Physical activity',
    'Food',
    'Stress',
    'Weather',
    'Sunlight',
    'Sleep deprivation',
    'Menstrual cycle',
    'Cold',
    'Heat',
    'Other'
  ];
  final List<String> _relievers = [
    'Rest',
    'Ice',
    'Heat',
    'Medication',
    'Sleep',
    'Exercise',
    'Hydration',
    'Moisturizer',
    'Massage',
    'Other'
  ];

  void _addSymptom() {
    setState(() {
      _symptoms.add({
        'symptom_name': _symptomNames.first,
        'age_onset': '',
        'severity': 5.0,
        'frequency': _frequencies.first,
        'body_locations': <String>[],
        'triggers': <String>[],
        'relievers': <String>[],
      });
    });
  }

  void _removeSymptom(int index) {
    setState(() {
      _symptoms.removeAt(index);
    });
  }

  Future<void> _saveTimeline() async {
    if (!_formKey.currentState!.validate()) return;
    if (_symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one symptom')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('timelines').insert({
        'user_id': userId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'symptoms': _symptoms,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timeline saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Timeline')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Timeline Title',
                hintText: 'e.g., My Symptom Journey',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Symptoms',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: _addSymptom,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Symptom'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_symptoms.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                      'No symptoms added yet. Tap "Add Symptom" to start.'),
                ),
              )
            else
              ..._symptoms.asMap().entries.map((entry) {
                final index = entry.key;
                final symptom = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Symptom #${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeSymptom(index),
                            ),
                          ],
                        ),
                        const Divider(),
                        DropdownButtonFormField<String>(
                          initialValue: symptom['symptom_name'],
                          decoration:
                              const InputDecoration(labelText: 'Symptom Name'),
                          items: _symptomNames
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => symptom['symptom_name'] = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: symptom['age_onset'],
                                decoration: const InputDecoration(
                                    labelText: 'Age of Onset'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => symptom['age_onset'] = v,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: symptom['frequency'],
                                decoration: const InputDecoration(
                                    labelText: 'Frequency'),
                                items: _frequencies
                                    .map((f) => DropdownMenuItem(
                                        value: f, child: Text(f)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => symptom['frequency'] = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Severity: ${symptom['severity'].round()}/10'),
                        Slider(
                          value: symptom['severity'],
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: symptom['severity'].round().toString(),
                          onChanged: (v) =>
                              setState(() => symptom['severity'] = v),
                        ),
                        const SizedBox(height: 8),
                        _buildMultiSelect(
                          context,
                          'Body Locations',
                          _bodyLocations,
                          symptom['body_locations'],
                          (selected) => setState(
                              () => symptom['body_locations'] = selected),
                        ),
                        const SizedBox(height: 8),
                        _buildMultiSelect(
                          context,
                          'Triggers',
                          _triggers,
                          symptom['triggers'],
                          (selected) =>
                              setState(() => symptom['triggers'] = selected),
                        ),
                        const SizedBox(height: 8),
                        _buildMultiSelect(
                          context,
                          'Relievers',
                          _relievers,
                          symptom['relievers'],
                          (selected) =>
                              setState(() => symptom['relievers'] = selected),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _saveTimeline,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save & Find Matches',
                        style: TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelect(
    BuildContext context,
    String title,
    List<String> options,
    List<dynamic> selectedValues,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8.0,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                final newSelectedValues = List<String>.from(selectedValues);
                if (selected) {
                  newSelectedValues.add(option);
                } else {
                  newSelectedValues.remove(option);
                }
                onChanged(newSelectedValues);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
