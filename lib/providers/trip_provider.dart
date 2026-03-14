import 'dart:async';
import 'package:flutter/material.dart';
import '../database/drift_database.dart';
import '../services/split_calculator.dart';

class TripProvider extends ChangeNotifier {
  final AppDatabase db;
  final SplitCalculator _calculator = SplitCalculator();

  Trip? _trip;
  List<Member> _members = [];
  List<Expense> _expenses = [];
  List<ExpenseParticipant> _participants = [];
  SplitResult? _splitResult;

  StreamSubscription? _tripSub;
  StreamSubscription? _memberSub;
  StreamSubscription? _expenseSub;

  TripProvider(this.db);

  Trip? get trip => _trip;
  List<Member> get members => _members;
  List<Expense> get expenses => _expenses;
  SplitResult? get splitResult => _splitResult;

  void loadTrip(int tripId) async {
    // Cancel previous subscriptions
    _tripSub?.cancel();
    _memberSub?.cancel();
    _expenseSub?.cancel();

    _trip = await db.getTrip(tripId);
    notifyListeners();

    _memberSub = db.watchTripMembers(tripId).listen((members) {
      _members = members;
      _calculateSplits();
      notifyListeners();
    });

    _expenseSub = db.watchTripExpenses(tripId).listen((expenses) async {
      _expenses = expenses;
      // We also need all participants for all these expenses
      _participants.clear();
      for (final exp in _expenses) {
        final parts = await db.getExpenseParticipants(exp.id);
        _participants.addAll(parts);
      }
      _calculateSplits();
      notifyListeners();
    });
  }

  void _calculateSplits() {
    if (_members.isNotEmpty || _expenses.isNotEmpty) {
      _splitResult = _calculator.calculateSplits(
        _members,
        _expenses,
        _participants,
      );
    }
  }

  Future<void> addExpense(
    ExpensesCompanion expense,
    List<int> memberIds,
  ) async {
    await db.insertExpenseWithParticipants(expense, memberIds);
  }

  Future<void> updateExpense(Expense expense, List<int> newMemberIds) async {
    await db.updateExpenseWithParticipants(expense, newMemberIds);
  }

  Future<void> deleteExpense(Expense expense) async {
    await db.deleteExpense(expense);
  }

  Future<void> addMember(String name) async {
    if (_trip != null) {
      await db.insertMember(
        MembersCompanion.insert(tripId: _trip!.id, name: name),
      );
    }
  }

  Future<void> removeMember(Member member) async {
    await db.deleteMember(member);
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _memberSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }
}
