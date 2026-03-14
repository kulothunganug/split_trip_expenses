import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/drift_database.dart';
import '../providers/trips_provider.dart';

class _MemberField {
  Member? member;
  TextEditingController controller;
  _MemberField({this.member, required this.controller});
}

class CreateTripDialog extends StatefulWidget {
  final Trip? trip;
  final List<Member>? existingMembers;

  const CreateTripDialog({super.key, this.trip, this.existingMembers});

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _budgetController = TextEditingController();
  final List<_MemberField> _memberFields = [];

  bool get _isEdit => widget.trip != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _titleController.text = widget.trip!.title;
      _budgetController.text = widget.trip!.budget?.toString() ?? '';
      if (widget.existingMembers != null &&
          widget.existingMembers!.isNotEmpty) {
        for (final m in widget.existingMembers!) {
          _memberFields.add(
            _MemberField(
              member: m,
              controller: TextEditingController(text: m.name),
            ),
          );
        }
      }
    } else {
      _memberFields.addAll([
        _MemberField(controller: TextEditingController(text: 'Me')),
        _MemberField(controller: TextEditingController()),
      ]);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    for (var f in _memberFields) {
      f.controller.dispose();
    }
    super.dispose();
  }

  void _addMemberField() {
    setState(() {
      _memberFields.add(_MemberField(controller: TextEditingController()));
    });
  }

  void _removeMemberField(int index) {
    if (_memberFields.length > 1) {
      setState(() {
        _memberFields[index].controller.dispose();
        _memberFields.removeAt(index);
      });
    }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    final validFields = _memberFields
        .where((f) => f.controller.text.trim().isNotEmpty)
        .toList();

    if (validFields.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one member')));
      return;
    }

    final db = context.read<AppDatabase>();
    final tripsProv = context.read<TripsProvider>();

    final budgetStr = _budgetController.text.trim();
    final budget = budgetStr.isEmpty ? null : double.tryParse(budgetStr);
    final title = _titleController.text.trim();

    if (_isEdit) {
      await db.updateTrip(
        Trip(
          id: widget.trip!.id,
          title: title,
          budget: budget,
          createdAt: widget.trip!.createdAt,
        ),
      );

      await db.transaction(() async {
        for (final field in validFields) {
          final name = field.controller.text.trim();
          if (field.member != null) {
            if (field.member!.name != name) {
              await db.updateMember(
                Member(
                  id: field.member!.id,
                  tripId: field.member!.tripId,
                  name: name,
                ),
              );
            }
          } else {
            await db.insertMember(
              MembersCompanion.insert(tripId: widget.trip!.id, name: name),
            );
          }
        }
      });
    } else {
      final tripId = await tripsProv.addTrip(title, budget);
      await db.transaction(() async {
        for (final field in validFields) {
          await db.insertMember(
            MembersCompanion.insert(
              tripId: tripId,
              name: field.controller.text.trim(),
            ),
          );
        }
      });
    }

    if (mounted) {
      Navigator.pop(context, true); // true indicates success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? 'Edit Trip' : 'Let\'s Start a Trip',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Title (e.g. Goa Trip)',
                    prefixIcon: Icon(Icons.flight_takeoff),
                  ),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Please enter title' : null,
                ),
                const SizedBox(height: 16),

                // Optional Budget
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total Budget (Optional)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // Members Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addMemberField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...List.generate(_memberFields.length, (index) {
                  final field = _memberFields[index];
                  final isExisting = field.member != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: field.controller,
                            decoration: InputDecoration(
                              labelText: 'Member ${index + 1}',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        if (_memberFields.length > 1 && !isExisting) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removeMemberField(index),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveTrip,
                        child: Text(_isEdit ? 'Save' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
