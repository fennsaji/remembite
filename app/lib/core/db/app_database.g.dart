// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RestaurantsTable extends Restaurants
    with TableInfo<$RestaurantsTable, RestaurantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestaurantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cuisineTypeMeta = const VerificationMeta(
    'cuisineType',
  );
  @override
  late final GeneratedColumn<String> cuisineType = GeneratedColumn<String>(
    'cuisine_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgRatingMeta = const VerificationMeta(
    'avgRating',
  );
  @override
  late final GeneratedColumn<double> avgRating = GeneratedColumn<double>(
    'avg_rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingCountMeta = const VerificationMeta(
    'ratingCount',
  );
  @override
  late final GeneratedColumn<int> ratingCount = GeneratedColumn<int>(
    'rating_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    city,
    latitude,
    longitude,
    cuisineType,
    avgRating,
    ratingCount,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restaurants';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestaurantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('cuisine_type')) {
      context.handle(
        _cuisineTypeMeta,
        cuisineType.isAcceptableOrUnknown(
          data['cuisine_type']!,
          _cuisineTypeMeta,
        ),
      );
    }
    if (data.containsKey('avg_rating')) {
      context.handle(
        _avgRatingMeta,
        avgRating.isAcceptableOrUnknown(data['avg_rating']!, _avgRatingMeta),
      );
    }
    if (data.containsKey('rating_count')) {
      context.handle(
        _ratingCountMeta,
        ratingCount.isAcceptableOrUnknown(
          data['rating_count']!,
          _ratingCountMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestaurantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestaurantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      cuisineType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cuisine_type'],
      ),
      avgRating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_rating'],
      ),
      ratingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating_count'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $RestaurantsTable createAlias(String alias) {
    return $RestaurantsTable(attachedDatabase, alias);
  }
}

