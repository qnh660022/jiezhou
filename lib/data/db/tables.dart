/// drift 表定义：9 张表。
library;
import "package:drift/drift.dart";

class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(Constant("📁"))();
  BoolColumn get budgetEnabled => boolean().withDefault(Constant(false))();
  IntColumn get budgetCents => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class Members extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(Constant(0))();
  IntColumn get createdAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get destination => text().withDefault(Constant(""))();
  TextColumn get emoji => text().withDefault(Constant("✈️"))();
  TextColumn get cover => text().withDefault(Constant("ocean"))();
  IntColumn get startEpochDay => integer().withDefault(Constant(0))();
  IntColumn get endEpochDay => integer().withDefault(Constant(0))();
  TextColumn get note => text().withDefault(Constant(""))();
  TextColumn get groupId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class TripItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  IntColumn get dateEpochDay => integer().withDefault(Constant(0))();
  TextColumn get type => text().withDefault(Constant("attraction"))();
  TextColumn get name => text().withDefault(Constant(""))();
  TextColumn get address => text().withDefault(Constant(""))();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get photoUri => text().nullable()();
  IntColumn get startTimeMin => integer().nullable()();
  IntColumn get durationMin => integer().nullable()();
  IntColumn get costCents => integer().nullable()();
  TextColumn get costCurrency => text().withDefault(Constant("CNY"))();
  TextColumn get note => text().withDefault(Constant(""))();
  TextColumn get fromName => text().withDefault(Constant(""))();
  TextColumn get fromAddress => text().withDefault(Constant(""))();
  RealColumn get fromLat => real().nullable()();
  RealColumn get fromLng => real().nullable()();
  TextColumn get toName => text().withDefault(Constant(""))();
  TextColumn get toAddress => text().withDefault(Constant(""))();
  RealColumn get toLat => real().nullable()();
  RealColumn get toLng => real().nullable()();
  TextColumn get flightNo => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class AlbumPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get uri => text()();
  IntColumn get dayEpochDay => integer().nullable()();
  IntColumn get createdAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text().withDefault(Constant("trip"))();
  TextColumn get tripId => text().nullable()();
  TextColumn get category => text().withDefault(Constant("other"))();
  TextColumn get label => text().withDefault(Constant(""))();
  BoolColumn get done => boolean().withDefault(Constant(false))();
  IntColumn get sortOrder => integer().withDefault(Constant(0))();
  @override Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  IntColumn get dateEpochDay => integer().withDefault(Constant(0))();
  TextColumn get title => text().withDefault(Constant(""))();
  TextColumn get categoryKey => text().withDefault(Constant("other"))();
  TextColumn get type => text().withDefault(Constant("normal"))();
  IntColumn get amountCents => integer().withDefault(Constant(0))();
  TextColumn get currency => text().withDefault(Constant("CNY"))();
  RealColumn get rate => real().withDefault(Constant(1.0))();
  IntColumn get amountForeignCents => integer().nullable()();
  TextColumn get payersJson => text().withDefault(Constant("[]"))();
  TextColumn get sharesJson => text().withDefault(Constant("[]"))();
  TextColumn get shareMode => text().withDefault(Constant("equal"))();
  TextColumn get portionsJson => text().nullable()();
  TextColumn get note => text().withDefault(Constant(""))();
  TextColumn get settledRoundId => text().nullable()();
  TextColumn get tripId => text().nullable()();
  TextColumn get tripItemId => text().nullable()();
  IntColumn get createdAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class Settlements extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get status => text().withDefault(Constant("active"))();
  TextColumn get transfersJson => text().withDefault(Constant("[]"))();
  TextColumn get expenseIdsJson => text().withDefault(Constant("[]"))();
  IntColumn get roundNo => integer().withDefault(Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get name => text().withDefault(Constant(""))();
  TextColumn get icon => text().withDefault(Constant("📦"))();
  BoolColumn get builtin => boolean().withDefault(Constant(false))();
  @override Set<Column> get primaryKey => {key};
}
