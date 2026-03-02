import 'package:drift/drift.dart';

@DataClassName('RestaurantRow')
class Restaurants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get city => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get cuisineType => text().nullable()();
  RealColumn get avgRating => real().nullable()();
  IntColumn get ratingCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
