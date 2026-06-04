import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/import_export_service.dart';
import '../providers/trip_provider.dart';
import '../providers/trips_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/app_provider.dart';
import '../database/drift_database.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/create_trip_dialog.dart';

const _kChartColors = [
  Color(0xFF5C6BC0),
  Color(0xFF42A5F5),
  Color(0xFF26C6DA),
  Color(0xFF66BB6A),
  Color(0xFFFFA726),
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF8D6E63),
];

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _selectedIndex = 0;

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
    final appProv = context.watch<AppProvider>();
    final theme = Theme.of(context);

    if (tripProv.trip == null || tripProv.trip!.id != widget.tripId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final trip = tripProv.trip!;
    final expenses = tripProv.expenses;
    final members = tripProv.members;
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final splitResult = tripProv.splitResult;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          if (_selectedIndex == 2 &&
              splitResult != null &&
              splitResult.transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share settlement',
              onPressed: () => _shareSettlement(tripProv, appProv),
            ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'edit') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      CreateTripDialog(trip: trip, existingMembers: members),
                );
                if (ok == true && context.mounted) {
                  context.read<TripProvider>().loadTrip(widget.tripId);
                }
              } else if (val == 'export') {
                try {
                  final jsonStr = await context
                      .read<ImportExportService>()
                      .exportTripToJson(widget.tripId);
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File('${dir.path}/trip_${widget.tripId}.json');
                  await file.writeAsString(jsonStr);
                  await Share.shareXFiles([
                    XFile(file.path),
                  ], text: 'Exported Trip Data');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error exporting trip: $e')),
                    );
                  }
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
              const PopupMenuItem(value: 'export', child: Text('Export Trip')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Trip', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildExpensesTab(
            expenses,
            members,
            categoriesProv,
            trip,
            totalSpent,
            theme,
          ),
          _buildAnalyticsTab(expenses, members, categoriesProv, appProv, theme),
          _buildSettlementTab(tripProv, appProv, theme),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: 'add_expense',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const AddExpenseDialog(),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Settlement',
          ),
        ],
      ),
    );
  }

  // ─── Expenses tab ──────────────────────────────────────────────────────────

  Widget _buildExpensesTab(
    List<Expense> expenses,
    List<Member> members,
    CategoriesProvider categoriesProv,
    Trip trip,
    double totalSpent,
    ThemeData theme,
  ) {
    if (expenses.isEmpty) return _buildEmptyState();
    return ListView(
      children: [
        if (trip.budget != null) _buildBudgetCard(totalSpent, trip.budget!),
        ..._buildGroupedExpenses(expenses, members, categoriesProv, theme),
        const SizedBox(height: 80),
      ],
    );
  }

  // ─── Analytics tab ─────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab(
    List<Expense> expenses,
    List<Member> members,
    CategoriesProvider categoriesProv,
    AppProvider appProv,
    ThemeData theme,
  ) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No data yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final cur = appProv.currency;
    final totalSpent = expenses.fold(0.0, (s, e) => s + e.amount);
    final avgPerPerson = members.isEmpty ? 0.0 : totalSpent / members.length;

    final Map<int, double> memberSpent = {};
    for (final e in expenses) {
      memberSpent[e.memberId] = (memberSpent[e.memberId] ?? 0) + e.amount;
    }

    final Map<int, double> catSpent = {};
    for (final e in expenses) {
      if (e.categoryId != null) {
        catSpent[e.categoryId!] = (catSpent[e.categoryId!] ?? 0) + e.amount;
      }
    }

    final Map<String, double> dailySpent = {};
    for (final e in expenses) {
      final key = DateFormat('yyyy-MM-dd').format(e.datetime);
      dailySpent[key] = (dailySpent[key] ?? 0) + e.amount;
    }
    final sortedDays = dailySpent.keys.toList()..sort();

    final memberEntries = memberSpent.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary stat cards
        Row(
          children: [
            _statCard(theme, 'Total', '$cur${totalSpent.toStringAsFixed(0)}'),
            const SizedBox(width: 8),
            _statCard(theme, 'Expenses', '${expenses.length}'),
            const SizedBox(width: 8),
            _statCard(
              theme,
              'Avg / person',
              '$cur${avgPerPerson.toStringAsFixed(0)}',
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Spending by member
        _sectionLabel('Spending by member'),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: _buildMemberPieChart(memberEntries)),
        const SizedBox(height: 12),
        _buildChartLegend([
          for (int i = 0; i < memberEntries.length; i++)
            (
              label: members
                  .firstWhere(
                    (m) => m.id == memberEntries[i].key,
                    orElse: () => const Member(id: -1, tripId: -1, name: '?'),
                  )
                  .name,
              value: '$cur${memberEntries[i].value.toStringAsFixed(0)}',
              colorIndex: i,
            ),
        ]),

        if (catSpent.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionLabel('Spending by category'),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: _buildCategoryChart(catSpent, categoriesProv),
          ),
        ],

        if (sortedDays.length > 1) ...[
          const SizedBox(height: 28),
          _sectionLabel('Daily spending'),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: _buildDailyChart(dailySpent, sortedDays, theme),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Settlement tab ────────────────────────────────────────────────────────

  Widget _buildSettlementTab(
    TripProvider tripProv,
    AppProvider appProv,
    ThemeData theme,
  ) {
    if (tripProv.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final result = tripProv.splitResult;
    if (result == null || result.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Everyone is settled up!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'No payments needed',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Minimum transactions to settle all debts',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: result.transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = result.transactions[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      child: const Icon(Icons.arrow_upward),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: t.from.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' owes '),
                            TextSpan(
                              text: t.to.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${appProv.currency}${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Chart helpers ─────────────────────────────────────────────────────────

  Widget _buildMemberPieChart(List<MapEntry<int, double>> entries) {
    return PieChart(
      PieChartData(
        sections: [
          for (int i = 0; i < entries.length; i++)
            PieChartSectionData(
              color: _kChartColors[i % _kChartColors.length],
              value: entries[i].value,
              title: '',
              radius: 65,
            ),
        ],
        centerSpaceRadius: 36,
      ),
    );
  }

  Widget _buildCategoryChart(
    Map<int, double> catSpent,
    CategoriesProvider catProv,
  ) {
    final entries = catSpent.entries.toList();
    final maxY = entries.map((e) => e.value).reduce(max) * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (int i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: _kChartColors[i % _kChartColors.length],
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx >= entries.length) return const SizedBox();
                final cat = catProv.categories.firstWhere(
                  (c) => c.id == entries[idx].key,
                  orElse: () => const Category(id: -1, title: '', emoji: '💸'),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(cat.emoji, style: const TextStyle(fontSize: 16)),
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

  Widget _buildDailyChart(
    Map<String, double> dailySpent,
    List<String> sortedDays,
    ThemeData theme,
  ) {
    final maxY = dailySpent.values.reduce(max) * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (int i = 0; i < sortedDays.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailySpent[sortedDays[i]]!,
                  color: theme.colorScheme.primary,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx >= sortedDays.length) return const SizedBox();
                final day = DateTime.parse(sortedDays[idx]);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(day),
                    style: const TextStyle(fontSize: 9),
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

  // ─── Small UI helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  Widget _statCard(ThemeData theme, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(
    List<({String label, String value, int colorIndex})> items,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _kChartColors[item.colorIndex % _kChartColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${item.label}  ${item.value}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }

  void _shareSettlement(TripProvider tripProv, AppProvider appProv) {
    final result = tripProv.splitResult;
    if (result == null) return;
    final buf = StringBuffer();
    buf.writeln('Settlement Summary — ${tripProv.trip?.title ?? 'Trip'}');
    buf.writeln();
    for (final t in result.transactions) {
      buf.writeln(
        '${t.from.name} owes ${t.to.name}  ${appProv.currency}${t.amount.toStringAsFixed(2)}',
      );
    }
    buf.writeln();
    buf.write('Minimum transactions to settle all debts.');
    Share.share(buf.toString());
  }

  // ─── Grouped expenses list ─────────────────────────────────────────────────

  List<Widget> _buildGroupedExpenses(
    List<Expense> expenses,
    List<Member> members,
    CategoriesProvider categoriesProv,
    ThemeData theme,
  ) {
    final sorted = [...expenses]
      ..sort((a, b) => b.datetime.compareTo(a.datetime));

    final Map<String, List<Expense>> groups = {};
    for (final e in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(e.datetime);
      groups.putIfAbsent(key, () => []).add(e);
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      final label = entry.key == today
          ? 'Today'
          : entry.key == yesterday
          ? 'Yesterday'
          : DateFormat('MMM d, yyyy').format(DateTime.parse(entry.key));

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );

      for (final expense in entry.value) {
        final category = categoriesProv.categories.firstWhere(
          (c) => c.id == expense.categoryId,
          orElse: () => const Category(id: -1, title: 'None', emoji: '💸'),
        );
        final payer = members.firstWhere(
          (m) => m.id == expense.memberId,
          orElse: () => const Member(id: -1, tripId: -1, name: 'Unknown'),
        );
        widgets.add(
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(category.emoji, style: const TextStyle(fontSize: 20)),
            ),
            title: Text(
              expense.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Paid by ${payer.name} • ${DateFormat('h:mm a').format(expense.datetime)}',
            ),
            trailing: Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 16,
              ),
            ),
            onTap: () =>
                _showExpenseDetails(context, expense, category, payer, members),
          ),
        );
      }
    }
    return widgets;
  }

  // ─── Budget card ───────────────────────────────────────────────────────────

  Widget _buildBudgetCard(double spent, double budget) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Budget',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first expense',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Expense detail bottom sheet ───────────────────────────────────────────

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
      builder: (bsCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bsCtx).viewInsets.bottom,
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
                      Navigator.pop(bsCtx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
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
                        context: bsCtx,
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
                        if (bsCtx.mounted) Navigator.pop(bsCtx);
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
      ),
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
