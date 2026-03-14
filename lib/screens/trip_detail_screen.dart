import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/import_export_service.dart';
import '../providers/trip_provider.dart';
import '../providers/trips_provider.dart';
import '../providers/categories_provider.dart';
import '../database/drift_database.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/split_settlement_dialog.dart';
import '../widgets/create_trip_dialog.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<TripProvider>().loadTrip(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripProv = context.watch<TripProvider>();
    final categoriesProv = context.watch<CategoriesProvider>();
    final theme = Theme.of(context);

    if (tripProv.trip == null || tripProv.trip!.id != widget.tripId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final trip = tripProv.trip!;
    final expenses = tripProv.expenses;
    final members = tripProv.members;

    // Calculate total spent
    final totalSpent = expenses.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: trip.budget != null ? 240 : 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                trip.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: trip.budget != null
                    ? _buildBudgetIndicator(totalSpent, trip.budget!)
                    : const SizedBox(),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'edit') {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => CreateTripDialog(
                        trip: trip,
                        existingMembers: members,
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<TripProvider>().loadTrip(widget.tripId);
                    }
                  } else if (val == 'export') {
                    try {
                      final jsonStr = await context
                          .read<ImportExportService>()
                          .exportTripToJson(widget.tripId);
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File(
                        '${dir.path}/trip_${widget.tripId}.json',
                      );
                      await file.writeAsString(jsonStr);
                      await Share.shareXFiles([
                        XFile(file.path),
                      ], text: 'Exported Trip Data');
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error exporting trip: $e')),
                        );
                    }
                  } else if (val == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Trip?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<TripsProvider>().deleteTrip(trip);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Trip')),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Export Trip'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete Trip',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (expenses.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PageView(
                        children: [
                          _buildMemberPieChart(tripProv),
                          _buildCategoryBarChart(tripProv, categoriesProv),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                final expense =
                    expenses[index - 1]; // -1 because index 0 is header
                final category = categoriesProv.categories.firstWhere(
                  (c) => c.id == expense.categoryId,
                  orElse: () =>
                      const Category(id: -1, title: 'None', emoji: '💸'),
                );
                final payer = members.firstWhere(
                  (m) => m.id == expense.memberId,
                  orElse: () =>
                      const Member(id: -1, tripId: -1, name: 'Unknown'),
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    expense.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Paid by ${payer.name} • ${DateFormat('MMM d').format(expense.datetime)}',
                  ),
                  trailing: Text(
                    '₹${expense.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    _showExpenseDetails(
                      context,
                      expense,
                      category,
                      payer,
                      members,
                    );
                  },
                );
              },
              childCount: expenses.length + 1, // +1 for header
            ),
          ),

          // Bottom padding so items aren't hidden behind buttons
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60), // Above the split button
        child: FloatingActionButton(
          heroTag: 'add_expense',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const AddExpenseDialog(),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SplitSettlementDialog(),
            );
          },
          child: const Text('Calculate Split'),
        ),
      ),
    );
  }

  Widget _buildBudgetIndicator(double spent, double budget) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 120,
            width: 120,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of Budget',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberPieChart(TripProvider tripProv) {
    if (tripProv.splitResult == null) return const SizedBox();

    final spentMap = tripProv.splitResult!.memberTotalSpent;
    final members = tripProv.members;

    if (spentMap.values.every((v) => v == 0)) {
      return const Center(child: Text('No spending yet'));
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
    ];

    List<PieChartSectionData> sections = [];
    int i = 0;
    spentMap.forEach((memberId, amount) {
      if (amount > 0) {
        final memberName = members
            .firstWhere(
              (m) => m.id == memberId,
              orElse: () => const Member(id: -1, tripId: -1, name: 'Unknown'),
            )
            .name;
        sections.add(
          PieChartSectionData(
            color: colors[i % colors.length],
            value: amount,
            title: memberName,
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
        );
      }
      i++;
    });

    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 40));
  }

  Widget _buildCategoryBarChart(
    TripProvider tripProv,
    CategoriesProvider catProv,
  ) {
    final expenses = tripProv.expenses;
    if (expenses.isEmpty) return const SizedBox();

    final Map<int, double> catSpent = {};
    for (final exp in expenses) {
      if (exp.categoryId != null) {
        catSpent[exp.categoryId!] =
            (catSpent[exp.categoryId!] ?? 0) + exp.amount;
      }
    }

    if (catSpent.isEmpty)
      return const Center(child: Text('No categorized spending'));

    final maxSpent = catSpent.values.reduce((a, b) => a > b ? a : b);

    List<BarChartGroupData> groups = [];
    int i = 0;
    catSpent.forEach((catId, amount) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: Theme.of(context).colorScheme.secondary,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      i++;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxSpent * 1.2,
        barGroups: groups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= catSpent.length) return const SizedBox();
                final catId = catSpent.keys.elementAt(value.toInt());
                final category = catProv.categories.firstWhere(
                  (c) => c.id == catId,
                  orElse: () =>
                      const Category(id: -1, title: 'None', emoji: '💸'),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
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
    );
  }

  void _showExpenseDetails(
    BuildContext context,
    Expense expense,
    Category category,
    Member payer,
    List<Member> allMembers,
  ) async {
    final tripProv = context.read<TripProvider>();
    final parts = await tripProv.db.getExpenseParticipants(expense.id);
    final participantNames = parts.map((p) {
      final m = allMembers.firstWhere(
        (m) => m.id == p.memberId,
        orElse: () => const Member(id: -1, tripId: -1, name: 'Unknown'),
      );
      return m.name;
    }).toList();

    if (!context.mounted) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          category.title,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${expense.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow(context, Icons.person, 'Paid by', payer.name),
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.calendar_today,
                'Date',
                DateFormat('MMM d, yyyy • h:mm a').format(expense.datetime),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.group,
                'Split between',
                participantNames.isEmpty
                    ? 'Everyone'
                    : participantNames.join(', '),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        showDialog(
                          context: context,
                          builder: (_) => AddExpenseDialog(expense: expense),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: bottomSheetContext,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Expense?'),
                            content: const Text(
                              'Are you sure you want to delete this?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          tripProv.deleteExpense(expense);
                          if (bottomSheetContext.mounted) {
                            Navigator.pop(bottomSheetContext);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Expense deleted')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete, size: 20),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
