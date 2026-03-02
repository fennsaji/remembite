import 'package:drift/drift.dart';

/// reaction values: so_yummy | tasty | pretty_good | meh | never_again
/// synced_at null = pending sync to cloud
@DataClassName('ReactionRow')
class Reactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get dishId => text()();
  TextColumn get reaction => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
