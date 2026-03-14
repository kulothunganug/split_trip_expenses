import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/drift_database.dart';

class ImportExportService {
  final AppDatabase db;

  ImportExportService(this.db);

  Future<String> exportTripToJson(int tripId) async {
    final trip = await db.getTrip(tripId);
    final members = await db.getTripMembers(tripId);
    final expenses = await db.getTripExpenses(tripId);

    final categoryIds = expenses
        .map((e) => e.categoryId)
        .whereType<int>()
        .toSet();
    final allCategories = await db.getAllCategories();
    final usedCategories = allCategories
        .where((c) => categoryIds.contains(c.id))
        .toList();

    final allParticipants = <ExpenseParticipant>[];
    for (final expense in expenses) {
      final participants = await db.getExpenseParticipants(expense.id);
      allParticipants.addAll(participants);
    }

    final data = {
      'trip': {
        'title': trip.title,
        'budget': trip.budget,
        'createdAt': trip.createdAt.toIso8601String(),
      },
      'members': members
          .map(
            (m) => {
              'id': m
                  .id, // Keep old ID mapping for relationship matching during import
              'name': m.name,
            },
          )
          .toList(),
      'categories': usedCategories
          .map((c) => {'id': c.id, 'emoji': c.emoji, 'title': c.title})
          .toList(),
      'expenses': expenses
          .map(
            (e) => {
              'id': e.id,
              'memberId': e.memberId,
              'categoryId': e.categoryId,
              'title': e.title,
              'amount': e.amount,
              'datetime': e.datetime.toIso8601String(),
            },
          )
          .toList(),
      'participants': allParticipants
          .map((p) => {'expenseId': p.expenseId, 'memberId': p.memberId})
          .toList(),
    };

    return jsonEncode(data);
  }

  /// Imports a trip from JSON string
  Future<void> importTripFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    await db.transaction(() async {
      // 1. Insert Trip
      final tripMap = data['trip'];
      final tripId = await db.insertTrip(
        TripsCompanion.insert(
          title: tripMap['title'],
          budget: Value(tripMap['budget']),
          createdAt: Value(DateTime.parse(tripMap['createdAt'])),
        ),
      );

      // 2. Insert Members & Keep Map of oldId -> newId
      final oldToNewMemberIds = <int, int>{};
      for (final mMap in data['members']) {
        final oldId = mMap['id'] as int;
        final newId = await db.insertMember(
          MembersCompanion.insert(tripId: tripId, name: mMap['name']),
        );
        oldToNewMemberIds[oldId] = newId;
      }

      // 3. Merge/Insert Categories
      final allDbCategories = await db.getAllCategories();
      final oldToNewCategoryIds = <int, int>{};

      for (final cMap in (data['categories'] ?? [])) {
        final oldId = cMap['id'] as int;
        // See if category with same emoji and title exists
        final existing = allDbCategories
            .where((c) => c.emoji == cMap['emoji'] && c.title == cMap['title'])
            .firstOrNull;

        if (existing != null) {
          oldToNewCategoryIds[oldId] = existing.id;
        } else {
          final newId = await db.insertCategory(
            CategoriesCompanion.insert(
              emoji: cMap['emoji'],
              title: cMap['title'],
            ),
          );
          oldToNewCategoryIds[oldId] = newId;
        }
      }

      // 4. Insert Expenses & Keep Map of oldExpenseId -> newExpenseId
      final oldToNewExpenseIds = <int, int>{};
      for (final eMap in data['expenses']) {
        final oldExpId = eMap['id'] as int;
        final oldMemId = eMap['memberId'] as int;
        final oldCatId = eMap['categoryId'] as int?;

        final newMemId = oldToNewMemberIds[oldMemId];
        if (newMemId == null) continue; // corrupted data

        final newCatId = oldCatId != null
            ? oldToNewCategoryIds[oldCatId]
            : null;

        final newExpId = await db.insertExpense(
          ExpensesCompanion.insert(
            tripId: tripId,
            memberId: newMemId,
            categoryId: Value(newCatId),
            title: eMap['title'],
            amount: eMap['amount'],
            datetime: Value(DateTime.parse(eMap['datetime'])),
          ),
        );
        oldToNewExpenseIds[oldExpId] = newExpId;
      }

      // 5. Insert Participants
      for (final pMap in data['participants']) {
        final oldExpId = pMap['expenseId'] as int;
        final oldMemId = pMap['memberId'] as int;

        final newExpId = oldToNewExpenseIds[oldExpId];
        final newMemId = oldToNewMemberIds[oldMemId];

        if (newExpId != null && newMemId != null) {
          await db.insertExpenseParticipant(
            ExpenseParticipantsCompanion.insert(
              expenseId: newExpId,
              memberId: newMemId,
            ),
          );
        }
      }
    });
  }

  // A basic CSV Export just for display/spreadsheet
  Future<String> exportTripToCsv(int tripId) async {
    final expenses = await db.getTripExpenses(tripId);
    final members = await db.getTripMembers(tripId);
    final memberNames = {for (var m in members) m.id: m.name};

    final allCategories = await db.getAllCategories();
    final categoriesMap = {for (var c in allCategories) c.id: c.title};

    final StringBuffer buffer = StringBuffer();
    // CSV Header
    buffer.writeln("Date,Title,Category,Paid By,Amount");

    for (final exp in expenses) {
      final date = exp.datetime.toIso8601String().split('T').first;
      final title = exp.title.replaceAll(
        ',',
        ' ',
      ); // Ensure no commas break the CSV structure
      final category = exp.categoryId != null
          ? categoriesMap[exp.categoryId] ?? 'None'
          : 'None';
      final paidBy = memberNames[exp.memberId] ?? 'Unknown';
      final amount = exp.amount.toStringAsFixed(2);

      buffer.writeln("$date,$title,$category,$paidBy,$amount");
    }

    return buffer.toString();
  }
}
