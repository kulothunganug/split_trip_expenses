import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/trip_provider.dart';
import '../providers/categories_provider.dart';
import '../database/drift_database.dart';

class AddExpenseDialog extends StatefulWidget {
  final Expense? expense;
  const AddExpenseDialog({super.key, this.expense});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  Category? _selectedCategory;
  Member? _paidBy;
  DateTime _selectedDate = DateTime.now();

  String _splitMode = 'Everyone'; // 'Everyone' or 'Selected'
  Set<int> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _selectedDate = widget.expense!.datetime;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final tripProv = context.read<TripProvider>();
        final catProv = context.read<CategoriesProvider>();

        setState(() {
          if (widget.expense!.categoryId != null) {
            try {
              _selectedCategory = catProv.categories.firstWhere(
                (c) => c.id == widget.expense!.categoryId,
              );
            } catch (_) {}
          }
          try {
            _paidBy = tripProv.members.firstWhere(
              (m) => m.id == widget.expense!.memberId,
            );
          } catch (_) {}
        });

        final participants = await tripProv.db.getExpenseParticipants(
          widget.expense!.id,
        );
        if (!mounted) return;

        setState(() {
          _selectedMemberIds = participants.map((p) => p.memberId).toSet();
          if (_selectedMemberIds.length == tripProv.members.length &&
              tripProv.members.isNotEmpty) {
            _splitMode = 'Everyone';
          } else {
            _splitMode = 'Selected';
          }
        });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Pre-select first category and first member
        final tripProv = context.read<TripProvider>();
        final catProv = context.read<CategoriesProvider>();
        if (tripProv.members.isNotEmpty) {
          setState(() => _paidBy = tripProv.members.first);
        }
        if (catProv.categories.isNotEmpty) {
          setState(() => _selectedCategory = catProv.categories.first);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidBy == null || _selectedCategory == null) return;

    final tripProv = context.read<TripProvider>();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    List<int> participantIds = [];
    if (_splitMode == 'Everyone') {
      participantIds = tripProv.members.map((m) => m.id).toList();
    } else {
      participantIds = _selectedMemberIds.toList();
    }

    if (participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one member to split with'),
        ),
      );
      return;
    }

    final expenseCompanion = ExpensesCompanion.insert(
      tripId: tripProv.trip!.id,
      memberId: _paidBy!.id,
      categoryId: drift.Value(_selectedCategory!.id),
      title: _titleController.text.trim(),
      amount: amount,
      datetime: drift.Value(_selectedDate),
    );

    if (widget.expense == null) {
      await tripProv.addExpense(expenseCompanion, participantIds);
    } else {
      // update -> need the raw Expense object modified
      final updated = widget.expense!.copyWith(
        memberId: _paidBy!.id,
        categoryId: drift.Value(_selectedCategory!.id),
        title: _titleController.text.trim(),
        amount: amount,
        datetime: _selectedDate,
      );
      await tripProv.updateExpense(updated, participantIds);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tripProv = context.watch<TripProvider>();
    final catProv = context.watch<CategoriesProvider>();
    final members = tripProv.members;
    final categories = catProv.categories;
    final theme = Theme.of(context);

    // Filter to ensure selected category/member exist in drops
    if (_paidBy != null && !members.contains(_paidBy)) _paidBy = null;
    if (_selectedCategory != null && !categories.contains(_selectedCategory))
      _selectedCategory = null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  widget.expense == null ? 'Add Expense' : 'Edit Expense',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Category & Date Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Category>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Text(c.emoji),
                                    const SizedBox(width: 8),
                                    Text(c.title),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            DateFormat('MMM d').format(_selectedDate),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Enter a description' : null,
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Enter amount' : null,
                ),
                const SizedBox(height: 16),

                // Paid By
                DropdownButtonFormField<Member>(
                  value: _paidBy,
                  decoration: const InputDecoration(
                    labelText: 'Paid By',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: members
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: 24),

                // Split Mode
                const Text(
                  'Split among',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Everyone'),
                        value: 'Everyone',
                        groupValue: _splitMode,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setState(() {
                            _splitMode = v!;
                            _selectedMemberIds.clear();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Selected'),
                        value: 'Selected',
                        groupValue: _splitMode,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setState(() {
                            _splitMode = v!;
                            // Default select all
                            _selectedMemberIds = members
                                .map((m) => m.id)
                                .toSet();
                          });
                        },
                      ),
                    ),
                  ],
                ),

                if (_splitMode == 'Selected') ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: members.map((m) {
                        return CheckboxListTile(
                          title: Text(m.name),
                          value: _selectedMemberIds.contains(m.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedMemberIds.add(m.id);
                              } else {
                                _selectedMemberIds.remove(m.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

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
                        onPressed: _saveExpense,
                        child: const Text('Save'),
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
