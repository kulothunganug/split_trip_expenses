import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/trip_provider.dart';
import '../providers/app_provider.dart';

class SplitSettlementDialog extends StatelessWidget {
  const SplitSettlementDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tripProv = context.watch<TripProvider>();
    final appProv = context.watch<AppProvider>();
    final result = tripProv.splitResult;
    final theme = Theme.of(context);

    if (result == null || result.transactions.isEmpty) {
      if (tripProv.expenses.isEmpty) {
        return _buildEmptyState(context, 'No expenses added yet.');
      }
      return _buildEmptyState(context, 'Everyone is settled up! 🎉');
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Settlement Summary',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share summary',
                    onPressed: () => _shareSummary(context, result, appProv.currency),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('How to settle all debts with minimum transactions:'),
          const Divider(height: 32),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: result.transactions.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final transaction = result.transactions[index];
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodyLarge,
                                children: [
                                  TextSpan(
                                    text: transaction.from.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' owes '),
                                  TextSpan(
                                    text: transaction.to.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${appProv.currency}${transaction.amount.toStringAsFixed(2)}',
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareSummary(BuildContext context, dynamic result, String currency) {
    final tripProv = context.read<TripProvider>();
    final tripName = tripProv.trip?.title ?? 'Trip';
    final lines = StringBuffer();
    lines.writeln('Settlement Summary — $tripName');
    lines.writeln();
    for (final t in result.transactions) {
      lines.writeln('${t.from.name} owes ${t.to.name}  $currency${t.amount.toStringAsFixed(2)}');
    }
    lines.writeln();
    lines.write('Minimum transactions to settle all debts.');
    Share.share(lines.toString());
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
