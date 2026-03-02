import 'package:drift/drift.dart';

@DataClassName('RatingRow')
class Ratings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get restaurantId => text()();
  IntColumn get stars => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