class RestaurantRow extends DataClass implements Insertable<RestaurantRow> {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String? cuisineType;
  final double? avgRating;
  final int ratingCount;
  final DateTime? syncedAt;
  const RestaurantRow({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.cuisineType,
    this.avgRating,
    required this.ratingCount,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['city'] = Variable<String>(city);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || cuisineType != null) {
      map['cuisine_type'] = Variable<String>(cuisineType);
    }
    if (!nullToAbsent || avgRating != null) {
      map['avg_rating'] = Variable<double>(avgRating);
    }
    map['rating_count'] = Variable<int>(ratingCount);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  RestaurantsCompanion toCompanion(bool nullToAbsent) {
    return RestaurantsCompanion(
      id: Value(id),
      name: Value(name),
      city: Value(city),
      latitude: Value(latitude),
      longitude: Value(longitude),
      cuisineType: cuisineType == null && nullToAbsent
          ? const Value.absent()
          : Value(cuisineType),
      avgRating: avgRating == null && nullToAbsent
          ? const Value.absent()
          : Value(avgRating),
      ratingCount: Value(ratingCount),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory RestaurantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestaurantRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      city: serializer.fromJson<String>(json['city']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      cuisineType: serializer.fromJson<String?>(json['cuisineType']),
      avgRating: serializer.fromJson<double?>(json['avgRating']),
      ratingCount: serializer.fromJson<int>(json['ratingCount']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'city': serializer.toJson<String>(city),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'cuisineType': serializer.toJson<String?>(cuisineType),
      'avgRating': serializer.toJson<double?>(avgRating),
      'ratingCount': serializer.toJson<int>(ratingCount),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  RestaurantRow copyWith({
    String? id,
    String? name,
    String? city,
    double? latitude,
    double? longitude,
    Value<String?> cuisineType = const Value.absent(),
    Value<double?> avgRating = const Value.absent(),
    int? ratingCount,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => RestaurantRow(
    id: id ?? this.id,
    name: name ?? this.name,
    city: city ?? this.city,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    cuisineType: cuisineType.present ? cuisineType.value : this.cuisineType,
    avgRating: avgRating.present ? avgRating.value : this.avgRating,
    ratingCount: ratingCount ?? this.ratingCount,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  RestaurantRow copyWithCompanion(RestaurantsCompanion data) {
    return RestaurantRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      city: data.city.present ? data.city.value : this.city,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      cuisineType: data.cuisineType.present
          ? data.cuisineType.value
          : this.cuisineType,
      avgRating: data.avgRating.present ? data.avgRating.value : this.avgRating,
      ratingCount: data.ratingCount.present
          ? data.ratingCount.value
          : this.ratingCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('city: $city, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cuisineType: $cuisineType, ')
          ..write('avgRating: $avgRating, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    city,
    latitude,
    longitude,
    cuisineType,
    avgRating,
    ratingCount,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestaurantRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.city == this.city &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.cuisineType == this.cuisineType &&
          other.avgRating == this.avgRating &&
          other.ratingCount == this.ratingCount &&
          other.syncedAt == this.syncedAt);
}

class RestaurantsCompanion extends UpdateCompanion<RestaurantRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> city;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> cuisineType;
  final Value<double?> avgRating;
  final Value<int> ratingCount;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const RestaurantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.city = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.cuisineType = const Value.absent(),
    this.avgRating = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestaurantsCompanion.insert({
    required String id,
    required String name,
    required String city,
    required double latitude,
    required double longitude,
    this.cuisineType = const Value.absent(),
    this.avgRating = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       city = Value(city),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<RestaurantRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? city,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? cuisineType,
    Expression<double>? avgRating,
    Expression<int>? ratingCount,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cuisineType != null) 'cuisine_type': cuisineType,
      if (avgRating != null) 'avg_rating': avgRating,
      if (ratingCount != null) 'rating_count': ratingCount,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestaurantsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? city,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String?>? cuisineType,
    Value<double?>? avgRating,
    Value<int>? ratingCount,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return RestaurantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cuisineType: cuisineType ?? this.cuisineType,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (cuisineType.present) {
      map['cuisine_type'] = Variable<String>(cuisineType.value);
    }
    if (avgRating.present) {
      map['avg_rating'] = Variable<double>(avgRating.value);
    }
    if (ratingCount.present) {
      map['rating_count'] = Variable<int>(ratingCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('city: $city, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cuisineType: $cuisineType, ')
          ..write('avgRating: $avgRating, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DishesTable extends Dishes with TableInfo<$DishesTable, DishRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DishesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restaurantIdMeta = const VerificationMeta(
    'restaurantId',
  );
  @override
  late final GeneratedColumn<String> restaurantId = GeneratedColumn<String>(
    'restaurant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attributeStateMeta = const VerificationMeta(
    'attributeState',
  );
  @override
  late final GeneratedColumn<String> attributeState = GeneratedColumn<String>(
    'attribute_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('classifying'),
  );
  static const VerificationMeta _communityScoreMeta = const VerificationMeta(
    'communityScore',
  );
  @override
  late final GeneratedColumn<double> communityScore = GeneratedColumn<double>(
    'community_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteCountMeta = const VerificationMeta(
    'voteCount',
  );
  @override
  late final GeneratedColumn<int> voteCount = GeneratedColumn<int>(
    'vote_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    restaurantId,
    name,
    category,
    price,
    attributeState,
    communityScore,
    voteCount,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dishes';
  @override
  VerificationContext validateIntegrity(
    Insertable<DishRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restaurant_id')) {
      context.handle(
        _restaurantIdMeta,
        restaurantId.isAcceptableOrUnknown(
          data['restaurant_id']!,
          _restaurantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restaurantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('attribute_state')) {
      context.handle(
        _attributeStateMeta,
        attributeState.isAcceptableOrUnknown(
          data['attribute_state']!,
          _attributeStateMeta,
        ),
      );
    }
    if (data.containsKey('community_score')) {
      context.handle(
        _communityScoreMeta,
        communityScore.isAcceptableOrUnknown(
          data['community_score']!,
          _communityScoreMeta,
        ),
      );
    }
    if (data.containsKey('vote_count')) {
      context.handle(
        _voteCountMeta,
        voteCount.isAcceptableOrUnknown(data['vote_count']!, _voteCountMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DishRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DishRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restaurantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restaurant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      ),
      attributeState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attribute_state'],
      )!,
      communityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}community_score'],
      ),
      voteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vote_count'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $DishesTable createAlias(String alias) {
    return $DishesTable(attachedDatabase, alias);
  }
}

class DishRow extends DataClass implements Insertable<DishRow> {
  final String id;
  final String restaurantId;
  final String name;
  final String? category;
  final int? price;
  final String attributeState;
  final double? communityScore;
  final int voteCount;
  final DateTime? syncedAt;
  const DishRow({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.category,
    this.price,
    required this.attributeState,
    this.communityScore,
    required this.voteCount,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['restaurant_id'] = Variable<String>(restaurantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    map['attribute_state'] = Variable<String>(attributeState);
    if (!nullToAbsent || communityScore != null) {
      map['community_score'] = Variable<double>(communityScore);
    }
    map['vote_count'] = Variable<int>(voteCount);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  DishesCompanion toCompanion(bool nullToAbsent) {
    return DishesCompanion(
      id: Value(id),
      restaurantId: Value(restaurantId),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      attributeState: Value(attributeState),
      communityScore: communityScore == null && nullToAbsent
          ? const Value.absent()
          : Value(communityScore),
      voteCount: Value(voteCount),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory DishRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DishRow(
      id: serializer.fromJson<String>(json['id']),
      restaurantId: serializer.fromJson<String>(json['restaurantId']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      price: serializer.fromJson<int?>(json['price']),
      attributeState: serializer.fromJson<String>(json['attributeState']),
      communityScore: serializer.fromJson<double?>(json['communityScore']),
      voteCount: serializer.fromJson<int>(json['voteCount']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'restaurantId': serializer.toJson<String>(restaurantId),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'price': serializer.toJson<int?>(price),
      'attributeState': serializer.toJson<String>(attributeState),
      'communityScore': serializer.toJson<double?>(communityScore),
      'voteCount': serializer.toJson<int>(voteCount),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  DishRow copyWith({
    String? id,
    String? restaurantId,
    String? name,
    Value<String?> category = const Value.absent(),
    Value<int?> price = const Value.absent(),
    String? attributeState,
    Value<double?> communityScore = const Value.absent(),
    int? voteCount,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => DishRow(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    price: price.present ? price.value : this.price,
    attributeState: attributeState ?? this.attributeState,
    communityScore: communityScore.present
        ? communityScore.value
        : this.communityScore,
    voteCount: voteCount ?? this.voteCount,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  DishRow copyWithCompanion(DishesCompanion data) {
    return DishRow(
      id: data.id.present ? data.id.value : this.id,
      restaurantId: data.restaurantId.present
          ? data.restaurantId.value
          : this.restaurantId,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      price: data.price.present ? data.price.value : this.price,
      attributeState: data.attributeState.present
          ? data.attributeState.value
          : this.attributeState,
      communityScore: data.communityScore.present
          ? data.communityScore.value
          : this.communityScore,
      voteCount: data.voteCount.present ? data.voteCount.value : this.voteCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DishRow(')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('attributeState: $attributeState, ')
          ..write('communityScore: $communityScore, ')
          ..write('voteCount: $voteCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    restaurantId,
    name,
    category,
    price,
    attributeState,
    communityScore,
    voteCount,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DishRow &&
          other.id == this.id &&
          other.restaurantId == this.restaurantId &&
          other.name == this.name &&
          other.category == this.category &&
          other.price == this.price &&
          other.attributeState == this.attributeState &&
          other.communityScore == this.communityScore &&
          other.voteCount == this.voteCount &&
          other.syncedAt == this.syncedAt);
}

class DishesCompanion extends UpdateCompanion<DishRow> {
  final Value<String> id;
  final Value<String> restaurantId;
  final Value<String> name;
  final Value<String?> category;
  final Value<int?> price;
  final Value<String> attributeState;
  final Value<double?> communityScore;
  final Value<int> voteCount;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const DishesCompanion({
    this.id = const Value.absent(),
    this.restaurantId = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.attributeState = const Value.absent(),
    this.communityScore = const Value.absent(),
    this.voteCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DishesCompanion.insert({
    required String id,
    required String restaurantId,
    required String name,
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.attributeState = const Value.absent(),
    this.communityScore = const Value.absent(),
    this.voteCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       restaurantId = Value(restaurantId),
       name = Value(name);
  static Insertable<DishRow> custom({
    Expression<String>? id,
    Expression<String>? restaurantId,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? price,
    Expression<String>? attributeState,
    Expression<double>? communityScore,
    Expression<int>? voteCount,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (restaurantId != null) 'restaurant_id': restaurantId,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (price != null) 'price': price,
      if (attributeState != null) 'attribute_state': attributeState,
      if (communityScore != null) 'community_score': communityScore,
      if (voteCount != null) 'vote_count': voteCount,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DishesCompanion copyWith({
    Value<String>? id,
    Value<String>? restaurantId,
    Value<String>? name,
    Value<String?>? category,
    Value<int?>? price,
    Value<String>? attributeState,
    Value<double?>? communityScore,
    Value<int>? voteCount,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return DishesCompanion(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      attributeState: attributeState ?? this.attributeState,
      communityScore: communityScore ?? this.communityScore,
      voteCount: voteCount ?? this.voteCount,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (restaurantId.present) {
      map['restaurant_id'] = Variable<String>(restaurantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (attributeState.present) {
      map['attribute_state'] = Variable<String>(attributeState.value);
    }
    if (communityScore.present) {
      map['community_score'] = Variable<double>(communityScore.value);
    }
    if (voteCount.present) {
      map['vote_count'] = Variable<int>(voteCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DishesCompanion(')
          ..write('id: $id, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('attributeState: $attributeState, ')
          ..write('communityScore: $communityScore, ')
          ..write('voteCount: $voteCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReactionsTable extends Reactions
    with TableInfo<$ReactionsTable, ReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dishIdMeta = const VerificationMeta('dishId');
  @override
  late final GeneratedColumn<String> dishId = GeneratedColumn<String>(
    'dish_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reactionMeta = const VerificationMeta(
    'reaction',
  );
  @override
  late final GeneratedColumn<String> reaction = GeneratedColumn<String>(
    'reaction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    dishId,
    reaction,
    createdAt,
    updatedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('dish_id')) {
      context.handle(
        _dishIdMeta,
        dishId.isAcceptableOrUnknown(data['dish_id']!, _dishIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dishIdMeta);
    }
    if (data.containsKey('reaction')) {
      context.handle(
        _reactionMeta,
        reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta),
      );
    } else if (isInserting) {
      context.missing(_reactionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dishId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dish_id'],
      )!,
      reaction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reaction'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $ReactionsTable createAlias(String alias) {
    return $ReactionsTable(attachedDatabase, alias);
  }
}

class ReactionRow extends DataClass implements Insertable<ReactionRow> {
  final String id;
  final String userId;
  final String dishId;
  final String reaction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  const ReactionRow({
    required this.id,
    required this.userId,
    required this.dishId,
    required this.reaction,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['dish_id'] = Variable<String>(dishId);
    map['reaction'] = Variable<String>(reaction);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  ReactionsCompanion toCompanion(bool nullToAbsent) {
    return ReactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      dishId: Value(dishId),
      reaction: Value(reaction),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ReactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReactionRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      dishId: serializer.fromJson<String>(json['dishId']),
      reaction: serializer.fromJson<String>(json['reaction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'dishId': serializer.toJson<String>(dishId),
      'reaction': serializer.toJson<String>(reaction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  ReactionRow copyWith({
    String? id,
    String? userId,
    String? dishId,
    String? reaction,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => ReactionRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    dishId: dishId ?? this.dishId,
    reaction: reaction ?? this.reaction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  ReactionRow copyWithCompanion(ReactionsCompanion data) {
    return ReactionRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      dishId: data.dishId.present ? data.dishId.value : this.dishId,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReactionRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('dishId: $dishId, ')
          ..write('reaction: $reaction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, dishId, reaction, createdAt, updatedAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReactionRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.dishId == this.dishId &&
          other.reaction == this.reaction &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class ReactionsCompanion extends UpdateCompanion<ReactionRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> dishId;
  final Value<String> reaction;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const ReactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.dishId = const Value.absent(),
    this.reaction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionsCompanion.insert({
    required String id,
    required String userId,
    required String dishId,
    required String reaction,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       dishId = Value(dishId),
       reaction = Value(reaction),
       createdAt = Value(createdAt);
  static Insertable<ReactionRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? dishId,
    Expression<String>? reaction,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (dishId != null) 'dish_id': dishId,
      if (reaction != null) 'reaction': reaction,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? dishId,
    Value<String>? reaction,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return ReactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dishId: dishId ?? this.dishId,
      reaction: reaction ?? this.reaction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dishId.present) {
      map['dish_id'] = Variable<String>(dishId.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<String>(reaction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('dishId: $dishId, ')
          ..write('reaction: $reaction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RatingsTable extends Ratings with TableInfo<$RatingsTable, RatingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restaurantIdMeta = const VerificationMeta(
    'restaurantId',
  );
  @override
  late final GeneratedColumn<String> restaurantId = GeneratedColumn<String>(
    'restaurant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _starsMeta = const VerificationMeta('stars');
  @override
  late final GeneratedColumn<int> stars = GeneratedColumn<int>(
    'stars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    restaurantId,
    stars,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ratings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RatingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('restaurant_id')) {
      context.handle(
        _restaurantIdMeta,
        restaurantId.isAcceptableOrUnknown(
          data['restaurant_id']!,
          _restaurantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restaurantIdMeta);
    }
    if (data.containsKey('stars')) {
      context.handle(
        _starsMeta,
        stars.isAcceptableOrUnknown(data['stars']!, _starsMeta),
      );
    } else if (isInserting) {
      context.missing(_starsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RatingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      restaurantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restaurant_id'],
      )!,
      stars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stars'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $RatingsTable createAlias(String alias) {
    return $RatingsTable(attachedDatabase, alias);
  }
}

class RatingRow extends DataClass implements Insertable<RatingRow> {
  final String id;
  final String userId;
  final String restaurantId;
  final int stars;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const RatingRow({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.stars,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['restaurant_id'] = Variable<String>(restaurantId);
    map['stars'] = Variable<int>(stars);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  RatingsCompanion toCompanion(bool nullToAbsent) {
    return RatingsCompanion(
      id: Value(id),
      userId: Value(userId),
      restaurantId: Value(restaurantId),
      stars: Value(stars),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory RatingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      restaurantId: serializer.fromJson<String>(json['restaurantId']),
      stars: serializer.fromJson<int>(json['stars']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'restaurantId': serializer.toJson<String>(restaurantId),
      'stars': serializer.toJson<int>(stars),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  RatingRow copyWith({
    String? id,
    String? userId,
    String? restaurantId,
    int? stars,
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => RatingRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    restaurantId: restaurantId ?? this.restaurantId,
    stars: stars ?? this.stars,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  RatingRow copyWithCompanion(RatingsCompanion data) {
    return RatingRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      restaurantId: data.restaurantId.present
          ? data.restaurantId.value
          : this.restaurantId,
      stars: data.stars.present ? data.stars.value : this.stars,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('stars: $stars, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, restaurantId, stars, createdAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.restaurantId == this.restaurantId &&
          other.stars == this.stars &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class RatingsCompanion extends UpdateCompanion<RatingRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> restaurantId;
  final Value<int> stars;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const RatingsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.restaurantId = const Value.absent(),
    this.stars = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatingsCompanion.insert({
    required String id,
    required String userId,
    required String restaurantId,
    required int stars,
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       restaurantId = Value(restaurantId),
       stars = Value(stars),
       createdAt = Value(createdAt);
  static Insertable<RatingRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? restaurantId,
    Expression<int>? stars,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (restaurantId != null) 'restaurant_id': restaurantId,
      if (stars != null) 'stars': stars,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatingsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? restaurantId,
    Value<int>? stars,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return RatingsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      stars: stars ?? this.stars,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (restaurantId.present) {
      map['restaurant_id'] = Variable<String>(restaurantId.value);
    }
    if (stars.present) {
      map['stars'] = Variable<int>(stars.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('restaurantId: $restaurantId, ')
          ..write('stars: $stars, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dishIdMeta = const VerificationMeta('dishId');
  @override
  late final GeneratedColumn<String> dishId = GeneratedColumn<String>(
    'dish_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, dishId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('dish_id')) {
      context.handle(
        _dishIdMeta,
        dishId.isAcceptableOrUnknown(data['dish_id']!, _dishIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dishIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, dishId};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dishId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dish_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String userId;
  final String dishId;
  final DateTime createdAt;
  const FavoriteRow({
    required this.userId,
    required this.dishId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['dish_id'] = Variable<String>(dishId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      userId: Value(userId),
      dishId: Value(dishId),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      userId: serializer.fromJson<String>(json['userId']),
      dishId: serializer.fromJson<String>(json['dishId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'dishId': serializer.toJson<String>(dishId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteRow copyWith({String? userId, String? dishId, DateTime? createdAt}) =>
      FavoriteRow(
        userId: userId ?? this.userId,
        dishId: dishId ?? this.dishId,
        createdAt: createdAt ?? this.createdAt,
      );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      dishId: data.dishId.present ? data.dishId.value : this.dishId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('userId: $userId, ')
          ..write('dishId: $dishId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, dishId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.userId == this.userId &&
          other.dishId == this.dishId &&
          other.createdAt == this.createdAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> userId;
  final Value<String> dishId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.userId = const Value.absent(),
    this.dishId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String userId,
    required String dishId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       dishId = Value(dishId),
       createdAt = Value(createdAt);
  static Insertable<FavoriteRow> custom({
    Expression<String>? userId,
    Expression<String>? dishId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (dishId != null) 'dish_id': dishId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? userId,
    Value<String>? dishId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      userId: userId ?? this.userId,
      dishId: dishId ?? this.dishId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dishId.present) {
      map['dish_id'] = Variable<String>(dishId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('userId: $userId, ')
          ..write('dishId: $dishId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RestaurantsTable restaurants = $RestaurantsTable(this);
  late final $DishesTable dishes = $DishesTable(this);
  late final $ReactionsTable reactions = $ReactionsTable(this);
  late final $RatingsTable ratings = $RatingsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final RestaurantDao restaurantDao = RestaurantDao(this as AppDatabase);
  late final DishDao dishDao = DishDao(this as AppDatabase);
  late final ReactionDao reactionDao = ReactionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    restaurants,
    dishes,
    reactions,
    ratings,
    favorites,
  ];
}

typedef $$RestaurantsTableCreateCompanionBuilder =
    RestaurantsCompanion Function({
      required String id,
      required String name,
      required String city,
      required double latitude,
      required double longitude,
      Value<String?> cuisineType,
      Value<double?> avgRating,
      Value<int> ratingCount,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$RestaurantsTableUpdateCompanionBuilder =
    RestaurantsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> city,
      Value<double> latitude,
      Value<double> longitude,
      Value<String?> cuisineType,
      Value<double?> avgRating,
      Value<int> ratingCount,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$RestaurantsTableFilterComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgRating => $composableBuilder(
    column: $table.avgRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestaurantsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgRating => $composableBuilder(
    column: $table.avgRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestaurantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestaurantsTable> {
  $$RestaurantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get cuisineType => $composableBuilder(
    column: $table.cuisineType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgRating =>
      $composableBuilder(column: $table.avgRating, builder: (column) => column);

  GeneratedColumn<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RestaurantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RestaurantsTable,
          RestaurantRow,
          $$RestaurantsTableFilterComposer,
          $$RestaurantsTableOrderingComposer,
          $$RestaurantsTableAnnotationComposer,
          $$RestaurantsTableCreateCompanionBuilder,
          $$RestaurantsTableUpdateCompanionBuilder,
          (
            RestaurantRow,
            BaseReferences<_$AppDatabase, $RestaurantsTable, RestaurantRow>,
          ),
          RestaurantRow,
          PrefetchHooks Function()
        > {
  $$RestaurantsTableTableManager(_$AppDatabase db, $RestaurantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestaurantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestaurantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestaurantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String?> cuisineType = const Value.absent(),
                Value<double?> avgRating = const Value.absent(),
                Value<int> ratingCount = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestaurantsCompanion(
                id: id,
                name: name,
                city: city,
                latitude: latitude,
                longitude: longitude,
                cuisineType: cuisineType,
                avgRating: avgRating,
                ratingCount: ratingCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String city,
                required double latitude,
                required double longitude,
                Value<String?> cuisineType = const Value.absent(),
                Value<double?> avgRating = const Value.absent(),
                Value<int> ratingCount = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestaurantsCompanion.insert(
                id: id,
                name: name,
                city: city,
                latitude: latitude,
                longitude: longitude,
                cuisineType: cuisineType,
                avgRating: avgRating,
                ratingCount: ratingCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestaurantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RestaurantsTable,
      RestaurantRow,
      $$RestaurantsTableFilterComposer,
      $$RestaurantsTableOrderingComposer,
      $$RestaurantsTableAnnotationComposer,
      $$RestaurantsTableCreateCompanionBuilder,
      $$RestaurantsTableUpdateCompanionBuilder,
      (
        RestaurantRow,
        BaseReferences<_$AppDatabase, $RestaurantsTable, RestaurantRow>,
      ),
      RestaurantRow,
      PrefetchHooks Function()
    >;
typedef $$DishesTableCreateCompanionBuilder =
    DishesCompanion Function({
      required String id,
      required String restaurantId,
      required String name,
      Value<String?> category,
      Value<int?> price,
      Value<String> attributeState,
      Value<double?> communityScore,
      Value<int> voteCount,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$DishesTableUpdateCompanionBuilder =
    DishesCompanion Function({
      Value<String> id,
      Value<String> restaurantId,
      Value<String> name,
      Value<String?> category,
      Value<int?> price,
      Value<String> attributeState,
      Value<double?> communityScore,
      Value<int> voteCount,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$DishesTableFilterComposer
    extends Composer<_$AppDatabase, $DishesTable> {
  $$DishesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attributeState => $composableBuilder(
    column: $table.attributeState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get communityScore => $composableBuilder(
    column: $table.communityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voteCount => $composableBuilder(
    column: $table.voteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DishesTableOrderingComposer
    extends Composer<_$AppDatabase, $DishesTable> {
  $$DishesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attributeState => $composableBuilder(
    column: $table.attributeState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get communityScore => $composableBuilder(
    column: $table.communityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voteCount => $composableBuilder(
    column: $table.voteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DishesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DishesTable> {
  $$DishesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get attributeState => $composableBuilder(
    column: $table.attributeState,
    builder: (column) => column,
  );

  GeneratedColumn<double> get communityScore => $composableBuilder(
    column: $table.communityScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get voteCount =>
      $composableBuilder(column: $table.voteCount, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$DishesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DishesTable,
          DishRow,
          $$DishesTableFilterComposer,
          $$DishesTableOrderingComposer,
          $$DishesTableAnnotationComposer,
          $$DishesTableCreateCompanionBuilder,
          $$DishesTableUpdateCompanionBuilder,
          (DishRow, BaseReferences<_$AppDatabase, $DishesTable, DishRow>),
          DishRow,
          PrefetchHooks Function()
        > {
  $$DishesTableTableManager(_$AppDatabase db, $DishesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DishesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DishesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DishesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> restaurantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> attributeState = const Value.absent(),
                Value<double?> communityScore = const Value.absent(),
                Value<int> voteCount = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DishesCompanion(
                id: id,
                restaurantId: restaurantId,
                name: name,
                category: category,
                price: price,
                attributeState: attributeState,
                communityScore: communityScore,
                voteCount: voteCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String restaurantId,
                required String name,
                Value<String?> category = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> attributeState = const Value.absent(),
                Value<double?> communityScore = const Value.absent(),
                Value<int> voteCount = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DishesCompanion.insert(
                id: id,
                restaurantId: restaurantId,
                name: name,
                category: category,
                price: price,
                attributeState: attributeState,
                communityScore: communityScore,
                voteCount: voteCount,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DishesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DishesTable,
      DishRow,
      $$DishesTableFilterComposer,
      $$DishesTableOrderingComposer,
      $$DishesTableAnnotationComposer,
      $$DishesTableCreateCompanionBuilder,
      $$DishesTableUpdateCompanionBuilder,
      (DishRow, BaseReferences<_$AppDatabase, $DishesTable, DishRow>),
      DishRow,
      PrefetchHooks Function()
    >;
typedef $$ReactionsTableCreateCompanionBuilder =
    ReactionsCompanion Function({
      required String id,
      required String userId,
      required String dishId,
      required String reaction,
      required DateTime createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$ReactionsTableUpdateCompanionBuilder =
    ReactionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> dishId,
      Value<String> reaction,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$ReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dishId =>
      $composableBuilder(column: $table.dishId, builder: (column) => column);

  GeneratedColumn<String> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReactionsTable,
          ReactionRow,
          $$ReactionsTableFilterComposer,
          $$ReactionsTableOrderingComposer,
          $$ReactionsTableAnnotationComposer,
          $$ReactionsTableCreateCompanionBuilder,
          $$ReactionsTableUpdateCompanionBuilder,
          (
            ReactionRow,
            BaseReferences<_$AppDatabase, $ReactionsTable, ReactionRow>,
          ),
          ReactionRow,
          PrefetchHooks Function()
        > {
  $$ReactionsTableTableManager(_$AppDatabase db, $ReactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> dishId = const Value.absent(),
                Value<String> reaction = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion(
                id: id,
                userId: userId,
                dishId: dishId,
                reaction: reaction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String dishId,
                required String reaction,
                required DateTime createdAt,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion.insert(
                id: id,
                userId: userId,
                dishId: dishId,
                reaction: reaction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReactionsTable,
      ReactionRow,
      $$ReactionsTableFilterComposer,
      $$ReactionsTableOrderingComposer,
      $$ReactionsTableAnnotationComposer,
      $$ReactionsTableCreateCompanionBuilder,
      $$ReactionsTableUpdateCompanionBuilder,
      (
        ReactionRow,
        BaseReferences<_$AppDatabase, $ReactionsTable, ReactionRow>,
      ),
      ReactionRow,
      PrefetchHooks Function()
    >;
typedef $$RatingsTableCreateCompanionBuilder =
    RatingsCompanion Function({
      required String id,
      required String userId,
      required String restaurantId,
      required int stars,
      required DateTime createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$RatingsTableUpdateCompanionBuilder =
    RatingsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> restaurantId,
      Value<int> stars,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$RatingsTableFilterComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RatingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RatingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get restaurantId => $composableBuilder(
    column: $table.restaurantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stars =>
      $composableBuilder(column: $table.stars, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RatingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatingsTable,
          RatingRow,
          $$RatingsTableFilterComposer,
          $$RatingsTableOrderingComposer,
          $$RatingsTableAnnotationComposer,
          $$RatingsTableCreateCompanionBuilder,
          $$RatingsTableUpdateCompanionBuilder,
          (RatingRow, BaseReferences<_$AppDatabase, $RatingsTable, RatingRow>),
          RatingRow,
          PrefetchHooks Function()
        > {
  $$RatingsTableTableManager(_$AppDatabase db, $RatingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> restaurantId = const Value.absent(),
                Value<int> stars = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatingsCompanion(
                id: id,
                userId: userId,
                restaurantId: restaurantId,
                stars: stars,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String restaurantId,
                required int stars,
                required DateTime createdAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatingsCompanion.insert(
                id: id,
                userId: userId,
                restaurantId: restaurantId,
                stars: stars,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RatingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatingsTable,
      RatingRow,
      $$RatingsTableFilterComposer,
      $$RatingsTableOrderingComposer,
      $$RatingsTableAnnotationComposer,
      $$RatingsTableCreateCompanionBuilder,
      $$RatingsTableUpdateCompanionBuilder,
      (RatingRow, BaseReferences<_$AppDatabase, $RatingsTable, RatingRow>),
      RatingRow,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String userId,
      required String dishId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> userId,
      Value<String> dishId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dishId =>
      $composableBuilder(column: $table.dishId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> dishId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                userId: userId,
                dishId: dishId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String dishId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                userId: userId,
                dishId: dishId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RestaurantsTableTableManager get restaurants =>
      $$RestaurantsTableTableManager(_db, _db.restaurants);
  $$DishesTableTableManager get dishes =>
      $$DishesTableTableManager(_db, _db.dishes);
  $$ReactionsTableTableManager get reactions =>
      $$ReactionsTableTableManager(_db, _db.reactions);
  $$RatingsTableTableManager get ratings =>
      $$RatingsTableTableManager(_db, _db.ratings);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'4db1c5efe1a73afafa926c6e91d12e49a68b1abc';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = AutoDisposeProvider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = AutoDisposeProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
