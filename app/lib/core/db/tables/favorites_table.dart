import 'package:drift/drift.dart';

@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get userId => text()();
  TextColumn get dishId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, dishId};
}
