import 'package:drift/drift.dart';

class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  RealColumn get budget => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get emoji => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get memberId => integer().references(
    Members,
    #id,
    onDelete: KeyAction.cascade,
  )(); // who paid
  IntColumn get categoryId => integer()
      .references(Categories, #id, onDelete: KeyAction.setNull)
      .nullable()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  RealColumn get amount => real()();
  DateTimeColumn get datetime => dateTime().withDefault(currentDateAndTime)();
}

class ExpenseParticipants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get expenseId =>
      integer().references(Expenses, #id, onDelete: KeyAction.cascade)();
  IntColumn get memberId =>
      integer().references(Members, #id, onDelete: KeyAction.cascade)();
}
