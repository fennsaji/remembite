import 'package:drift/drift.dart';

/// attribute_state values: classifying | classified | failed
@DataClassName('DishRow')
class Dishes extends Table {
  TextColumn get id => text()();
  TextColumn get restaurantId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  IntColumn get price => integer().nullable()();
  TextColumn get attributeState =>
      text().withDefault(const Constant('classifying'))();
  RealColumn get communityScore => real().nullable()();
  IntColumn get voteCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
