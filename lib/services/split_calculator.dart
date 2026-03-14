import '../database/drift_database.dart';

class Transaction {
  final Member from;
  final Member to;
  final double amount;

  Transaction({required this.from, required this.to, required this.amount});
}

class SplitResult {
  final Map<int, double> memberTotalSpent;
  final Map<int, double> memberBalances;
  final List<Transaction> transactions;

  SplitResult({
    required this.memberTotalSpent,
    required this.memberBalances,
    required this.transactions,
  });
}

class SplitCalculator {
  SplitResult calculateSplits(
    List<Member> members,
    List<Expense> expenses,
    List<ExpenseParticipant> participants,
  ) {
    // member.id -> amount
    final memberTotalSpent = <int, double>{};
    final memberBalances = <int, double>{};

    for (final member in members) {
      memberTotalSpent[member.id] = 0;
      memberBalances[member.id] = 0; // Balance = Paid - Owed
    }

    // Process expenses
    for (final expense in expenses) {
      if (memberTotalSpent.containsKey(expense.memberId)) {
        memberTotalSpent[expense.memberId] =
            memberTotalSpent[expense.memberId]! + expense.amount;
        memberBalances[expense.memberId] =
            memberBalances[expense.memberId]! + expense.amount;
      }

      // Find participants for this expense
      final expenseParticipants = participants
          .where((p) => p.expenseId == expense.id)
          .toList();
      if (expenseParticipants.isNotEmpty) {
        final splitAmount = expense.amount / expenseParticipants.length;
        for (final participant in expenseParticipants) {
          if (memberBalances.containsKey(participant.memberId)) {
            memberBalances[participant.memberId] =
                memberBalances[participant.memberId]! - splitAmount;
          }
        }
      }
    }

    // Now simplify transactions
    // Debtors: Negative balance (they owe money)
    // Creditors: Positive balance (they are owed money)
    final debtors = <Member, double>{};
    final creditors = <Member, double>{};

    for (final member in members) {
      final balance = memberBalances[member.id] ?? 0;
      // To avoid precision issues
      if (balance > 0.01) {
        creditors[member] = balance;
      } else if (balance < -0.01) {
        debtors[member] = -balance;
      }
    }

    final transactions = <Transaction>[];

    final debtorEntries = debtors.entries.toList();
    final creditorEntries = creditors.entries.toList();

    int i = 0; // debtors index
    int j = 0; // creditors index

    while (i < debtorEntries.length && j < creditorEntries.length) {
      final debtor = debtorEntries[i];
      final creditor = creditorEntries[j];

      final amountToSettle = debtor.value < creditor.value
          ? debtor.value
          : creditor.value;

      transactions.add(
        Transaction(from: debtor.key, to: creditor.key, amount: amountToSettle),
      );

      debtorEntries[i] = MapEntry(debtor.key, debtor.value - amountToSettle);
      creditorEntries[j] = MapEntry(
        creditor.key,
        creditor.value - amountToSettle,
      );

      if (debtorEntries[i].value < 0.01) {
        i++;
      }
      if (creditorEntries[j].value < 0.01) {
        j++;
      }
    }

    return SplitResult(
      memberTotalSpent: memberTotalSpent,
      memberBalances: memberBalances,
      transactions: transactions,
    );
  }
}
