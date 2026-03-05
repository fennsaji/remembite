import 'package:drift/drift.dart';

class DishIntents extends Table {
  TextColumn get id => text()();
  TextColumn get dishId => text()();
  TextColumn get intent => text().withDefault(const Constant('want_to_try'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
