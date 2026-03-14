import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'drift_database.g.dart';

@DriftDatabase(
  tables: [Trips, Members, Categories, Expenses, ExpenseParticipants],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Trips CRUD
  Future<List<Trip>> getAllTrips() => select(trips).get();
  Stream<List<Trip>> watchAllTrips() => select(trips).watch();
  Future<Trip> getTrip(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingle();
  Future<int> insertTrip(TripsCompanion trip) => into(trips).insert(trip);
  Future<bool> updateTrip(Trip trip) => update(trips).replace(trip);
  Future<int> deleteTrip(Trip trip) => delete(trips).delete(trip);

  // Members CRUD
  Future<List<Member>> getTripMembers(int tripId) =>
      (select(members)..where((m) => m.tripId.equals(tripId))).get();
  Stream<List<Member>> watchTripMembers(int tripId) =>
      (select(members)..where((m) => m.tripId.equals(tripId))).watch();
  Future<int> insertMember(MembersCompanion member) =>
      into(members).insert(member);
  Future<bool> updateMember(Member member) => update(members).replace(member);
  Future<int> deleteMember(Member member) => delete(members).delete(member);

  // Categories CRUD
  Future<List<Category>> getAllCategories() => select(categories).get();
  Stream<List<Category>> watchAllCategories() => select(categories).watch();
  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);
  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);
  Future<int> deleteCategory(Category category) =>
      delete(categories).delete(category);

  // Default Categories
  Future<void> insertDefaultCategories() async {
    final count = await select(categories).get().then((value) => value.length);
    if (count == 0) {
      await batch((batch) {
        batch.insertAll(categories, [
          CategoriesCompanion.insert(emoji: '🍔', title: 'Food'),
          CategoriesCompanion.insert(emoji: '🚕', title: 'Transport'),
          CategoriesCompanion.insert(emoji: '🏨', title: 'Hotel'),
          CategoriesCompanion.insert(emoji: '🎉', title: 'Entertainment'),
          CategoriesCompanion.insert(emoji: '🛍️', title: 'Shopping'),
        ]);
      });
    }
  }

  // Expenses CRUD
  Future<List<Expense>> getTripExpenses(int tripId) =>
      (select(expenses)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.datetime, mode: OrderingMode.desc),
            ]))
          .get();

  Stream<List<Expense>> watchTripExpenses(int tripId) =>
      (select(expenses)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.datetime, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<int> insertExpense(ExpensesCompanion expense) =>
      into(expenses).insert(expense);
  Future<bool> updateExpense(Expense expense) =>
      update(expenses).replace(expense);
  Future<int> deleteExpense(Expense expense) =>
      delete(expenses).delete(expense);

  // Expense Participants CRUD
  Future<List<ExpenseParticipant>> getExpenseParticipants(int expenseId) =>
      (select(
        expenseParticipants,
      )..where((ep) => ep.expenseId.equals(expenseId))).get();

  Future<int> insertExpenseParticipant(
    ExpenseParticipantsCompanion participant,
  ) => into(expenseParticipants).insert(participant);

  Future<int> deleteExpenseParticipants(int expenseId) => (delete(
    expenseParticipants,
  )..where((ep) => ep.expenseId.equals(expenseId))).go();

  // Full Expense Insertion (Transaction)
  Future<void> insertExpenseWithParticipants(
    ExpensesCompanion expense,
    List<int> memberIds,
  ) async {
    return transaction(() async {
      final expenseId = await insertExpense(expense);
      for (final memberId in memberIds) {
        await insertExpenseParticipant(
          ExpenseParticipantsCompanion.insert(
            expenseId: expenseId,
            memberId: memberId,
          ),
        );
      }
    });
  }

  Future<void> updateExpenseWithParticipants(
    Expense expense,
    List<int> newMemberIds,
  ) async {
    return transaction(() async {
      await updateExpense(expense);
      await deleteExpenseParticipants(expense.id);
      for (final memberId in newMemberIds) {
        await insertExpenseParticipant(
          ExpenseParticipantsCompanion.insert(
            expenseId: expense.id,
            memberId: memberId,
          ),
        );
      }
    });
  }

  // To check if DB is open and let drift automatically enable foreign keys (SQLite specific)
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // optionally insert defaults
        await insertDefaultCategories();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
