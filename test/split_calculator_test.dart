import 'package:flutter_test/flutter_test.dart';
import 'package:split_trip_expense/services/split_calculator.dart';
import 'package:split_trip_expense/database/drift_database.dart';

void main() {
  group('SplitCalculator Tests', () {
    final calculator = SplitCalculator();

    test('Equal split between two members', () {
      final members = [
        const Member(id: 1, tripId: 1, name: 'Alice'),
        const Member(id: 2, tripId: 1, name: 'Bob'),
      ];

      final expenses = [
        Expense(
          id: 101,
          tripId: 1,
          memberId: 1,
          title: 'Lunch',
          amount: 100.0,
          datetime: DateTime.now(),
        ),
      ];

      final participants = [
        const ExpenseParticipant(id: 201, expenseId: 101, memberId: 1),
        const ExpenseParticipant(id: 202, expenseId: 101, memberId: 2),
      ];

      final result = calculator.calculateSplits(
        members,
        expenses,
        participants,
      );

      expect(result.memberTotalSpent[1], 100.0);
      expect(result.memberTotalSpent[2], 0.0);

      // Alice paid 100. She owes 50. Her balance should be +50 (creditor)
      // Bob paid 0. He owes 50. His balance should be -50 (debtor)
      expect(result.memberBalances[1], 50.0);
      expect(result.memberBalances[2], -50.0);

      expect(result.transactions.length, 1);

      final transaction = result.transactions.first;
      expect(transaction.from.id, 2); // Bob pays
      expect(transaction.to.id, 1); // Alice receives
      expect(transaction.amount, 50.0);
    });

    test('Complex split among three members', () {
      final members = [
        const Member(id: 1, tripId: 1, name: 'A'),
        const Member(id: 2, tripId: 1, name: 'B'),
        const Member(id: 3, tripId: 1, name: 'C'),
      ];

      final expenses = [
        Expense(
          id: 1,
          tripId: 1,
          memberId: 1,
          title: 'Hotel',
          amount: 300.0,
          datetime: DateTime.now(),
        ), // A pays 300 for A, B, C (100 each)
        Expense(
          id: 2,
          tripId: 1,
          memberId: 2,
          title: 'Food',
          amount: 50.0,
          datetime: DateTime.now(),
        ), // B pays 50 for B, C (25 each)
      ];

      final participants = [
        const ExpenseParticipant(id: 1, expenseId: 1, memberId: 1),
        const ExpenseParticipant(id: 2, expenseId: 1, memberId: 2),
        const ExpenseParticipant(id: 3, expenseId: 1, memberId: 3),
        const ExpenseParticipant(id: 4, expenseId: 2, memberId: 2),
        const ExpenseParticipant(id: 5, expenseId: 2, memberId: 3),
      ];

      final result = calculator.calculateSplits(
        members,
        expenses,
        participants,
      );

      // Totals
      expect(result.memberTotalSpent[1], 300.0);
      expect(result.memberTotalSpent[2], 50.0);
      expect(result.memberTotalSpent[3], 0.0);

      // Balances
      // A paid 300, owes 100 -> +200
      // B paid 50, owes 100 (from A) + 25 (from B) = 125 -> -75
      // C paid 0, owes 100 (from A) + 25 (from B) = 125 -> -125

      expect(result.memberBalances[1], 200.0);
      expect(result.memberBalances[2], -75.0);
      expect(result.memberBalances[3], -125.0);

      expect(result.transactions.length, 2);
    });
  });
}
