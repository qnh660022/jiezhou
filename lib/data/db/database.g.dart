// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("📁"),
  );
  static const VerificationMeta _budgetEnabledMeta = const VerificationMeta(
    'budgetEnabled',
  );
  @override
  late final GeneratedColumn<bool> budgetEnabled = GeneratedColumn<bool>(
    'budget_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("budget_enabled" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _budgetCentsMeta = const VerificationMeta(
    'budgetCents',
  );
  @override
  late final GeneratedColumn<int> budgetCents = GeneratedColumn<int>(
    'budget_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _archivedAtMsMeta = const VerificationMeta(
    'archivedAtMs',
  );
  @override
  late final GeneratedColumn<int> archivedAtMs = GeneratedColumn<int>(
    'archived_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("travel"),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    budgetEnabled,
    budgetCents,
    archived,
    archivedAtMs,
    kind,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('budget_enabled')) {
      context.handle(
        _budgetEnabledMeta,
        budgetEnabled.isAcceptableOrUnknown(
          data['budget_enabled']!,
          _budgetEnabledMeta,
        ),
      );
    }
    if (data.containsKey('budget_cents')) {
      context.handle(
        _budgetCentsMeta,
        budgetCents.isAcceptableOrUnknown(
          data['budget_cents']!,
          _budgetCentsMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('archived_at_ms')) {
      context.handle(
        _archivedAtMsMeta,
        archivedAtMs.isAcceptableOrUnknown(
          data['archived_at_ms']!,
          _archivedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      budgetEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}budget_enabled'],
      )!,
      budgetCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_cents'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      archivedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at_ms'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String name;
  final String icon;
  final bool budgetEnabled;
  final int? budgetCents;
  final bool archived;
  final int? archivedAtMs;
  final String kind;
  final int createdAt;
  final int updatedAt;
  const Group({
    required this.id,
    required this.name,
    required this.icon,
    required this.budgetEnabled,
    this.budgetCents,
    required this.archived,
    this.archivedAtMs,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['budget_enabled'] = Variable<bool>(budgetEnabled);
    if (!nullToAbsent || budgetCents != null) {
      map['budget_cents'] = Variable<int>(budgetCents);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || archivedAtMs != null) {
      map['archived_at_ms'] = Variable<int>(archivedAtMs);
    }
    map['kind'] = Variable<String>(kind);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      budgetEnabled: Value(budgetEnabled),
      budgetCents: budgetCents == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetCents),
      archived: Value(archived),
      archivedAtMs: archivedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtMs),
      kind: Value(kind),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      budgetEnabled: serializer.fromJson<bool>(json['budgetEnabled']),
      budgetCents: serializer.fromJson<int?>(json['budgetCents']),
      archived: serializer.fromJson<bool>(json['archived']),
      archivedAtMs: serializer.fromJson<int?>(json['archivedAtMs']),
      kind: serializer.fromJson<String>(json['kind']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'budgetEnabled': serializer.toJson<bool>(budgetEnabled),
      'budgetCents': serializer.toJson<int?>(budgetCents),
      'archived': serializer.toJson<bool>(archived),
      'archivedAtMs': serializer.toJson<int?>(archivedAtMs),
      'kind': serializer.toJson<String>(kind),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? icon,
    bool? budgetEnabled,
    Value<int?> budgetCents = const Value.absent(),
    bool? archived,
    Value<int?> archivedAtMs = const Value.absent(),
    String? kind,
    int? createdAt,
    int? updatedAt,
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    budgetEnabled: budgetEnabled ?? this.budgetEnabled,
    budgetCents: budgetCents.present ? budgetCents.value : this.budgetCents,
    archived: archived ?? this.archived,
    archivedAtMs: archivedAtMs.present ? archivedAtMs.value : this.archivedAtMs,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      budgetEnabled: data.budgetEnabled.present
          ? data.budgetEnabled.value
          : this.budgetEnabled,
      budgetCents: data.budgetCents.present
          ? data.budgetCents.value
          : this.budgetCents,
      archived: data.archived.present ? data.archived.value : this.archived,
      archivedAtMs: data.archivedAtMs.present
          ? data.archivedAtMs.value
          : this.archivedAtMs,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('budgetEnabled: $budgetEnabled, ')
          ..write('budgetCents: $budgetCents, ')
          ..write('archived: $archived, ')
          ..write('archivedAtMs: $archivedAtMs, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    budgetEnabled,
    budgetCents,
    archived,
    archivedAtMs,
    kind,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.budgetEnabled == this.budgetEnabled &&
          other.budgetCents == this.budgetCents &&
          other.archived == this.archived &&
          other.archivedAtMs == this.archivedAtMs &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<bool> budgetEnabled;
  final Value<int?> budgetCents;
  final Value<bool> archived;
  final Value<int?> archivedAtMs;
  final Value<String> kind;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.budgetEnabled = const Value.absent(),
    this.budgetCents = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAtMs = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.budgetEnabled = const Value.absent(),
    this.budgetCents = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAtMs = const Value.absent(),
    this.kind = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<bool>? budgetEnabled,
    Expression<int>? budgetCents,
    Expression<bool>? archived,
    Expression<int>? archivedAtMs,
    Expression<String>? kind,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (budgetEnabled != null) 'budget_enabled': budgetEnabled,
      if (budgetCents != null) 'budget_cents': budgetCents,
      if (archived != null) 'archived': archived,
      if (archivedAtMs != null) 'archived_at_ms': archivedAtMs,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<bool>? budgetEnabled,
    Value<int?>? budgetCents,
    Value<bool>? archived,
    Value<int?>? archivedAtMs,
    Value<String>? kind,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      budgetEnabled: budgetEnabled ?? this.budgetEnabled,
      budgetCents: budgetCents ?? this.budgetCents,
      archived: archived ?? this.archived,
      archivedAtMs: archivedAtMs ?? this.archivedAtMs,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (budgetEnabled.present) {
      map['budget_enabled'] = Variable<bool>(budgetEnabled.value);
    }
    if (budgetCents.present) {
      map['budget_cents'] = Variable<int>(budgetCents.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (archivedAtMs.present) {
      map['archived_at_ms'] = Variable<int>(archivedAtMs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('budgetEnabled: $budgetEnabled, ')
          ..write('budgetCents: $budgetCents, ')
          ..write('archived: $archived, ')
          ..write('archivedAtMs: $archivedAtMs, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembersTable extends Members with TableInfo<$MembersTable, Member> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
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
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    colorIndex,
    archived,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'members';
  @override
  VerificationContext validateIntegrity(
    Insertable<Member> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Member map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Member(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MembersTable createAlias(String alias) {
    return $MembersTable(attachedDatabase, alias);
  }
}

class Member extends DataClass implements Insertable<Member> {
  final String id;
  final String groupId;
  final String name;
  final int colorIndex;
  final bool archived;
  final int createdAt;
  const Member({
    required this.id,
    required this.groupId,
    required this.name,
    required this.colorIndex,
    required this.archived,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MembersCompanion toCompanion(bool nullToAbsent) {
    return MembersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      colorIndex: Value(colorIndex),
      archived: Value(archived),
      createdAt: Value(createdAt),
    );
  }

  factory Member.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Member(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Member copyWith({
    String? id,
    String? groupId,
    String? name,
    int? colorIndex,
    bool? archived,
    int? createdAt,
  }) => Member(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
  );
  Member copyWithCompanion(MembersCompanion data) {
    return Member(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Member(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, name, colorIndex, archived, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Member &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt);
}

class MembersCompanion extends UpdateCompanion<Member> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembersCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    this.colorIndex = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Member> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembersCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("✈️"),
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("ocean"),
  );
  static const VerificationMeta _startEpochDayMeta = const VerificationMeta(
    'startEpochDay',
  );
  @override
  late final GeneratedColumn<int> startEpochDay = GeneratedColumn<int>(
    'start_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _endEpochDayMeta = const VerificationMeta(
    'endEpochDay',
  );
  @override
  late final GeneratedColumn<int> endEpochDay = GeneratedColumn<int>(
    'end_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _paceMeta = const VerificationMeta('pace');
  @override
  late final GeneratedColumn<String> pace = GeneratedColumn<String>(
    'pace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("standard"),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    destination,
    emoji,
    cover,
    startEpochDay,
    endEpochDay,
    note,
    groupId,
    archived,
    pace,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
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
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('start_epoch_day')) {
      context.handle(
        _startEpochDayMeta,
        startEpochDay.isAcceptableOrUnknown(
          data['start_epoch_day']!,
          _startEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('end_epoch_day')) {
      context.handle(
        _endEpochDayMeta,
        endEpochDay.isAcceptableOrUnknown(
          data['end_epoch_day']!,
          _endEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('pace')) {
      context.handle(
        _paceMeta,
        pace.isAcceptableOrUnknown(data['pace']!, _paceMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      )!,
      startEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_epoch_day'],
      )!,
      endEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_epoch_day'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      pace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final String id;
  final String name;
  final String destination;
  final String emoji;
  final String cover;
  final int startEpochDay;
  final int endEpochDay;
  final String note;
  final String? groupId;
  final bool archived;
  final String pace;
  final int createdAt;
  final int updatedAt;
  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.emoji,
    required this.cover,
    required this.startEpochDay,
    required this.endEpochDay,
    required this.note,
    this.groupId,
    required this.archived,
    required this.pace,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['destination'] = Variable<String>(destination);
    map['emoji'] = Variable<String>(emoji);
    map['cover'] = Variable<String>(cover);
    map['start_epoch_day'] = Variable<int>(startEpochDay);
    map['end_epoch_day'] = Variable<int>(endEpochDay);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['archived'] = Variable<bool>(archived);
    map['pace'] = Variable<String>(pace);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      name: Value(name),
      destination: Value(destination),
      emoji: Value(emoji),
      cover: Value(cover),
      startEpochDay: Value(startEpochDay),
      endEpochDay: Value(endEpochDay),
      note: Value(note),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      archived: Value(archived),
      pace: Value(pace),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      destination: serializer.fromJson<String>(json['destination']),
      emoji: serializer.fromJson<String>(json['emoji']),
      cover: serializer.fromJson<String>(json['cover']),
      startEpochDay: serializer.fromJson<int>(json['startEpochDay']),
      endEpochDay: serializer.fromJson<int>(json['endEpochDay']),
      note: serializer.fromJson<String>(json['note']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      archived: serializer.fromJson<bool>(json['archived']),
      pace: serializer.fromJson<String>(json['pace']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'destination': serializer.toJson<String>(destination),
      'emoji': serializer.toJson<String>(emoji),
      'cover': serializer.toJson<String>(cover),
      'startEpochDay': serializer.toJson<int>(startEpochDay),
      'endEpochDay': serializer.toJson<int>(endEpochDay),
      'note': serializer.toJson<String>(note),
      'groupId': serializer.toJson<String?>(groupId),
      'archived': serializer.toJson<bool>(archived),
      'pace': serializer.toJson<String>(pace),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Trip copyWith({
    String? id,
    String? name,
    String? destination,
    String? emoji,
    String? cover,
    int? startEpochDay,
    int? endEpochDay,
    String? note,
    Value<String?> groupId = const Value.absent(),
    bool? archived,
    String? pace,
    int? createdAt,
    int? updatedAt,
  }) => Trip(
    id: id ?? this.id,
    name: name ?? this.name,
    destination: destination ?? this.destination,
    emoji: emoji ?? this.emoji,
    cover: cover ?? this.cover,
    startEpochDay: startEpochDay ?? this.startEpochDay,
    endEpochDay: endEpochDay ?? this.endEpochDay,
    note: note ?? this.note,
    groupId: groupId.present ? groupId.value : this.groupId,
    archived: archived ?? this.archived,
    pace: pace ?? this.pace,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      cover: data.cover.present ? data.cover.value : this.cover,
      startEpochDay: data.startEpochDay.present
          ? data.startEpochDay.value
          : this.startEpochDay,
      endEpochDay: data.endEpochDay.present
          ? data.endEpochDay.value
          : this.endEpochDay,
      note: data.note.present ? data.note.value : this.note,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      archived: data.archived.present ? data.archived.value : this.archived,
      pace: data.pace.present ? data.pace.value : this.pace,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('destination: $destination, ')
          ..write('emoji: $emoji, ')
          ..write('cover: $cover, ')
          ..write('startEpochDay: $startEpochDay, ')
          ..write('endEpochDay: $endEpochDay, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('archived: $archived, ')
          ..write('pace: $pace, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    destination,
    emoji,
    cover,
    startEpochDay,
    endEpochDay,
    note,
    groupId,
    archived,
    pace,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.name == this.name &&
          other.destination == this.destination &&
          other.emoji == this.emoji &&
          other.cover == this.cover &&
          other.startEpochDay == this.startEpochDay &&
          other.endEpochDay == this.endEpochDay &&
          other.note == this.note &&
          other.groupId == this.groupId &&
          other.archived == this.archived &&
          other.pace == this.pace &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> destination;
  final Value<String> emoji;
  final Value<String> cover;
  final Value<int> startEpochDay;
  final Value<int> endEpochDay;
  final Value<String> note;
  final Value<String?> groupId;
  final Value<bool> archived;
  final Value<String> pace;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.destination = const Value.absent(),
    this.emoji = const Value.absent(),
    this.cover = const Value.absent(),
    this.startEpochDay = const Value.absent(),
    this.endEpochDay = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.archived = const Value.absent(),
    this.pace = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String name,
    this.destination = const Value.absent(),
    this.emoji = const Value.absent(),
    this.cover = const Value.absent(),
    this.startEpochDay = const Value.absent(),
    this.endEpochDay = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.archived = const Value.absent(),
    this.pace = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Trip> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? destination,
    Expression<String>? emoji,
    Expression<String>? cover,
    Expression<int>? startEpochDay,
    Expression<int>? endEpochDay,
    Expression<String>? note,
    Expression<String>? groupId,
    Expression<bool>? archived,
    Expression<String>? pace,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (destination != null) 'destination': destination,
      if (emoji != null) 'emoji': emoji,
      if (cover != null) 'cover': cover,
      if (startEpochDay != null) 'start_epoch_day': startEpochDay,
      if (endEpochDay != null) 'end_epoch_day': endEpochDay,
      if (note != null) 'note': note,
      if (groupId != null) 'group_id': groupId,
      if (archived != null) 'archived': archived,
      if (pace != null) 'pace': pace,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? destination,
    Value<String>? emoji,
    Value<String>? cover,
    Value<int>? startEpochDay,
    Value<int>? endEpochDay,
    Value<String>? note,
    Value<String?>? groupId,
    Value<bool>? archived,
    Value<String>? pace,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      emoji: emoji ?? this.emoji,
      cover: cover ?? this.cover,
      startEpochDay: startEpochDay ?? this.startEpochDay,
      endEpochDay: endEpochDay ?? this.endEpochDay,
      note: note ?? this.note,
      groupId: groupId ?? this.groupId,
      archived: archived ?? this.archived,
      pace: pace ?? this.pace,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (startEpochDay.present) {
      map['start_epoch_day'] = Variable<int>(startEpochDay.value);
    }
    if (endEpochDay.present) {
      map['end_epoch_day'] = Variable<int>(endEpochDay.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (pace.present) {
      map['pace'] = Variable<String>(pace.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('destination: $destination, ')
          ..write('emoji: $emoji, ')
          ..write('cover: $cover, ')
          ..write('startEpochDay: $startEpochDay, ')
          ..write('endEpochDay: $endEpochDay, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('archived: $archived, ')
          ..write('pace: $pace, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripItemsTable extends TripItems
    with TableInfo<$TripItemsTable, TripItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id)',
    ),
  );
  static const VerificationMeta _dateEpochDayMeta = const VerificationMeta(
    'dateEpochDay',
  );
  @override
  late final GeneratedColumn<int> dateEpochDay = GeneratedColumn<int>(
    'date_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("attraction"),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUriMeta = const VerificationMeta(
    'photoUri',
  );
  @override
  late final GeneratedColumn<String> photoUri = GeneratedColumn<String>(
    'photo_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMinMeta = const VerificationMeta(
    'startTimeMin',
  );
  @override
  late final GeneratedColumn<int> startTimeMin = GeneratedColumn<int>(
    'start_time_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costCentsMeta = const VerificationMeta(
    'costCents',
  );
  @override
  late final GeneratedColumn<int> costCents = GeneratedColumn<int>(
    'cost_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costCurrencyMeta = const VerificationMeta(
    'costCurrency',
  );
  @override
  late final GeneratedColumn<String> costCurrency = GeneratedColumn<String>(
    'cost_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("CNY"),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromNameMeta = const VerificationMeta(
    'fromName',
  );
  @override
  late final GeneratedColumn<String> fromName = GeneratedColumn<String>(
    'from_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromAddressMeta = const VerificationMeta(
    'fromAddress',
  );
  @override
  late final GeneratedColumn<String> fromAddress = GeneratedColumn<String>(
    'from_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromLatMeta = const VerificationMeta(
    'fromLat',
  );
  @override
  late final GeneratedColumn<double> fromLat = GeneratedColumn<double>(
    'from_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromLngMeta = const VerificationMeta(
    'fromLng',
  );
  @override
  late final GeneratedColumn<double> fromLng = GeneratedColumn<double>(
    'from_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toNameMeta = const VerificationMeta('toName');
  @override
  late final GeneratedColumn<String> toName = GeneratedColumn<String>(
    'to_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _toAddressMeta = const VerificationMeta(
    'toAddress',
  );
  @override
  late final GeneratedColumn<String> toAddress = GeneratedColumn<String>(
    'to_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _toLatMeta = const VerificationMeta('toLat');
  @override
  late final GeneratedColumn<double> toLat = GeneratedColumn<double>(
    'to_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLngMeta = const VerificationMeta('toLng');
  @override
  late final GeneratedColumn<double> toLng = GeneratedColumn<double>(
    'to_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flightNoMeta = const VerificationMeta(
    'flightNo',
  );
  @override
  late final GeneratedColumn<String> flightNo = GeneratedColumn<String>(
    'flight_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _guideRefMeta = const VerificationMeta(
    'guideRef',
  );
  @override
  late final GeneratedColumn<String> guideRef = GeneratedColumn<String>(
    'guide_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backupOfMeta = const VerificationMeta(
    'backupOf',
  );
  @override
  late final GeneratedColumn<String> backupOf = GeneratedColumn<String>(
    'backup_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    dateEpochDay,
    type,
    name,
    address,
    lat,
    lng,
    photoUri,
    startTimeMin,
    durationMin,
    costCents,
    costCurrency,
    note,
    fromName,
    fromAddress,
    fromLat,
    fromLng,
    toName,
    toAddress,
    toLat,
    toLng,
    flightNo,
    sortOrder,
    guideRef,
    backupOf,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('date_epoch_day')) {
      context.handle(
        _dateEpochDayMeta,
        dateEpochDay.isAcceptableOrUnknown(
          data['date_epoch_day']!,
          _dateEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('photo_uri')) {
      context.handle(
        _photoUriMeta,
        photoUri.isAcceptableOrUnknown(data['photo_uri']!, _photoUriMeta),
      );
    }
    if (data.containsKey('start_time_min')) {
      context.handle(
        _startTimeMinMeta,
        startTimeMin.isAcceptableOrUnknown(
          data['start_time_min']!,
          _startTimeMinMeta,
        ),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('cost_cents')) {
      context.handle(
        _costCentsMeta,
        costCents.isAcceptableOrUnknown(data['cost_cents']!, _costCentsMeta),
      );
    }
    if (data.containsKey('cost_currency')) {
      context.handle(
        _costCurrencyMeta,
        costCurrency.isAcceptableOrUnknown(
          data['cost_currency']!,
          _costCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('from_name')) {
      context.handle(
        _fromNameMeta,
        fromName.isAcceptableOrUnknown(data['from_name']!, _fromNameMeta),
      );
    }
    if (data.containsKey('from_address')) {
      context.handle(
        _fromAddressMeta,
        fromAddress.isAcceptableOrUnknown(
          data['from_address']!,
          _fromAddressMeta,
        ),
      );
    }
    if (data.containsKey('from_lat')) {
      context.handle(
        _fromLatMeta,
        fromLat.isAcceptableOrUnknown(data['from_lat']!, _fromLatMeta),
      );
    }
    if (data.containsKey('from_lng')) {
      context.handle(
        _fromLngMeta,
        fromLng.isAcceptableOrUnknown(data['from_lng']!, _fromLngMeta),
      );
    }
    if (data.containsKey('to_name')) {
      context.handle(
        _toNameMeta,
        toName.isAcceptableOrUnknown(data['to_name']!, _toNameMeta),
      );
    }
    if (data.containsKey('to_address')) {
      context.handle(
        _toAddressMeta,
        toAddress.isAcceptableOrUnknown(data['to_address']!, _toAddressMeta),
      );
    }
    if (data.containsKey('to_lat')) {
      context.handle(
        _toLatMeta,
        toLat.isAcceptableOrUnknown(data['to_lat']!, _toLatMeta),
      );
    }
    if (data.containsKey('to_lng')) {
      context.handle(
        _toLngMeta,
        toLng.isAcceptableOrUnknown(data['to_lng']!, _toLngMeta),
      );
    }
    if (data.containsKey('flight_no')) {
      context.handle(
        _flightNoMeta,
        flightNo.isAcceptableOrUnknown(data['flight_no']!, _flightNoMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('guide_ref')) {
      context.handle(
        _guideRefMeta,
        guideRef.isAcceptableOrUnknown(data['guide_ref']!, _guideRefMeta),
      );
    }
    if (data.containsKey('backup_of')) {
      context.handle(
        _backupOfMeta,
        backupOf.isAcceptableOrUnknown(data['backup_of']!, _backupOfMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      dateEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_epoch_day'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      photoUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_uri'],
      ),
      startTimeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_min'],
      ),
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      costCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_cents'],
      ),
      costCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_currency'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      fromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_name'],
      )!,
      fromAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_address'],
      )!,
      fromLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lat'],
      ),
      fromLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lng'],
      ),
      toName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_name'],
      )!,
      toAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_address'],
      )!,
      toLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lat'],
      ),
      toLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lng'],
      ),
      flightNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flight_no'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      guideRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_ref'],
      ),
      backupOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_of'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TripItemsTable createAlias(String alias) {
    return $TripItemsTable(attachedDatabase, alias);
  }
}

class TripItem extends DataClass implements Insertable<TripItem> {
  final String id;
  final String tripId;
  final int dateEpochDay;
  final String type;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? photoUri;
  final int? startTimeMin;
  final int? durationMin;
  final int? costCents;
  final String costCurrency;
  final String note;
  final String fromName;
  final String fromAddress;
  final double? fromLat;
  final double? fromLng;
  final String toName;
  final String toAddress;
  final double? toLat;
  final double? toLng;
  final String? flightNo;
  final int sortOrder;
  final String? guideRef;
  final String? backupOf;
  final int createdAt;
  final int updatedAt;
  const TripItem({
    required this.id,
    required this.tripId,
    required this.dateEpochDay,
    required this.type,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.photoUri,
    this.startTimeMin,
    this.durationMin,
    this.costCents,
    required this.costCurrency,
    required this.note,
    required this.fromName,
    required this.fromAddress,
    this.fromLat,
    this.fromLng,
    required this.toName,
    required this.toAddress,
    this.toLat,
    this.toLng,
    this.flightNo,
    required this.sortOrder,
    this.guideRef,
    this.backupOf,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['date_epoch_day'] = Variable<int>(dateEpochDay);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || photoUri != null) {
      map['photo_uri'] = Variable<String>(photoUri);
    }
    if (!nullToAbsent || startTimeMin != null) {
      map['start_time_min'] = Variable<int>(startTimeMin);
    }
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || costCents != null) {
      map['cost_cents'] = Variable<int>(costCents);
    }
    map['cost_currency'] = Variable<String>(costCurrency);
    map['note'] = Variable<String>(note);
    map['from_name'] = Variable<String>(fromName);
    map['from_address'] = Variable<String>(fromAddress);
    if (!nullToAbsent || fromLat != null) {
      map['from_lat'] = Variable<double>(fromLat);
    }
    if (!nullToAbsent || fromLng != null) {
      map['from_lng'] = Variable<double>(fromLng);
    }
    map['to_name'] = Variable<String>(toName);
    map['to_address'] = Variable<String>(toAddress);
    if (!nullToAbsent || toLat != null) {
      map['to_lat'] = Variable<double>(toLat);
    }
    if (!nullToAbsent || toLng != null) {
      map['to_lng'] = Variable<double>(toLng);
    }
    if (!nullToAbsent || flightNo != null) {
      map['flight_no'] = Variable<String>(flightNo);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || guideRef != null) {
      map['guide_ref'] = Variable<String>(guideRef);
    }
    if (!nullToAbsent || backupOf != null) {
      map['backup_of'] = Variable<String>(backupOf);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TripItemsCompanion toCompanion(bool nullToAbsent) {
    return TripItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      dateEpochDay: Value(dateEpochDay),
      type: Value(type),
      name: Value(name),
      address: Value(address),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      photoUri: photoUri == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUri),
      startTimeMin: startTimeMin == null && nullToAbsent
          ? const Value.absent()
          : Value(startTimeMin),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      costCents: costCents == null && nullToAbsent
          ? const Value.absent()
          : Value(costCents),
      costCurrency: Value(costCurrency),
      note: Value(note),
      fromName: Value(fromName),
      fromAddress: Value(fromAddress),
      fromLat: fromLat == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLat),
      fromLng: fromLng == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLng),
      toName: Value(toName),
      toAddress: Value(toAddress),
      toLat: toLat == null && nullToAbsent
          ? const Value.absent()
          : Value(toLat),
      toLng: toLng == null && nullToAbsent
          ? const Value.absent()
          : Value(toLng),
      flightNo: flightNo == null && nullToAbsent
          ? const Value.absent()
          : Value(flightNo),
      sortOrder: Value(sortOrder),
      guideRef: guideRef == null && nullToAbsent
          ? const Value.absent()
          : Value(guideRef),
      backupOf: backupOf == null && nullToAbsent
          ? const Value.absent()
          : Value(backupOf),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TripItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripItem(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      dateEpochDay: serializer.fromJson<int>(json['dateEpochDay']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      photoUri: serializer.fromJson<String?>(json['photoUri']),
      startTimeMin: serializer.fromJson<int?>(json['startTimeMin']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      costCents: serializer.fromJson<int?>(json['costCents']),
      costCurrency: serializer.fromJson<String>(json['costCurrency']),
      note: serializer.fromJson<String>(json['note']),
      fromName: serializer.fromJson<String>(json['fromName']),
      fromAddress: serializer.fromJson<String>(json['fromAddress']),
      fromLat: serializer.fromJson<double?>(json['fromLat']),
      fromLng: serializer.fromJson<double?>(json['fromLng']),
      toName: serializer.fromJson<String>(json['toName']),
      toAddress: serializer.fromJson<String>(json['toAddress']),
      toLat: serializer.fromJson<double?>(json['toLat']),
      toLng: serializer.fromJson<double?>(json['toLng']),
      flightNo: serializer.fromJson<String?>(json['flightNo']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      guideRef: serializer.fromJson<String?>(json['guideRef']),
      backupOf: serializer.fromJson<String?>(json['backupOf']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'dateEpochDay': serializer.toJson<int>(dateEpochDay),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'photoUri': serializer.toJson<String?>(photoUri),
      'startTimeMin': serializer.toJson<int?>(startTimeMin),
      'durationMin': serializer.toJson<int?>(durationMin),
      'costCents': serializer.toJson<int?>(costCents),
      'costCurrency': serializer.toJson<String>(costCurrency),
      'note': serializer.toJson<String>(note),
      'fromName': serializer.toJson<String>(fromName),
      'fromAddress': serializer.toJson<String>(fromAddress),
      'fromLat': serializer.toJson<double?>(fromLat),
      'fromLng': serializer.toJson<double?>(fromLng),
      'toName': serializer.toJson<String>(toName),
      'toAddress': serializer.toJson<String>(toAddress),
      'toLat': serializer.toJson<double?>(toLat),
      'toLng': serializer.toJson<double?>(toLng),
      'flightNo': serializer.toJson<String?>(flightNo),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'guideRef': serializer.toJson<String?>(guideRef),
      'backupOf': serializer.toJson<String?>(backupOf),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TripItem copyWith({
    String? id,
    String? tripId,
    int? dateEpochDay,
    String? type,
    String? name,
    String? address,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> photoUri = const Value.absent(),
    Value<int?> startTimeMin = const Value.absent(),
    Value<int?> durationMin = const Value.absent(),
    Value<int?> costCents = const Value.absent(),
    String? costCurrency,
    String? note,
    String? fromName,
    String? fromAddress,
    Value<double?> fromLat = const Value.absent(),
    Value<double?> fromLng = const Value.absent(),
    String? toName,
    String? toAddress,
    Value<double?> toLat = const Value.absent(),
    Value<double?> toLng = const Value.absent(),
    Value<String?> flightNo = const Value.absent(),
    int? sortOrder,
    Value<String?> guideRef = const Value.absent(),
    Value<String?> backupOf = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => TripItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    dateEpochDay: dateEpochDay ?? this.dateEpochDay,
    type: type ?? this.type,
    name: name ?? this.name,
    address: address ?? this.address,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    photoUri: photoUri.present ? photoUri.value : this.photoUri,
    startTimeMin: startTimeMin.present ? startTimeMin.value : this.startTimeMin,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    costCents: costCents.present ? costCents.value : this.costCents,
    costCurrency: costCurrency ?? this.costCurrency,
    note: note ?? this.note,
    fromName: fromName ?? this.fromName,
    fromAddress: fromAddress ?? this.fromAddress,
    fromLat: fromLat.present ? fromLat.value : this.fromLat,
    fromLng: fromLng.present ? fromLng.value : this.fromLng,
    toName: toName ?? this.toName,
    toAddress: toAddress ?? this.toAddress,
    toLat: toLat.present ? toLat.value : this.toLat,
    toLng: toLng.present ? toLng.value : this.toLng,
    flightNo: flightNo.present ? flightNo.value : this.flightNo,
    sortOrder: sortOrder ?? this.sortOrder,
    guideRef: guideRef.present ? guideRef.value : this.guideRef,
    backupOf: backupOf.present ? backupOf.value : this.backupOf,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TripItem copyWithCompanion(TripItemsCompanion data) {
    return TripItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      dateEpochDay: data.dateEpochDay.present
          ? data.dateEpochDay.value
          : this.dateEpochDay,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      photoUri: data.photoUri.present ? data.photoUri.value : this.photoUri,
      startTimeMin: data.startTimeMin.present
          ? data.startTimeMin.value
          : this.startTimeMin,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      costCents: data.costCents.present ? data.costCents.value : this.costCents,
      costCurrency: data.costCurrency.present
          ? data.costCurrency.value
          : this.costCurrency,
      note: data.note.present ? data.note.value : this.note,
      fromName: data.fromName.present ? data.fromName.value : this.fromName,
      fromAddress: data.fromAddress.present
          ? data.fromAddress.value
          : this.fromAddress,
      fromLat: data.fromLat.present ? data.fromLat.value : this.fromLat,
      fromLng: data.fromLng.present ? data.fromLng.value : this.fromLng,
      toName: data.toName.present ? data.toName.value : this.toName,
      toAddress: data.toAddress.present ? data.toAddress.value : this.toAddress,
      toLat: data.toLat.present ? data.toLat.value : this.toLat,
      toLng: data.toLng.present ? data.toLng.value : this.toLng,
      flightNo: data.flightNo.present ? data.flightNo.value : this.flightNo,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      guideRef: data.guideRef.present ? data.guideRef.value : this.guideRef,
      backupOf: data.backupOf.present ? data.backupOf.value : this.backupOf,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('photoUri: $photoUri, ')
          ..write('startTimeMin: $startTimeMin, ')
          ..write('durationMin: $durationMin, ')
          ..write('costCents: $costCents, ')
          ..write('costCurrency: $costCurrency, ')
          ..write('note: $note, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLng: $fromLng, ')
          ..write('toName: $toName, ')
          ..write('toAddress: $toAddress, ')
          ..write('toLat: $toLat, ')
          ..write('toLng: $toLng, ')
          ..write('flightNo: $flightNo, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('guideRef: $guideRef, ')
          ..write('backupOf: $backupOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tripId,
    dateEpochDay,
    type,
    name,
    address,
    lat,
    lng,
    photoUri,
    startTimeMin,
    durationMin,
    costCents,
    costCurrency,
    note,
    fromName,
    fromAddress,
    fromLat,
    fromLng,
    toName,
    toAddress,
    toLat,
    toLng,
    flightNo,
    sortOrder,
    guideRef,
    backupOf,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.dateEpochDay == this.dateEpochDay &&
          other.type == this.type &&
          other.name == this.name &&
          other.address == this.address &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.photoUri == this.photoUri &&
          other.startTimeMin == this.startTimeMin &&
          other.durationMin == this.durationMin &&
          other.costCents == this.costCents &&
          other.costCurrency == this.costCurrency &&
          other.note == this.note &&
          other.fromName == this.fromName &&
          other.fromAddress == this.fromAddress &&
          other.fromLat == this.fromLat &&
          other.fromLng == this.fromLng &&
          other.toName == this.toName &&
          other.toAddress == this.toAddress &&
          other.toLat == this.toLat &&
          other.toLng == this.toLng &&
          other.flightNo == this.flightNo &&
          other.sortOrder == this.sortOrder &&
          other.guideRef == this.guideRef &&
          other.backupOf == this.backupOf &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TripItemsCompanion extends UpdateCompanion<TripItem> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<int> dateEpochDay;
  final Value<String> type;
  final Value<String> name;
  final Value<String> address;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> photoUri;
  final Value<int?> startTimeMin;
  final Value<int?> durationMin;
  final Value<int?> costCents;
  final Value<String> costCurrency;
  final Value<String> note;
  final Value<String> fromName;
  final Value<String> fromAddress;
  final Value<double?> fromLat;
  final Value<double?> fromLng;
  final Value<String> toName;
  final Value<String> toAddress;
  final Value<double?> toLat;
  final Value<double?> toLng;
  final Value<String?> flightNo;
  final Value<int> sortOrder;
  final Value<String?> guideRef;
  final Value<String?> backupOf;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TripItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.dateEpochDay = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.photoUri = const Value.absent(),
    this.startTimeMin = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.costCents = const Value.absent(),
    this.costCurrency = const Value.absent(),
    this.note = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLng = const Value.absent(),
    this.toName = const Value.absent(),
    this.toAddress = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLng = const Value.absent(),
    this.flightNo = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.backupOf = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripItemsCompanion.insert({
    required String id,
    required String tripId,
    this.dateEpochDay = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.photoUri = const Value.absent(),
    this.startTimeMin = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.costCents = const Value.absent(),
    this.costCurrency = const Value.absent(),
    this.note = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLng = const Value.absent(),
    this.toName = const Value.absent(),
    this.toAddress = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLng = const Value.absent(),
    this.flightNo = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.backupOf = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TripItem> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<int>? dateEpochDay,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? address,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? photoUri,
    Expression<int>? startTimeMin,
    Expression<int>? durationMin,
    Expression<int>? costCents,
    Expression<String>? costCurrency,
    Expression<String>? note,
    Expression<String>? fromName,
    Expression<String>? fromAddress,
    Expression<double>? fromLat,
    Expression<double>? fromLng,
    Expression<String>? toName,
    Expression<String>? toAddress,
    Expression<double>? toLat,
    Expression<double>? toLng,
    Expression<String>? flightNo,
    Expression<int>? sortOrder,
    Expression<String>? guideRef,
    Expression<String>? backupOf,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (dateEpochDay != null) 'date_epoch_day': dateEpochDay,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (photoUri != null) 'photo_uri': photoUri,
      if (startTimeMin != null) 'start_time_min': startTimeMin,
      if (durationMin != null) 'duration_min': durationMin,
      if (costCents != null) 'cost_cents': costCents,
      if (costCurrency != null) 'cost_currency': costCurrency,
      if (note != null) 'note': note,
      if (fromName != null) 'from_name': fromName,
      if (fromAddress != null) 'from_address': fromAddress,
      if (fromLat != null) 'from_lat': fromLat,
      if (fromLng != null) 'from_lng': fromLng,
      if (toName != null) 'to_name': toName,
      if (toAddress != null) 'to_address': toAddress,
      if (toLat != null) 'to_lat': toLat,
      if (toLng != null) 'to_lng': toLng,
      if (flightNo != null) 'flight_no': flightNo,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (guideRef != null) 'guide_ref': guideRef,
      if (backupOf != null) 'backup_of': backupOf,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<int>? dateEpochDay,
    Value<String>? type,
    Value<String>? name,
    Value<String>? address,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<String?>? photoUri,
    Value<int?>? startTimeMin,
    Value<int?>? durationMin,
    Value<int?>? costCents,
    Value<String>? costCurrency,
    Value<String>? note,
    Value<String>? fromName,
    Value<String>? fromAddress,
    Value<double?>? fromLat,
    Value<double?>? fromLng,
    Value<String>? toName,
    Value<String>? toAddress,
    Value<double?>? toLat,
    Value<double?>? toLng,
    Value<String?>? flightNo,
    Value<int>? sortOrder,
    Value<String?>? guideRef,
    Value<String?>? backupOf,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TripItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dateEpochDay: dateEpochDay ?? this.dateEpochDay,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photoUri: photoUri ?? this.photoUri,
      startTimeMin: startTimeMin ?? this.startTimeMin,
      durationMin: durationMin ?? this.durationMin,
      costCents: costCents ?? this.costCents,
      costCurrency: costCurrency ?? this.costCurrency,
      note: note ?? this.note,
      fromName: fromName ?? this.fromName,
      fromAddress: fromAddress ?? this.fromAddress,
      fromLat: fromLat ?? this.fromLat,
      fromLng: fromLng ?? this.fromLng,
      toName: toName ?? this.toName,
      toAddress: toAddress ?? this.toAddress,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      flightNo: flightNo ?? this.flightNo,
      sortOrder: sortOrder ?? this.sortOrder,
      guideRef: guideRef ?? this.guideRef,
      backupOf: backupOf ?? this.backupOf,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (dateEpochDay.present) {
      map['date_epoch_day'] = Variable<int>(dateEpochDay.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (photoUri.present) {
      map['photo_uri'] = Variable<String>(photoUri.value);
    }
    if (startTimeMin.present) {
      map['start_time_min'] = Variable<int>(startTimeMin.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (costCents.present) {
      map['cost_cents'] = Variable<int>(costCents.value);
    }
    if (costCurrency.present) {
      map['cost_currency'] = Variable<String>(costCurrency.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (fromName.present) {
      map['from_name'] = Variable<String>(fromName.value);
    }
    if (fromAddress.present) {
      map['from_address'] = Variable<String>(fromAddress.value);
    }
    if (fromLat.present) {
      map['from_lat'] = Variable<double>(fromLat.value);
    }
    if (fromLng.present) {
      map['from_lng'] = Variable<double>(fromLng.value);
    }
    if (toName.present) {
      map['to_name'] = Variable<String>(toName.value);
    }
    if (toAddress.present) {
      map['to_address'] = Variable<String>(toAddress.value);
    }
    if (toLat.present) {
      map['to_lat'] = Variable<double>(toLat.value);
    }
    if (toLng.present) {
      map['to_lng'] = Variable<double>(toLng.value);
    }
    if (flightNo.present) {
      map['flight_no'] = Variable<String>(flightNo.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (guideRef.present) {
      map['guide_ref'] = Variable<String>(guideRef.value);
    }
    if (backupOf.present) {
      map['backup_of'] = Variable<String>(backupOf.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('photoUri: $photoUri, ')
          ..write('startTimeMin: $startTimeMin, ')
          ..write('durationMin: $durationMin, ')
          ..write('costCents: $costCents, ')
          ..write('costCurrency: $costCurrency, ')
          ..write('note: $note, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLng: $fromLng, ')
          ..write('toName: $toName, ')
          ..write('toAddress: $toAddress, ')
          ..write('toLat: $toLat, ')
          ..write('toLng: $toLng, ')
          ..write('flightNo: $flightNo, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('guideRef: $guideRef, ')
          ..write('backupOf: $backupOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumPhotosTable extends AlbumPhotos
    with TableInfo<$AlbumPhotosTable, AlbumPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id)',
    ),
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayEpochDayMeta = const VerificationMeta(
    'dayEpochDay',
  );
  @override
  late final GeneratedColumn<int> dayEpochDay = GeneratedColumn<int>(
    'day_epoch_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    uri,
    dayEpochDay,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'album_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('day_epoch_day')) {
      context.handle(
        _dayEpochDayMeta,
        dayEpochDay.isAcceptableOrUnknown(
          data['day_epoch_day']!,
          _dayEpochDayMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlbumPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      dayEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_epoch_day'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AlbumPhotosTable createAlias(String alias) {
    return $AlbumPhotosTable(attachedDatabase, alias);
  }
}

class AlbumPhoto extends DataClass implements Insertable<AlbumPhoto> {
  final String id;
  final String tripId;
  final String uri;
  final int? dayEpochDay;
  final int createdAt;
  const AlbumPhoto({
    required this.id,
    required this.tripId,
    required this.uri,
    this.dayEpochDay,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['uri'] = Variable<String>(uri);
    if (!nullToAbsent || dayEpochDay != null) {
      map['day_epoch_day'] = Variable<int>(dayEpochDay);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AlbumPhotosCompanion toCompanion(bool nullToAbsent) {
    return AlbumPhotosCompanion(
      id: Value(id),
      tripId: Value(tripId),
      uri: Value(uri),
      dayEpochDay: dayEpochDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dayEpochDay),
      createdAt: Value(createdAt),
    );
  }

  factory AlbumPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumPhoto(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      uri: serializer.fromJson<String>(json['uri']),
      dayEpochDay: serializer.fromJson<int?>(json['dayEpochDay']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'uri': serializer.toJson<String>(uri),
      'dayEpochDay': serializer.toJson<int?>(dayEpochDay),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AlbumPhoto copyWith({
    String? id,
    String? tripId,
    String? uri,
    Value<int?> dayEpochDay = const Value.absent(),
    int? createdAt,
  }) => AlbumPhoto(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    uri: uri ?? this.uri,
    dayEpochDay: dayEpochDay.present ? dayEpochDay.value : this.dayEpochDay,
    createdAt: createdAt ?? this.createdAt,
  );
  AlbumPhoto copyWithCompanion(AlbumPhotosCompanion data) {
    return AlbumPhoto(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      uri: data.uri.present ? data.uri.value : this.uri,
      dayEpochDay: data.dayEpochDay.present
          ? data.dayEpochDay.value
          : this.dayEpochDay,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumPhoto(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('uri: $uri, ')
          ..write('dayEpochDay: $dayEpochDay, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, uri, dayEpochDay, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumPhoto &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.uri == this.uri &&
          other.dayEpochDay == this.dayEpochDay &&
          other.createdAt == this.createdAt);
}

class AlbumPhotosCompanion extends UpdateCompanion<AlbumPhoto> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> uri;
  final Value<int?> dayEpochDay;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AlbumPhotosCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.uri = const Value.absent(),
    this.dayEpochDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumPhotosCompanion.insert({
    required String id,
    required String tripId,
    required String uri,
    this.dayEpochDay = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       uri = Value(uri),
       createdAt = Value(createdAt);
  static Insertable<AlbumPhoto> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? uri,
    Expression<int>? dayEpochDay,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (uri != null) 'uri': uri,
      if (dayEpochDay != null) 'day_epoch_day': dayEpochDay,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? uri,
    Value<int?>? dayEpochDay,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AlbumPhotosCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      uri: uri ?? this.uri,
      dayEpochDay: dayEpochDay ?? this.dayEpochDay,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (dayEpochDay.present) {
      map['day_epoch_day'] = Variable<int>(dayEpochDay.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumPhotosCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('uri: $uri, ')
          ..write('dayEpochDay: $dayEpochDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistItemsTable extends ChecklistItems
    with TableInfo<$ChecklistItemsTable, ChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("trip"),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("other"),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    tripId,
    category,
    label,
    done,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ChecklistItemsTable createAlias(String alias) {
    return $ChecklistItemsTable(attachedDatabase, alias);
  }
}

class ChecklistItem extends DataClass implements Insertable<ChecklistItem> {
  final String id;
  final String scope;
  final String? tripId;
  final String category;
  final String label;
  final bool done;
  final int sortOrder;
  const ChecklistItem({
    required this.id,
    required this.scope,
    this.tripId,
    required this.category,
    required this.label,
    required this.done,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    map['category'] = Variable<String>(category);
    map['label'] = Variable<String>(label);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistItemsCompanion(
      id: Value(id),
      scope: Value(scope),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      category: Value(category),
      label: Value(label),
      done: Value(done),
      sortOrder: Value(sortOrder),
    );
  }

  factory ChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChecklistItem(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      category: serializer.fromJson<String>(json['category']),
      label: serializer.fromJson<String>(json['label']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'tripId': serializer.toJson<String?>(tripId),
      'category': serializer.toJson<String>(category),
      'label': serializer.toJson<String>(label),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ChecklistItem copyWith({
    String? id,
    String? scope,
    Value<String?> tripId = const Value.absent(),
    String? category,
    String? label,
    bool? done,
    int? sortOrder,
  }) => ChecklistItem(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    tripId: tripId.present ? tripId.value : this.tripId,
    category: category ?? this.category,
    label: label ?? this.label,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ChecklistItem copyWithCompanion(ChecklistItemsCompanion data) {
    return ChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      category: data.category.present ? data.category.value : this.category,
      label: data.label.present ? data.label.value : this.label,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItem(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('tripId: $tripId, ')
          ..write('category: $category, ')
          ..write('label: $label, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scope, tripId, category, label, done, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChecklistItem &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.tripId == this.tripId &&
          other.category == this.category &&
          other.label == this.label &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder);
}

class ChecklistItemsCompanion extends UpdateCompanion<ChecklistItem> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String?> tripId;
  final Value<String> category;
  final Value<String> label;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.tripId = const Value.absent(),
    this.category = const Value.absent(),
    this.label = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChecklistItemsCompanion.insert({
    required String id,
    this.scope = const Value.absent(),
    this.tripId = const Value.absent(),
    this.category = const Value.absent(),
    this.label = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ChecklistItem> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? tripId,
    Expression<String>? category,
    Expression<String>? label,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (tripId != null) 'trip_id': tripId,
      if (category != null) 'category': category,
      if (label != null) 'label': label,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChecklistItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String?>? tripId,
    Value<String>? category,
    Value<String>? label,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ChecklistItemsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      label: label ?? this.label,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('tripId: $tripId, ')
          ..write('category: $category, ')
          ..write('label: $label, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _dateEpochDayMeta = const VerificationMeta(
    'dateEpochDay',
  );
  @override
  late final GeneratedColumn<int> dateEpochDay = GeneratedColumn<int>(
    'date_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("other"),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("normal"),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("CNY"),
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: Constant(1.0),
  );
  static const VerificationMeta _amountForeignCentsMeta =
      const VerificationMeta('amountForeignCents');
  @override
  late final GeneratedColumn<int> amountForeignCents = GeneratedColumn<int>(
    'amount_foreign_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payersJsonMeta = const VerificationMeta(
    'payersJson',
  );
  @override
  late final GeneratedColumn<String> payersJson = GeneratedColumn<String>(
    'payers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _sharesJsonMeta = const VerificationMeta(
    'sharesJson',
  );
  @override
  late final GeneratedColumn<String> sharesJson = GeneratedColumn<String>(
    'shares_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _shareModeMeta = const VerificationMeta(
    'shareMode',
  );
  @override
  late final GeneratedColumn<String> shareMode = GeneratedColumn<String>(
    'share_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("equal"),
  );
  static const VerificationMeta _portionsJsonMeta = const VerificationMeta(
    'portionsJson',
  );
  @override
  late final GeneratedColumn<String> portionsJson = GeneratedColumn<String>(
    'portions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _settledRoundIdMeta = const VerificationMeta(
    'settledRoundId',
  );
  @override
  late final GeneratedColumn<String> settledRoundId = GeneratedColumn<String>(
    'settled_round_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripItemIdMeta = const VerificationMeta(
    'tripItemId',
  );
  @override
  late final GeneratedColumn<String> tripItemId = GeneratedColumn<String>(
    'trip_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fundIdMeta = const VerificationMeta('fundId');
  @override
  late final GeneratedColumn<String> fundId = GeneratedColumn<String>(
    'fund_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payMethodMeta = const VerificationMeta(
    'payMethod',
  );
  @override
  late final GeneratedColumn<String> payMethod = GeneratedColumn<String>(
    'pay_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    dateEpochDay,
    title,
    categoryKey,
    type,
    amountCents,
    currency,
    rate,
    amountForeignCents,
    payersJson,
    sharesJson,
    shareMode,
    portionsJson,
    note,
    settledRoundId,
    tripId,
    tripItemId,
    fundId,
    payMethod,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('date_epoch_day')) {
      context.handle(
        _dateEpochDayMeta,
        dateEpochDay.isAcceptableOrUnknown(
          data['date_epoch_day']!,
          _dateEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('amount_foreign_cents')) {
      context.handle(
        _amountForeignCentsMeta,
        amountForeignCents.isAcceptableOrUnknown(
          data['amount_foreign_cents']!,
          _amountForeignCentsMeta,
        ),
      );
    }
    if (data.containsKey('payers_json')) {
      context.handle(
        _payersJsonMeta,
        payersJson.isAcceptableOrUnknown(data['payers_json']!, _payersJsonMeta),
      );
    }
    if (data.containsKey('shares_json')) {
      context.handle(
        _sharesJsonMeta,
        sharesJson.isAcceptableOrUnknown(data['shares_json']!, _sharesJsonMeta),
      );
    }
    if (data.containsKey('share_mode')) {
      context.handle(
        _shareModeMeta,
        shareMode.isAcceptableOrUnknown(data['share_mode']!, _shareModeMeta),
      );
    }
    if (data.containsKey('portions_json')) {
      context.handle(
        _portionsJsonMeta,
        portionsJson.isAcceptableOrUnknown(
          data['portions_json']!,
          _portionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('settled_round_id')) {
      context.handle(
        _settledRoundIdMeta,
        settledRoundId.isAcceptableOrUnknown(
          data['settled_round_id']!,
          _settledRoundIdMeta,
        ),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('trip_item_id')) {
      context.handle(
        _tripItemIdMeta,
        tripItemId.isAcceptableOrUnknown(
          data['trip_item_id']!,
          _tripItemIdMeta,
        ),
      );
    }
    if (data.containsKey('fund_id')) {
      context.handle(
        _fundIdMeta,
        fundId.isAcceptableOrUnknown(data['fund_id']!, _fundIdMeta),
      );
    }
    if (data.containsKey('pay_method')) {
      context.handle(
        _payMethodMeta,
        payMethod.isAcceptableOrUnknown(data['pay_method']!, _payMethodMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      dateEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_epoch_day'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
      amountForeignCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_foreign_cents'],
      ),
      payersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payers_json'],
      )!,
      sharesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shares_json'],
      )!,
      shareMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_mode'],
      )!,
      portionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portions_json'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      settledRoundId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settled_round_id'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      tripItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_item_id'],
      ),
      fundId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fund_id'],
      ),
      payMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pay_method'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class Expense extends DataClass implements Insertable<Expense> {
  final String id;
  final String groupId;
  final int dateEpochDay;
  final String title;
  final String categoryKey;
  final String type;
  final int amountCents;
  final String currency;
  final double rate;
  final int? amountForeignCents;
  final String payersJson;
  final String sharesJson;
  final String shareMode;
  final String? portionsJson;
  final String note;
  final String? settledRoundId;
  final String? tripId;
  final String? tripItemId;
  final String? fundId;
  final String? payMethod;
  final int createdAt;
  const Expense({
    required this.id,
    required this.groupId,
    required this.dateEpochDay,
    required this.title,
    required this.categoryKey,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.rate,
    this.amountForeignCents,
    required this.payersJson,
    required this.sharesJson,
    required this.shareMode,
    this.portionsJson,
    required this.note,
    this.settledRoundId,
    this.tripId,
    this.tripItemId,
    this.fundId,
    this.payMethod,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['date_epoch_day'] = Variable<int>(dateEpochDay);
    map['title'] = Variable<String>(title);
    map['category_key'] = Variable<String>(categoryKey);
    map['type'] = Variable<String>(type);
    map['amount_cents'] = Variable<int>(amountCents);
    map['currency'] = Variable<String>(currency);
    map['rate'] = Variable<double>(rate);
    if (!nullToAbsent || amountForeignCents != null) {
      map['amount_foreign_cents'] = Variable<int>(amountForeignCents);
    }
    map['payers_json'] = Variable<String>(payersJson);
    map['shares_json'] = Variable<String>(sharesJson);
    map['share_mode'] = Variable<String>(shareMode);
    if (!nullToAbsent || portionsJson != null) {
      map['portions_json'] = Variable<String>(portionsJson);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || settledRoundId != null) {
      map['settled_round_id'] = Variable<String>(settledRoundId);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    if (!nullToAbsent || tripItemId != null) {
      map['trip_item_id'] = Variable<String>(tripItemId);
    }
    if (!nullToAbsent || fundId != null) {
      map['fund_id'] = Variable<String>(fundId);
    }
    if (!nullToAbsent || payMethod != null) {
      map['pay_method'] = Variable<String>(payMethod);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      dateEpochDay: Value(dateEpochDay),
      title: Value(title),
      categoryKey: Value(categoryKey),
      type: Value(type),
      amountCents: Value(amountCents),
      currency: Value(currency),
      rate: Value(rate),
      amountForeignCents: amountForeignCents == null && nullToAbsent
          ? const Value.absent()
          : Value(amountForeignCents),
      payersJson: Value(payersJson),
      sharesJson: Value(sharesJson),
      shareMode: Value(shareMode),
      portionsJson: portionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(portionsJson),
      note: Value(note),
      settledRoundId: settledRoundId == null && nullToAbsent
          ? const Value.absent()
          : Value(settledRoundId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      tripItemId: tripItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripItemId),
      fundId: fundId == null && nullToAbsent
          ? const Value.absent()
          : Value(fundId),
      payMethod: payMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(payMethod),
      createdAt: Value(createdAt),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      dateEpochDay: serializer.fromJson<int>(json['dateEpochDay']),
      title: serializer.fromJson<String>(json['title']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      type: serializer.fromJson<String>(json['type']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      currency: serializer.fromJson<String>(json['currency']),
      rate: serializer.fromJson<double>(json['rate']),
      amountForeignCents: serializer.fromJson<int?>(json['amountForeignCents']),
      payersJson: serializer.fromJson<String>(json['payersJson']),
      sharesJson: serializer.fromJson<String>(json['sharesJson']),
      shareMode: serializer.fromJson<String>(json['shareMode']),
      portionsJson: serializer.fromJson<String?>(json['portionsJson']),
      note: serializer.fromJson<String>(json['note']),
      settledRoundId: serializer.fromJson<String?>(json['settledRoundId']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      tripItemId: serializer.fromJson<String?>(json['tripItemId']),
      fundId: serializer.fromJson<String?>(json['fundId']),
      payMethod: serializer.fromJson<String?>(json['payMethod']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'dateEpochDay': serializer.toJson<int>(dateEpochDay),
      'title': serializer.toJson<String>(title),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'type': serializer.toJson<String>(type),
      'amountCents': serializer.toJson<int>(amountCents),
      'currency': serializer.toJson<String>(currency),
      'rate': serializer.toJson<double>(rate),
      'amountForeignCents': serializer.toJson<int?>(amountForeignCents),
      'payersJson': serializer.toJson<String>(payersJson),
      'sharesJson': serializer.toJson<String>(sharesJson),
      'shareMode': serializer.toJson<String>(shareMode),
      'portionsJson': serializer.toJson<String?>(portionsJson),
      'note': serializer.toJson<String>(note),
      'settledRoundId': serializer.toJson<String?>(settledRoundId),
      'tripId': serializer.toJson<String?>(tripId),
      'tripItemId': serializer.toJson<String?>(tripItemId),
      'fundId': serializer.toJson<String?>(fundId),
      'payMethod': serializer.toJson<String?>(payMethod),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Expense copyWith({
    String? id,
    String? groupId,
    int? dateEpochDay,
    String? title,
    String? categoryKey,
    String? type,
    int? amountCents,
    String? currency,
    double? rate,
    Value<int?> amountForeignCents = const Value.absent(),
    String? payersJson,
    String? sharesJson,
    String? shareMode,
    Value<String?> portionsJson = const Value.absent(),
    String? note,
    Value<String?> settledRoundId = const Value.absent(),
    Value<String?> tripId = const Value.absent(),
    Value<String?> tripItemId = const Value.absent(),
    Value<String?> fundId = const Value.absent(),
    Value<String?> payMethod = const Value.absent(),
    int? createdAt,
  }) => Expense(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    dateEpochDay: dateEpochDay ?? this.dateEpochDay,
    title: title ?? this.title,
    categoryKey: categoryKey ?? this.categoryKey,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    currency: currency ?? this.currency,
    rate: rate ?? this.rate,
    amountForeignCents: amountForeignCents.present
        ? amountForeignCents.value
        : this.amountForeignCents,
    payersJson: payersJson ?? this.payersJson,
    sharesJson: sharesJson ?? this.sharesJson,
    shareMode: shareMode ?? this.shareMode,
    portionsJson: portionsJson.present ? portionsJson.value : this.portionsJson,
    note: note ?? this.note,
    settledRoundId: settledRoundId.present
        ? settledRoundId.value
        : this.settledRoundId,
    tripId: tripId.present ? tripId.value : this.tripId,
    tripItemId: tripItemId.present ? tripItemId.value : this.tripItemId,
    fundId: fundId.present ? fundId.value : this.fundId,
    payMethod: payMethod.present ? payMethod.value : this.payMethod,
    createdAt: createdAt ?? this.createdAt,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      dateEpochDay: data.dateEpochDay.present
          ? data.dateEpochDay.value
          : this.dateEpochDay,
      title: data.title.present ? data.title.value : this.title,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      type: data.type.present ? data.type.value : this.type,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      rate: data.rate.present ? data.rate.value : this.rate,
      amountForeignCents: data.amountForeignCents.present
          ? data.amountForeignCents.value
          : this.amountForeignCents,
      payersJson: data.payersJson.present
          ? data.payersJson.value
          : this.payersJson,
      sharesJson: data.sharesJson.present
          ? data.sharesJson.value
          : this.sharesJson,
      shareMode: data.shareMode.present ? data.shareMode.value : this.shareMode,
      portionsJson: data.portionsJson.present
          ? data.portionsJson.value
          : this.portionsJson,
      note: data.note.present ? data.note.value : this.note,
      settledRoundId: data.settledRoundId.present
          ? data.settledRoundId.value
          : this.settledRoundId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      tripItemId: data.tripItemId.present
          ? data.tripItemId.value
          : this.tripItemId,
      fundId: data.fundId.present ? data.fundId.value : this.fundId,
      payMethod: data.payMethod.present ? data.payMethod.value : this.payMethod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('title: $title, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('amountForeignCents: $amountForeignCents, ')
          ..write('payersJson: $payersJson, ')
          ..write('sharesJson: $sharesJson, ')
          ..write('shareMode: $shareMode, ')
          ..write('portionsJson: $portionsJson, ')
          ..write('note: $note, ')
          ..write('settledRoundId: $settledRoundId, ')
          ..write('tripId: $tripId, ')
          ..write('tripItemId: $tripItemId, ')
          ..write('fundId: $fundId, ')
          ..write('payMethod: $payMethod, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    groupId,
    dateEpochDay,
    title,
    categoryKey,
    type,
    amountCents,
    currency,
    rate,
    amountForeignCents,
    payersJson,
    sharesJson,
    shareMode,
    portionsJson,
    note,
    settledRoundId,
    tripId,
    tripItemId,
    fundId,
    payMethod,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.dateEpochDay == this.dateEpochDay &&
          other.title == this.title &&
          other.categoryKey == this.categoryKey &&
          other.type == this.type &&
          other.amountCents == this.amountCents &&
          other.currency == this.currency &&
          other.rate == this.rate &&
          other.amountForeignCents == this.amountForeignCents &&
          other.payersJson == this.payersJson &&
          other.sharesJson == this.sharesJson &&
          other.shareMode == this.shareMode &&
          other.portionsJson == this.portionsJson &&
          other.note == this.note &&
          other.settledRoundId == this.settledRoundId &&
          other.tripId == this.tripId &&
          other.tripItemId == this.tripItemId &&
          other.fundId == this.fundId &&
          other.payMethod == this.payMethod &&
          other.createdAt == this.createdAt);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> dateEpochDay;
  final Value<String> title;
  final Value<String> categoryKey;
  final Value<String> type;
  final Value<int> amountCents;
  final Value<String> currency;
  final Value<double> rate;
  final Value<int?> amountForeignCents;
  final Value<String> payersJson;
  final Value<String> sharesJson;
  final Value<String> shareMode;
  final Value<String?> portionsJson;
  final Value<String> note;
  final Value<String?> settledRoundId;
  final Value<String?> tripId;
  final Value<String?> tripItemId;
  final Value<String?> fundId;
  final Value<String?> payMethod;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.dateEpochDay = const Value.absent(),
    this.title = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.type = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.amountForeignCents = const Value.absent(),
    this.payersJson = const Value.absent(),
    this.sharesJson = const Value.absent(),
    this.shareMode = const Value.absent(),
    this.portionsJson = const Value.absent(),
    this.note = const Value.absent(),
    this.settledRoundId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.tripItemId = const Value.absent(),
    this.fundId = const Value.absent(),
    this.payMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required String groupId,
    this.dateEpochDay = const Value.absent(),
    this.title = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.type = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.amountForeignCents = const Value.absent(),
    this.payersJson = const Value.absent(),
    this.sharesJson = const Value.absent(),
    this.shareMode = const Value.absent(),
    this.portionsJson = const Value.absent(),
    this.note = const Value.absent(),
    this.settledRoundId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.tripItemId = const Value.absent(),
    this.fundId = const Value.absent(),
    this.payMethod = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       createdAt = Value(createdAt);
  static Insertable<Expense> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? dateEpochDay,
    Expression<String>? title,
    Expression<String>? categoryKey,
    Expression<String>? type,
    Expression<int>? amountCents,
    Expression<String>? currency,
    Expression<double>? rate,
    Expression<int>? amountForeignCents,
    Expression<String>? payersJson,
    Expression<String>? sharesJson,
    Expression<String>? shareMode,
    Expression<String>? portionsJson,
    Expression<String>? note,
    Expression<String>? settledRoundId,
    Expression<String>? tripId,
    Expression<String>? tripItemId,
    Expression<String>? fundId,
    Expression<String>? payMethod,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (dateEpochDay != null) 'date_epoch_day': dateEpochDay,
      if (title != null) 'title': title,
      if (categoryKey != null) 'category_key': categoryKey,
      if (type != null) 'type': type,
      if (amountCents != null) 'amount_cents': amountCents,
      if (currency != null) 'currency': currency,
      if (rate != null) 'rate': rate,
      if (amountForeignCents != null)
        'amount_foreign_cents': amountForeignCents,
      if (payersJson != null) 'payers_json': payersJson,
      if (sharesJson != null) 'shares_json': sharesJson,
      if (shareMode != null) 'share_mode': shareMode,
      if (portionsJson != null) 'portions_json': portionsJson,
      if (note != null) 'note': note,
      if (settledRoundId != null) 'settled_round_id': settledRoundId,
      if (tripId != null) 'trip_id': tripId,
      if (tripItemId != null) 'trip_item_id': tripItemId,
      if (fundId != null) 'fund_id': fundId,
      if (payMethod != null) 'pay_method': payMethod,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int>? dateEpochDay,
    Value<String>? title,
    Value<String>? categoryKey,
    Value<String>? type,
    Value<int>? amountCents,
    Value<String>? currency,
    Value<double>? rate,
    Value<int?>? amountForeignCents,
    Value<String>? payersJson,
    Value<String>? sharesJson,
    Value<String>? shareMode,
    Value<String?>? portionsJson,
    Value<String>? note,
    Value<String?>? settledRoundId,
    Value<String?>? tripId,
    Value<String?>? tripItemId,
    Value<String?>? fundId,
    Value<String?>? payMethod,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      dateEpochDay: dateEpochDay ?? this.dateEpochDay,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      rate: rate ?? this.rate,
      amountForeignCents: amountForeignCents ?? this.amountForeignCents,
      payersJson: payersJson ?? this.payersJson,
      sharesJson: sharesJson ?? this.sharesJson,
      shareMode: shareMode ?? this.shareMode,
      portionsJson: portionsJson ?? this.portionsJson,
      note: note ?? this.note,
      settledRoundId: settledRoundId ?? this.settledRoundId,
      tripId: tripId ?? this.tripId,
      tripItemId: tripItemId ?? this.tripItemId,
      fundId: fundId ?? this.fundId,
      payMethod: payMethod ?? this.payMethod,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (dateEpochDay.present) {
      map['date_epoch_day'] = Variable<int>(dateEpochDay.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (amountForeignCents.present) {
      map['amount_foreign_cents'] = Variable<int>(amountForeignCents.value);
    }
    if (payersJson.present) {
      map['payers_json'] = Variable<String>(payersJson.value);
    }
    if (sharesJson.present) {
      map['shares_json'] = Variable<String>(sharesJson.value);
    }
    if (shareMode.present) {
      map['share_mode'] = Variable<String>(shareMode.value);
    }
    if (portionsJson.present) {
      map['portions_json'] = Variable<String>(portionsJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (settledRoundId.present) {
      map['settled_round_id'] = Variable<String>(settledRoundId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (tripItemId.present) {
      map['trip_item_id'] = Variable<String>(tripItemId.value);
    }
    if (fundId.present) {
      map['fund_id'] = Variable<String>(fundId.value);
    }
    if (payMethod.present) {
      map['pay_method'] = Variable<String>(payMethod.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('title: $title, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('amountForeignCents: $amountForeignCents, ')
          ..write('payersJson: $payersJson, ')
          ..write('sharesJson: $sharesJson, ')
          ..write('shareMode: $shareMode, ')
          ..write('portionsJson: $portionsJson, ')
          ..write('note: $note, ')
          ..write('settledRoundId: $settledRoundId, ')
          ..write('tripId: $tripId, ')
          ..write('tripItemId: $tripItemId, ')
          ..write('fundId: $fundId, ')
          ..write('payMethod: $payMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettlementsTable extends Settlements
    with TableInfo<$SettlementsTable, Settlement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettlementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("active"),
  );
  static const VerificationMeta _transfersJsonMeta = const VerificationMeta(
    'transfersJson',
  );
  @override
  late final GeneratedColumn<String> transfersJson = GeneratedColumn<String>(
    'transfers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _expenseIdsJsonMeta = const VerificationMeta(
    'expenseIdsJson',
  );
  @override
  late final GeneratedColumn<String> expenseIdsJson = GeneratedColumn<String>(
    'expense_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _roundNoMeta = const VerificationMeta(
    'roundNo',
  );
  @override
  late final GeneratedColumn<int> roundNo = GeneratedColumn<int>(
    'round_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(1),
  );
  static const VerificationMeta _strategyMeta = const VerificationMeta(
    'strategy',
  );
  @override
  late final GeneratedColumn<String> strategy = GeneratedColumn<String>(
    'strategy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("minTransfers"),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    status,
    transfersJson,
    expenseIdsJson,
    roundNo,
    strategy,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settlements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Settlement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('transfers_json')) {
      context.handle(
        _transfersJsonMeta,
        transfersJson.isAcceptableOrUnknown(
          data['transfers_json']!,
          _transfersJsonMeta,
        ),
      );
    }
    if (data.containsKey('expense_ids_json')) {
      context.handle(
        _expenseIdsJsonMeta,
        expenseIdsJson.isAcceptableOrUnknown(
          data['expense_ids_json']!,
          _expenseIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('round_no')) {
      context.handle(
        _roundNoMeta,
        roundNo.isAcceptableOrUnknown(data['round_no']!, _roundNoMeta),
      );
    }
    if (data.containsKey('strategy')) {
      context.handle(
        _strategyMeta,
        strategy.isAcceptableOrUnknown(data['strategy']!, _strategyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Settlement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Settlement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      transfersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfers_json'],
      )!,
      expenseIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_ids_json'],
      )!,
      roundNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_no'],
      )!,
      strategy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strategy'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $SettlementsTable createAlias(String alias) {
    return $SettlementsTable(attachedDatabase, alias);
  }
}

class Settlement extends DataClass implements Insertable<Settlement> {
  final String id;
  final String groupId;
  final String status;
  final String transfersJson;
  final String expenseIdsJson;
  final int roundNo;
  final String strategy;
  final int createdAt;
  final int? completedAt;
  const Settlement({
    required this.id,
    required this.groupId,
    required this.status,
    required this.transfersJson,
    required this.expenseIdsJson,
    required this.roundNo,
    required this.strategy,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['status'] = Variable<String>(status);
    map['transfers_json'] = Variable<String>(transfersJson);
    map['expense_ids_json'] = Variable<String>(expenseIdsJson);
    map['round_no'] = Variable<int>(roundNo);
    map['strategy'] = Variable<String>(strategy);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  SettlementsCompanion toCompanion(bool nullToAbsent) {
    return SettlementsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      status: Value(status),
      transfersJson: Value(transfersJson),
      expenseIdsJson: Value(expenseIdsJson),
      roundNo: Value(roundNo),
      strategy: Value(strategy),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Settlement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Settlement(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      status: serializer.fromJson<String>(json['status']),
      transfersJson: serializer.fromJson<String>(json['transfersJson']),
      expenseIdsJson: serializer.fromJson<String>(json['expenseIdsJson']),
      roundNo: serializer.fromJson<int>(json['roundNo']),
      strategy: serializer.fromJson<String>(json['strategy']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'status': serializer.toJson<String>(status),
      'transfersJson': serializer.toJson<String>(transfersJson),
      'expenseIdsJson': serializer.toJson<String>(expenseIdsJson),
      'roundNo': serializer.toJson<int>(roundNo),
      'strategy': serializer.toJson<String>(strategy),
      'createdAt': serializer.toJson<int>(createdAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  Settlement copyWith({
    String? id,
    String? groupId,
    String? status,
    String? transfersJson,
    String? expenseIdsJson,
    int? roundNo,
    String? strategy,
    int? createdAt,
    Value<int?> completedAt = const Value.absent(),
  }) => Settlement(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    status: status ?? this.status,
    transfersJson: transfersJson ?? this.transfersJson,
    expenseIdsJson: expenseIdsJson ?? this.expenseIdsJson,
    roundNo: roundNo ?? this.roundNo,
    strategy: strategy ?? this.strategy,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Settlement copyWithCompanion(SettlementsCompanion data) {
    return Settlement(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      status: data.status.present ? data.status.value : this.status,
      transfersJson: data.transfersJson.present
          ? data.transfersJson.value
          : this.transfersJson,
      expenseIdsJson: data.expenseIdsJson.present
          ? data.expenseIdsJson.value
          : this.expenseIdsJson,
      roundNo: data.roundNo.present ? data.roundNo.value : this.roundNo,
      strategy: data.strategy.present ? data.strategy.value : this.strategy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Settlement(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('transfersJson: $transfersJson, ')
          ..write('expenseIdsJson: $expenseIdsJson, ')
          ..write('roundNo: $roundNo, ')
          ..write('strategy: $strategy, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    status,
    transfersJson,
    expenseIdsJson,
    roundNo,
    strategy,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Settlement &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.status == this.status &&
          other.transfersJson == this.transfersJson &&
          other.expenseIdsJson == this.expenseIdsJson &&
          other.roundNo == this.roundNo &&
          other.strategy == this.strategy &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class SettlementsCompanion extends UpdateCompanion<Settlement> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> status;
  final Value<String> transfersJson;
  final Value<String> expenseIdsJson;
  final Value<int> roundNo;
  final Value<String> strategy;
  final Value<int> createdAt;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const SettlementsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.status = const Value.absent(),
    this.transfersJson = const Value.absent(),
    this.expenseIdsJson = const Value.absent(),
    this.roundNo = const Value.absent(),
    this.strategy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettlementsCompanion.insert({
    required String id,
    required String groupId,
    this.status = const Value.absent(),
    this.transfersJson = const Value.absent(),
    this.expenseIdsJson = const Value.absent(),
    this.roundNo = const Value.absent(),
    this.strategy = const Value.absent(),
    required int createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       createdAt = Value(createdAt);
  static Insertable<Settlement> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? status,
    Expression<String>? transfersJson,
    Expression<String>? expenseIdsJson,
    Expression<int>? roundNo,
    Expression<String>? strategy,
    Expression<int>? createdAt,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (status != null) 'status': status,
      if (transfersJson != null) 'transfers_json': transfersJson,
      if (expenseIdsJson != null) 'expense_ids_json': expenseIdsJson,
      if (roundNo != null) 'round_no': roundNo,
      if (strategy != null) 'strategy': strategy,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettlementsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? status,
    Value<String>? transfersJson,
    Value<String>? expenseIdsJson,
    Value<int>? roundNo,
    Value<String>? strategy,
    Value<int>? createdAt,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return SettlementsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      transfersJson: transfersJson ?? this.transfersJson,
      expenseIdsJson: expenseIdsJson ?? this.expenseIdsJson,
      roundNo: roundNo ?? this.roundNo,
      strategy: strategy ?? this.strategy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (transfersJson.present) {
      map['transfers_json'] = Variable<String>(transfersJson.value);
    }
    if (expenseIdsJson.present) {
      map['expense_ids_json'] = Variable<String>(expenseIdsJson.value);
    }
    if (roundNo.present) {
      map['round_no'] = Variable<int>(roundNo.value);
    }
    if (strategy.present) {
      map['strategy'] = Variable<String>(strategy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettlementsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('transfersJson: $transfersJson, ')
          ..write('expenseIdsJson: $expenseIdsJson, ')
          ..write('roundNo: $roundNo, ')
          ..write('strategy: $strategy, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("📦"),
  );
  static const VerificationMeta _builtinMeta = const VerificationMeta(
    'builtin',
  );
  @override
  late final GeneratedColumn<bool> builtin = GeneratedColumn<bool>(
    'builtin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("builtin" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [key, name, icon, builtin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('builtin')) {
      context.handle(
        _builtinMeta,
        builtin.isAcceptableOrUnknown(data['builtin']!, _builtinMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      builtin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}builtin'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String key;
  final String name;
  final String icon;
  final bool builtin;
  const Category({
    required this.key,
    required this.name,
    required this.icon,
    required this.builtin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['builtin'] = Variable<bool>(builtin);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      key: Value(key),
      name: Value(name),
      icon: Value(icon),
      builtin: Value(builtin),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      builtin: serializer.fromJson<bool>(json['builtin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'builtin': serializer.toJson<bool>(builtin),
    };
  }

  Category copyWith({String? key, String? name, String? icon, bool? builtin}) =>
      Category(
        key: key ?? this.key,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        builtin: builtin ?? this.builtin,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      builtin: data.builtin.present ? data.builtin.value : this.builtin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('builtin: $builtin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, name, icon, builtin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.key == this.key &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.builtin == this.builtin);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> key;
  final Value<String> name;
  final Value<String> icon;
  final Value<bool> builtin;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.builtin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String key,
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.builtin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Category> custom({
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<bool>? builtin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (builtin != null) 'builtin': builtin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? key,
    Value<String>? name,
    Value<String>? icon,
    Value<bool>? builtin,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      key: key ?? this.key,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      builtin: builtin ?? this.builtin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (builtin.present) {
      map['builtin'] = Variable<bool>(builtin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('builtin: $builtin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    entity,
    rowId,
    op,
    updatedMs,
    attemptCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, rowId};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String entity;
  final String rowId;
  final String op;
  final int updatedMs;
  final int attemptCount;
  const SyncOutboxData({
    required this.entity,
    required this.rowId,
    required this.op,
    required this.updatedMs,
    required this.attemptCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['row_id'] = Variable<String>(rowId);
    map['op'] = Variable<String>(op);
    map['updated_ms'] = Variable<int>(updatedMs);
    map['attempt_count'] = Variable<int>(attemptCount);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      entity: Value(entity),
      rowId: Value(rowId),
      op: Value(op),
      updatedMs: Value(updatedMs),
      attemptCount: Value(attemptCount),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      entity: serializer.fromJson<String>(json['entity']),
      rowId: serializer.fromJson<String>(json['rowId']),
      op: serializer.fromJson<String>(json['op']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'rowId': serializer.toJson<String>(rowId),
      'op': serializer.toJson<String>(op),
      'updatedMs': serializer.toJson<int>(updatedMs),
      'attemptCount': serializer.toJson<int>(attemptCount),
    };
  }

  SyncOutboxData copyWith({
    String? entity,
    String? rowId,
    String? op,
    int? updatedMs,
    int? attemptCount,
  }) => SyncOutboxData(
    entity: entity ?? this.entity,
    rowId: rowId ?? this.rowId,
    op: op ?? this.op,
    updatedMs: updatedMs ?? this.updatedMs,
    attemptCount: attemptCount ?? this.attemptCount,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      entity: data.entity.present ? data.entity.value : this.entity,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      op: data.op.present ? data.op.value : this.op,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('attemptCount: $attemptCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, rowId, op, updatedMs, attemptCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.entity == this.entity &&
          other.rowId == this.rowId &&
          other.op == this.op &&
          other.updatedMs == this.updatedMs &&
          other.attemptCount == this.attemptCount);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> entity;
  final Value<String> rowId;
  final Value<String> op;
  final Value<int> updatedMs;
  final Value<int> attemptCount;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.entity = const Value.absent(),
    this.rowId = const Value.absent(),
    this.op = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String entity,
    required String rowId,
    required String op,
    required int updatedMs,
    this.attemptCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       rowId = Value(rowId),
       op = Value(op),
       updatedMs = Value(updatedMs);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? entity,
    Expression<String>? rowId,
    Expression<String>? op,
    Expression<int>? updatedMs,
    Expression<int>? attemptCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (rowId != null) 'row_id': rowId,
      if (op != null) 'op': op,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? entity,
    Value<String>? rowId,
    Value<String>? op,
    Value<int>? updatedMs,
    Value<int>? attemptCount,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      entity: entity ?? this.entity,
      rowId: rowId ?? this.rowId,
      op: op ?? this.op,
      updatedMs: updatedMs ?? this.updatedMs,
      attemptCount: attemptCount ?? this.attemptCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledMsMeta = const VerificationMeta(
    'lastPulledMs',
  );
  @override
  late final GeneratedColumn<int> lastPulledMs = GeneratedColumn<int>(
    'last_pulled_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [entity, lastPulledMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('last_pulled_ms')) {
      context.handle(
        _lastPulledMsMeta,
        lastPulledMs.isAcceptableOrUnknown(
          data['last_pulled_ms']!,
          _lastPulledMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      lastPulledMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_ms'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String entity;
  final int lastPulledMs;
  const SyncMetaData({required this.entity, required this.lastPulledMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['last_pulled_ms'] = Variable<int>(lastPulledMs);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      entity: Value(entity),
      lastPulledMs: Value(lastPulledMs),
    );
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      entity: serializer.fromJson<String>(json['entity']),
      lastPulledMs: serializer.fromJson<int>(json['lastPulledMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'lastPulledMs': serializer.toJson<int>(lastPulledMs),
    };
  }

  SyncMetaData copyWith({String? entity, int? lastPulledMs}) => SyncMetaData(
    entity: entity ?? this.entity,
    lastPulledMs: lastPulledMs ?? this.lastPulledMs,
  );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      entity: data.entity.present ? data.entity.value : this.entity,
      lastPulledMs: data.lastPulledMs.present
          ? data.lastPulledMs.value
          : this.lastPulledMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('entity: $entity, ')
          ..write('lastPulledMs: $lastPulledMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, lastPulledMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.entity == this.entity &&
          other.lastPulledMs == this.lastPulledMs);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> entity;
  final Value<int> lastPulledMs;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.entity = const Value.absent(),
    this.lastPulledMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String entity,
    this.lastPulledMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity);
  static Insertable<SyncMetaData> custom({
    Expression<String>? entity,
    Expression<int>? lastPulledMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (lastPulledMs != null) 'last_pulled_ms': lastPulledMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? entity,
    Value<int>? lastPulledMs,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      entity: entity ?? this.entity,
      lastPulledMs: lastPulledMs ?? this.lastPulledMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (lastPulledMs.present) {
      map['last_pulled_ms'] = Variable<int>(lastPulledMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('entity: $entity, ')
          ..write('lastPulledMs: $lastPulledMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedGroupsTable extends SharedGroups
    with TableInfo<$SharedGroupsTable, SharedGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("📁"),
  );
  static const VerificationMeta _budgetEnabledMeta = const VerificationMeta(
    'budgetEnabled',
  );
  @override
  late final GeneratedColumn<bool> budgetEnabled = GeneratedColumn<bool>(
    'budget_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("budget_enabled" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _budgetCentsMeta = const VerificationMeta(
    'budgetCents',
  );
  @override
  late final GeneratedColumn<int> budgetCents = GeneratedColumn<int>(
    'budget_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _archivedAtMsMeta = const VerificationMeta(
    'archivedAtMs',
  );
  @override
  late final GeneratedColumn<int> archivedAtMs = GeneratedColumn<int>(
    'archived_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    budgetEnabled,
    budgetCents,
    archived,
    archivedAtMs,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedGroup> instance, {
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('budget_enabled')) {
      context.handle(
        _budgetEnabledMeta,
        budgetEnabled.isAcceptableOrUnknown(
          data['budget_enabled']!,
          _budgetEnabledMeta,
        ),
      );
    }
    if (data.containsKey('budget_cents')) {
      context.handle(
        _budgetCentsMeta,
        budgetCents.isAcceptableOrUnknown(
          data['budget_cents']!,
          _budgetCentsMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('archived_at_ms')) {
      context.handle(
        _archivedAtMsMeta,
        archivedAtMs.isAcceptableOrUnknown(
          data['archived_at_ms']!,
          _archivedAtMsMeta,
        ),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      budgetEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}budget_enabled'],
      )!,
      budgetCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_cents'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      archivedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharedGroupsTable createAlias(String alias) {
    return $SharedGroupsTable(attachedDatabase, alias);
  }
}

class SharedGroup extends DataClass implements Insertable<SharedGroup> {
  final String id;
  final String name;
  final String icon;
  final bool budgetEnabled;
  final int? budgetCents;
  final bool archived;
  final int? archivedAtMs;
  final int createdAt;
  final int updatedAt;
  const SharedGroup({
    required this.id,
    required this.name,
    required this.icon,
    required this.budgetEnabled,
    this.budgetCents,
    required this.archived,
    this.archivedAtMs,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['budget_enabled'] = Variable<bool>(budgetEnabled);
    if (!nullToAbsent || budgetCents != null) {
      map['budget_cents'] = Variable<int>(budgetCents);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || archivedAtMs != null) {
      map['archived_at_ms'] = Variable<int>(archivedAtMs);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SharedGroupsCompanion toCompanion(bool nullToAbsent) {
    return SharedGroupsCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      budgetEnabled: Value(budgetEnabled),
      budgetCents: budgetCents == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetCents),
      archived: Value(archived),
      archivedAtMs: archivedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      budgetEnabled: serializer.fromJson<bool>(json['budgetEnabled']),
      budgetCents: serializer.fromJson<int?>(json['budgetCents']),
      archived: serializer.fromJson<bool>(json['archived']),
      archivedAtMs: serializer.fromJson<int?>(json['archivedAtMs']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'budgetEnabled': serializer.toJson<bool>(budgetEnabled),
      'budgetCents': serializer.toJson<int?>(budgetCents),
      'archived': serializer.toJson<bool>(archived),
      'archivedAtMs': serializer.toJson<int?>(archivedAtMs),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SharedGroup copyWith({
    String? id,
    String? name,
    String? icon,
    bool? budgetEnabled,
    Value<int?> budgetCents = const Value.absent(),
    bool? archived,
    Value<int?> archivedAtMs = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => SharedGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    budgetEnabled: budgetEnabled ?? this.budgetEnabled,
    budgetCents: budgetCents.present ? budgetCents.value : this.budgetCents,
    archived: archived ?? this.archived,
    archivedAtMs: archivedAtMs.present ? archivedAtMs.value : this.archivedAtMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharedGroup copyWithCompanion(SharedGroupsCompanion data) {
    return SharedGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      budgetEnabled: data.budgetEnabled.present
          ? data.budgetEnabled.value
          : this.budgetEnabled,
      budgetCents: data.budgetCents.present
          ? data.budgetCents.value
          : this.budgetCents,
      archived: data.archived.present ? data.archived.value : this.archived,
      archivedAtMs: data.archivedAtMs.present
          ? data.archivedAtMs.value
          : this.archivedAtMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('budgetEnabled: $budgetEnabled, ')
          ..write('budgetCents: $budgetCents, ')
          ..write('archived: $archived, ')
          ..write('archivedAtMs: $archivedAtMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    budgetEnabled,
    budgetCents,
    archived,
    archivedAtMs,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.budgetEnabled == this.budgetEnabled &&
          other.budgetCents == this.budgetCents &&
          other.archived == this.archived &&
          other.archivedAtMs == this.archivedAtMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SharedGroupsCompanion extends UpdateCompanion<SharedGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<bool> budgetEnabled;
  final Value<int?> budgetCents;
  final Value<bool> archived;
  final Value<int?> archivedAtMs;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SharedGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.budgetEnabled = const Value.absent(),
    this.budgetCents = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAtMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedGroupsCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.budgetEnabled = const Value.absent(),
    this.budgetCents = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAtMs = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SharedGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<bool>? budgetEnabled,
    Expression<int>? budgetCents,
    Expression<bool>? archived,
    Expression<int>? archivedAtMs,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (budgetEnabled != null) 'budget_enabled': budgetEnabled,
      if (budgetCents != null) 'budget_cents': budgetCents,
      if (archived != null) 'archived': archived,
      if (archivedAtMs != null) 'archived_at_ms': archivedAtMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<bool>? budgetEnabled,
    Value<int?>? budgetCents,
    Value<bool>? archived,
    Value<int?>? archivedAtMs,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharedGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      budgetEnabled: budgetEnabled ?? this.budgetEnabled,
      budgetCents: budgetCents ?? this.budgetCents,
      archived: archived ?? this.archived,
      archivedAtMs: archivedAtMs ?? this.archivedAtMs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (budgetEnabled.present) {
      map['budget_enabled'] = Variable<bool>(budgetEnabled.value);
    }
    if (budgetCents.present) {
      map['budget_cents'] = Variable<int>(budgetCents.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (archivedAtMs.present) {
      map['archived_at_ms'] = Variable<int>(archivedAtMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('budgetEnabled: $budgetEnabled, ')
          ..write('budgetCents: $budgetCents, ')
          ..write('archived: $archived, ')
          ..write('archivedAtMs: $archivedAtMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedMembersTable extends SharedMembers
    with TableInfo<$SharedMembersTable, SharedMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
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
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    colorIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SharedMembersTable createAlias(String alias) {
    return $SharedMembersTable(attachedDatabase, alias);
  }
}

class SharedMember extends DataClass implements Insertable<SharedMember> {
  final String id;
  final String groupId;
  final String name;
  final int colorIndex;
  final int createdAt;
  const SharedMember({
    required this.id,
    required this.groupId,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SharedMembersCompanion toCompanion(bool nullToAbsent) {
    return SharedMembersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      colorIndex: Value(colorIndex),
      createdAt: Value(createdAt),
    );
  }

  factory SharedMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedMember(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SharedMember copyWith({
    String? id,
    String? groupId,
    String? name,
    int? colorIndex,
    int? createdAt,
  }) => SharedMember(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  SharedMember copyWithCompanion(SharedMembersCompanion data) {
    return SharedMember(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedMember(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, name, colorIndex, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedMember &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.createdAt == this.createdAt);
}

class SharedMembersCompanion extends UpdateCompanion<SharedMember> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SharedMembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedMembersCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    this.colorIndex = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SharedMember> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SharedMembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedMembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedExpensesTable extends SharedExpenses
    with TableInfo<$SharedExpensesTable, SharedExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateEpochDayMeta = const VerificationMeta(
    'dateEpochDay',
  );
  @override
  late final GeneratedColumn<int> dateEpochDay = GeneratedColumn<int>(
    'date_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("other"),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("normal"),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("CNY"),
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: Constant(1.0),
  );
  static const VerificationMeta _amountForeignCentsMeta =
      const VerificationMeta('amountForeignCents');
  @override
  late final GeneratedColumn<int> amountForeignCents = GeneratedColumn<int>(
    'amount_foreign_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payersJsonMeta = const VerificationMeta(
    'payersJson',
  );
  @override
  late final GeneratedColumn<String> payersJson = GeneratedColumn<String>(
    'payers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _sharesJsonMeta = const VerificationMeta(
    'sharesJson',
  );
  @override
  late final GeneratedColumn<String> sharesJson = GeneratedColumn<String>(
    'shares_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _shareModeMeta = const VerificationMeta(
    'shareMode',
  );
  @override
  late final GeneratedColumn<String> shareMode = GeneratedColumn<String>(
    'share_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("equal"),
  );
  static const VerificationMeta _portionsJsonMeta = const VerificationMeta(
    'portionsJson',
  );
  @override
  late final GeneratedColumn<String> portionsJson = GeneratedColumn<String>(
    'portions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _settledRoundIdMeta = const VerificationMeta(
    'settledRoundId',
  );
  @override
  late final GeneratedColumn<String> settledRoundId = GeneratedColumn<String>(
    'settled_round_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripItemIdMeta = const VerificationMeta(
    'tripItemId',
  );
  @override
  late final GeneratedColumn<String> tripItemId = GeneratedColumn<String>(
    'trip_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    dateEpochDay,
    title,
    categoryKey,
    type,
    amountCents,
    currency,
    rate,
    amountForeignCents,
    payersJson,
    sharesJson,
    shareMode,
    portionsJson,
    note,
    settledRoundId,
    tripId,
    tripItemId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedExpense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('date_epoch_day')) {
      context.handle(
        _dateEpochDayMeta,
        dateEpochDay.isAcceptableOrUnknown(
          data['date_epoch_day']!,
          _dateEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('amount_foreign_cents')) {
      context.handle(
        _amountForeignCentsMeta,
        amountForeignCents.isAcceptableOrUnknown(
          data['amount_foreign_cents']!,
          _amountForeignCentsMeta,
        ),
      );
    }
    if (data.containsKey('payers_json')) {
      context.handle(
        _payersJsonMeta,
        payersJson.isAcceptableOrUnknown(data['payers_json']!, _payersJsonMeta),
      );
    }
    if (data.containsKey('shares_json')) {
      context.handle(
        _sharesJsonMeta,
        sharesJson.isAcceptableOrUnknown(data['shares_json']!, _sharesJsonMeta),
      );
    }
    if (data.containsKey('share_mode')) {
      context.handle(
        _shareModeMeta,
        shareMode.isAcceptableOrUnknown(data['share_mode']!, _shareModeMeta),
      );
    }
    if (data.containsKey('portions_json')) {
      context.handle(
        _portionsJsonMeta,
        portionsJson.isAcceptableOrUnknown(
          data['portions_json']!,
          _portionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('settled_round_id')) {
      context.handle(
        _settledRoundIdMeta,
        settledRoundId.isAcceptableOrUnknown(
          data['settled_round_id']!,
          _settledRoundIdMeta,
        ),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('trip_item_id')) {
      context.handle(
        _tripItemIdMeta,
        tripItemId.isAcceptableOrUnknown(
          data['trip_item_id']!,
          _tripItemIdMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedExpense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      dateEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_epoch_day'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
      amountForeignCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_foreign_cents'],
      ),
      payersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payers_json'],
      )!,
      sharesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shares_json'],
      )!,
      shareMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_mode'],
      )!,
      portionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portions_json'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      settledRoundId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settled_round_id'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      tripItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_item_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SharedExpensesTable createAlias(String alias) {
    return $SharedExpensesTable(attachedDatabase, alias);
  }
}

class SharedExpense extends DataClass implements Insertable<SharedExpense> {
  final String id;
  final String groupId;
  final int dateEpochDay;
  final String title;
  final String categoryKey;
  final String type;
  final int amountCents;
  final String currency;
  final double rate;
  final int? amountForeignCents;
  final String payersJson;
  final String sharesJson;
  final String shareMode;
  final String? portionsJson;
  final String note;
  final String? settledRoundId;
  final String? tripId;
  final String? tripItemId;
  final int createdAt;
  const SharedExpense({
    required this.id,
    required this.groupId,
    required this.dateEpochDay,
    required this.title,
    required this.categoryKey,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.rate,
    this.amountForeignCents,
    required this.payersJson,
    required this.sharesJson,
    required this.shareMode,
    this.portionsJson,
    required this.note,
    this.settledRoundId,
    this.tripId,
    this.tripItemId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['date_epoch_day'] = Variable<int>(dateEpochDay);
    map['title'] = Variable<String>(title);
    map['category_key'] = Variable<String>(categoryKey);
    map['type'] = Variable<String>(type);
    map['amount_cents'] = Variable<int>(amountCents);
    map['currency'] = Variable<String>(currency);
    map['rate'] = Variable<double>(rate);
    if (!nullToAbsent || amountForeignCents != null) {
      map['amount_foreign_cents'] = Variable<int>(amountForeignCents);
    }
    map['payers_json'] = Variable<String>(payersJson);
    map['shares_json'] = Variable<String>(sharesJson);
    map['share_mode'] = Variable<String>(shareMode);
    if (!nullToAbsent || portionsJson != null) {
      map['portions_json'] = Variable<String>(portionsJson);
    }
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || settledRoundId != null) {
      map['settled_round_id'] = Variable<String>(settledRoundId);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    if (!nullToAbsent || tripItemId != null) {
      map['trip_item_id'] = Variable<String>(tripItemId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SharedExpensesCompanion toCompanion(bool nullToAbsent) {
    return SharedExpensesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      dateEpochDay: Value(dateEpochDay),
      title: Value(title),
      categoryKey: Value(categoryKey),
      type: Value(type),
      amountCents: Value(amountCents),
      currency: Value(currency),
      rate: Value(rate),
      amountForeignCents: amountForeignCents == null && nullToAbsent
          ? const Value.absent()
          : Value(amountForeignCents),
      payersJson: Value(payersJson),
      sharesJson: Value(sharesJson),
      shareMode: Value(shareMode),
      portionsJson: portionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(portionsJson),
      note: Value(note),
      settledRoundId: settledRoundId == null && nullToAbsent
          ? const Value.absent()
          : Value(settledRoundId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      tripItemId: tripItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripItemId),
      createdAt: Value(createdAt),
    );
  }

  factory SharedExpense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedExpense(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      dateEpochDay: serializer.fromJson<int>(json['dateEpochDay']),
      title: serializer.fromJson<String>(json['title']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      type: serializer.fromJson<String>(json['type']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      currency: serializer.fromJson<String>(json['currency']),
      rate: serializer.fromJson<double>(json['rate']),
      amountForeignCents: serializer.fromJson<int?>(json['amountForeignCents']),
      payersJson: serializer.fromJson<String>(json['payersJson']),
      sharesJson: serializer.fromJson<String>(json['sharesJson']),
      shareMode: serializer.fromJson<String>(json['shareMode']),
      portionsJson: serializer.fromJson<String?>(json['portionsJson']),
      note: serializer.fromJson<String>(json['note']),
      settledRoundId: serializer.fromJson<String?>(json['settledRoundId']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      tripItemId: serializer.fromJson<String?>(json['tripItemId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'dateEpochDay': serializer.toJson<int>(dateEpochDay),
      'title': serializer.toJson<String>(title),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'type': serializer.toJson<String>(type),
      'amountCents': serializer.toJson<int>(amountCents),
      'currency': serializer.toJson<String>(currency),
      'rate': serializer.toJson<double>(rate),
      'amountForeignCents': serializer.toJson<int?>(amountForeignCents),
      'payersJson': serializer.toJson<String>(payersJson),
      'sharesJson': serializer.toJson<String>(sharesJson),
      'shareMode': serializer.toJson<String>(shareMode),
      'portionsJson': serializer.toJson<String?>(portionsJson),
      'note': serializer.toJson<String>(note),
      'settledRoundId': serializer.toJson<String?>(settledRoundId),
      'tripId': serializer.toJson<String?>(tripId),
      'tripItemId': serializer.toJson<String?>(tripItemId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SharedExpense copyWith({
    String? id,
    String? groupId,
    int? dateEpochDay,
    String? title,
    String? categoryKey,
    String? type,
    int? amountCents,
    String? currency,
    double? rate,
    Value<int?> amountForeignCents = const Value.absent(),
    String? payersJson,
    String? sharesJson,
    String? shareMode,
    Value<String?> portionsJson = const Value.absent(),
    String? note,
    Value<String?> settledRoundId = const Value.absent(),
    Value<String?> tripId = const Value.absent(),
    Value<String?> tripItemId = const Value.absent(),
    int? createdAt,
  }) => SharedExpense(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    dateEpochDay: dateEpochDay ?? this.dateEpochDay,
    title: title ?? this.title,
    categoryKey: categoryKey ?? this.categoryKey,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    currency: currency ?? this.currency,
    rate: rate ?? this.rate,
    amountForeignCents: amountForeignCents.present
        ? amountForeignCents.value
        : this.amountForeignCents,
    payersJson: payersJson ?? this.payersJson,
    sharesJson: sharesJson ?? this.sharesJson,
    shareMode: shareMode ?? this.shareMode,
    portionsJson: portionsJson.present ? portionsJson.value : this.portionsJson,
    note: note ?? this.note,
    settledRoundId: settledRoundId.present
        ? settledRoundId.value
        : this.settledRoundId,
    tripId: tripId.present ? tripId.value : this.tripId,
    tripItemId: tripItemId.present ? tripItemId.value : this.tripItemId,
    createdAt: createdAt ?? this.createdAt,
  );
  SharedExpense copyWithCompanion(SharedExpensesCompanion data) {
    return SharedExpense(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      dateEpochDay: data.dateEpochDay.present
          ? data.dateEpochDay.value
          : this.dateEpochDay,
      title: data.title.present ? data.title.value : this.title,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      type: data.type.present ? data.type.value : this.type,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      rate: data.rate.present ? data.rate.value : this.rate,
      amountForeignCents: data.amountForeignCents.present
          ? data.amountForeignCents.value
          : this.amountForeignCents,
      payersJson: data.payersJson.present
          ? data.payersJson.value
          : this.payersJson,
      sharesJson: data.sharesJson.present
          ? data.sharesJson.value
          : this.sharesJson,
      shareMode: data.shareMode.present ? data.shareMode.value : this.shareMode,
      portionsJson: data.portionsJson.present
          ? data.portionsJson.value
          : this.portionsJson,
      note: data.note.present ? data.note.value : this.note,
      settledRoundId: data.settledRoundId.present
          ? data.settledRoundId.value
          : this.settledRoundId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      tripItemId: data.tripItemId.present
          ? data.tripItemId.value
          : this.tripItemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedExpense(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('title: $title, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('amountForeignCents: $amountForeignCents, ')
          ..write('payersJson: $payersJson, ')
          ..write('sharesJson: $sharesJson, ')
          ..write('shareMode: $shareMode, ')
          ..write('portionsJson: $portionsJson, ')
          ..write('note: $note, ')
          ..write('settledRoundId: $settledRoundId, ')
          ..write('tripId: $tripId, ')
          ..write('tripItemId: $tripItemId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    dateEpochDay,
    title,
    categoryKey,
    type,
    amountCents,
    currency,
    rate,
    amountForeignCents,
    payersJson,
    sharesJson,
    shareMode,
    portionsJson,
    note,
    settledRoundId,
    tripId,
    tripItemId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedExpense &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.dateEpochDay == this.dateEpochDay &&
          other.title == this.title &&
          other.categoryKey == this.categoryKey &&
          other.type == this.type &&
          other.amountCents == this.amountCents &&
          other.currency == this.currency &&
          other.rate == this.rate &&
          other.amountForeignCents == this.amountForeignCents &&
          other.payersJson == this.payersJson &&
          other.sharesJson == this.sharesJson &&
          other.shareMode == this.shareMode &&
          other.portionsJson == this.portionsJson &&
          other.note == this.note &&
          other.settledRoundId == this.settledRoundId &&
          other.tripId == this.tripId &&
          other.tripItemId == this.tripItemId &&
          other.createdAt == this.createdAt);
}

class SharedExpensesCompanion extends UpdateCompanion<SharedExpense> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> dateEpochDay;
  final Value<String> title;
  final Value<String> categoryKey;
  final Value<String> type;
  final Value<int> amountCents;
  final Value<String> currency;
  final Value<double> rate;
  final Value<int?> amountForeignCents;
  final Value<String> payersJson;
  final Value<String> sharesJson;
  final Value<String> shareMode;
  final Value<String?> portionsJson;
  final Value<String> note;
  final Value<String?> settledRoundId;
  final Value<String?> tripId;
  final Value<String?> tripItemId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SharedExpensesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.dateEpochDay = const Value.absent(),
    this.title = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.type = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.amountForeignCents = const Value.absent(),
    this.payersJson = const Value.absent(),
    this.sharesJson = const Value.absent(),
    this.shareMode = const Value.absent(),
    this.portionsJson = const Value.absent(),
    this.note = const Value.absent(),
    this.settledRoundId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.tripItemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedExpensesCompanion.insert({
    required String id,
    required String groupId,
    this.dateEpochDay = const Value.absent(),
    this.title = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.type = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.amountForeignCents = const Value.absent(),
    this.payersJson = const Value.absent(),
    this.sharesJson = const Value.absent(),
    this.shareMode = const Value.absent(),
    this.portionsJson = const Value.absent(),
    this.note = const Value.absent(),
    this.settledRoundId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.tripItemId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       createdAt = Value(createdAt);
  static Insertable<SharedExpense> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? dateEpochDay,
    Expression<String>? title,
    Expression<String>? categoryKey,
    Expression<String>? type,
    Expression<int>? amountCents,
    Expression<String>? currency,
    Expression<double>? rate,
    Expression<int>? amountForeignCents,
    Expression<String>? payersJson,
    Expression<String>? sharesJson,
    Expression<String>? shareMode,
    Expression<String>? portionsJson,
    Expression<String>? note,
    Expression<String>? settledRoundId,
    Expression<String>? tripId,
    Expression<String>? tripItemId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (dateEpochDay != null) 'date_epoch_day': dateEpochDay,
      if (title != null) 'title': title,
      if (categoryKey != null) 'category_key': categoryKey,
      if (type != null) 'type': type,
      if (amountCents != null) 'amount_cents': amountCents,
      if (currency != null) 'currency': currency,
      if (rate != null) 'rate': rate,
      if (amountForeignCents != null)
        'amount_foreign_cents': amountForeignCents,
      if (payersJson != null) 'payers_json': payersJson,
      if (sharesJson != null) 'shares_json': sharesJson,
      if (shareMode != null) 'share_mode': shareMode,
      if (portionsJson != null) 'portions_json': portionsJson,
      if (note != null) 'note': note,
      if (settledRoundId != null) 'settled_round_id': settledRoundId,
      if (tripId != null) 'trip_id': tripId,
      if (tripItemId != null) 'trip_item_id': tripItemId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int>? dateEpochDay,
    Value<String>? title,
    Value<String>? categoryKey,
    Value<String>? type,
    Value<int>? amountCents,
    Value<String>? currency,
    Value<double>? rate,
    Value<int?>? amountForeignCents,
    Value<String>? payersJson,
    Value<String>? sharesJson,
    Value<String>? shareMode,
    Value<String?>? portionsJson,
    Value<String>? note,
    Value<String?>? settledRoundId,
    Value<String?>? tripId,
    Value<String?>? tripItemId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SharedExpensesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      dateEpochDay: dateEpochDay ?? this.dateEpochDay,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      rate: rate ?? this.rate,
      amountForeignCents: amountForeignCents ?? this.amountForeignCents,
      payersJson: payersJson ?? this.payersJson,
      sharesJson: sharesJson ?? this.sharesJson,
      shareMode: shareMode ?? this.shareMode,
      portionsJson: portionsJson ?? this.portionsJson,
      note: note ?? this.note,
      settledRoundId: settledRoundId ?? this.settledRoundId,
      tripId: tripId ?? this.tripId,
      tripItemId: tripItemId ?? this.tripItemId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (dateEpochDay.present) {
      map['date_epoch_day'] = Variable<int>(dateEpochDay.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (amountForeignCents.present) {
      map['amount_foreign_cents'] = Variable<int>(amountForeignCents.value);
    }
    if (payersJson.present) {
      map['payers_json'] = Variable<String>(payersJson.value);
    }
    if (sharesJson.present) {
      map['shares_json'] = Variable<String>(sharesJson.value);
    }
    if (shareMode.present) {
      map['share_mode'] = Variable<String>(shareMode.value);
    }
    if (portionsJson.present) {
      map['portions_json'] = Variable<String>(portionsJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (settledRoundId.present) {
      map['settled_round_id'] = Variable<String>(settledRoundId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (tripItemId.present) {
      map['trip_item_id'] = Variable<String>(tripItemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedExpensesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('title: $title, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('amountForeignCents: $amountForeignCents, ')
          ..write('payersJson: $payersJson, ')
          ..write('sharesJson: $sharesJson, ')
          ..write('shareMode: $shareMode, ')
          ..write('portionsJson: $portionsJson, ')
          ..write('note: $note, ')
          ..write('settledRoundId: $settledRoundId, ')
          ..write('tripId: $tripId, ')
          ..write('tripItemId: $tripItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedSettlementsTable extends SharedSettlements
    with TableInfo<$SharedSettlementsTable, SharedSettlement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedSettlementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("active"),
  );
  static const VerificationMeta _transfersJsonMeta = const VerificationMeta(
    'transfersJson',
  );
  @override
  late final GeneratedColumn<String> transfersJson = GeneratedColumn<String>(
    'transfers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _expenseIdsJsonMeta = const VerificationMeta(
    'expenseIdsJson',
  );
  @override
  late final GeneratedColumn<String> expenseIdsJson = GeneratedColumn<String>(
    'expense_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("[]"),
  );
  static const VerificationMeta _roundNoMeta = const VerificationMeta(
    'roundNo',
  );
  @override
  late final GeneratedColumn<int> roundNo = GeneratedColumn<int>(
    'round_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    status,
    transfersJson,
    expenseIdsJson,
    roundNo,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_settlements';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedSettlement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('transfers_json')) {
      context.handle(
        _transfersJsonMeta,
        transfersJson.isAcceptableOrUnknown(
          data['transfers_json']!,
          _transfersJsonMeta,
        ),
      );
    }
    if (data.containsKey('expense_ids_json')) {
      context.handle(
        _expenseIdsJsonMeta,
        expenseIdsJson.isAcceptableOrUnknown(
          data['expense_ids_json']!,
          _expenseIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('round_no')) {
      context.handle(
        _roundNoMeta,
        roundNo.isAcceptableOrUnknown(data['round_no']!, _roundNoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedSettlement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedSettlement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      transfersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfers_json'],
      )!,
      expenseIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_ids_json'],
      )!,
      roundNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_no'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $SharedSettlementsTable createAlias(String alias) {
    return $SharedSettlementsTable(attachedDatabase, alias);
  }
}

class SharedSettlement extends DataClass
    implements Insertable<SharedSettlement> {
  final String id;
  final String groupId;
  final String status;
  final String transfersJson;
  final String expenseIdsJson;
  final int roundNo;
  final int createdAt;
  final int? completedAt;
  const SharedSettlement({
    required this.id,
    required this.groupId,
    required this.status,
    required this.transfersJson,
    required this.expenseIdsJson,
    required this.roundNo,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['status'] = Variable<String>(status);
    map['transfers_json'] = Variable<String>(transfersJson);
    map['expense_ids_json'] = Variable<String>(expenseIdsJson);
    map['round_no'] = Variable<int>(roundNo);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  SharedSettlementsCompanion toCompanion(bool nullToAbsent) {
    return SharedSettlementsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      status: Value(status),
      transfersJson: Value(transfersJson),
      expenseIdsJson: Value(expenseIdsJson),
      roundNo: Value(roundNo),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory SharedSettlement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedSettlement(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      status: serializer.fromJson<String>(json['status']),
      transfersJson: serializer.fromJson<String>(json['transfersJson']),
      expenseIdsJson: serializer.fromJson<String>(json['expenseIdsJson']),
      roundNo: serializer.fromJson<int>(json['roundNo']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'status': serializer.toJson<String>(status),
      'transfersJson': serializer.toJson<String>(transfersJson),
      'expenseIdsJson': serializer.toJson<String>(expenseIdsJson),
      'roundNo': serializer.toJson<int>(roundNo),
      'createdAt': serializer.toJson<int>(createdAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  SharedSettlement copyWith({
    String? id,
    String? groupId,
    String? status,
    String? transfersJson,
    String? expenseIdsJson,
    int? roundNo,
    int? createdAt,
    Value<int?> completedAt = const Value.absent(),
  }) => SharedSettlement(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    status: status ?? this.status,
    transfersJson: transfersJson ?? this.transfersJson,
    expenseIdsJson: expenseIdsJson ?? this.expenseIdsJson,
    roundNo: roundNo ?? this.roundNo,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  SharedSettlement copyWithCompanion(SharedSettlementsCompanion data) {
    return SharedSettlement(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      status: data.status.present ? data.status.value : this.status,
      transfersJson: data.transfersJson.present
          ? data.transfersJson.value
          : this.transfersJson,
      expenseIdsJson: data.expenseIdsJson.present
          ? data.expenseIdsJson.value
          : this.expenseIdsJson,
      roundNo: data.roundNo.present ? data.roundNo.value : this.roundNo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedSettlement(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('transfersJson: $transfersJson, ')
          ..write('expenseIdsJson: $expenseIdsJson, ')
          ..write('roundNo: $roundNo, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    status,
    transfersJson,
    expenseIdsJson,
    roundNo,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedSettlement &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.status == this.status &&
          other.transfersJson == this.transfersJson &&
          other.expenseIdsJson == this.expenseIdsJson &&
          other.roundNo == this.roundNo &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class SharedSettlementsCompanion extends UpdateCompanion<SharedSettlement> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> status;
  final Value<String> transfersJson;
  final Value<String> expenseIdsJson;
  final Value<int> roundNo;
  final Value<int> createdAt;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const SharedSettlementsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.status = const Value.absent(),
    this.transfersJson = const Value.absent(),
    this.expenseIdsJson = const Value.absent(),
    this.roundNo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedSettlementsCompanion.insert({
    required String id,
    required String groupId,
    this.status = const Value.absent(),
    this.transfersJson = const Value.absent(),
    this.expenseIdsJson = const Value.absent(),
    this.roundNo = const Value.absent(),
    required int createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       createdAt = Value(createdAt);
  static Insertable<SharedSettlement> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? status,
    Expression<String>? transfersJson,
    Expression<String>? expenseIdsJson,
    Expression<int>? roundNo,
    Expression<int>? createdAt,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (status != null) 'status': status,
      if (transfersJson != null) 'transfers_json': transfersJson,
      if (expenseIdsJson != null) 'expense_ids_json': expenseIdsJson,
      if (roundNo != null) 'round_no': roundNo,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedSettlementsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? status,
    Value<String>? transfersJson,
    Value<String>? expenseIdsJson,
    Value<int>? roundNo,
    Value<int>? createdAt,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return SharedSettlementsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      transfersJson: transfersJson ?? this.transfersJson,
      expenseIdsJson: expenseIdsJson ?? this.expenseIdsJson,
      roundNo: roundNo ?? this.roundNo,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (transfersJson.present) {
      map['transfers_json'] = Variable<String>(transfersJson.value);
    }
    if (expenseIdsJson.present) {
      map['expense_ids_json'] = Variable<String>(expenseIdsJson.value);
    }
    if (roundNo.present) {
      map['round_no'] = Variable<int>(roundNo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedSettlementsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('transfersJson: $transfersJson, ')
          ..write('expenseIdsJson: $expenseIdsJson, ')
          ..write('roundNo: $roundNo, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TravelSpacesTable extends TravelSpaces
    with TableInfo<$TravelSpacesTable, TravelSpace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelSpacesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("active"),
  );
  static const VerificationMeta _createdMsMeta = const VerificationMeta(
    'createdMs',
  );
  @override
  late final GeneratedColumn<int> createdMs = GeneratedColumn<int>(
    'created_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMsMeta = const VerificationMeta(
    'deletedMs',
  );
  @override
  late final GeneratedColumn<int> deletedMs = GeneratedColumn<int>(
    'deleted_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    tripId,
    groupId,
    createdBy,
    note,
    status,
    createdMs,
    updatedMs,
    deletedMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_spaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<TravelSpace> instance, {
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
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_ms')) {
      context.handle(
        _createdMsMeta,
        createdMs.isAcceptableOrUnknown(data['created_ms']!, _createdMsMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMsMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    if (data.containsKey('deleted_ms')) {
      context.handle(
        _deletedMsMeta,
        deletedMs.isAcceptableOrUnknown(data['deleted_ms']!, _deletedMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TravelSpace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TravelSpace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_ms'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
      deletedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_ms'],
      ),
    );
  }

  @override
  $TravelSpacesTable createAlias(String alias) {
    return $TravelSpacesTable(attachedDatabase, alias);
  }
}

class TravelSpace extends DataClass implements Insertable<TravelSpace> {
  final String id;
  final String name;
  final String? tripId;
  final String? groupId;
  final String createdBy;
  final String? note;
  final String status;
  final int createdMs;
  final int updatedMs;
  final int? deletedMs;
  const TravelSpace({
    required this.id,
    required this.name,
    this.tripId,
    this.groupId,
    required this.createdBy,
    this.note,
    required this.status,
    required this.createdMs,
    required this.updatedMs,
    this.deletedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['status'] = Variable<String>(status);
    map['created_ms'] = Variable<int>(createdMs);
    map['updated_ms'] = Variable<int>(updatedMs);
    if (!nullToAbsent || deletedMs != null) {
      map['deleted_ms'] = Variable<int>(deletedMs);
    }
    return map;
  }

  TravelSpacesCompanion toCompanion(bool nullToAbsent) {
    return TravelSpacesCompanion(
      id: Value(id),
      name: Value(name),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      createdBy: Value(createdBy),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      status: Value(status),
      createdMs: Value(createdMs),
      updatedMs: Value(updatedMs),
      deletedMs: deletedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedMs),
    );
  }

  factory TravelSpace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TravelSpace(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      note: serializer.fromJson<String?>(json['note']),
      status: serializer.fromJson<String>(json['status']),
      createdMs: serializer.fromJson<int>(json['createdMs']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
      deletedMs: serializer.fromJson<int?>(json['deletedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tripId': serializer.toJson<String?>(tripId),
      'groupId': serializer.toJson<String?>(groupId),
      'createdBy': serializer.toJson<String>(createdBy),
      'note': serializer.toJson<String?>(note),
      'status': serializer.toJson<String>(status),
      'createdMs': serializer.toJson<int>(createdMs),
      'updatedMs': serializer.toJson<int>(updatedMs),
      'deletedMs': serializer.toJson<int?>(deletedMs),
    };
  }

  TravelSpace copyWith({
    String? id,
    String? name,
    Value<String?> tripId = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    String? createdBy,
    Value<String?> note = const Value.absent(),
    String? status,
    int? createdMs,
    int? updatedMs,
    Value<int?> deletedMs = const Value.absent(),
  }) => TravelSpace(
    id: id ?? this.id,
    name: name ?? this.name,
    tripId: tripId.present ? tripId.value : this.tripId,
    groupId: groupId.present ? groupId.value : this.groupId,
    createdBy: createdBy ?? this.createdBy,
    note: note.present ? note.value : this.note,
    status: status ?? this.status,
    createdMs: createdMs ?? this.createdMs,
    updatedMs: updatedMs ?? this.updatedMs,
    deletedMs: deletedMs.present ? deletedMs.value : this.deletedMs,
  );
  TravelSpace copyWithCompanion(TravelSpacesCompanion data) {
    return TravelSpace(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      createdMs: data.createdMs.present ? data.createdMs.value : this.createdMs,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
      deletedMs: data.deletedMs.present ? data.deletedMs.value : this.deletedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TravelSpace(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tripId: $tripId, ')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deletedMs: $deletedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    tripId,
    groupId,
    createdBy,
    note,
    status,
    createdMs,
    updatedMs,
    deletedMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TravelSpace &&
          other.id == this.id &&
          other.name == this.name &&
          other.tripId == this.tripId &&
          other.groupId == this.groupId &&
          other.createdBy == this.createdBy &&
          other.note == this.note &&
          other.status == this.status &&
          other.createdMs == this.createdMs &&
          other.updatedMs == this.updatedMs &&
          other.deletedMs == this.deletedMs);
}

class TravelSpacesCompanion extends UpdateCompanion<TravelSpace> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> tripId;
  final Value<String?> groupId;
  final Value<String> createdBy;
  final Value<String?> note;
  final Value<String> status;
  final Value<int> createdMs;
  final Value<int> updatedMs;
  final Value<int?> deletedMs;
  final Value<int> rowid;
  const TravelSpacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tripId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.createdMs = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.deletedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TravelSpacesCompanion.insert({
    required String id,
    required String name,
    this.tripId = const Value.absent(),
    this.groupId = const Value.absent(),
    required String createdBy,
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    required int createdMs,
    required int updatedMs,
    this.deletedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdBy = Value(createdBy),
       createdMs = Value(createdMs),
       updatedMs = Value(updatedMs);
  static Insertable<TravelSpace> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tripId,
    Expression<String>? groupId,
    Expression<String>? createdBy,
    Expression<String>? note,
    Expression<String>? status,
    Expression<int>? createdMs,
    Expression<int>? updatedMs,
    Expression<int>? deletedMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tripId != null) 'trip_id': tripId,
      if (groupId != null) 'group_id': groupId,
      if (createdBy != null) 'created_by': createdBy,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (createdMs != null) 'created_ms': createdMs,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (deletedMs != null) 'deleted_ms': deletedMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TravelSpacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? tripId,
    Value<String?>? groupId,
    Value<String>? createdBy,
    Value<String?>? note,
    Value<String>? status,
    Value<int>? createdMs,
    Value<int>? updatedMs,
    Value<int?>? deletedMs,
    Value<int>? rowid,
  }) {
    return TravelSpacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      note: note ?? this.note,
      status: status ?? this.status,
      createdMs: createdMs ?? this.createdMs,
      updatedMs: updatedMs ?? this.updatedMs,
      deletedMs: deletedMs ?? this.deletedMs,
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
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdMs.present) {
      map['created_ms'] = Variable<int>(createdMs.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (deletedMs.present) {
      map['deleted_ms'] = Variable<int>(deletedMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelSpacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tripId: $tripId, ')
          ..write('groupId: $groupId, ')
          ..write('createdBy: $createdBy, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deletedMs: $deletedMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpaceMembersTable extends SpaceMembers
    with TableInfo<$SpaceMembersTable, SpaceMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpaceMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
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
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("viewer"),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("旅伴"),
  );
  static const VerificationMeta _joinedMsMeta = const VerificationMeta(
    'joinedMs',
  );
  @override
  late final GeneratedColumn<int> joinedMs = GeneratedColumn<int>(
    'joined_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMsMeta = const VerificationMeta(
    'createdMs',
  );
  @override
  late final GeneratedColumn<int> createdMs = GeneratedColumn<int>(
    'created_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMsMeta = const VerificationMeta(
    'deletedMs',
  );
  @override
  late final GeneratedColumn<int> deletedMs = GeneratedColumn<int>(
    'deleted_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    userId,
    role,
    displayName,
    joinedMs,
    createdMs,
    updatedMs,
    deletedMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpaceMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('joined_ms')) {
      context.handle(
        _joinedMsMeta,
        joinedMs.isAcceptableOrUnknown(data['joined_ms']!, _joinedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedMsMeta);
    }
    if (data.containsKey('created_ms')) {
      context.handle(
        _createdMsMeta,
        createdMs.isAcceptableOrUnknown(data['created_ms']!, _createdMsMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMsMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    if (data.containsKey('deleted_ms')) {
      context.handle(
        _deletedMsMeta,
        deletedMs.isAcceptableOrUnknown(data['deleted_ms']!, _deletedMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpaceMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      joinedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}joined_ms'],
      )!,
      createdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_ms'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
      deletedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_ms'],
      ),
    );
  }

  @override
  $SpaceMembersTable createAlias(String alias) {
    return $SpaceMembersTable(attachedDatabase, alias);
  }
}

class SpaceMember extends DataClass implements Insertable<SpaceMember> {
  final String id;
  final String spaceId;
  final String userId;
  final String role;
  final String displayName;
  final int joinedMs;
  final int createdMs;
  final int updatedMs;
  final int? deletedMs;
  const SpaceMember({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.role,
    required this.displayName,
    required this.joinedMs,
    required this.createdMs,
    required this.updatedMs,
    this.deletedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    map['display_name'] = Variable<String>(displayName);
    map['joined_ms'] = Variable<int>(joinedMs);
    map['created_ms'] = Variable<int>(createdMs);
    map['updated_ms'] = Variable<int>(updatedMs);
    if (!nullToAbsent || deletedMs != null) {
      map['deleted_ms'] = Variable<int>(deletedMs);
    }
    return map;
  }

  SpaceMembersCompanion toCompanion(bool nullToAbsent) {
    return SpaceMembersCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      userId: Value(userId),
      role: Value(role),
      displayName: Value(displayName),
      joinedMs: Value(joinedMs),
      createdMs: Value(createdMs),
      updatedMs: Value(updatedMs),
      deletedMs: deletedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedMs),
    );
  }

  factory SpaceMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceMember(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      displayName: serializer.fromJson<String>(json['displayName']),
      joinedMs: serializer.fromJson<int>(json['joinedMs']),
      createdMs: serializer.fromJson<int>(json['createdMs']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
      deletedMs: serializer.fromJson<int?>(json['deletedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'displayName': serializer.toJson<String>(displayName),
      'joinedMs': serializer.toJson<int>(joinedMs),
      'createdMs': serializer.toJson<int>(createdMs),
      'updatedMs': serializer.toJson<int>(updatedMs),
      'deletedMs': serializer.toJson<int?>(deletedMs),
    };
  }

  SpaceMember copyWith({
    String? id,
    String? spaceId,
    String? userId,
    String? role,
    String? displayName,
    int? joinedMs,
    int? createdMs,
    int? updatedMs,
    Value<int?> deletedMs = const Value.absent(),
  }) => SpaceMember(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    displayName: displayName ?? this.displayName,
    joinedMs: joinedMs ?? this.joinedMs,
    createdMs: createdMs ?? this.createdMs,
    updatedMs: updatedMs ?? this.updatedMs,
    deletedMs: deletedMs.present ? deletedMs.value : this.deletedMs,
  );
  SpaceMember copyWithCompanion(SpaceMembersCompanion data) {
    return SpaceMember(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      joinedMs: data.joinedMs.present ? data.joinedMs.value : this.joinedMs,
      createdMs: data.createdMs.present ? data.createdMs.value : this.createdMs,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
      deletedMs: data.deletedMs.present ? data.deletedMs.value : this.deletedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMember(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('joinedMs: $joinedMs, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deletedMs: $deletedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    userId,
    role,
    displayName,
    joinedMs,
    createdMs,
    updatedMs,
    deletedMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceMember &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.displayName == this.displayName &&
          other.joinedMs == this.joinedMs &&
          other.createdMs == this.createdMs &&
          other.updatedMs == this.updatedMs &&
          other.deletedMs == this.deletedMs);
}

class SpaceMembersCompanion extends UpdateCompanion<SpaceMember> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> userId;
  final Value<String> role;
  final Value<String> displayName;
  final Value<int> joinedMs;
  final Value<int> createdMs;
  final Value<int> updatedMs;
  final Value<int?> deletedMs;
  final Value<int> rowid;
  const SpaceMembersCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.displayName = const Value.absent(),
    this.joinedMs = const Value.absent(),
    this.createdMs = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.deletedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceMembersCompanion.insert({
    required String id,
    required String spaceId,
    required String userId,
    this.role = const Value.absent(),
    this.displayName = const Value.absent(),
    required int joinedMs,
    required int createdMs,
    required int updatedMs,
    this.deletedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       userId = Value(userId),
       joinedMs = Value(joinedMs),
       createdMs = Value(createdMs),
       updatedMs = Value(updatedMs);
  static Insertable<SpaceMember> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<String>? displayName,
    Expression<int>? joinedMs,
    Expression<int>? createdMs,
    Expression<int>? updatedMs,
    Expression<int>? deletedMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (displayName != null) 'display_name': displayName,
      if (joinedMs != null) 'joined_ms': joinedMs,
      if (createdMs != null) 'created_ms': createdMs,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (deletedMs != null) 'deleted_ms': deletedMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? userId,
    Value<String>? role,
    Value<String>? displayName,
    Value<int>? joinedMs,
    Value<int>? createdMs,
    Value<int>? updatedMs,
    Value<int?>? deletedMs,
    Value<int>? rowid,
  }) {
    return SpaceMembersCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      joinedMs: joinedMs ?? this.joinedMs,
      createdMs: createdMs ?? this.createdMs,
      updatedMs: updatedMs ?? this.updatedMs,
      deletedMs: deletedMs ?? this.deletedMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (joinedMs.present) {
      map['joined_ms'] = Variable<int>(joinedMs.value);
    }
    if (createdMs.present) {
      map['created_ms'] = Variable<int>(createdMs.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (deletedMs.present) {
      map['deleted_ms'] = Variable<int>(deletedMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMembersCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('joinedMs: $joinedMs, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('deletedMs: $deletedMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpaceEventsTable extends SpaceEvents
    with TableInfo<$SpaceEventsTable, SpaceEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpaceEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserMeta = const VerificationMeta(
    'actorUser',
  );
  @override
  late final GeneratedColumn<String> actorUser = GeneratedColumn<String>(
    'actor_user',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKindMeta = const VerificationMeta(
    'entityKind',
  );
  @override
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _createdMsMeta = const VerificationMeta(
    'createdMs',
  );
  @override
  late final GeneratedColumn<int> createdMs = GeneratedColumn<int>(
    'created_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    actorUser,
    action,
    entityKind,
    entityId,
    summary,
    createdMs,
    updatedMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpaceEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('actor_user')) {
      context.handle(
        _actorUserMeta,
        actorUser.isAcceptableOrUnknown(data['actor_user']!, _actorUserMeta),
      );
    } else if (isInserting) {
      context.missing(_actorUserMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
        _entityKindMeta,
        entityKind.isAcceptableOrUnknown(data['entity_kind']!, _entityKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('created_ms')) {
      context.handle(
        _createdMsMeta,
        createdMs.isAcceptableOrUnknown(data['created_ms']!, _createdMsMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMsMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpaceEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      actorUser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      createdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_ms'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
    );
  }

  @override
  $SpaceEventsTable createAlias(String alias) {
    return $SpaceEventsTable(attachedDatabase, alias);
  }
}

class SpaceEvent extends DataClass implements Insertable<SpaceEvent> {
  final String id;
  final String spaceId;
  final String actorUser;
  final String action;
  final String entityKind;
  final String? entityId;
  final String summary;
  final int createdMs;
  final int updatedMs;
  const SpaceEvent({
    required this.id,
    required this.spaceId,
    required this.actorUser,
    required this.action,
    required this.entityKind,
    this.entityId,
    required this.summary,
    required this.createdMs,
    required this.updatedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['actor_user'] = Variable<String>(actorUser);
    map['action'] = Variable<String>(action);
    map['entity_kind'] = Variable<String>(entityKind);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    map['summary'] = Variable<String>(summary);
    map['created_ms'] = Variable<int>(createdMs);
    map['updated_ms'] = Variable<int>(updatedMs);
    return map;
  }

  SpaceEventsCompanion toCompanion(bool nullToAbsent) {
    return SpaceEventsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      actorUser: Value(actorUser),
      action: Value(action),
      entityKind: Value(entityKind),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      summary: Value(summary),
      createdMs: Value(createdMs),
      updatedMs: Value(updatedMs),
    );
  }

  factory SpaceEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceEvent(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      actorUser: serializer.fromJson<String>(json['actorUser']),
      action: serializer.fromJson<String>(json['action']),
      entityKind: serializer.fromJson<String>(json['entityKind']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      summary: serializer.fromJson<String>(json['summary']),
      createdMs: serializer.fromJson<int>(json['createdMs']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'actorUser': serializer.toJson<String>(actorUser),
      'action': serializer.toJson<String>(action),
      'entityKind': serializer.toJson<String>(entityKind),
      'entityId': serializer.toJson<String?>(entityId),
      'summary': serializer.toJson<String>(summary),
      'createdMs': serializer.toJson<int>(createdMs),
      'updatedMs': serializer.toJson<int>(updatedMs),
    };
  }

  SpaceEvent copyWith({
    String? id,
    String? spaceId,
    String? actorUser,
    String? action,
    String? entityKind,
    Value<String?> entityId = const Value.absent(),
    String? summary,
    int? createdMs,
    int? updatedMs,
  }) => SpaceEvent(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    actorUser: actorUser ?? this.actorUser,
    action: action ?? this.action,
    entityKind: entityKind ?? this.entityKind,
    entityId: entityId.present ? entityId.value : this.entityId,
    summary: summary ?? this.summary,
    createdMs: createdMs ?? this.createdMs,
    updatedMs: updatedMs ?? this.updatedMs,
  );
  SpaceEvent copyWithCompanion(SpaceEventsCompanion data) {
    return SpaceEvent(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      actorUser: data.actorUser.present ? data.actorUser.value : this.actorUser,
      action: data.action.present ? data.action.value : this.action,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      summary: data.summary.present ? data.summary.value : this.summary,
      createdMs: data.createdMs.present ? data.createdMs.value : this.createdMs,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceEvent(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('actorUser: $actorUser, ')
          ..write('action: $action, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('summary: $summary, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    actorUser,
    action,
    entityKind,
    entityId,
    summary,
    createdMs,
    updatedMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceEvent &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.actorUser == this.actorUser &&
          other.action == this.action &&
          other.entityKind == this.entityKind &&
          other.entityId == this.entityId &&
          other.summary == this.summary &&
          other.createdMs == this.createdMs &&
          other.updatedMs == this.updatedMs);
}

class SpaceEventsCompanion extends UpdateCompanion<SpaceEvent> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> actorUser;
  final Value<String> action;
  final Value<String> entityKind;
  final Value<String?> entityId;
  final Value<String> summary;
  final Value<int> createdMs;
  final Value<int> updatedMs;
  final Value<int> rowid;
  const SpaceEventsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.actorUser = const Value.absent(),
    this.action = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.summary = const Value.absent(),
    this.createdMs = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceEventsCompanion.insert({
    required String id,
    required String spaceId,
    required String actorUser,
    required String action,
    required String entityKind,
    this.entityId = const Value.absent(),
    this.summary = const Value.absent(),
    required int createdMs,
    required int updatedMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       actorUser = Value(actorUser),
       action = Value(action),
       entityKind = Value(entityKind),
       createdMs = Value(createdMs),
       updatedMs = Value(updatedMs);
  static Insertable<SpaceEvent> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? actorUser,
    Expression<String>? action,
    Expression<String>? entityKind,
    Expression<String>? entityId,
    Expression<String>? summary,
    Expression<int>? createdMs,
    Expression<int>? updatedMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (actorUser != null) 'actor_user': actorUser,
      if (action != null) 'action': action,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityId != null) 'entity_id': entityId,
      if (summary != null) 'summary': summary,
      if (createdMs != null) 'created_ms': createdMs,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? actorUser,
    Value<String>? action,
    Value<String>? entityKind,
    Value<String?>? entityId,
    Value<String>? summary,
    Value<int>? createdMs,
    Value<int>? updatedMs,
    Value<int>? rowid,
  }) {
    return SpaceEventsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      actorUser: actorUser ?? this.actorUser,
      action: action ?? this.action,
      entityKind: entityKind ?? this.entityKind,
      entityId: entityId ?? this.entityId,
      summary: summary ?? this.summary,
      createdMs: createdMs ?? this.createdMs,
      updatedMs: updatedMs ?? this.updatedMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (actorUser.present) {
      map['actor_user'] = Variable<String>(actorUser.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (createdMs.present) {
      map['created_ms'] = Variable<int>(createdMs.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceEventsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('actorUser: $actorUser, ')
          ..write('action: $action, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('summary: $summary, ')
          ..write('createdMs: $createdMs, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedTripsTable extends SharedTrips
    with TableInfo<$SharedTripsTable, SharedTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedTripsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("✈️"),
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("ocean"),
  );
  static const VerificationMeta _startEpochDayMeta = const VerificationMeta(
    'startEpochDay',
  );
  @override
  late final GeneratedColumn<int> startEpochDay = GeneratedColumn<int>(
    'start_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _endEpochDayMeta = const VerificationMeta(
    'endEpochDay',
  );
  @override
  late final GeneratedColumn<int> endEpochDay = GeneratedColumn<int>(
    'end_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _paceMeta = const VerificationMeta('pace');
  @override
  late final GeneratedColumn<String> pace = GeneratedColumn<String>(
    'pace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("standard"),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    destination,
    emoji,
    cover,
    startEpochDay,
    endEpochDay,
    note,
    groupId,
    archived,
    pace,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedTrip> instance, {
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
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('start_epoch_day')) {
      context.handle(
        _startEpochDayMeta,
        startEpochDay.isAcceptableOrUnknown(
          data['start_epoch_day']!,
          _startEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('end_epoch_day')) {
      context.handle(
        _endEpochDayMeta,
        endEpochDay.isAcceptableOrUnknown(
          data['end_epoch_day']!,
          _endEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('pace')) {
      context.handle(
        _paceMeta,
        pace.isAcceptableOrUnknown(data['pace']!, _paceMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedTrip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      )!,
      startEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_epoch_day'],
      )!,
      endEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_epoch_day'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      pace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharedTripsTable createAlias(String alias) {
    return $SharedTripsTable(attachedDatabase, alias);
  }
}

class SharedTrip extends DataClass implements Insertable<SharedTrip> {
  final String id;
  final String name;
  final String destination;
  final String emoji;
  final String cover;
  final int startEpochDay;
  final int endEpochDay;
  final String note;
  final String? groupId;
  final bool archived;
  final String pace;
  final int createdAt;
  final int updatedAt;
  const SharedTrip({
    required this.id,
    required this.name,
    required this.destination,
    required this.emoji,
    required this.cover,
    required this.startEpochDay,
    required this.endEpochDay,
    required this.note,
    this.groupId,
    required this.archived,
    required this.pace,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['destination'] = Variable<String>(destination);
    map['emoji'] = Variable<String>(emoji);
    map['cover'] = Variable<String>(cover);
    map['start_epoch_day'] = Variable<int>(startEpochDay);
    map['end_epoch_day'] = Variable<int>(endEpochDay);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['archived'] = Variable<bool>(archived);
    map['pace'] = Variable<String>(pace);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SharedTripsCompanion toCompanion(bool nullToAbsent) {
    return SharedTripsCompanion(
      id: Value(id),
      name: Value(name),
      destination: Value(destination),
      emoji: Value(emoji),
      cover: Value(cover),
      startEpochDay: Value(startEpochDay),
      endEpochDay: Value(endEpochDay),
      note: Value(note),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      archived: Value(archived),
      pace: Value(pace),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedTrip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedTrip(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      destination: serializer.fromJson<String>(json['destination']),
      emoji: serializer.fromJson<String>(json['emoji']),
      cover: serializer.fromJson<String>(json['cover']),
      startEpochDay: serializer.fromJson<int>(json['startEpochDay']),
      endEpochDay: serializer.fromJson<int>(json['endEpochDay']),
      note: serializer.fromJson<String>(json['note']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      archived: serializer.fromJson<bool>(json['archived']),
      pace: serializer.fromJson<String>(json['pace']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'destination': serializer.toJson<String>(destination),
      'emoji': serializer.toJson<String>(emoji),
      'cover': serializer.toJson<String>(cover),
      'startEpochDay': serializer.toJson<int>(startEpochDay),
      'endEpochDay': serializer.toJson<int>(endEpochDay),
      'note': serializer.toJson<String>(note),
      'groupId': serializer.toJson<String?>(groupId),
      'archived': serializer.toJson<bool>(archived),
      'pace': serializer.toJson<String>(pace),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SharedTrip copyWith({
    String? id,
    String? name,
    String? destination,
    String? emoji,
    String? cover,
    int? startEpochDay,
    int? endEpochDay,
    String? note,
    Value<String?> groupId = const Value.absent(),
    bool? archived,
    String? pace,
    int? createdAt,
    int? updatedAt,
  }) => SharedTrip(
    id: id ?? this.id,
    name: name ?? this.name,
    destination: destination ?? this.destination,
    emoji: emoji ?? this.emoji,
    cover: cover ?? this.cover,
    startEpochDay: startEpochDay ?? this.startEpochDay,
    endEpochDay: endEpochDay ?? this.endEpochDay,
    note: note ?? this.note,
    groupId: groupId.present ? groupId.value : this.groupId,
    archived: archived ?? this.archived,
    pace: pace ?? this.pace,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharedTrip copyWithCompanion(SharedTripsCompanion data) {
    return SharedTrip(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      cover: data.cover.present ? data.cover.value : this.cover,
      startEpochDay: data.startEpochDay.present
          ? data.startEpochDay.value
          : this.startEpochDay,
      endEpochDay: data.endEpochDay.present
          ? data.endEpochDay.value
          : this.endEpochDay,
      note: data.note.present ? data.note.value : this.note,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      archived: data.archived.present ? data.archived.value : this.archived,
      pace: data.pace.present ? data.pace.value : this.pace,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedTrip(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('destination: $destination, ')
          ..write('emoji: $emoji, ')
          ..write('cover: $cover, ')
          ..write('startEpochDay: $startEpochDay, ')
          ..write('endEpochDay: $endEpochDay, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('archived: $archived, ')
          ..write('pace: $pace, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    destination,
    emoji,
    cover,
    startEpochDay,
    endEpochDay,
    note,
    groupId,
    archived,
    pace,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedTrip &&
          other.id == this.id &&
          other.name == this.name &&
          other.destination == this.destination &&
          other.emoji == this.emoji &&
          other.cover == this.cover &&
          other.startEpochDay == this.startEpochDay &&
          other.endEpochDay == this.endEpochDay &&
          other.note == this.note &&
          other.groupId == this.groupId &&
          other.archived == this.archived &&
          other.pace == this.pace &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SharedTripsCompanion extends UpdateCompanion<SharedTrip> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> destination;
  final Value<String> emoji;
  final Value<String> cover;
  final Value<int> startEpochDay;
  final Value<int> endEpochDay;
  final Value<String> note;
  final Value<String?> groupId;
  final Value<bool> archived;
  final Value<String> pace;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SharedTripsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.destination = const Value.absent(),
    this.emoji = const Value.absent(),
    this.cover = const Value.absent(),
    this.startEpochDay = const Value.absent(),
    this.endEpochDay = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.archived = const Value.absent(),
    this.pace = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedTripsCompanion.insert({
    required String id,
    required String name,
    this.destination = const Value.absent(),
    this.emoji = const Value.absent(),
    this.cover = const Value.absent(),
    this.startEpochDay = const Value.absent(),
    this.endEpochDay = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.archived = const Value.absent(),
    this.pace = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SharedTrip> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? destination,
    Expression<String>? emoji,
    Expression<String>? cover,
    Expression<int>? startEpochDay,
    Expression<int>? endEpochDay,
    Expression<String>? note,
    Expression<String>? groupId,
    Expression<bool>? archived,
    Expression<String>? pace,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (destination != null) 'destination': destination,
      if (emoji != null) 'emoji': emoji,
      if (cover != null) 'cover': cover,
      if (startEpochDay != null) 'start_epoch_day': startEpochDay,
      if (endEpochDay != null) 'end_epoch_day': endEpochDay,
      if (note != null) 'note': note,
      if (groupId != null) 'group_id': groupId,
      if (archived != null) 'archived': archived,
      if (pace != null) 'pace': pace,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedTripsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? destination,
    Value<String>? emoji,
    Value<String>? cover,
    Value<int>? startEpochDay,
    Value<int>? endEpochDay,
    Value<String>? note,
    Value<String?>? groupId,
    Value<bool>? archived,
    Value<String>? pace,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharedTripsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      emoji: emoji ?? this.emoji,
      cover: cover ?? this.cover,
      startEpochDay: startEpochDay ?? this.startEpochDay,
      endEpochDay: endEpochDay ?? this.endEpochDay,
      note: note ?? this.note,
      groupId: groupId ?? this.groupId,
      archived: archived ?? this.archived,
      pace: pace ?? this.pace,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (startEpochDay.present) {
      map['start_epoch_day'] = Variable<int>(startEpochDay.value);
    }
    if (endEpochDay.present) {
      map['end_epoch_day'] = Variable<int>(endEpochDay.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (pace.present) {
      map['pace'] = Variable<String>(pace.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedTripsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('destination: $destination, ')
          ..write('emoji: $emoji, ')
          ..write('cover: $cover, ')
          ..write('startEpochDay: $startEpochDay, ')
          ..write('endEpochDay: $endEpochDay, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('archived: $archived, ')
          ..write('pace: $pace, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedTripItemsTable extends SharedTripItems
    with TableInfo<$SharedTripItemsTable, SharedTripItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedTripItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateEpochDayMeta = const VerificationMeta(
    'dateEpochDay',
  );
  @override
  late final GeneratedColumn<int> dateEpochDay = GeneratedColumn<int>(
    'date_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("attraction"),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUriMeta = const VerificationMeta(
    'photoUri',
  );
  @override
  late final GeneratedColumn<String> photoUri = GeneratedColumn<String>(
    'photo_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMinMeta = const VerificationMeta(
    'startTimeMin',
  );
  @override
  late final GeneratedColumn<int> startTimeMin = GeneratedColumn<int>(
    'start_time_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costCentsMeta = const VerificationMeta(
    'costCents',
  );
  @override
  late final GeneratedColumn<int> costCents = GeneratedColumn<int>(
    'cost_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costCurrencyMeta = const VerificationMeta(
    'costCurrency',
  );
  @override
  late final GeneratedColumn<String> costCurrency = GeneratedColumn<String>(
    'cost_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("CNY"),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromNameMeta = const VerificationMeta(
    'fromName',
  );
  @override
  late final GeneratedColumn<String> fromName = GeneratedColumn<String>(
    'from_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromAddressMeta = const VerificationMeta(
    'fromAddress',
  );
  @override
  late final GeneratedColumn<String> fromAddress = GeneratedColumn<String>(
    'from_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _fromLatMeta = const VerificationMeta(
    'fromLat',
  );
  @override
  late final GeneratedColumn<double> fromLat = GeneratedColumn<double>(
    'from_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromLngMeta = const VerificationMeta(
    'fromLng',
  );
  @override
  late final GeneratedColumn<double> fromLng = GeneratedColumn<double>(
    'from_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toNameMeta = const VerificationMeta('toName');
  @override
  late final GeneratedColumn<String> toName = GeneratedColumn<String>(
    'to_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _toAddressMeta = const VerificationMeta(
    'toAddress',
  );
  @override
  late final GeneratedColumn<String> toAddress = GeneratedColumn<String>(
    'to_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _toLatMeta = const VerificationMeta('toLat');
  @override
  late final GeneratedColumn<double> toLat = GeneratedColumn<double>(
    'to_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLngMeta = const VerificationMeta('toLng');
  @override
  late final GeneratedColumn<double> toLng = GeneratedColumn<double>(
    'to_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flightNoMeta = const VerificationMeta(
    'flightNo',
  );
  @override
  late final GeneratedColumn<String> flightNo = GeneratedColumn<String>(
    'flight_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _guideRefMeta = const VerificationMeta(
    'guideRef',
  );
  @override
  late final GeneratedColumn<String> guideRef = GeneratedColumn<String>(
    'guide_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backupOfMeta = const VerificationMeta(
    'backupOf',
  );
  @override
  late final GeneratedColumn<String> backupOf = GeneratedColumn<String>(
    'backup_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    dateEpochDay,
    type,
    name,
    address,
    lat,
    lng,
    photoUri,
    startTimeMin,
    durationMin,
    costCents,
    costCurrency,
    note,
    fromName,
    fromAddress,
    fromLat,
    fromLng,
    toName,
    toAddress,
    toLat,
    toLng,
    flightNo,
    sortOrder,
    guideRef,
    backupOf,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_trip_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedTripItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('date_epoch_day')) {
      context.handle(
        _dateEpochDayMeta,
        dateEpochDay.isAcceptableOrUnknown(
          data['date_epoch_day']!,
          _dateEpochDayMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('photo_uri')) {
      context.handle(
        _photoUriMeta,
        photoUri.isAcceptableOrUnknown(data['photo_uri']!, _photoUriMeta),
      );
    }
    if (data.containsKey('start_time_min')) {
      context.handle(
        _startTimeMinMeta,
        startTimeMin.isAcceptableOrUnknown(
          data['start_time_min']!,
          _startTimeMinMeta,
        ),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('cost_cents')) {
      context.handle(
        _costCentsMeta,
        costCents.isAcceptableOrUnknown(data['cost_cents']!, _costCentsMeta),
      );
    }
    if (data.containsKey('cost_currency')) {
      context.handle(
        _costCurrencyMeta,
        costCurrency.isAcceptableOrUnknown(
          data['cost_currency']!,
          _costCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('from_name')) {
      context.handle(
        _fromNameMeta,
        fromName.isAcceptableOrUnknown(data['from_name']!, _fromNameMeta),
      );
    }
    if (data.containsKey('from_address')) {
      context.handle(
        _fromAddressMeta,
        fromAddress.isAcceptableOrUnknown(
          data['from_address']!,
          _fromAddressMeta,
        ),
      );
    }
    if (data.containsKey('from_lat')) {
      context.handle(
        _fromLatMeta,
        fromLat.isAcceptableOrUnknown(data['from_lat']!, _fromLatMeta),
      );
    }
    if (data.containsKey('from_lng')) {
      context.handle(
        _fromLngMeta,
        fromLng.isAcceptableOrUnknown(data['from_lng']!, _fromLngMeta),
      );
    }
    if (data.containsKey('to_name')) {
      context.handle(
        _toNameMeta,
        toName.isAcceptableOrUnknown(data['to_name']!, _toNameMeta),
      );
    }
    if (data.containsKey('to_address')) {
      context.handle(
        _toAddressMeta,
        toAddress.isAcceptableOrUnknown(data['to_address']!, _toAddressMeta),
      );
    }
    if (data.containsKey('to_lat')) {
      context.handle(
        _toLatMeta,
        toLat.isAcceptableOrUnknown(data['to_lat']!, _toLatMeta),
      );
    }
    if (data.containsKey('to_lng')) {
      context.handle(
        _toLngMeta,
        toLng.isAcceptableOrUnknown(data['to_lng']!, _toLngMeta),
      );
    }
    if (data.containsKey('flight_no')) {
      context.handle(
        _flightNoMeta,
        flightNo.isAcceptableOrUnknown(data['flight_no']!, _flightNoMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('guide_ref')) {
      context.handle(
        _guideRefMeta,
        guideRef.isAcceptableOrUnknown(data['guide_ref']!, _guideRefMeta),
      );
    }
    if (data.containsKey('backup_of')) {
      context.handle(
        _backupOfMeta,
        backupOf.isAcceptableOrUnknown(data['backup_of']!, _backupOfMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedTripItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedTripItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      dateEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_epoch_day'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      photoUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_uri'],
      ),
      startTimeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_min'],
      ),
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      costCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_cents'],
      ),
      costCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cost_currency'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      fromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_name'],
      )!,
      fromAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_address'],
      )!,
      fromLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lat'],
      ),
      fromLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lng'],
      ),
      toName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_name'],
      )!,
      toAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_address'],
      )!,
      toLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lat'],
      ),
      toLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lng'],
      ),
      flightNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flight_no'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      guideRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_ref'],
      ),
      backupOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_of'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharedTripItemsTable createAlias(String alias) {
    return $SharedTripItemsTable(attachedDatabase, alias);
  }
}

class SharedTripItem extends DataClass implements Insertable<SharedTripItem> {
  final String id;
  final String tripId;
  final int dateEpochDay;
  final String type;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? photoUri;
  final int? startTimeMin;
  final int? durationMin;
  final int? costCents;
  final String costCurrency;
  final String note;
  final String fromName;
  final String fromAddress;
  final double? fromLat;
  final double? fromLng;
  final String toName;
  final String toAddress;
  final double? toLat;
  final double? toLng;
  final String? flightNo;
  final int sortOrder;
  final String? guideRef;
  final String? backupOf;
  final int createdAt;
  final int updatedAt;
  const SharedTripItem({
    required this.id,
    required this.tripId,
    required this.dateEpochDay,
    required this.type,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.photoUri,
    this.startTimeMin,
    this.durationMin,
    this.costCents,
    required this.costCurrency,
    required this.note,
    required this.fromName,
    required this.fromAddress,
    this.fromLat,
    this.fromLng,
    required this.toName,
    required this.toAddress,
    this.toLat,
    this.toLng,
    this.flightNo,
    required this.sortOrder,
    this.guideRef,
    this.backupOf,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['date_epoch_day'] = Variable<int>(dateEpochDay);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || photoUri != null) {
      map['photo_uri'] = Variable<String>(photoUri);
    }
    if (!nullToAbsent || startTimeMin != null) {
      map['start_time_min'] = Variable<int>(startTimeMin);
    }
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || costCents != null) {
      map['cost_cents'] = Variable<int>(costCents);
    }
    map['cost_currency'] = Variable<String>(costCurrency);
    map['note'] = Variable<String>(note);
    map['from_name'] = Variable<String>(fromName);
    map['from_address'] = Variable<String>(fromAddress);
    if (!nullToAbsent || fromLat != null) {
      map['from_lat'] = Variable<double>(fromLat);
    }
    if (!nullToAbsent || fromLng != null) {
      map['from_lng'] = Variable<double>(fromLng);
    }
    map['to_name'] = Variable<String>(toName);
    map['to_address'] = Variable<String>(toAddress);
    if (!nullToAbsent || toLat != null) {
      map['to_lat'] = Variable<double>(toLat);
    }
    if (!nullToAbsent || toLng != null) {
      map['to_lng'] = Variable<double>(toLng);
    }
    if (!nullToAbsent || flightNo != null) {
      map['flight_no'] = Variable<String>(flightNo);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || guideRef != null) {
      map['guide_ref'] = Variable<String>(guideRef);
    }
    if (!nullToAbsent || backupOf != null) {
      map['backup_of'] = Variable<String>(backupOf);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SharedTripItemsCompanion toCompanion(bool nullToAbsent) {
    return SharedTripItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      dateEpochDay: Value(dateEpochDay),
      type: Value(type),
      name: Value(name),
      address: Value(address),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      photoUri: photoUri == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUri),
      startTimeMin: startTimeMin == null && nullToAbsent
          ? const Value.absent()
          : Value(startTimeMin),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      costCents: costCents == null && nullToAbsent
          ? const Value.absent()
          : Value(costCents),
      costCurrency: Value(costCurrency),
      note: Value(note),
      fromName: Value(fromName),
      fromAddress: Value(fromAddress),
      fromLat: fromLat == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLat),
      fromLng: fromLng == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLng),
      toName: Value(toName),
      toAddress: Value(toAddress),
      toLat: toLat == null && nullToAbsent
          ? const Value.absent()
          : Value(toLat),
      toLng: toLng == null && nullToAbsent
          ? const Value.absent()
          : Value(toLng),
      flightNo: flightNo == null && nullToAbsent
          ? const Value.absent()
          : Value(flightNo),
      sortOrder: Value(sortOrder),
      guideRef: guideRef == null && nullToAbsent
          ? const Value.absent()
          : Value(guideRef),
      backupOf: backupOf == null && nullToAbsent
          ? const Value.absent()
          : Value(backupOf),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedTripItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedTripItem(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      dateEpochDay: serializer.fromJson<int>(json['dateEpochDay']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      photoUri: serializer.fromJson<String?>(json['photoUri']),
      startTimeMin: serializer.fromJson<int?>(json['startTimeMin']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      costCents: serializer.fromJson<int?>(json['costCents']),
      costCurrency: serializer.fromJson<String>(json['costCurrency']),
      note: serializer.fromJson<String>(json['note']),
      fromName: serializer.fromJson<String>(json['fromName']),
      fromAddress: serializer.fromJson<String>(json['fromAddress']),
      fromLat: serializer.fromJson<double?>(json['fromLat']),
      fromLng: serializer.fromJson<double?>(json['fromLng']),
      toName: serializer.fromJson<String>(json['toName']),
      toAddress: serializer.fromJson<String>(json['toAddress']),
      toLat: serializer.fromJson<double?>(json['toLat']),
      toLng: serializer.fromJson<double?>(json['toLng']),
      flightNo: serializer.fromJson<String?>(json['flightNo']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      guideRef: serializer.fromJson<String?>(json['guideRef']),
      backupOf: serializer.fromJson<String?>(json['backupOf']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'dateEpochDay': serializer.toJson<int>(dateEpochDay),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'photoUri': serializer.toJson<String?>(photoUri),
      'startTimeMin': serializer.toJson<int?>(startTimeMin),
      'durationMin': serializer.toJson<int?>(durationMin),
      'costCents': serializer.toJson<int?>(costCents),
      'costCurrency': serializer.toJson<String>(costCurrency),
      'note': serializer.toJson<String>(note),
      'fromName': serializer.toJson<String>(fromName),
      'fromAddress': serializer.toJson<String>(fromAddress),
      'fromLat': serializer.toJson<double?>(fromLat),
      'fromLng': serializer.toJson<double?>(fromLng),
      'toName': serializer.toJson<String>(toName),
      'toAddress': serializer.toJson<String>(toAddress),
      'toLat': serializer.toJson<double?>(toLat),
      'toLng': serializer.toJson<double?>(toLng),
      'flightNo': serializer.toJson<String?>(flightNo),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'guideRef': serializer.toJson<String?>(guideRef),
      'backupOf': serializer.toJson<String?>(backupOf),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SharedTripItem copyWith({
    String? id,
    String? tripId,
    int? dateEpochDay,
    String? type,
    String? name,
    String? address,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> photoUri = const Value.absent(),
    Value<int?> startTimeMin = const Value.absent(),
    Value<int?> durationMin = const Value.absent(),
    Value<int?> costCents = const Value.absent(),
    String? costCurrency,
    String? note,
    String? fromName,
    String? fromAddress,
    Value<double?> fromLat = const Value.absent(),
    Value<double?> fromLng = const Value.absent(),
    String? toName,
    String? toAddress,
    Value<double?> toLat = const Value.absent(),
    Value<double?> toLng = const Value.absent(),
    Value<String?> flightNo = const Value.absent(),
    int? sortOrder,
    Value<String?> guideRef = const Value.absent(),
    Value<String?> backupOf = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => SharedTripItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    dateEpochDay: dateEpochDay ?? this.dateEpochDay,
    type: type ?? this.type,
    name: name ?? this.name,
    address: address ?? this.address,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    photoUri: photoUri.present ? photoUri.value : this.photoUri,
    startTimeMin: startTimeMin.present ? startTimeMin.value : this.startTimeMin,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    costCents: costCents.present ? costCents.value : this.costCents,
    costCurrency: costCurrency ?? this.costCurrency,
    note: note ?? this.note,
    fromName: fromName ?? this.fromName,
    fromAddress: fromAddress ?? this.fromAddress,
    fromLat: fromLat.present ? fromLat.value : this.fromLat,
    fromLng: fromLng.present ? fromLng.value : this.fromLng,
    toName: toName ?? this.toName,
    toAddress: toAddress ?? this.toAddress,
    toLat: toLat.present ? toLat.value : this.toLat,
    toLng: toLng.present ? toLng.value : this.toLng,
    flightNo: flightNo.present ? flightNo.value : this.flightNo,
    sortOrder: sortOrder ?? this.sortOrder,
    guideRef: guideRef.present ? guideRef.value : this.guideRef,
    backupOf: backupOf.present ? backupOf.value : this.backupOf,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharedTripItem copyWithCompanion(SharedTripItemsCompanion data) {
    return SharedTripItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      dateEpochDay: data.dateEpochDay.present
          ? data.dateEpochDay.value
          : this.dateEpochDay,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      photoUri: data.photoUri.present ? data.photoUri.value : this.photoUri,
      startTimeMin: data.startTimeMin.present
          ? data.startTimeMin.value
          : this.startTimeMin,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      costCents: data.costCents.present ? data.costCents.value : this.costCents,
      costCurrency: data.costCurrency.present
          ? data.costCurrency.value
          : this.costCurrency,
      note: data.note.present ? data.note.value : this.note,
      fromName: data.fromName.present ? data.fromName.value : this.fromName,
      fromAddress: data.fromAddress.present
          ? data.fromAddress.value
          : this.fromAddress,
      fromLat: data.fromLat.present ? data.fromLat.value : this.fromLat,
      fromLng: data.fromLng.present ? data.fromLng.value : this.fromLng,
      toName: data.toName.present ? data.toName.value : this.toName,
      toAddress: data.toAddress.present ? data.toAddress.value : this.toAddress,
      toLat: data.toLat.present ? data.toLat.value : this.toLat,
      toLng: data.toLng.present ? data.toLng.value : this.toLng,
      flightNo: data.flightNo.present ? data.flightNo.value : this.flightNo,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      guideRef: data.guideRef.present ? data.guideRef.value : this.guideRef,
      backupOf: data.backupOf.present ? data.backupOf.value : this.backupOf,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedTripItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('photoUri: $photoUri, ')
          ..write('startTimeMin: $startTimeMin, ')
          ..write('durationMin: $durationMin, ')
          ..write('costCents: $costCents, ')
          ..write('costCurrency: $costCurrency, ')
          ..write('note: $note, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLng: $fromLng, ')
          ..write('toName: $toName, ')
          ..write('toAddress: $toAddress, ')
          ..write('toLat: $toLat, ')
          ..write('toLng: $toLng, ')
          ..write('flightNo: $flightNo, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('guideRef: $guideRef, ')
          ..write('backupOf: $backupOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tripId,
    dateEpochDay,
    type,
    name,
    address,
    lat,
    lng,
    photoUri,
    startTimeMin,
    durationMin,
    costCents,
    costCurrency,
    note,
    fromName,
    fromAddress,
    fromLat,
    fromLng,
    toName,
    toAddress,
    toLat,
    toLng,
    flightNo,
    sortOrder,
    guideRef,
    backupOf,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedTripItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.dateEpochDay == this.dateEpochDay &&
          other.type == this.type &&
          other.name == this.name &&
          other.address == this.address &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.photoUri == this.photoUri &&
          other.startTimeMin == this.startTimeMin &&
          other.durationMin == this.durationMin &&
          other.costCents == this.costCents &&
          other.costCurrency == this.costCurrency &&
          other.note == this.note &&
          other.fromName == this.fromName &&
          other.fromAddress == this.fromAddress &&
          other.fromLat == this.fromLat &&
          other.fromLng == this.fromLng &&
          other.toName == this.toName &&
          other.toAddress == this.toAddress &&
          other.toLat == this.toLat &&
          other.toLng == this.toLng &&
          other.flightNo == this.flightNo &&
          other.sortOrder == this.sortOrder &&
          other.guideRef == this.guideRef &&
          other.backupOf == this.backupOf &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SharedTripItemsCompanion extends UpdateCompanion<SharedTripItem> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<int> dateEpochDay;
  final Value<String> type;
  final Value<String> name;
  final Value<String> address;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> photoUri;
  final Value<int?> startTimeMin;
  final Value<int?> durationMin;
  final Value<int?> costCents;
  final Value<String> costCurrency;
  final Value<String> note;
  final Value<String> fromName;
  final Value<String> fromAddress;
  final Value<double?> fromLat;
  final Value<double?> fromLng;
  final Value<String> toName;
  final Value<String> toAddress;
  final Value<double?> toLat;
  final Value<double?> toLng;
  final Value<String?> flightNo;
  final Value<int> sortOrder;
  final Value<String?> guideRef;
  final Value<String?> backupOf;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SharedTripItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.dateEpochDay = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.photoUri = const Value.absent(),
    this.startTimeMin = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.costCents = const Value.absent(),
    this.costCurrency = const Value.absent(),
    this.note = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLng = const Value.absent(),
    this.toName = const Value.absent(),
    this.toAddress = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLng = const Value.absent(),
    this.flightNo = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.backupOf = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedTripItemsCompanion.insert({
    required String id,
    required String tripId,
    this.dateEpochDay = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.photoUri = const Value.absent(),
    this.startTimeMin = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.costCents = const Value.absent(),
    this.costCurrency = const Value.absent(),
    this.note = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLng = const Value.absent(),
    this.toName = const Value.absent(),
    this.toAddress = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLng = const Value.absent(),
    this.flightNo = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.backupOf = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SharedTripItem> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<int>? dateEpochDay,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? address,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? photoUri,
    Expression<int>? startTimeMin,
    Expression<int>? durationMin,
    Expression<int>? costCents,
    Expression<String>? costCurrency,
    Expression<String>? note,
    Expression<String>? fromName,
    Expression<String>? fromAddress,
    Expression<double>? fromLat,
    Expression<double>? fromLng,
    Expression<String>? toName,
    Expression<String>? toAddress,
    Expression<double>? toLat,
    Expression<double>? toLng,
    Expression<String>? flightNo,
    Expression<int>? sortOrder,
    Expression<String>? guideRef,
    Expression<String>? backupOf,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (dateEpochDay != null) 'date_epoch_day': dateEpochDay,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (photoUri != null) 'photo_uri': photoUri,
      if (startTimeMin != null) 'start_time_min': startTimeMin,
      if (durationMin != null) 'duration_min': durationMin,
      if (costCents != null) 'cost_cents': costCents,
      if (costCurrency != null) 'cost_currency': costCurrency,
      if (note != null) 'note': note,
      if (fromName != null) 'from_name': fromName,
      if (fromAddress != null) 'from_address': fromAddress,
      if (fromLat != null) 'from_lat': fromLat,
      if (fromLng != null) 'from_lng': fromLng,
      if (toName != null) 'to_name': toName,
      if (toAddress != null) 'to_address': toAddress,
      if (toLat != null) 'to_lat': toLat,
      if (toLng != null) 'to_lng': toLng,
      if (flightNo != null) 'flight_no': flightNo,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (guideRef != null) 'guide_ref': guideRef,
      if (backupOf != null) 'backup_of': backupOf,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedTripItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<int>? dateEpochDay,
    Value<String>? type,
    Value<String>? name,
    Value<String>? address,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<String?>? photoUri,
    Value<int?>? startTimeMin,
    Value<int?>? durationMin,
    Value<int?>? costCents,
    Value<String>? costCurrency,
    Value<String>? note,
    Value<String>? fromName,
    Value<String>? fromAddress,
    Value<double?>? fromLat,
    Value<double?>? fromLng,
    Value<String>? toName,
    Value<String>? toAddress,
    Value<double?>? toLat,
    Value<double?>? toLng,
    Value<String?>? flightNo,
    Value<int>? sortOrder,
    Value<String?>? guideRef,
    Value<String?>? backupOf,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharedTripItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dateEpochDay: dateEpochDay ?? this.dateEpochDay,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photoUri: photoUri ?? this.photoUri,
      startTimeMin: startTimeMin ?? this.startTimeMin,
      durationMin: durationMin ?? this.durationMin,
      costCents: costCents ?? this.costCents,
      costCurrency: costCurrency ?? this.costCurrency,
      note: note ?? this.note,
      fromName: fromName ?? this.fromName,
      fromAddress: fromAddress ?? this.fromAddress,
      fromLat: fromLat ?? this.fromLat,
      fromLng: fromLng ?? this.fromLng,
      toName: toName ?? this.toName,
      toAddress: toAddress ?? this.toAddress,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      flightNo: flightNo ?? this.flightNo,
      sortOrder: sortOrder ?? this.sortOrder,
      guideRef: guideRef ?? this.guideRef,
      backupOf: backupOf ?? this.backupOf,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (dateEpochDay.present) {
      map['date_epoch_day'] = Variable<int>(dateEpochDay.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (photoUri.present) {
      map['photo_uri'] = Variable<String>(photoUri.value);
    }
    if (startTimeMin.present) {
      map['start_time_min'] = Variable<int>(startTimeMin.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (costCents.present) {
      map['cost_cents'] = Variable<int>(costCents.value);
    }
    if (costCurrency.present) {
      map['cost_currency'] = Variable<String>(costCurrency.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (fromName.present) {
      map['from_name'] = Variable<String>(fromName.value);
    }
    if (fromAddress.present) {
      map['from_address'] = Variable<String>(fromAddress.value);
    }
    if (fromLat.present) {
      map['from_lat'] = Variable<double>(fromLat.value);
    }
    if (fromLng.present) {
      map['from_lng'] = Variable<double>(fromLng.value);
    }
    if (toName.present) {
      map['to_name'] = Variable<String>(toName.value);
    }
    if (toAddress.present) {
      map['to_address'] = Variable<String>(toAddress.value);
    }
    if (toLat.present) {
      map['to_lat'] = Variable<double>(toLat.value);
    }
    if (toLng.present) {
      map['to_lng'] = Variable<double>(toLng.value);
    }
    if (flightNo.present) {
      map['flight_no'] = Variable<String>(flightNo.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (guideRef.present) {
      map['guide_ref'] = Variable<String>(guideRef.value);
    }
    if (backupOf.present) {
      map['backup_of'] = Variable<String>(backupOf.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedTripItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('dateEpochDay: $dateEpochDay, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('photoUri: $photoUri, ')
          ..write('startTimeMin: $startTimeMin, ')
          ..write('durationMin: $durationMin, ')
          ..write('costCents: $costCents, ')
          ..write('costCurrency: $costCurrency, ')
          ..write('note: $note, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLng: $fromLng, ')
          ..write('toName: $toName, ')
          ..write('toAddress: $toAddress, ')
          ..write('toLat: $toLat, ')
          ..write('toLng: $toLng, ')
          ..write('flightNo: $flightNo, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('guideRef: $guideRef, ')
          ..write('backupOf: $backupOf, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FundsTable extends Funds with TableInfo<$FundsTable, Fund> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
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
  static const VerificationMeta _managerMemberIdMeta = const VerificationMeta(
    'managerMemberId',
  );
  @override
  late final GeneratedColumn<String> managerMemberId = GeneratedColumn<String>(
    'manager_member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetCentsMeta = const VerificationMeta(
    'targetCents',
  );
  @override
  late final GeneratedColumn<int> targetCents = GeneratedColumn<int>(
    'target_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("open"),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    managerMemberId,
    targetCents,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'funds';
  @override
  VerificationContext validateIntegrity(
    Insertable<Fund> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('manager_member_id')) {
      context.handle(
        _managerMemberIdMeta,
        managerMemberId.isAcceptableOrUnknown(
          data['manager_member_id']!,
          _managerMemberIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_managerMemberIdMeta);
    }
    if (data.containsKey('target_cents')) {
      context.handle(
        _targetCentsMeta,
        targetCents.isAcceptableOrUnknown(
          data['target_cents']!,
          _targetCentsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Fund map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Fund(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      managerMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manager_member_id'],
      )!,
      targetCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_cents'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FundsTable createAlias(String alias) {
    return $FundsTable(attachedDatabase, alias);
  }
}

class Fund extends DataClass implements Insertable<Fund> {
  final String id;
  final String groupId;
  final String name;
  final String managerMemberId;
  final int? targetCents;
  final String status;
  final int createdAt;
  final int updatedAt;
  const Fund({
    required this.id,
    required this.groupId,
    required this.name,
    required this.managerMemberId,
    this.targetCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['manager_member_id'] = Variable<String>(managerMemberId);
    if (!nullToAbsent || targetCents != null) {
      map['target_cents'] = Variable<int>(targetCents);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FundsCompanion toCompanion(bool nullToAbsent) {
    return FundsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      managerMemberId: Value(managerMemberId),
      targetCents: targetCents == null && nullToAbsent
          ? const Value.absent()
          : Value(targetCents),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Fund.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fund(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      managerMemberId: serializer.fromJson<String>(json['managerMemberId']),
      targetCents: serializer.fromJson<int?>(json['targetCents']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'managerMemberId': serializer.toJson<String>(managerMemberId),
      'targetCents': serializer.toJson<int?>(targetCents),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Fund copyWith({
    String? id,
    String? groupId,
    String? name,
    String? managerMemberId,
    Value<int?> targetCents = const Value.absent(),
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => Fund(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    managerMemberId: managerMemberId ?? this.managerMemberId,
    targetCents: targetCents.present ? targetCents.value : this.targetCents,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Fund copyWithCompanion(FundsCompanion data) {
    return Fund(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      managerMemberId: data.managerMemberId.present
          ? data.managerMemberId.value
          : this.managerMemberId,
      targetCents: data.targetCents.present
          ? data.targetCents.value
          : this.targetCents,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fund(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('managerMemberId: $managerMemberId, ')
          ..write('targetCents: $targetCents, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    name,
    managerMemberId,
    targetCents,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fund &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.managerMemberId == this.managerMemberId &&
          other.targetCents == this.targetCents &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FundsCompanion extends UpdateCompanion<Fund> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<String> managerMemberId;
  final Value<int?> targetCents;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const FundsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.managerMemberId = const Value.absent(),
    this.targetCents = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FundsCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    required String managerMemberId,
    this.targetCents = const Value.absent(),
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       name = Value(name),
       managerMemberId = Value(managerMemberId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Fund> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<String>? managerMemberId,
    Expression<int>? targetCents,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (managerMemberId != null) 'manager_member_id': managerMemberId,
      if (targetCents != null) 'target_cents': targetCents,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FundsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? name,
    Value<String>? managerMemberId,
    Value<int?>? targetCents,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return FundsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      managerMemberId: managerMemberId ?? this.managerMemberId,
      targetCents: targetCents ?? this.targetCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (managerMemberId.present) {
      map['manager_member_id'] = Variable<String>(managerMemberId.value);
    }
    if (targetCents.present) {
      map['target_cents'] = Variable<int>(targetCents.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FundsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('managerMemberId: $managerMemberId, ')
          ..write('targetCents: $targetCents, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxItemsTable extends InboxItems
    with TableInfo<$InboxItemsTable, InboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("manual"),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("pending"),
  );
  static const VerificationMeta _convertedExpenseIdMeta =
      const VerificationMeta('convertedExpenseId');
  @override
  late final GeneratedColumn<String> convertedExpenseId =
      GeneratedColumn<String>(
        'converted_expense_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    amountCents,
    note,
    capturedAt,
    source,
    status,
    convertedExpenseId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('converted_expense_id')) {
      context.handle(
        _convertedExpenseIdMeta,
        convertedExpenseId.isAcceptableOrUnknown(
          data['converted_expense_id']!,
          _convertedExpenseIdMeta,
        ),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      convertedExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_expense_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $InboxItemsTable createAlias(String alias) {
    return $InboxItemsTable(attachedDatabase, alias);
  }
}

class InboxItem extends DataClass implements Insertable<InboxItem> {
  final String id;
  final String groupId;
  final int amountCents;
  final String? note;
  final int capturedAt;
  final String source;
  final String status;
  final String? convertedExpenseId;
  final int createdAt;
  final int updatedAt;
  const InboxItem({
    required this.id,
    required this.groupId,
    required this.amountCents,
    this.note,
    required this.capturedAt,
    required this.source,
    required this.status,
    this.convertedExpenseId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['captured_at'] = Variable<int>(capturedAt);
    map['source'] = Variable<String>(source);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || convertedExpenseId != null) {
      map['converted_expense_id'] = Variable<String>(convertedExpenseId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  InboxItemsCompanion toCompanion(bool nullToAbsent) {
    return InboxItemsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      amountCents: Value(amountCents),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      capturedAt: Value(capturedAt),
      source: Value(source),
      status: Value(status),
      convertedExpenseId: convertedExpenseId == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedExpenseId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InboxItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxItem(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      note: serializer.fromJson<String?>(json['note']),
      capturedAt: serializer.fromJson<int>(json['capturedAt']),
      source: serializer.fromJson<String>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      convertedExpenseId: serializer.fromJson<String?>(
        json['convertedExpenseId'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'amountCents': serializer.toJson<int>(amountCents),
      'note': serializer.toJson<String?>(note),
      'capturedAt': serializer.toJson<int>(capturedAt),
      'source': serializer.toJson<String>(source),
      'status': serializer.toJson<String>(status),
      'convertedExpenseId': serializer.toJson<String?>(convertedExpenseId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  InboxItem copyWith({
    String? id,
    String? groupId,
    int? amountCents,
    Value<String?> note = const Value.absent(),
    int? capturedAt,
    String? source,
    String? status,
    Value<String?> convertedExpenseId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => InboxItem(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    amountCents: amountCents ?? this.amountCents,
    note: note.present ? note.value : this.note,
    capturedAt: capturedAt ?? this.capturedAt,
    source: source ?? this.source,
    status: status ?? this.status,
    convertedExpenseId: convertedExpenseId.present
        ? convertedExpenseId.value
        : this.convertedExpenseId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InboxItem copyWithCompanion(InboxItemsCompanion data) {
    return InboxItem(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      note: data.note.present ? data.note.value : this.note,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      convertedExpenseId: data.convertedExpenseId.present
          ? data.convertedExpenseId.value
          : this.convertedExpenseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxItem(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('convertedExpenseId: $convertedExpenseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    amountCents,
    note,
    capturedAt,
    source,
    status,
    convertedExpenseId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxItem &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.amountCents == this.amountCents &&
          other.note == this.note &&
          other.capturedAt == this.capturedAt &&
          other.source == this.source &&
          other.status == this.status &&
          other.convertedExpenseId == this.convertedExpenseId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InboxItemsCompanion extends UpdateCompanion<InboxItem> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> amountCents;
  final Value<String?> note;
  final Value<int> capturedAt;
  final Value<String> source;
  final Value<String> status;
  final Value<String?> convertedExpenseId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const InboxItemsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.note = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.convertedExpenseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxItemsCompanion.insert({
    required String id,
    required String groupId,
    this.amountCents = const Value.absent(),
    this.note = const Value.absent(),
    required int capturedAt,
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.convertedExpenseId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       capturedAt = Value(capturedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<InboxItem> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? amountCents,
    Expression<String>? note,
    Expression<int>? capturedAt,
    Expression<String>? source,
    Expression<String>? status,
    Expression<String>? convertedExpenseId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (note != null) 'note': note,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (convertedExpenseId != null)
        'converted_expense_id': convertedExpenseId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int>? amountCents,
    Value<String?>? note,
    Value<int>? capturedAt,
    Value<String>? source,
    Value<String>? status,
    Value<String?>? convertedExpenseId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return InboxItemsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      amountCents: amountCents ?? this.amountCents,
      note: note ?? this.note,
      capturedAt: capturedAt ?? this.capturedAt,
      source: source ?? this.source,
      status: status ?? this.status,
      convertedExpenseId: convertedExpenseId ?? this.convertedExpenseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (convertedExpenseId.present) {
      map['converted_expense_id'] = Variable<String>(convertedExpenseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('convertedExpenseId: $convertedExpenseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorMemberIdMeta = const VerificationMeta(
    'actorMemberId',
  );
  @override
  late final GeneratedColumn<String> actorMemberId = GeneratedColumn<String>(
    'actor_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedFieldsJsonMeta = const VerificationMeta(
    'changedFieldsJson',
  );
  @override
  late final GeneratedColumn<String> changedFieldsJson =
      GeneratedColumn<String>(
        'changed_fields_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant("{}"),
      );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    entity,
    entityId,
    action,
    actorMemberId,
    changedFieldsJson,
    atMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('actor_member_id')) {
      context.handle(
        _actorMemberIdMeta,
        actorMemberId.isAcceptableOrUnknown(
          data['actor_member_id']!,
          _actorMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('changed_fields_json')) {
      context.handle(
        _changedFieldsJsonMeta,
        changedFieldsJson.isAcceptableOrUnknown(
          data['changed_fields_json']!,
          _changedFieldsJsonMeta,
        ),
      );
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      actorMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_member_id'],
      ),
      changedFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_fields_json'],
      )!,
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final String id;
  final String groupId;
  final String entity;
  final String entityId;
  final String action;
  final String? actorMemberId;
  final String changedFieldsJson;
  final int atMs;
  const AuditLog({
    required this.id,
    required this.groupId,
    required this.entity,
    required this.entityId,
    required this.action,
    this.actorMemberId,
    required this.changedFieldsJson,
    required this.atMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || actorMemberId != null) {
      map['actor_member_id'] = Variable<String>(actorMemberId);
    }
    map['changed_fields_json'] = Variable<String>(changedFieldsJson);
    map['at_ms'] = Variable<int>(atMs);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      entity: Value(entity),
      entityId: Value(entityId),
      action: Value(action),
      actorMemberId: actorMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorMemberId),
      changedFieldsJson: Value(changedFieldsJson),
      atMs: Value(atMs),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      actorMemberId: serializer.fromJson<String?>(json['actorMemberId']),
      changedFieldsJson: serializer.fromJson<String>(json['changedFieldsJson']),
      atMs: serializer.fromJson<int>(json['atMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'actorMemberId': serializer.toJson<String?>(actorMemberId),
      'changedFieldsJson': serializer.toJson<String>(changedFieldsJson),
      'atMs': serializer.toJson<int>(atMs),
    };
  }

  AuditLog copyWith({
    String? id,
    String? groupId,
    String? entity,
    String? entityId,
    String? action,
    Value<String?> actorMemberId = const Value.absent(),
    String? changedFieldsJson,
    int? atMs,
  }) => AuditLog(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    actorMemberId: actorMemberId.present
        ? actorMemberId.value
        : this.actorMemberId,
    changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
    atMs: atMs ?? this.atMs,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      actorMemberId: data.actorMemberId.present
          ? data.actorMemberId.value
          : this.actorMemberId,
      changedFieldsJson: data.changedFieldsJson.present
          ? data.changedFieldsJson.value
          : this.changedFieldsJson,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('atMs: $atMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    entity,
    entityId,
    action,
    actorMemberId,
    changedFieldsJson,
    atMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.actorMemberId == this.actorMemberId &&
          other.changedFieldsJson == this.changedFieldsJson &&
          other.atMs == this.atMs);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> action;
  final Value<String?> actorMemberId;
  final Value<String> changedFieldsJson;
  final Value<int> atMs;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.actorMemberId = const Value.absent(),
    this.changedFieldsJson = const Value.absent(),
    this.atMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    required String id,
    required String groupId,
    required String entity,
    required String entityId,
    required String action,
    this.actorMemberId = const Value.absent(),
    this.changedFieldsJson = const Value.absent(),
    required int atMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       entity = Value(entity),
       entityId = Value(entityId),
       action = Value(action),
       atMs = Value(atMs);
  static Insertable<AuditLog> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<String>? actorMemberId,
    Expression<String>? changedFieldsJson,
    Expression<int>? atMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (actorMemberId != null) 'actor_member_id': actorMemberId,
      if (changedFieldsJson != null) 'changed_fields_json': changedFieldsJson,
      if (atMs != null) 'at_ms': atMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? action,
    Value<String?>? actorMemberId,
    Value<String>? changedFieldsJson,
    Value<int>? atMs,
    Value<int>? rowid,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      actorMemberId: actorMemberId ?? this.actorMemberId,
      changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
      atMs: atMs ?? this.atMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (actorMemberId.present) {
      map['actor_member_id'] = Variable<String>(actorMemberId.value);
    }
    if (changedFieldsJson.present) {
      map['changed_fields_json'] = Variable<String>(changedFieldsJson.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('atMs: $atMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictRecordsTable extends ConflictRecords
    with TableInfo<$ConflictRecordsTable, ConflictRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localUpdatedMsMeta = const VerificationMeta(
    'localUpdatedMs',
  );
  @override
  late final GeneratedColumn<int> localUpdatedMs = GeneratedColumn<int>(
    'local_updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteUpdatedMsMeta = const VerificationMeta(
    'remoteUpdatedMs',
  );
  @override
  late final GeneratedColumn<int> remoteUpdatedMs = GeneratedColumn<int>(
    'remote_updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winnerMeta = const VerificationMeta('winner');
  @override
  late final GeneratedColumn<String> winner = GeneratedColumn<String>(
    'winner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMsMeta = const VerificationMeta(
    'detectedAtMs',
  );
  @override
  late final GeneratedColumn<int> detectedAtMs = GeneratedColumn<int>(
    'detected_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acknowledgedMeta = const VerificationMeta(
    'acknowledged',
  );
  @override
  late final GeneratedColumn<int> acknowledged = GeneratedColumn<int>(
    'acknowledged',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    entity,
    entityId,
    localUpdatedMs,
    remoteUpdatedMs,
    winner,
    detectedAtMs,
    acknowledged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflict_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('local_updated_ms')) {
      context.handle(
        _localUpdatedMsMeta,
        localUpdatedMs.isAcceptableOrUnknown(
          data['local_updated_ms']!,
          _localUpdatedMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedMsMeta);
    }
    if (data.containsKey('remote_updated_ms')) {
      context.handle(
        _remoteUpdatedMsMeta,
        remoteUpdatedMs.isAcceptableOrUnknown(
          data['remote_updated_ms']!,
          _remoteUpdatedMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteUpdatedMsMeta);
    }
    if (data.containsKey('winner')) {
      context.handle(
        _winnerMeta,
        winner.isAcceptableOrUnknown(data['winner']!, _winnerMeta),
      );
    } else if (isInserting) {
      context.missing(_winnerMeta);
    }
    if (data.containsKey('detected_at_ms')) {
      context.handle(
        _detectedAtMsMeta,
        detectedAtMs.isAcceptableOrUnknown(
          data['detected_at_ms']!,
          _detectedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMsMeta);
    }
    if (data.containsKey('acknowledged')) {
      context.handle(
        _acknowledgedMeta,
        acknowledged.isAcceptableOrUnknown(
          data['acknowledged']!,
          _acknowledgedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      localUpdatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_updated_ms'],
      )!,
      remoteUpdatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_updated_ms'],
      )!,
      winner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner'],
      )!,
      detectedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at_ms'],
      )!,
      acknowledged: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acknowledged'],
      )!,
    );
  }

  @override
  $ConflictRecordsTable createAlias(String alias) {
    return $ConflictRecordsTable(attachedDatabase, alias);
  }
}

class ConflictRecord extends DataClass implements Insertable<ConflictRecord> {
  final String id;
  final String groupId;
  final String entity;
  final String entityId;
  final int localUpdatedMs;
  final int remoteUpdatedMs;
  final String winner;
  final int detectedAtMs;
  final int acknowledged;
  const ConflictRecord({
    required this.id,
    required this.groupId,
    required this.entity,
    required this.entityId,
    required this.localUpdatedMs,
    required this.remoteUpdatedMs,
    required this.winner,
    required this.detectedAtMs,
    required this.acknowledged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['local_updated_ms'] = Variable<int>(localUpdatedMs);
    map['remote_updated_ms'] = Variable<int>(remoteUpdatedMs);
    map['winner'] = Variable<String>(winner);
    map['detected_at_ms'] = Variable<int>(detectedAtMs);
    map['acknowledged'] = Variable<int>(acknowledged);
    return map;
  }

  ConflictRecordsCompanion toCompanion(bool nullToAbsent) {
    return ConflictRecordsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      entity: Value(entity),
      entityId: Value(entityId),
      localUpdatedMs: Value(localUpdatedMs),
      remoteUpdatedMs: Value(remoteUpdatedMs),
      winner: Value(winner),
      detectedAtMs: Value(detectedAtMs),
      acknowledged: Value(acknowledged),
    );
  }

  factory ConflictRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictRecord(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localUpdatedMs: serializer.fromJson<int>(json['localUpdatedMs']),
      remoteUpdatedMs: serializer.fromJson<int>(json['remoteUpdatedMs']),
      winner: serializer.fromJson<String>(json['winner']),
      detectedAtMs: serializer.fromJson<int>(json['detectedAtMs']),
      acknowledged: serializer.fromJson<int>(json['acknowledged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'localUpdatedMs': serializer.toJson<int>(localUpdatedMs),
      'remoteUpdatedMs': serializer.toJson<int>(remoteUpdatedMs),
      'winner': serializer.toJson<String>(winner),
      'detectedAtMs': serializer.toJson<int>(detectedAtMs),
      'acknowledged': serializer.toJson<int>(acknowledged),
    };
  }

  ConflictRecord copyWith({
    String? id,
    String? groupId,
    String? entity,
    String? entityId,
    int? localUpdatedMs,
    int? remoteUpdatedMs,
    String? winner,
    int? detectedAtMs,
    int? acknowledged,
  }) => ConflictRecord(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    localUpdatedMs: localUpdatedMs ?? this.localUpdatedMs,
    remoteUpdatedMs: remoteUpdatedMs ?? this.remoteUpdatedMs,
    winner: winner ?? this.winner,
    detectedAtMs: detectedAtMs ?? this.detectedAtMs,
    acknowledged: acknowledged ?? this.acknowledged,
  );
  ConflictRecord copyWithCompanion(ConflictRecordsCompanion data) {
    return ConflictRecord(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localUpdatedMs: data.localUpdatedMs.present
          ? data.localUpdatedMs.value
          : this.localUpdatedMs,
      remoteUpdatedMs: data.remoteUpdatedMs.present
          ? data.remoteUpdatedMs.value
          : this.remoteUpdatedMs,
      winner: data.winner.present ? data.winner.value : this.winner,
      detectedAtMs: data.detectedAtMs.present
          ? data.detectedAtMs.value
          : this.detectedAtMs,
      acknowledged: data.acknowledged.present
          ? data.acknowledged.value
          : this.acknowledged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRecord(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('localUpdatedMs: $localUpdatedMs, ')
          ..write('remoteUpdatedMs: $remoteUpdatedMs, ')
          ..write('winner: $winner, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('acknowledged: $acknowledged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    entity,
    entityId,
    localUpdatedMs,
    remoteUpdatedMs,
    winner,
    detectedAtMs,
    acknowledged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictRecord &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.localUpdatedMs == this.localUpdatedMs &&
          other.remoteUpdatedMs == this.remoteUpdatedMs &&
          other.winner == this.winner &&
          other.detectedAtMs == this.detectedAtMs &&
          other.acknowledged == this.acknowledged);
}

class ConflictRecordsCompanion extends UpdateCompanion<ConflictRecord> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<int> localUpdatedMs;
  final Value<int> remoteUpdatedMs;
  final Value<String> winner;
  final Value<int> detectedAtMs;
  final Value<int> acknowledged;
  final Value<int> rowid;
  const ConflictRecordsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localUpdatedMs = const Value.absent(),
    this.remoteUpdatedMs = const Value.absent(),
    this.winner = const Value.absent(),
    this.detectedAtMs = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictRecordsCompanion.insert({
    required String id,
    required String groupId,
    required String entity,
    required String entityId,
    required int localUpdatedMs,
    required int remoteUpdatedMs,
    required String winner,
    required int detectedAtMs,
    this.acknowledged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       entity = Value(entity),
       entityId = Value(entityId),
       localUpdatedMs = Value(localUpdatedMs),
       remoteUpdatedMs = Value(remoteUpdatedMs),
       winner = Value(winner),
       detectedAtMs = Value(detectedAtMs);
  static Insertable<ConflictRecord> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<int>? localUpdatedMs,
    Expression<int>? remoteUpdatedMs,
    Expression<String>? winner,
    Expression<int>? detectedAtMs,
    Expression<int>? acknowledged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (localUpdatedMs != null) 'local_updated_ms': localUpdatedMs,
      if (remoteUpdatedMs != null) 'remote_updated_ms': remoteUpdatedMs,
      if (winner != null) 'winner': winner,
      if (detectedAtMs != null) 'detected_at_ms': detectedAtMs,
      if (acknowledged != null) 'acknowledged': acknowledged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<int>? localUpdatedMs,
    Value<int>? remoteUpdatedMs,
    Value<String>? winner,
    Value<int>? detectedAtMs,
    Value<int>? acknowledged,
    Value<int>? rowid,
  }) {
    return ConflictRecordsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      localUpdatedMs: localUpdatedMs ?? this.localUpdatedMs,
      remoteUpdatedMs: remoteUpdatedMs ?? this.remoteUpdatedMs,
      winner: winner ?? this.winner,
      detectedAtMs: detectedAtMs ?? this.detectedAtMs,
      acknowledged: acknowledged ?? this.acknowledged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localUpdatedMs.present) {
      map['local_updated_ms'] = Variable<int>(localUpdatedMs.value);
    }
    if (remoteUpdatedMs.present) {
      map['remote_updated_ms'] = Variable<int>(remoteUpdatedMs.value);
    }
    if (winner.present) {
      map['winner'] = Variable<String>(winner.value);
    }
    if (detectedAtMs.present) {
      map['detected_at_ms'] = Variable<int>(detectedAtMs.value);
    }
    if (acknowledged.present) {
      map['acknowledged'] = Variable<int>(acknowledged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictRecordsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('localUpdatedMs: $localUpdatedMs, ')
          ..write('remoteUpdatedMs: $remoteUpdatedMs, ')
          ..write('winner: $winner, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('acknowledged: $acknowledged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishlistItemsTable extends WishlistItems
    with TableInfo<$WishlistItemsTable, WishlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id)',
    ),
  );
  static const VerificationMeta _cityKeyMeta = const VerificationMeta(
    'cityKey',
  );
  @override
  late final GeneratedColumn<String> cityKey = GeneratedColumn<String>(
    'city_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("attraction"),
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _guideRefMeta = const VerificationMeta(
    'guideRef',
  );
  @override
  late final GeneratedColumn<String> guideRef = GeneratedColumn<String>(
    'guide_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    cityKey,
    name,
    address,
    type,
    durationMin,
    tag,
    guideRef,
    note,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WishlistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('city_key')) {
      context.handle(
        _cityKeyMeta,
        cityKey.isAcceptableOrUnknown(data['city_key']!, _cityKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    }
    if (data.containsKey('guide_ref')) {
      context.handle(
        _guideRefMeta,
        guideRef.isAcceptableOrUnknown(data['guide_ref']!, _guideRefMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WishlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishlistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      cityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      ),
      guideRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_ref'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WishlistItemsTable createAlias(String alias) {
    return $WishlistItemsTable(attachedDatabase, alias);
  }
}

class WishlistItem extends DataClass implements Insertable<WishlistItem> {
  final String id;
  final String tripId;
  final String cityKey;
  final String name;
  final String address;
  final String type;
  final int? durationMin;
  final String? tag;
  final String? guideRef;
  final String note;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const WishlistItem({
    required this.id,
    required this.tripId,
    required this.cityKey,
    required this.name,
    required this.address,
    required this.type,
    this.durationMin,
    this.tag,
    this.guideRef,
    required this.note,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['city_key'] = Variable<String>(cityKey);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    if (!nullToAbsent || guideRef != null) {
      map['guide_ref'] = Variable<String>(guideRef);
    }
    map['note'] = Variable<String>(note);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  WishlistItemsCompanion toCompanion(bool nullToAbsent) {
    return WishlistItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      cityKey: Value(cityKey),
      name: Value(name),
      address: Value(address),
      type: Value(type),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      guideRef: guideRef == null && nullToAbsent
          ? const Value.absent()
          : Value(guideRef),
      note: Value(note),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WishlistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishlistItem(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      cityKey: serializer.fromJson<String>(json['cityKey']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      type: serializer.fromJson<String>(json['type']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      tag: serializer.fromJson<String?>(json['tag']),
      guideRef: serializer.fromJson<String?>(json['guideRef']),
      note: serializer.fromJson<String>(json['note']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'cityKey': serializer.toJson<String>(cityKey),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'type': serializer.toJson<String>(type),
      'durationMin': serializer.toJson<int?>(durationMin),
      'tag': serializer.toJson<String?>(tag),
      'guideRef': serializer.toJson<String?>(guideRef),
      'note': serializer.toJson<String>(note),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  WishlistItem copyWith({
    String? id,
    String? tripId,
    String? cityKey,
    String? name,
    String? address,
    String? type,
    Value<int?> durationMin = const Value.absent(),
    Value<String?> tag = const Value.absent(),
    Value<String?> guideRef = const Value.absent(),
    String? note,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => WishlistItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    cityKey: cityKey ?? this.cityKey,
    name: name ?? this.name,
    address: address ?? this.address,
    type: type ?? this.type,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    tag: tag.present ? tag.value : this.tag,
    guideRef: guideRef.present ? guideRef.value : this.guideRef,
    note: note ?? this.note,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WishlistItem copyWithCompanion(WishlistItemsCompanion data) {
    return WishlistItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      cityKey: data.cityKey.present ? data.cityKey.value : this.cityKey,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      type: data.type.present ? data.type.value : this.type,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      tag: data.tag.present ? data.tag.value : this.tag,
      guideRef: data.guideRef.present ? data.guideRef.value : this.guideRef,
      note: data.note.present ? data.note.value : this.note,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('cityKey: $cityKey, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('type: $type, ')
          ..write('durationMin: $durationMin, ')
          ..write('tag: $tag, ')
          ..write('guideRef: $guideRef, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    cityKey,
    name,
    address,
    type,
    durationMin,
    tag,
    guideRef,
    note,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.cityKey == this.cityKey &&
          other.name == this.name &&
          other.address == this.address &&
          other.type == this.type &&
          other.durationMin == this.durationMin &&
          other.tag == this.tag &&
          other.guideRef == this.guideRef &&
          other.note == this.note &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WishlistItemsCompanion extends UpdateCompanion<WishlistItem> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> cityKey;
  final Value<String> name;
  final Value<String> address;
  final Value<String> type;
  final Value<int?> durationMin;
  final Value<String?> tag;
  final Value<String?> guideRef;
  final Value<String> note;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const WishlistItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.cityKey = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tag = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishlistItemsCompanion.insert({
    required String id,
    required String tripId,
    this.cityKey = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tag = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WishlistItem> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? cityKey,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? type,
    Expression<int>? durationMin,
    Expression<String>? tag,
    Expression<String>? guideRef,
    Expression<String>? note,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (cityKey != null) 'city_key': cityKey,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (type != null) 'type': type,
      if (durationMin != null) 'duration_min': durationMin,
      if (tag != null) 'tag': tag,
      if (guideRef != null) 'guide_ref': guideRef,
      if (note != null) 'note': note,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishlistItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? cityKey,
    Value<String>? name,
    Value<String>? address,
    Value<String>? type,
    Value<int?>? durationMin,
    Value<String?>? tag,
    Value<String?>? guideRef,
    Value<String>? note,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return WishlistItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      cityKey: cityKey ?? this.cityKey,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      durationMin: durationMin ?? this.durationMin,
      tag: tag ?? this.tag,
      guideRef: guideRef ?? this.guideRef,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (cityKey.present) {
      map['city_key'] = Variable<String>(cityKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (guideRef.present) {
      map['guide_ref'] = Variable<String>(guideRef.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('cityKey: $cityKey, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('type: $type, ')
          ..write('durationMin: $durationMin, ')
          ..write('tag: $tag, ')
          ..write('guideRef: $guideRef, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedWishlistItemsTable extends SharedWishlistItems
    with TableInfo<$SharedWishlistItemsTable, SharedWishlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedWishlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityKeyMeta = const VerificationMeta(
    'cityKey',
  );
  @override
  late final GeneratedColumn<String> cityKey = GeneratedColumn<String>(
    'city_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("attraction"),
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _guideRefMeta = const VerificationMeta(
    'guideRef',
  );
  @override
  late final GeneratedColumn<String> guideRef = GeneratedColumn<String>(
    'guide_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    cityKey,
    name,
    address,
    type,
    durationMin,
    tag,
    guideRef,
    note,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_wishlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedWishlistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('city_key')) {
      context.handle(
        _cityKeyMeta,
        cityKey.isAcceptableOrUnknown(data['city_key']!, _cityKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    }
    if (data.containsKey('guide_ref')) {
      context.handle(
        _guideRefMeta,
        guideRef.isAcceptableOrUnknown(data['guide_ref']!, _guideRefMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedWishlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedWishlistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      cityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      ),
      guideRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guide_ref'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharedWishlistItemsTable createAlias(String alias) {
    return $SharedWishlistItemsTable(attachedDatabase, alias);
  }
}

class SharedWishlistItem extends DataClass
    implements Insertable<SharedWishlistItem> {
  final String id;
  final String tripId;
  final String cityKey;
  final String name;
  final String address;
  final String type;
  final int? durationMin;
  final String? tag;
  final String? guideRef;
  final String note;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const SharedWishlistItem({
    required this.id,
    required this.tripId,
    required this.cityKey,
    required this.name,
    required this.address,
    required this.type,
    this.durationMin,
    this.tag,
    this.guideRef,
    required this.note,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['city_key'] = Variable<String>(cityKey);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    if (!nullToAbsent || guideRef != null) {
      map['guide_ref'] = Variable<String>(guideRef);
    }
    map['note'] = Variable<String>(note);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SharedWishlistItemsCompanion toCompanion(bool nullToAbsent) {
    return SharedWishlistItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      cityKey: Value(cityKey),
      name: Value(name),
      address: Value(address),
      type: Value(type),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      guideRef: guideRef == null && nullToAbsent
          ? const Value.absent()
          : Value(guideRef),
      note: Value(note),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedWishlistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedWishlistItem(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      cityKey: serializer.fromJson<String>(json['cityKey']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      type: serializer.fromJson<String>(json['type']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      tag: serializer.fromJson<String?>(json['tag']),
      guideRef: serializer.fromJson<String?>(json['guideRef']),
      note: serializer.fromJson<String>(json['note']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'cityKey': serializer.toJson<String>(cityKey),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'type': serializer.toJson<String>(type),
      'durationMin': serializer.toJson<int?>(durationMin),
      'tag': serializer.toJson<String?>(tag),
      'guideRef': serializer.toJson<String?>(guideRef),
      'note': serializer.toJson<String>(note),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SharedWishlistItem copyWith({
    String? id,
    String? tripId,
    String? cityKey,
    String? name,
    String? address,
    String? type,
    Value<int?> durationMin = const Value.absent(),
    Value<String?> tag = const Value.absent(),
    Value<String?> guideRef = const Value.absent(),
    String? note,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => SharedWishlistItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    cityKey: cityKey ?? this.cityKey,
    name: name ?? this.name,
    address: address ?? this.address,
    type: type ?? this.type,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    tag: tag.present ? tag.value : this.tag,
    guideRef: guideRef.present ? guideRef.value : this.guideRef,
    note: note ?? this.note,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharedWishlistItem copyWithCompanion(SharedWishlistItemsCompanion data) {
    return SharedWishlistItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      cityKey: data.cityKey.present ? data.cityKey.value : this.cityKey,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      type: data.type.present ? data.type.value : this.type,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      tag: data.tag.present ? data.tag.value : this.tag,
      guideRef: data.guideRef.present ? data.guideRef.value : this.guideRef,
      note: data.note.present ? data.note.value : this.note,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedWishlistItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('cityKey: $cityKey, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('type: $type, ')
          ..write('durationMin: $durationMin, ')
          ..write('tag: $tag, ')
          ..write('guideRef: $guideRef, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    cityKey,
    name,
    address,
    type,
    durationMin,
    tag,
    guideRef,
    note,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedWishlistItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.cityKey == this.cityKey &&
          other.name == this.name &&
          other.address == this.address &&
          other.type == this.type &&
          other.durationMin == this.durationMin &&
          other.tag == this.tag &&
          other.guideRef == this.guideRef &&
          other.note == this.note &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SharedWishlistItemsCompanion extends UpdateCompanion<SharedWishlistItem> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> cityKey;
  final Value<String> name;
  final Value<String> address;
  final Value<String> type;
  final Value<int?> durationMin;
  final Value<String?> tag;
  final Value<String?> guideRef;
  final Value<String> note;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SharedWishlistItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.cityKey = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tag = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedWishlistItemsCompanion.insert({
    required String id,
    required String tripId,
    this.cityKey = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.type = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.tag = const Value.absent(),
    this.guideRef = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SharedWishlistItem> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? cityKey,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? type,
    Expression<int>? durationMin,
    Expression<String>? tag,
    Expression<String>? guideRef,
    Expression<String>? note,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (cityKey != null) 'city_key': cityKey,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (type != null) 'type': type,
      if (durationMin != null) 'duration_min': durationMin,
      if (tag != null) 'tag': tag,
      if (guideRef != null) 'guide_ref': guideRef,
      if (note != null) 'note': note,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedWishlistItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? cityKey,
    Value<String>? name,
    Value<String>? address,
    Value<String>? type,
    Value<int?>? durationMin,
    Value<String?>? tag,
    Value<String?>? guideRef,
    Value<String>? note,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharedWishlistItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      cityKey: cityKey ?? this.cityKey,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      durationMin: durationMin ?? this.durationMin,
      tag: tag ?? this.tag,
      guideRef: guideRef ?? this.guideRef,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (cityKey.present) {
      map['city_key'] = Variable<String>(cityKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (guideRef.present) {
      map['guide_ref'] = Variable<String>(guideRef.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedWishlistItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('cityKey: $cityKey, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('type: $type, ')
          ..write('durationMin: $durationMin, ')
          ..write('tag: $tag, ')
          ..write('guideRef: $guideRef, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubBudgetsTable extends SubBudgets
    with TableInfo<$SubBudgetsTable, SubBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(""),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    categoryKey,
    amount,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sub_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
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
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubBudget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SubBudgetsTable createAlias(String alias) {
    return $SubBudgetsTable(attachedDatabase, alias);
  }
}

class SubBudget extends DataClass implements Insertable<SubBudget> {
  final String id;
  final String groupId;
  final String categoryKey;
  final int amount;
  final int createdAt;
  final int updatedAt;
  const SubBudget({
    required this.id,
    required this.groupId,
    required this.categoryKey,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['category_key'] = Variable<String>(categoryKey);
    map['amount'] = Variable<int>(amount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SubBudgetsCompanion toCompanion(bool nullToAbsent) {
    return SubBudgetsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      categoryKey: Value(categoryKey),
      amount: Value(amount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SubBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubBudget(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      amount: serializer.fromJson<int>(json['amount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'amount': serializer.toJson<int>(amount),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SubBudget copyWith({
    String? id,
    String? groupId,
    String? categoryKey,
    int? amount,
    int? createdAt,
    int? updatedAt,
  }) => SubBudget(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    categoryKey: categoryKey ?? this.categoryKey,
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SubBudget copyWithCompanion(SubBudgetsCompanion data) {
    return SubBudget(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      amount: data.amount.present ? data.amount.value : this.amount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubBudget(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, categoryKey, amount, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubBudget &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.categoryKey == this.categoryKey &&
          other.amount == this.amount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SubBudgetsCompanion extends UpdateCompanion<SubBudget> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> categoryKey;
  final Value<int> amount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SubBudgetsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.amount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubBudgetsCompanion.insert({
    required String id,
    required String groupId,
    this.categoryKey = const Value.absent(),
    required int amount,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       amount = Value(amount),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SubBudget> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? categoryKey,
    Expression<int>? amount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (categoryKey != null) 'category_key': categoryKey,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubBudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? categoryKey,
    Value<int>? amount,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SubBudgetsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      categoryKey: categoryKey ?? this.categoryKey,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $MembersTable members = $MembersTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripItemsTable tripItems = $TripItemsTable(this);
  late final $AlbumPhotosTable albumPhotos = $AlbumPhotosTable(this);
  late final $ChecklistItemsTable checklistItems = $ChecklistItemsTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $SettlementsTable settlements = $SettlementsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $SharedGroupsTable sharedGroups = $SharedGroupsTable(this);
  late final $SharedMembersTable sharedMembers = $SharedMembersTable(this);
  late final $SharedExpensesTable sharedExpenses = $SharedExpensesTable(this);
  late final $SharedSettlementsTable sharedSettlements =
      $SharedSettlementsTable(this);
  late final $TravelSpacesTable travelSpaces = $TravelSpacesTable(this);
  late final $SpaceMembersTable spaceMembers = $SpaceMembersTable(this);
  late final $SpaceEventsTable spaceEvents = $SpaceEventsTable(this);
  late final $SharedTripsTable sharedTrips = $SharedTripsTable(this);
  late final $SharedTripItemsTable sharedTripItems = $SharedTripItemsTable(
    this,
  );
  late final $FundsTable funds = $FundsTable(this);
  late final $InboxItemsTable inboxItems = $InboxItemsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $ConflictRecordsTable conflictRecords = $ConflictRecordsTable(
    this,
  );
  late final $WishlistItemsTable wishlistItems = $WishlistItemsTable(this);
  late final $SharedWishlistItemsTable sharedWishlistItems =
      $SharedWishlistItemsTable(this);
  late final $SubBudgetsTable subBudgets = $SubBudgetsTable(this);
  late final TripsDao tripsDao = TripsDao(this as AppDatabase);
  late final GroupsDao groupsDao = GroupsDao(this as AppDatabase);
  late final ExpensesDao expensesDao = ExpensesDao(this as AppDatabase);
  late final ChecklistDao checklistDao = ChecklistDao(this as AppDatabase);
  late final AlbumDao albumDao = AlbumDao(this as AppDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final WishlistDao wishlistDao = WishlistDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    groups,
    members,
    trips,
    tripItems,
    albumPhotos,
    checklistItems,
    expenses,
    settlements,
    categories,
    syncOutbox,
    syncMeta,
    sharedGroups,
    sharedMembers,
    sharedExpenses,
    sharedSettlements,
    travelSpaces,
    spaceMembers,
    spaceEvents,
    sharedTrips,
    sharedTripItems,
    funds,
    inboxItems,
    auditLogs,
    conflictRecords,
    wishlistItems,
    sharedWishlistItems,
    subBudgets,
  ];
}

typedef $$GroupsTableCreateCompanionBuilder = GroupsCompanion Function({
  required String id,
  required String name,
  Value<String> icon,
  Value<bool> budgetEnabled,
  Value<int?> budgetCents,
  Value<bool> archived,
  Value<int?> archivedAtMs,
  Value<String> kind,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$GroupsTableUpdateCompanionBuilder = GroupsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> icon,
  Value<bool> budgetEnabled,
  Value<int?> budgetCents,
  Value<bool> archived,
  Value<int?> archivedAtMs,
  Value<String> kind,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$GroupsTableReferences
    extends BaseReferences<_$AppDatabase, $GroupsTable, Group> {
  $$GroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MembersTable, List<Member>> _membersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.members,
    aliasName: 'groups__id__members__group_id',
  );

  $$MembersTableProcessedTableManager get membersRefs {
    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_membersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'groups__id__expenses__group_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SettlementsTable, List<Settlement>>
  _settlementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.settlements,
    aliasName: 'groups__id__settlements__group_id',
  );

  $$SettlementsTableProcessedTableManager get settlementsRefs {
    final manager = $$SettlementsTableTableManager(
      $_db,
      $_db.settlements,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_settlementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FundsTable, List<Fund>> _fundsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.funds,
    aliasName: 'groups__id__funds__group_id',
  );

  $$FundsTableProcessedTableManager get fundsRefs {
    final manager = $$FundsTableTableManager(
      $_db,
      $_db.funds,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fundsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InboxItemsTable, List<InboxItem>>
  _inboxItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inboxItems,
    aliasName: 'groups__id__inbox_items__group_id',
  );

  $$InboxItemsTableProcessedTableManager get inboxItemsRefs {
    final manager = $$InboxItemsTableTableManager(
      $_db,
      $_db.inboxItems,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_inboxItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SubBudgetsTable, List<SubBudget>>
  _subBudgetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subBudgets,
    aliasName: 'groups__id__sub_budgets__group_id',
  );

  $$SubBudgetsTableProcessedTableManager get subBudgetsRefs {
    final manager = $$SubBudgetsTableTableManager(
      $_db,
      $_db.subBudgets,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subBudgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
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

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> membersRefs(
    Expression<bool> Function($$MembersTableFilterComposer f) f,
  ) {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> settlementsRefs(
    Expression<bool> Function($$SettlementsTableFilterComposer f) f,
  ) {
    final $$SettlementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.settlements,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SettlementsTableFilterComposer(
            $db: $db,
            $table: $db.settlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fundsRefs(
    Expression<bool> Function($$FundsTableFilterComposer f) f,
  ) {
    final $$FundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.funds,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FundsTableFilterComposer(
            $db: $db,
            $table: $db.funds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inboxItemsRefs(
    Expression<bool> Function($$InboxItemsTableFilterComposer f) f,
  ) {
    final $$InboxItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItems,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemsTableFilterComposer(
            $db: $db,
            $table: $db.inboxItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subBudgetsRefs(
    Expression<bool> Function($$SubBudgetsTableFilterComposer f) f,
  ) {
    final $$SubBudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subBudgets,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubBudgetsTableFilterComposer(
            $db: $db,
            $table: $db.subBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
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

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
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

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> membersRefs<T extends Object>(
    Expression<T> Function($$MembersTableAnnotationComposer a) f,
  ) {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> settlementsRefs<T extends Object>(
    Expression<T> Function($$SettlementsTableAnnotationComposer a) f,
  ) {
    final $$SettlementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.settlements,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SettlementsTableAnnotationComposer(
            $db: $db,
            $table: $db.settlements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fundsRefs<T extends Object>(
    Expression<T> Function($$FundsTableAnnotationComposer a) f,
  ) {
    final $$FundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.funds,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FundsTableAnnotationComposer(
            $db: $db,
            $table: $db.funds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inboxItemsRefs<T extends Object>(
    Expression<T> Function($$InboxItemsTableAnnotationComposer a) f,
  ) {
    final $$InboxItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItems,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.inboxItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> subBudgetsRefs<T extends Object>(
    Expression<T> Function($$SubBudgetsTableAnnotationComposer a) f,
  ) {
    final $$SubBudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subBudgets,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubBudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.subBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, $$GroupsTableReferences),
          Group,
          PrefetchHooks Function({
            bool membersRefs,
            bool expensesRefs,
            bool settlementsRefs,
            bool fundsRefs,
            bool inboxItemsRefs,
            bool subBudgetsRefs,
          })
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> budgetEnabled = const Value.absent(),
                Value<int?> budgetCents = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> archivedAtMs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                icon: icon,
                budgetEnabled: budgetEnabled,
                budgetCents: budgetCents,
                archived: archived,
                archivedAtMs: archivedAtMs,
                kind: kind,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> icon = const Value.absent(),
                Value<bool> budgetEnabled = const Value.absent(),
                Value<int?> budgetCents = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> archivedAtMs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                budgetEnabled: budgetEnabled,
                budgetCents: budgetCents,
                archived: archived,
                archivedAtMs: archivedAtMs,
                kind: kind,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupsTable, Group>(table),
                  $$GroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                membersRefs = false,
                expensesRefs = false,
                settlementsRefs = false,
                fundsRefs = false,
                inboxItemsRefs = false,
                subBudgetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (membersRefs) db.members,
                    if (expensesRefs) db.expenses,
                    if (settlementsRefs) db.settlements,
                    if (fundsRefs) db.funds,
                    if (inboxItemsRefs) db.inboxItems,
                    if (subBudgetsRefs) db.subBudgets,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (membersRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Member>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._membersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).membersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expensesRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Expense>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (settlementsRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          Settlement
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._settlementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).settlementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (fundsRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Fund>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._fundsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(db, table, p0).fundsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (inboxItemsRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          InboxItem
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._inboxItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).inboxItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subBudgetsRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          SubBudget
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._subBudgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).subBudgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, $$GroupsTableReferences),
      Group,
      PrefetchHooks Function({
        bool membersRefs,
        bool expensesRefs,
        bool settlementsRefs,
        bool fundsRefs,
        bool inboxItemsRefs,
        bool subBudgetsRefs,
      })
    >;
typedef $$MembersTableCreateCompanionBuilder = MembersCompanion Function({
  required String id,
  required String groupId,
  required String name,
  Value<int> colorIndex,
  Value<bool> archived,
  required int createdAt,
  Value<int> rowid,
});
typedef $$MembersTableUpdateCompanionBuilder = MembersCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> name,
  Value<int> colorIndex,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$MembersTableReferences
    extends BaseReferences<_$AppDatabase, $MembersTable, Member> {
  $$MembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('members__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MembersTableFilterComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableFilterComposer({
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

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembersTableOrderingComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableOrderingComposer({
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

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableAnnotationComposer({
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

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembersTable,
          Member,
          $$MembersTableFilterComposer,
          $$MembersTableOrderingComposer,
          $$MembersTableAnnotationComposer,
          $$MembersTableCreateCompanionBuilder,
          $$MembersTableUpdateCompanionBuilder,
          (Member, $$MembersTableReferences),
          Member,
          PrefetchHooks Function({bool groupId})
        > {
  $$MembersTableTableManager(_$AppDatabase db, $MembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion(
                id: id,
                groupId: groupId,
                name: name,
                colorIndex: colorIndex,
                archived: archived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                colorIndex: colorIndex,
                archived: archived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MembersTable, Member>(table),
                  $$MembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$MembersTableReferences._groupIdTable(
                          db,
                        ),
                        referencedColumn: $$MembersTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembersTable,
      Member,
      $$MembersTableFilterComposer,
      $$MembersTableOrderingComposer,
      $$MembersTableAnnotationComposer,
      $$MembersTableCreateCompanionBuilder,
      $$MembersTableUpdateCompanionBuilder,
      (Member, $$MembersTableReferences),
      Member,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$TripsTableCreateCompanionBuilder = TripsCompanion Function({
  required String id,
  required String name,
  Value<String> destination,
  Value<String> emoji,
  Value<String> cover,
  Value<int> startEpochDay,
  Value<int> endEpochDay,
  Value<String> note,
  Value<String?> groupId,
  Value<bool> archived,
  Value<String> pace,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TripsTableUpdateCompanionBuilder = TripsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> destination,
  Value<String> emoji,
  Value<String> cover,
  Value<int> startEpochDay,
  Value<int> endEpochDay,
  Value<String> note,
  Value<String?> groupId,
  Value<bool> archived,
  Value<String> pace,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripItemsTable, List<TripItem>>
  _tripItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripItems,
    aliasName: 'trips__id__trip_items__trip_id',
  );

  $$TripItemsTableProcessedTableManager get tripItemsRefs {
    final manager = $$TripItemsTableTableManager(
      $_db,
      $_db.tripItems,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AlbumPhotosTable, List<AlbumPhoto>>
  _albumPhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.albumPhotos,
    aliasName: 'trips__id__album_photos__trip_id',
  );

  $$AlbumPhotosTableProcessedTableManager get albumPhotosRefs {
    final manager = $$AlbumPhotosTableTableManager(
      $_db,
      $_db.albumPhotos,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_albumPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WishlistItemsTable, List<WishlistItem>>
  _wishlistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wishlistItems,
    aliasName: 'trips__id__wishlist_items__trip_id',
  );

  $$WishlistItemsTableProcessedTableManager get wishlistItemsRefs {
    final manager = $$WishlistItemsTableTableManager(
      $_db,
      $_db.wishlistItems,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wishlistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
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

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripItemsRefs(
    Expression<bool> Function($$TripItemsTableFilterComposer f) f,
  ) {
    final $$TripItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripItemsTableFilterComposer(
            $db: $db,
            $table: $db.tripItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> albumPhotosRefs(
    Expression<bool> Function($$AlbumPhotosTableFilterComposer f) f,
  ) {
    final $$AlbumPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albumPhotos,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumPhotosTableFilterComposer(
            $db: $db,
            $table: $db.albumPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wishlistItemsRefs(
    Expression<bool> Function($$WishlistItemsTableFilterComposer f) f,
  ) {
    final $$WishlistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlistItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistItemsTableFilterComposer(
            $db: $db,
            $table: $db.wishlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
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

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
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

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get pace =>
      $composableBuilder(column: $table.pace, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tripItemsRefs<T extends Object>(
    Expression<T> Function($$TripItemsTableAnnotationComposer a) f,
  ) {
    final $$TripItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> albumPhotosRefs<T extends Object>(
    Expression<T> Function($$AlbumPhotosTableAnnotationComposer a) f,
  ) {
    final $$AlbumPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albumPhotos,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.albumPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wishlistItemsRefs<T extends Object>(
    Expression<T> Function($$WishlistItemsTableAnnotationComposer a) f,
  ) {
    final $$WishlistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlistItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.wishlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({
            bool tripItemsRefs,
            bool albumPhotosRefs,
            bool wishlistItemsRefs,
          })
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<int> startEpochDay = const Value.absent(),
                Value<int> endEpochDay = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> pace = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                name: name,
                destination: destination,
                emoji: emoji,
                cover: cover,
                startEpochDay: startEpochDay,
                endEpochDay: endEpochDay,
                note: note,
                groupId: groupId,
                archived: archived,
                pace: pace,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> destination = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<int> startEpochDay = const Value.absent(),
                Value<int> endEpochDay = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> pace = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                name: name,
                destination: destination,
                emoji: emoji,
                cover: cover,
                startEpochDay: startEpochDay,
                endEpochDay: endEpochDay,
                note: note,
                groupId: groupId,
                archived: archived,
                pace: pace,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TripsTable, Trip>(table),
                  $$TripsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripItemsRefs = false,
                albumPhotosRefs = false,
                wishlistItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripItemsRefs) db.tripItems,
                    if (albumPhotosRefs) db.albumPhotos,
                    if (wishlistItemsRefs) db.wishlistItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripItemsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripItem>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (albumPhotosRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          AlbumPhoto
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._albumPhotosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).albumPhotosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wishlistItemsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          WishlistItem
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._wishlistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).wishlistItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({
        bool tripItemsRefs,
        bool albumPhotosRefs,
        bool wishlistItemsRefs,
      })
    >;
typedef $$TripItemsTableCreateCompanionBuilder = TripItemsCompanion Function({
  required String id,
  required String tripId,
  Value<int> dateEpochDay,
  Value<String> type,
  Value<String> name,
  Value<String> address,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> photoUri,
  Value<int?> startTimeMin,
  Value<int?> durationMin,
  Value<int?> costCents,
  Value<String> costCurrency,
  Value<String> note,
  Value<String> fromName,
  Value<String> fromAddress,
  Value<double?> fromLat,
  Value<double?> fromLng,
  Value<String> toName,
  Value<String> toAddress,
  Value<double?> toLat,
  Value<double?> toLng,
  Value<String?> flightNo,
  Value<int> sortOrder,
  Value<String?> guideRef,
  Value<String?> backupOf,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TripItemsTableUpdateCompanionBuilder = TripItemsCompanion Function({
  Value<String> id,
  Value<String> tripId,
  Value<int> dateEpochDay,
  Value<String> type,
  Value<String> name,
  Value<String> address,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> photoUri,
  Value<int?> startTimeMin,
  Value<int?> durationMin,
  Value<int?> costCents,
  Value<String> costCurrency,
  Value<String> note,
  Value<String> fromName,
  Value<String> fromAddress,
  Value<double?> fromLat,
  Value<double?> fromLng,
  Value<String> toName,
  Value<String> toAddress,
  Value<double?> toLat,
  Value<double?> toLng,
  Value<String?> flightNo,
  Value<int> sortOrder,
  Value<String?> guideRef,
  Value<String?> backupOf,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$TripItemsTableReferences
    extends BaseReferences<_$AppDatabase, $TripItemsTable, TripItem> {
  $$TripItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_items__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TripItemsTable> {
  $$TripItemsTableFilterComposer({
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

  ColumnFilters<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUri => $composableBuilder(
    column: $table.photoUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLng => $composableBuilder(
    column: $table.fromLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toName => $composableBuilder(
    column: $table.toName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAddress => $composableBuilder(
    column: $table.toAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLng => $composableBuilder(
    column: $table.toLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flightNo => $composableBuilder(
    column: $table.flightNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupOf => $composableBuilder(
    column: $table.backupOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripItemsTable> {
  $$TripItemsTableOrderingComposer({
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

  ColumnOrderings<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUri => $composableBuilder(
    column: $table.photoUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fromLng => $composableBuilder(
    column: $table.fromLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toName => $composableBuilder(
    column: $table.toName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAddress => $composableBuilder(
    column: $table.toAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLng => $composableBuilder(
    column: $table.toLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flightNo => $composableBuilder(
    column: $table.flightNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupOf => $composableBuilder(
    column: $table.backupOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripItemsTable> {
  $$TripItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get photoUri =>
      $composableBuilder(column: $table.photoUri, builder: (column) => column);

  GeneratedColumn<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => column);

  GeneratedColumn<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get fromName =>
      $composableBuilder(column: $table.fromName, builder: (column) => column);

  GeneratedColumn<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fromLat =>
      $composableBuilder(column: $table.fromLat, builder: (column) => column);

  GeneratedColumn<double> get fromLng =>
      $composableBuilder(column: $table.fromLng, builder: (column) => column);

  GeneratedColumn<String> get toName =>
      $composableBuilder(column: $table.toName, builder: (column) => column);

  GeneratedColumn<String> get toAddress =>
      $composableBuilder(column: $table.toAddress, builder: (column) => column);

  GeneratedColumn<double> get toLat =>
      $composableBuilder(column: $table.toLat, builder: (column) => column);

  GeneratedColumn<double> get toLng =>
      $composableBuilder(column: $table.toLng, builder: (column) => column);

  GeneratedColumn<String> get flightNo =>
      $composableBuilder(column: $table.flightNo, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get guideRef =>
      $composableBuilder(column: $table.guideRef, builder: (column) => column);

  GeneratedColumn<String> get backupOf =>
      $composableBuilder(column: $table.backupOf, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripItemsTable,
          TripItem,
          $$TripItemsTableFilterComposer,
          $$TripItemsTableOrderingComposer,
          $$TripItemsTableAnnotationComposer,
          $$TripItemsTableCreateCompanionBuilder,
          $$TripItemsTableUpdateCompanionBuilder,
          (TripItem, $$TripItemsTableReferences),
          TripItem,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripItemsTableTableManager(_$AppDatabase db, $TripItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> photoUri = const Value.absent(),
                Value<int?> startTimeMin = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<int?> costCents = const Value.absent(),
                Value<String> costCurrency = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLng = const Value.absent(),
                Value<String> toName = const Value.absent(),
                Value<String> toAddress = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLng = const Value.absent(),
                Value<String?> flightNo = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String?> backupOf = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripItemsCompanion(
                id: id,
                tripId: tripId,
                dateEpochDay: dateEpochDay,
                type: type,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                photoUri: photoUri,
                startTimeMin: startTimeMin,
                durationMin: durationMin,
                costCents: costCents,
                costCurrency: costCurrency,
                note: note,
                fromName: fromName,
                fromAddress: fromAddress,
                fromLat: fromLat,
                fromLng: fromLng,
                toName: toName,
                toAddress: toAddress,
                toLat: toLat,
                toLng: toLng,
                flightNo: flightNo,
                sortOrder: sortOrder,
                guideRef: guideRef,
                backupOf: backupOf,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> photoUri = const Value.absent(),
                Value<int?> startTimeMin = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<int?> costCents = const Value.absent(),
                Value<String> costCurrency = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLng = const Value.absent(),
                Value<String> toName = const Value.absent(),
                Value<String> toAddress = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLng = const Value.absent(),
                Value<String?> flightNo = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String?> backupOf = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TripItemsCompanion.insert(
                id: id,
                tripId: tripId,
                dateEpochDay: dateEpochDay,
                type: type,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                photoUri: photoUri,
                startTimeMin: startTimeMin,
                durationMin: durationMin,
                costCents: costCents,
                costCurrency: costCurrency,
                note: note,
                fromName: fromName,
                fromAddress: fromAddress,
                fromLat: fromLat,
                fromLng: fromLng,
                toName: toName,
                toAddress: toAddress,
                toLat: toLat,
                toLng: toLng,
                flightNo: flightNo,
                sortOrder: sortOrder,
                guideRef: guideRef,
                backupOf: backupOf,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TripItemsTable, TripItem>(table),
                  $$TripItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tripId,
                        referencedTable: $$TripItemsTableReferences
                            ._tripIdTable(db),
                        referencedColumn: $$TripItemsTableReferences
                            ._tripIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripItemsTable,
      TripItem,
      $$TripItemsTableFilterComposer,
      $$TripItemsTableOrderingComposer,
      $$TripItemsTableAnnotationComposer,
      $$TripItemsTableCreateCompanionBuilder,
      $$TripItemsTableUpdateCompanionBuilder,
      (TripItem, $$TripItemsTableReferences),
      TripItem,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$AlbumPhotosTableCreateCompanionBuilder =
    AlbumPhotosCompanion Function({
      required String id,
      required String tripId,
      required String uri,
      Value<int?> dayEpochDay,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AlbumPhotosTableUpdateCompanionBuilder =
    AlbumPhotosCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> uri,
      Value<int?> dayEpochDay,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$AlbumPhotosTableReferences
    extends BaseReferences<_$AppDatabase, $AlbumPhotosTable, AlbumPhoto> {
  $$AlbumPhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('album_photos__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AlbumPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumPhotosTable> {
  $$AlbumPhotosTableFilterComposer({
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

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayEpochDay => $composableBuilder(
    column: $table.dayEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumPhotosTable> {
  $$AlbumPhotosTableOrderingComposer({
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

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayEpochDay => $composableBuilder(
    column: $table.dayEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumPhotosTable> {
  $$AlbumPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<int> get dayEpochDay => $composableBuilder(
    column: $table.dayEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumPhotosTable,
          AlbumPhoto,
          $$AlbumPhotosTableFilterComposer,
          $$AlbumPhotosTableOrderingComposer,
          $$AlbumPhotosTableAnnotationComposer,
          $$AlbumPhotosTableCreateCompanionBuilder,
          $$AlbumPhotosTableUpdateCompanionBuilder,
          (AlbumPhoto, $$AlbumPhotosTableReferences),
          AlbumPhoto,
          PrefetchHooks Function({bool tripId})
        > {
  $$AlbumPhotosTableTableManager(_$AppDatabase db, $AlbumPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<int?> dayEpochDay = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumPhotosCompanion(
                id: id,
                tripId: tripId,
                uri: uri,
                dayEpochDay: dayEpochDay,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String uri,
                Value<int?> dayEpochDay = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AlbumPhotosCompanion.insert(
                id: id,
                tripId: tripId,
                uri: uri,
                dayEpochDay: dayEpochDay,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlbumPhotosTable, AlbumPhoto>(table),
                  $$AlbumPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tripId,
                        referencedTable: $$AlbumPhotosTableReferences
                            ._tripIdTable(db),
                        referencedColumn: $$AlbumPhotosTableReferences
                            ._tripIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AlbumPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumPhotosTable,
      AlbumPhoto,
      $$AlbumPhotosTableFilterComposer,
      $$AlbumPhotosTableOrderingComposer,
      $$AlbumPhotosTableAnnotationComposer,
      $$AlbumPhotosTableCreateCompanionBuilder,
      $$AlbumPhotosTableUpdateCompanionBuilder,
      (AlbumPhoto, $$AlbumPhotosTableReferences),
      AlbumPhoto,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$ChecklistItemsTableCreateCompanionBuilder =
    ChecklistItemsCompanion Function({
      required String id,
      Value<String> scope,
      Value<String?> tripId,
      Value<String> category,
      Value<String> label,
      Value<bool> done,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ChecklistItemsTableUpdateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String?> tripId,
      Value<String> category,
      Value<String> label,
      Value<bool> done,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableFilterComposer({
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

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableOrderingComposer({
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

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistItemsTable,
          ChecklistItem,
          $$ChecklistItemsTableFilterComposer,
          $$ChecklistItemsTableOrderingComposer,
          $$ChecklistItemsTableAnnotationComposer,
          $$ChecklistItemsTableCreateCompanionBuilder,
          $$ChecklistItemsTableUpdateCompanionBuilder,
          (
            ChecklistItem,
            BaseReferences<_$AppDatabase, $ChecklistItemsTable, ChecklistItem>,
          ),
          ChecklistItem,
          PrefetchHooks Function()
        > {
  $$ChecklistItemsTableTableManager(
    _$AppDatabase db,
    $ChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion(
                id: id,
                scope: scope,
                tripId: tripId,
                category: category,
                label: label,
                done: done,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> scope = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion.insert(
                id: id,
                scope: scope,
                tripId: tripId,
                category: category,
                label: label,
                done: done,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChecklistItemsTable, ChecklistItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChecklistItemsTable,
                    ChecklistItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistItemsTable,
      ChecklistItem,
      $$ChecklistItemsTableFilterComposer,
      $$ChecklistItemsTableOrderingComposer,
      $$ChecklistItemsTableAnnotationComposer,
      $$ChecklistItemsTableCreateCompanionBuilder,
      $$ChecklistItemsTableUpdateCompanionBuilder,
      (
        ChecklistItem,
        BaseReferences<_$AppDatabase, $ChecklistItemsTable, ChecklistItem>,
      ),
      ChecklistItem,
      PrefetchHooks Function()
    >;
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required String groupId,
  Value<int> dateEpochDay,
  Value<String> title,
  Value<String> categoryKey,
  Value<String> type,
  Value<int> amountCents,
  Value<String> currency,
  Value<double> rate,
  Value<int?> amountForeignCents,
  Value<String> payersJson,
  Value<String> sharesJson,
  Value<String> shareMode,
  Value<String?> portionsJson,
  Value<String> note,
  Value<String?> settledRoundId,
  Value<String?> tripId,
  Value<String?> tripItemId,
  Value<String?> fundId,
  Value<String?> payMethod,
  required int createdAt,
  Value<int> rowid,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<int> dateEpochDay,
  Value<String> title,
  Value<String> categoryKey,
  Value<String> type,
  Value<int> amountCents,
  Value<String> currency,
  Value<double> rate,
  Value<int?> amountForeignCents,
  Value<String> payersJson,
  Value<String> sharesJson,
  Value<String> shareMode,
  Value<String?> portionsJson,
  Value<String> note,
  Value<String?> settledRoundId,
  Value<String?> tripId,
  Value<String?> tripItemId,
  Value<String?> fundId,
  Value<String?> payMethod,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$ExpensesTableReferences
    extends BaseReferences<_$AppDatabase, $ExpensesTable, Expense> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('expenses__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
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

  ColumnFilters<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareMode => $composableBuilder(
    column: $table.shareMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fundId => $composableBuilder(
    column: $table.fundId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payMethod => $composableBuilder(
    column: $table.payMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
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

  ColumnOrderings<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareMode => $composableBuilder(
    column: $table.shareMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fundId => $composableBuilder(
    column: $table.fundId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payMethod => $composableBuilder(
    column: $table.payMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shareMode =>
      $composableBuilder(column: $table.shareMode, builder: (column) => column);

  GeneratedColumn<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fundId =>
      $composableBuilder(column: $table.fundId, builder: (column) => column);

  GeneratedColumn<String> get payMethod =>
      $composableBuilder(column: $table.payMethod, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, $$ExpensesTableReferences),
          Expense,
          PrefetchHooks Function({bool groupId})
        > {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<int?> amountForeignCents = const Value.absent(),
                Value<String> payersJson = const Value.absent(),
                Value<String> sharesJson = const Value.absent(),
                Value<String> shareMode = const Value.absent(),
                Value<String?> portionsJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> settledRoundId = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> tripItemId = const Value.absent(),
                Value<String?> fundId = const Value.absent(),
                Value<String?> payMethod = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                groupId: groupId,
                dateEpochDay: dateEpochDay,
                title: title,
                categoryKey: categoryKey,
                type: type,
                amountCents: amountCents,
                currency: currency,
                rate: rate,
                amountForeignCents: amountForeignCents,
                payersJson: payersJson,
                sharesJson: sharesJson,
                shareMode: shareMode,
                portionsJson: portionsJson,
                note: note,
                settledRoundId: settledRoundId,
                tripId: tripId,
                tripItemId: tripItemId,
                fundId: fundId,
                payMethod: payMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<int?> amountForeignCents = const Value.absent(),
                Value<String> payersJson = const Value.absent(),
                Value<String> sharesJson = const Value.absent(),
                Value<String> shareMode = const Value.absent(),
                Value<String?> portionsJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> settledRoundId = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> tripItemId = const Value.absent(),
                Value<String?> fundId = const Value.absent(),
                Value<String?> payMethod = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                groupId: groupId,
                dateEpochDay: dateEpochDay,
                title: title,
                categoryKey: categoryKey,
                type: type,
                amountCents: amountCents,
                currency: currency,
                rate: rate,
                amountForeignCents: amountForeignCents,
                payersJson: payersJson,
                sharesJson: sharesJson,
                shareMode: shareMode,
                portionsJson: portionsJson,
                note: note,
                settledRoundId: settledRoundId,
                tripId: tripId,
                tripItemId: tripItemId,
                fundId: fundId,
                payMethod: payMethod,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExpensesTable, Expense>(table),
                  $$ExpensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$ExpensesTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$ExpensesTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, $$ExpensesTableReferences),
      Expense,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$SettlementsTableCreateCompanionBuilder =
    SettlementsCompanion Function({
      required String id,
      required String groupId,
      Value<String> status,
      Value<String> transfersJson,
      Value<String> expenseIdsJson,
      Value<int> roundNo,
      Value<String> strategy,
      required int createdAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$SettlementsTableUpdateCompanionBuilder =
    SettlementsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> status,
      Value<String> transfersJson,
      Value<String> expenseIdsJson,
      Value<int> roundNo,
      Value<String> strategy,
      Value<int> createdAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });

final class $$SettlementsTableReferences
    extends BaseReferences<_$AppDatabase, $SettlementsTable, Settlement> {
  $$SettlementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('settlements__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SettlementsTableFilterComposer
    extends Composer<_$AppDatabase, $SettlementsTable> {
  $$SettlementsTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundNo => $composableBuilder(
    column: $table.roundNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strategy => $composableBuilder(
    column: $table.strategy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SettlementsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettlementsTable> {
  $$SettlementsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundNo => $composableBuilder(
    column: $table.roundNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strategy => $composableBuilder(
    column: $table.strategy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SettlementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettlementsTable> {
  $$SettlementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roundNo =>
      $composableBuilder(column: $table.roundNo, builder: (column) => column);

  GeneratedColumn<String> get strategy =>
      $composableBuilder(column: $table.strategy, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SettlementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettlementsTable,
          Settlement,
          $$SettlementsTableFilterComposer,
          $$SettlementsTableOrderingComposer,
          $$SettlementsTableAnnotationComposer,
          $$SettlementsTableCreateCompanionBuilder,
          $$SettlementsTableUpdateCompanionBuilder,
          (Settlement, $$SettlementsTableReferences),
          Settlement,
          PrefetchHooks Function({bool groupId})
        > {
  $$SettlementsTableTableManager(_$AppDatabase db, $SettlementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettlementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettlementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettlementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> transfersJson = const Value.absent(),
                Value<String> expenseIdsJson = const Value.absent(),
                Value<int> roundNo = const Value.absent(),
                Value<String> strategy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettlementsCompanion(
                id: id,
                groupId: groupId,
                status: status,
                transfersJson: transfersJson,
                expenseIdsJson: expenseIdsJson,
                roundNo: roundNo,
                strategy: strategy,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String> status = const Value.absent(),
                Value<String> transfersJson = const Value.absent(),
                Value<String> expenseIdsJson = const Value.absent(),
                Value<int> roundNo = const Value.absent(),
                Value<String> strategy = const Value.absent(),
                required int createdAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettlementsCompanion.insert(
                id: id,
                groupId: groupId,
                status: status,
                transfersJson: transfersJson,
                expenseIdsJson: expenseIdsJson,
                roundNo: roundNo,
                strategy: strategy,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettlementsTable, Settlement>(table),
                  $$SettlementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$SettlementsTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$SettlementsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SettlementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettlementsTable,
      Settlement,
      $$SettlementsTableFilterComposer,
      $$SettlementsTableOrderingComposer,
      $$SettlementsTableAnnotationComposer,
      $$SettlementsTableCreateCompanionBuilder,
      $$SettlementsTableUpdateCompanionBuilder,
      (Settlement, $$SettlementsTableReferences),
      Settlement,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String key,
  Value<String> name,
  Value<String> icon,
  Value<bool> builtin,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> key,
  Value<String> name,
  Value<String> icon,
  Value<bool> builtin,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get builtin => $composableBuilder(
    column: $table.builtin,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get builtin => $composableBuilder(
    column: $table.builtin,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get builtin =>
      $composableBuilder(column: $table.builtin, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> builtin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                key: key,
                name: name,
                icon: icon,
                builtin: builtin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> builtin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                key: key,
                name: name,
                icon: icon,
                builtin: builtin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<_$AppDatabase, $CategoriesTable, Category>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String entity,
  required String rowId,
  required String op,
  required int updatedMs,
  Value<int> attemptCount,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> entity,
  Value<String> rowId,
  Value<String> op,
  Value<int> updatedMs,
  Value<int> attemptCount,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                entity: entity,
                rowId: rowId,
                op: op,
                updatedMs: updatedMs,
                attemptCount: attemptCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String rowId,
                required String op,
                required int updatedMs,
                Value<int> attemptCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                entity: entity,
                rowId: rowId,
                op: op,
                updatedMs: updatedMs,
                attemptCount: attemptCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTable,
                    SyncOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String entity,
  Value<int> lastPulledMs,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> entity,
  Value<int> lastPulledMs,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledMs => $composableBuilder(
    column: $table.lastPulledMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledMs => $composableBuilder(
    column: $table.lastPulledMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<int> get lastPulledMs => $composableBuilder(
    column: $table.lastPulledMs,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<int> lastPulledMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion(
                entity: entity,
                lastPulledMs: lastPulledMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                Value<int> lastPulledMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                entity: entity,
                lastPulledMs: lastPulledMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetaData>(table),
                  BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;
typedef $$SharedGroupsTableCreateCompanionBuilder =
    SharedGroupsCompanion Function({
      required String id,
      required String name,
      Value<String> icon,
      Value<bool> budgetEnabled,
      Value<int?> budgetCents,
      Value<bool> archived,
      Value<int?> archivedAtMs,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SharedGroupsTableUpdateCompanionBuilder =
    SharedGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> icon,
      Value<bool> budgetEnabled,
      Value<int?> budgetCents,
      Value<bool> archived,
      Value<int?> archivedAtMs,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SharedGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedGroupsTable> {
  $$SharedGroupsTableFilterComposer({
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

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedGroupsTable> {
  $$SharedGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedGroupsTable> {
  $$SharedGroupsTableAnnotationComposer({
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

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get budgetEnabled => $composableBuilder(
    column: $table.budgetEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get budgetCents => $composableBuilder(
    column: $table.budgetCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get archivedAtMs => $composableBuilder(
    column: $table.archivedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedGroupsTable,
          SharedGroup,
          $$SharedGroupsTableFilterComposer,
          $$SharedGroupsTableOrderingComposer,
          $$SharedGroupsTableAnnotationComposer,
          $$SharedGroupsTableCreateCompanionBuilder,
          $$SharedGroupsTableUpdateCompanionBuilder,
          (
            SharedGroup,
            BaseReferences<_$AppDatabase, $SharedGroupsTable, SharedGroup>,
          ),
          SharedGroup,
          PrefetchHooks Function()
        > {
  $$SharedGroupsTableTableManager(_$AppDatabase db, $SharedGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> budgetEnabled = const Value.absent(),
                Value<int?> budgetCents = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> archivedAtMs = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedGroupsCompanion(
                id: id,
                name: name,
                icon: icon,
                budgetEnabled: budgetEnabled,
                budgetCents: budgetCents,
                archived: archived,
                archivedAtMs: archivedAtMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> icon = const Value.absent(),
                Value<bool> budgetEnabled = const Value.absent(),
                Value<int?> budgetCents = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> archivedAtMs = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedGroupsCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                budgetEnabled: budgetEnabled,
                budgetCents: budgetCents,
                archived: archived,
                archivedAtMs: archivedAtMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedGroupsTable, SharedGroup>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedGroupsTable,
                    SharedGroup
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedGroupsTable,
      SharedGroup,
      $$SharedGroupsTableFilterComposer,
      $$SharedGroupsTableOrderingComposer,
      $$SharedGroupsTableAnnotationComposer,
      $$SharedGroupsTableCreateCompanionBuilder,
      $$SharedGroupsTableUpdateCompanionBuilder,
      (
        SharedGroup,
        BaseReferences<_$AppDatabase, $SharedGroupsTable, SharedGroup>,
      ),
      SharedGroup,
      PrefetchHooks Function()
    >;
typedef $$SharedMembersTableCreateCompanionBuilder =
    SharedMembersCompanion Function({
      required String id,
      required String groupId,
      required String name,
      Value<int> colorIndex,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SharedMembersTableUpdateCompanionBuilder =
    SharedMembersCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> name,
      Value<int> colorIndex,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SharedMembersTableFilterComposer
    extends Composer<_$AppDatabase, $SharedMembersTable> {
  $$SharedMembersTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedMembersTable> {
  $$SharedMembersTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedMembersTable> {
  $$SharedMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SharedMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedMembersTable,
          SharedMember,
          $$SharedMembersTableFilterComposer,
          $$SharedMembersTableOrderingComposer,
          $$SharedMembersTableAnnotationComposer,
          $$SharedMembersTableCreateCompanionBuilder,
          $$SharedMembersTableUpdateCompanionBuilder,
          (
            SharedMember,
            BaseReferences<_$AppDatabase, $SharedMembersTable, SharedMember>,
          ),
          SharedMember,
          PrefetchHooks Function()
        > {
  $$SharedMembersTableTableManager(_$AppDatabase db, $SharedMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedMembersCompanion(
                id: id,
                groupId: groupId,
                name: name,
                colorIndex: colorIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedMembersCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                colorIndex: colorIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedMembersTable, SharedMember>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedMembersTable,
                    SharedMember
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedMembersTable,
      SharedMember,
      $$SharedMembersTableFilterComposer,
      $$SharedMembersTableOrderingComposer,
      $$SharedMembersTableAnnotationComposer,
      $$SharedMembersTableCreateCompanionBuilder,
      $$SharedMembersTableUpdateCompanionBuilder,
      (
        SharedMember,
        BaseReferences<_$AppDatabase, $SharedMembersTable, SharedMember>,
      ),
      SharedMember,
      PrefetchHooks Function()
    >;
typedef $$SharedExpensesTableCreateCompanionBuilder =
    SharedExpensesCompanion Function({
      required String id,
      required String groupId,
      Value<int> dateEpochDay,
      Value<String> title,
      Value<String> categoryKey,
      Value<String> type,
      Value<int> amountCents,
      Value<String> currency,
      Value<double> rate,
      Value<int?> amountForeignCents,
      Value<String> payersJson,
      Value<String> sharesJson,
      Value<String> shareMode,
      Value<String?> portionsJson,
      Value<String> note,
      Value<String?> settledRoundId,
      Value<String?> tripId,
      Value<String?> tripItemId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SharedExpensesTableUpdateCompanionBuilder =
    SharedExpensesCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<int> dateEpochDay,
      Value<String> title,
      Value<String> categoryKey,
      Value<String> type,
      Value<int> amountCents,
      Value<String> currency,
      Value<double> rate,
      Value<int?> amountForeignCents,
      Value<String> payersJson,
      Value<String> sharesJson,
      Value<String> shareMode,
      Value<String?> portionsJson,
      Value<String> note,
      Value<String?> settledRoundId,
      Value<String?> tripId,
      Value<String?> tripItemId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SharedExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $SharedExpensesTable> {
  $$SharedExpensesTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareMode => $composableBuilder(
    column: $table.shareMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedExpensesTable> {
  $$SharedExpensesTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareMode => $composableBuilder(
    column: $table.shareMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedExpensesTable> {
  $$SharedExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<int> get amountForeignCents => $composableBuilder(
    column: $table.amountForeignCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payersJson => $composableBuilder(
    column: $table.payersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sharesJson => $composableBuilder(
    column: $table.sharesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shareMode =>
      $composableBuilder(column: $table.shareMode, builder: (column) => column);

  GeneratedColumn<String> get portionsJson => $composableBuilder(
    column: $table.portionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get settledRoundId => $composableBuilder(
    column: $table.settledRoundId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get tripItemId => $composableBuilder(
    column: $table.tripItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SharedExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedExpensesTable,
          SharedExpense,
          $$SharedExpensesTableFilterComposer,
          $$SharedExpensesTableOrderingComposer,
          $$SharedExpensesTableAnnotationComposer,
          $$SharedExpensesTableCreateCompanionBuilder,
          $$SharedExpensesTableUpdateCompanionBuilder,
          (
            SharedExpense,
            BaseReferences<_$AppDatabase, $SharedExpensesTable, SharedExpense>,
          ),
          SharedExpense,
          PrefetchHooks Function()
        > {
  $$SharedExpensesTableTableManager(
    _$AppDatabase db,
    $SharedExpensesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<int?> amountForeignCents = const Value.absent(),
                Value<String> payersJson = const Value.absent(),
                Value<String> sharesJson = const Value.absent(),
                Value<String> shareMode = const Value.absent(),
                Value<String?> portionsJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> settledRoundId = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> tripItemId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedExpensesCompanion(
                id: id,
                groupId: groupId,
                dateEpochDay: dateEpochDay,
                title: title,
                categoryKey: categoryKey,
                type: type,
                amountCents: amountCents,
                currency: currency,
                rate: rate,
                amountForeignCents: amountForeignCents,
                payersJson: payersJson,
                sharesJson: sharesJson,
                shareMode: shareMode,
                portionsJson: portionsJson,
                note: note,
                settledRoundId: settledRoundId,
                tripId: tripId,
                tripItemId: tripItemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<int?> amountForeignCents = const Value.absent(),
                Value<String> payersJson = const Value.absent(),
                Value<String> sharesJson = const Value.absent(),
                Value<String> shareMode = const Value.absent(),
                Value<String?> portionsJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> settledRoundId = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> tripItemId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedExpensesCompanion.insert(
                id: id,
                groupId: groupId,
                dateEpochDay: dateEpochDay,
                title: title,
                categoryKey: categoryKey,
                type: type,
                amountCents: amountCents,
                currency: currency,
                rate: rate,
                amountForeignCents: amountForeignCents,
                payersJson: payersJson,
                sharesJson: sharesJson,
                shareMode: shareMode,
                portionsJson: portionsJson,
                note: note,
                settledRoundId: settledRoundId,
                tripId: tripId,
                tripItemId: tripItemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedExpensesTable, SharedExpense>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedExpensesTable,
                    SharedExpense
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedExpensesTable,
      SharedExpense,
      $$SharedExpensesTableFilterComposer,
      $$SharedExpensesTableOrderingComposer,
      $$SharedExpensesTableAnnotationComposer,
      $$SharedExpensesTableCreateCompanionBuilder,
      $$SharedExpensesTableUpdateCompanionBuilder,
      (
        SharedExpense,
        BaseReferences<_$AppDatabase, $SharedExpensesTable, SharedExpense>,
      ),
      SharedExpense,
      PrefetchHooks Function()
    >;
typedef $$SharedSettlementsTableCreateCompanionBuilder =
    SharedSettlementsCompanion Function({
      required String id,
      required String groupId,
      Value<String> status,
      Value<String> transfersJson,
      Value<String> expenseIdsJson,
      Value<int> roundNo,
      required int createdAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$SharedSettlementsTableUpdateCompanionBuilder =
    SharedSettlementsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> status,
      Value<String> transfersJson,
      Value<String> expenseIdsJson,
      Value<int> roundNo,
      Value<int> createdAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });

class $$SharedSettlementsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedSettlementsTable> {
  $$SharedSettlementsTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundNo => $composableBuilder(
    column: $table.roundNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedSettlementsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedSettlementsTable> {
  $$SharedSettlementsTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundNo => $composableBuilder(
    column: $table.roundNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedSettlementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedSettlementsTable> {
  $$SharedSettlementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get transfersJson => $composableBuilder(
    column: $table.transfersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expenseIdsJson => $composableBuilder(
    column: $table.expenseIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roundNo =>
      $composableBuilder(column: $table.roundNo, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$SharedSettlementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedSettlementsTable,
          SharedSettlement,
          $$SharedSettlementsTableFilterComposer,
          $$SharedSettlementsTableOrderingComposer,
          $$SharedSettlementsTableAnnotationComposer,
          $$SharedSettlementsTableCreateCompanionBuilder,
          $$SharedSettlementsTableUpdateCompanionBuilder,
          (
            SharedSettlement,
            BaseReferences<
              _$AppDatabase,
              $SharedSettlementsTable,
              SharedSettlement
            >,
          ),
          SharedSettlement,
          PrefetchHooks Function()
        > {
  $$SharedSettlementsTableTableManager(
    _$AppDatabase db,
    $SharedSettlementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedSettlementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedSettlementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedSettlementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> transfersJson = const Value.absent(),
                Value<String> expenseIdsJson = const Value.absent(),
                Value<int> roundNo = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedSettlementsCompanion(
                id: id,
                groupId: groupId,
                status: status,
                transfersJson: transfersJson,
                expenseIdsJson: expenseIdsJson,
                roundNo: roundNo,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String> status = const Value.absent(),
                Value<String> transfersJson = const Value.absent(),
                Value<String> expenseIdsJson = const Value.absent(),
                Value<int> roundNo = const Value.absent(),
                required int createdAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedSettlementsCompanion.insert(
                id: id,
                groupId: groupId,
                status: status,
                transfersJson: transfersJson,
                expenseIdsJson: expenseIdsJson,
                roundNo: roundNo,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedSettlementsTable, SharedSettlement>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedSettlementsTable,
                    SharedSettlement
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedSettlementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedSettlementsTable,
      SharedSettlement,
      $$SharedSettlementsTableFilterComposer,
      $$SharedSettlementsTableOrderingComposer,
      $$SharedSettlementsTableAnnotationComposer,
      $$SharedSettlementsTableCreateCompanionBuilder,
      $$SharedSettlementsTableUpdateCompanionBuilder,
      (
        SharedSettlement,
        BaseReferences<
          _$AppDatabase,
          $SharedSettlementsTable,
          SharedSettlement
        >,
      ),
      SharedSettlement,
      PrefetchHooks Function()
    >;
typedef $$TravelSpacesTableCreateCompanionBuilder =
    TravelSpacesCompanion Function({
      required String id,
      required String name,
      Value<String?> tripId,
      Value<String?> groupId,
      required String createdBy,
      Value<String?> note,
      Value<String> status,
      required int createdMs,
      required int updatedMs,
      Value<int?> deletedMs,
      Value<int> rowid,
    });
typedef $$TravelSpacesTableUpdateCompanionBuilder =
    TravelSpacesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> tripId,
      Value<String?> groupId,
      Value<String> createdBy,
      Value<String?> note,
      Value<String> status,
      Value<int> createdMs,
      Value<int> updatedMs,
      Value<int?> deletedMs,
      Value<int> rowid,
    });

class $$TravelSpacesTableFilterComposer
    extends Composer<_$AppDatabase, $TravelSpacesTable> {
  $$TravelSpacesTableFilterComposer({
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

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedMs => $composableBuilder(
    column: $table.deletedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TravelSpacesTableOrderingComposer
    extends Composer<_$AppDatabase, $TravelSpacesTable> {
  $$TravelSpacesTableOrderingComposer({
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

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedMs => $composableBuilder(
    column: $table.deletedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TravelSpacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TravelSpacesTable> {
  $$TravelSpacesTableAnnotationComposer({
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

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdMs =>
      $composableBuilder(column: $table.createdMs, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);

  GeneratedColumn<int> get deletedMs =>
      $composableBuilder(column: $table.deletedMs, builder: (column) => column);
}

class $$TravelSpacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TravelSpacesTable,
          TravelSpace,
          $$TravelSpacesTableFilterComposer,
          $$TravelSpacesTableOrderingComposer,
          $$TravelSpacesTableAnnotationComposer,
          $$TravelSpacesTableCreateCompanionBuilder,
          $$TravelSpacesTableUpdateCompanionBuilder,
          (
            TravelSpace,
            BaseReferences<_$AppDatabase, $TravelSpacesTable, TravelSpace>,
          ),
          TravelSpace,
          PrefetchHooks Function()
        > {
  $$TravelSpacesTableTableManager(_$AppDatabase db, $TravelSpacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TravelSpacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TravelSpacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TravelSpacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdMs = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<int?> deletedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TravelSpacesCompanion(
                id: id,
                name: name,
                tripId: tripId,
                groupId: groupId,
                createdBy: createdBy,
                note: note,
                status: status,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deletedMs: deletedMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> tripId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                required String createdBy,
                Value<String?> note = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdMs,
                required int updatedMs,
                Value<int?> deletedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TravelSpacesCompanion.insert(
                id: id,
                name: name,
                tripId: tripId,
                groupId: groupId,
                createdBy: createdBy,
                note: note,
                status: status,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deletedMs: deletedMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TravelSpacesTable, TravelSpace>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TravelSpacesTable,
                    TravelSpace
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TravelSpacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TravelSpacesTable,
      TravelSpace,
      $$TravelSpacesTableFilterComposer,
      $$TravelSpacesTableOrderingComposer,
      $$TravelSpacesTableAnnotationComposer,
      $$TravelSpacesTableCreateCompanionBuilder,
      $$TravelSpacesTableUpdateCompanionBuilder,
      (
        TravelSpace,
        BaseReferences<_$AppDatabase, $TravelSpacesTable, TravelSpace>,
      ),
      TravelSpace,
      PrefetchHooks Function()
    >;
typedef $$SpaceMembersTableCreateCompanionBuilder =
    SpaceMembersCompanion Function({
      required String id,
      required String spaceId,
      required String userId,
      Value<String> role,
      Value<String> displayName,
      required int joinedMs,
      required int createdMs,
      required int updatedMs,
      Value<int?> deletedMs,
      Value<int> rowid,
    });
typedef $$SpaceMembersTableUpdateCompanionBuilder =
    SpaceMembersCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> userId,
      Value<String> role,
      Value<String> displayName,
      Value<int> joinedMs,
      Value<int> createdMs,
      Value<int> updatedMs,
      Value<int?> deletedMs,
      Value<int> rowid,
    });

class $$SpaceMembersTableFilterComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinedMs => $composableBuilder(
    column: $table.joinedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedMs => $composableBuilder(
    column: $table.deletedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpaceMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinedMs => $composableBuilder(
    column: $table.joinedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedMs => $composableBuilder(
    column: $table.deletedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpaceMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpaceMembersTable> {
  $$SpaceMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get joinedMs =>
      $composableBuilder(column: $table.joinedMs, builder: (column) => column);

  GeneratedColumn<int> get createdMs =>
      $composableBuilder(column: $table.createdMs, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);

  GeneratedColumn<int> get deletedMs =>
      $composableBuilder(column: $table.deletedMs, builder: (column) => column);
}

class $$SpaceMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpaceMembersTable,
          SpaceMember,
          $$SpaceMembersTableFilterComposer,
          $$SpaceMembersTableOrderingComposer,
          $$SpaceMembersTableAnnotationComposer,
          $$SpaceMembersTableCreateCompanionBuilder,
          $$SpaceMembersTableUpdateCompanionBuilder,
          (
            SpaceMember,
            BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMember>,
          ),
          SpaceMember,
          PrefetchHooks Function()
        > {
  $$SpaceMembersTableTableManager(_$AppDatabase db, $SpaceMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpaceMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpaceMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpaceMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> joinedMs = const Value.absent(),
                Value<int> createdMs = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<int?> deletedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion(
                id: id,
                spaceId: spaceId,
                userId: userId,
                role: role,
                displayName: displayName,
                joinedMs: joinedMs,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deletedMs: deletedMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String userId,
                Value<String> role = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                required int joinedMs,
                required int createdMs,
                required int updatedMs,
                Value<int?> deletedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion.insert(
                id: id,
                spaceId: spaceId,
                userId: userId,
                role: role,
                displayName: displayName,
                joinedMs: joinedMs,
                createdMs: createdMs,
                updatedMs: updatedMs,
                deletedMs: deletedMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpaceMembersTable, SpaceMember>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SpaceMembersTable,
                    SpaceMember
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpaceMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpaceMembersTable,
      SpaceMember,
      $$SpaceMembersTableFilterComposer,
      $$SpaceMembersTableOrderingComposer,
      $$SpaceMembersTableAnnotationComposer,
      $$SpaceMembersTableCreateCompanionBuilder,
      $$SpaceMembersTableUpdateCompanionBuilder,
      (
        SpaceMember,
        BaseReferences<_$AppDatabase, $SpaceMembersTable, SpaceMember>,
      ),
      SpaceMember,
      PrefetchHooks Function()
    >;
typedef $$SpaceEventsTableCreateCompanionBuilder =
    SpaceEventsCompanion Function({
      required String id,
      required String spaceId,
      required String actorUser,
      required String action,
      required String entityKind,
      Value<String?> entityId,
      Value<String> summary,
      required int createdMs,
      required int updatedMs,
      Value<int> rowid,
    });
typedef $$SpaceEventsTableUpdateCompanionBuilder =
    SpaceEventsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> actorUser,
      Value<String> action,
      Value<String> entityKind,
      Value<String?> entityId,
      Value<String> summary,
      Value<int> createdMs,
      Value<int> updatedMs,
      Value<int> rowid,
    });

class $$SpaceEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SpaceEventsTable> {
  $$SpaceEventsTableFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUser => $composableBuilder(
    column: $table.actorUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpaceEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SpaceEventsTable> {
  $$SpaceEventsTableOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUser => $composableBuilder(
    column: $table.actorUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdMs => $composableBuilder(
    column: $table.createdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpaceEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpaceEventsTable> {
  $$SpaceEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get actorUser =>
      $composableBuilder(column: $table.actorUser, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get createdMs =>
      $composableBuilder(column: $table.createdMs, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);
}

class $$SpaceEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpaceEventsTable,
          SpaceEvent,
          $$SpaceEventsTableFilterComposer,
          $$SpaceEventsTableOrderingComposer,
          $$SpaceEventsTableAnnotationComposer,
          $$SpaceEventsTableCreateCompanionBuilder,
          $$SpaceEventsTableUpdateCompanionBuilder,
          (
            SpaceEvent,
            BaseReferences<_$AppDatabase, $SpaceEventsTable, SpaceEvent>,
          ),
          SpaceEvent,
          PrefetchHooks Function()
        > {
  $$SpaceEventsTableTableManager(_$AppDatabase db, $SpaceEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpaceEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpaceEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpaceEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> actorUser = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> entityKind = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<int> createdMs = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceEventsCompanion(
                id: id,
                spaceId: spaceId,
                actorUser: actorUser,
                action: action,
                entityKind: entityKind,
                entityId: entityId,
                summary: summary,
                createdMs: createdMs,
                updatedMs: updatedMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String actorUser,
                required String action,
                required String entityKind,
                Value<String?> entityId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                required int createdMs,
                required int updatedMs,
                Value<int> rowid = const Value.absent(),
              }) => SpaceEventsCompanion.insert(
                id: id,
                spaceId: spaceId,
                actorUser: actorUser,
                action: action,
                entityKind: entityKind,
                entityId: entityId,
                summary: summary,
                createdMs: createdMs,
                updatedMs: updatedMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpaceEventsTable, SpaceEvent>(table),
                  BaseReferences<_$AppDatabase, $SpaceEventsTable, SpaceEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpaceEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpaceEventsTable,
      SpaceEvent,
      $$SpaceEventsTableFilterComposer,
      $$SpaceEventsTableOrderingComposer,
      $$SpaceEventsTableAnnotationComposer,
      $$SpaceEventsTableCreateCompanionBuilder,
      $$SpaceEventsTableUpdateCompanionBuilder,
      (
        SpaceEvent,
        BaseReferences<_$AppDatabase, $SpaceEventsTable, SpaceEvent>,
      ),
      SpaceEvent,
      PrefetchHooks Function()
    >;
typedef $$SharedTripsTableCreateCompanionBuilder =
    SharedTripsCompanion Function({
      required String id,
      required String name,
      Value<String> destination,
      Value<String> emoji,
      Value<String> cover,
      Value<int> startEpochDay,
      Value<int> endEpochDay,
      Value<String> note,
      Value<String?> groupId,
      Value<bool> archived,
      Value<String> pace,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SharedTripsTableUpdateCompanionBuilder =
    SharedTripsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> destination,
      Value<String> emoji,
      Value<String> cover,
      Value<int> startEpochDay,
      Value<int> endEpochDay,
      Value<String> note,
      Value<String?> groupId,
      Value<bool> archived,
      Value<String> pace,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SharedTripsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedTripsTable> {
  $$SharedTripsTableFilterComposer({
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

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedTripsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedTripsTable> {
  $$SharedTripsTableOrderingComposer({
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

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedTripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedTripsTable> {
  $$SharedTripsTableAnnotationComposer({
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

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get startEpochDay => $composableBuilder(
    column: $table.startEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endEpochDay => $composableBuilder(
    column: $table.endEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get pace =>
      $composableBuilder(column: $table.pace, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedTripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedTripsTable,
          SharedTrip,
          $$SharedTripsTableFilterComposer,
          $$SharedTripsTableOrderingComposer,
          $$SharedTripsTableAnnotationComposer,
          $$SharedTripsTableCreateCompanionBuilder,
          $$SharedTripsTableUpdateCompanionBuilder,
          (
            SharedTrip,
            BaseReferences<_$AppDatabase, $SharedTripsTable, SharedTrip>,
          ),
          SharedTrip,
          PrefetchHooks Function()
        > {
  $$SharedTripsTableTableManager(_$AppDatabase db, $SharedTripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedTripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedTripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedTripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<int> startEpochDay = const Value.absent(),
                Value<int> endEpochDay = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> pace = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedTripsCompanion(
                id: id,
                name: name,
                destination: destination,
                emoji: emoji,
                cover: cover,
                startEpochDay: startEpochDay,
                endEpochDay: endEpochDay,
                note: note,
                groupId: groupId,
                archived: archived,
                pace: pace,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> destination = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<int> startEpochDay = const Value.absent(),
                Value<int> endEpochDay = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> pace = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedTripsCompanion.insert(
                id: id,
                name: name,
                destination: destination,
                emoji: emoji,
                cover: cover,
                startEpochDay: startEpochDay,
                endEpochDay: endEpochDay,
                note: note,
                groupId: groupId,
                archived: archived,
                pace: pace,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedTripsTable, SharedTrip>(table),
                  BaseReferences<_$AppDatabase, $SharedTripsTable, SharedTrip>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedTripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedTripsTable,
      SharedTrip,
      $$SharedTripsTableFilterComposer,
      $$SharedTripsTableOrderingComposer,
      $$SharedTripsTableAnnotationComposer,
      $$SharedTripsTableCreateCompanionBuilder,
      $$SharedTripsTableUpdateCompanionBuilder,
      (
        SharedTrip,
        BaseReferences<_$AppDatabase, $SharedTripsTable, SharedTrip>,
      ),
      SharedTrip,
      PrefetchHooks Function()
    >;
typedef $$SharedTripItemsTableCreateCompanionBuilder =
    SharedTripItemsCompanion Function({
      required String id,
      required String tripId,
      Value<int> dateEpochDay,
      Value<String> type,
      Value<String> name,
      Value<String> address,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> photoUri,
      Value<int?> startTimeMin,
      Value<int?> durationMin,
      Value<int?> costCents,
      Value<String> costCurrency,
      Value<String> note,
      Value<String> fromName,
      Value<String> fromAddress,
      Value<double?> fromLat,
      Value<double?> fromLng,
      Value<String> toName,
      Value<String> toAddress,
      Value<double?> toLat,
      Value<double?> toLng,
      Value<String?> flightNo,
      Value<int> sortOrder,
      Value<String?> guideRef,
      Value<String?> backupOf,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SharedTripItemsTableUpdateCompanionBuilder =
    SharedTripItemsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<int> dateEpochDay,
      Value<String> type,
      Value<String> name,
      Value<String> address,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> photoUri,
      Value<int?> startTimeMin,
      Value<int?> durationMin,
      Value<int?> costCents,
      Value<String> costCurrency,
      Value<String> note,
      Value<String> fromName,
      Value<String> fromAddress,
      Value<double?> fromLat,
      Value<double?> fromLng,
      Value<String> toName,
      Value<String> toAddress,
      Value<double?> toLat,
      Value<double?> toLng,
      Value<String?> flightNo,
      Value<int> sortOrder,
      Value<String?> guideRef,
      Value<String?> backupOf,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SharedTripItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedTripItemsTable> {
  $$SharedTripItemsTableFilterComposer({
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

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUri => $composableBuilder(
    column: $table.photoUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLng => $composableBuilder(
    column: $table.fromLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toName => $composableBuilder(
    column: $table.toName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAddress => $composableBuilder(
    column: $table.toAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLng => $composableBuilder(
    column: $table.toLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flightNo => $composableBuilder(
    column: $table.flightNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupOf => $composableBuilder(
    column: $table.backupOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedTripItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedTripItemsTable> {
  $$SharedTripItemsTableOrderingComposer({
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

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUri => $composableBuilder(
    column: $table.photoUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fromLng => $composableBuilder(
    column: $table.fromLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toName => $composableBuilder(
    column: $table.toName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAddress => $composableBuilder(
    column: $table.toAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLng => $composableBuilder(
    column: $table.toLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flightNo => $composableBuilder(
    column: $table.flightNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupOf => $composableBuilder(
    column: $table.backupOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedTripItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedTripItemsTable> {
  $$SharedTripItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<int> get dateEpochDay => $composableBuilder(
    column: $table.dateEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get photoUri =>
      $composableBuilder(column: $table.photoUri, builder: (column) => column);

  GeneratedColumn<int> get startTimeMin => $composableBuilder(
    column: $table.startTimeMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => column);

  GeneratedColumn<String> get costCurrency => $composableBuilder(
    column: $table.costCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get fromName =>
      $composableBuilder(column: $table.fromName, builder: (column) => column);

  GeneratedColumn<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fromLat =>
      $composableBuilder(column: $table.fromLat, builder: (column) => column);

  GeneratedColumn<double> get fromLng =>
      $composableBuilder(column: $table.fromLng, builder: (column) => column);

  GeneratedColumn<String> get toName =>
      $composableBuilder(column: $table.toName, builder: (column) => column);

  GeneratedColumn<String> get toAddress =>
      $composableBuilder(column: $table.toAddress, builder: (column) => column);

  GeneratedColumn<double> get toLat =>
      $composableBuilder(column: $table.toLat, builder: (column) => column);

  GeneratedColumn<double> get toLng =>
      $composableBuilder(column: $table.toLng, builder: (column) => column);

  GeneratedColumn<String> get flightNo =>
      $composableBuilder(column: $table.flightNo, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get guideRef =>
      $composableBuilder(column: $table.guideRef, builder: (column) => column);

  GeneratedColumn<String> get backupOf =>
      $composableBuilder(column: $table.backupOf, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedTripItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedTripItemsTable,
          SharedTripItem,
          $$SharedTripItemsTableFilterComposer,
          $$SharedTripItemsTableOrderingComposer,
          $$SharedTripItemsTableAnnotationComposer,
          $$SharedTripItemsTableCreateCompanionBuilder,
          $$SharedTripItemsTableUpdateCompanionBuilder,
          (
            SharedTripItem,
            BaseReferences<
              _$AppDatabase,
              $SharedTripItemsTable,
              SharedTripItem
            >,
          ),
          SharedTripItem,
          PrefetchHooks Function()
        > {
  $$SharedTripItemsTableTableManager(
    _$AppDatabase db,
    $SharedTripItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedTripItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedTripItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedTripItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> photoUri = const Value.absent(),
                Value<int?> startTimeMin = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<int?> costCents = const Value.absent(),
                Value<String> costCurrency = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLng = const Value.absent(),
                Value<String> toName = const Value.absent(),
                Value<String> toAddress = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLng = const Value.absent(),
                Value<String?> flightNo = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String?> backupOf = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedTripItemsCompanion(
                id: id,
                tripId: tripId,
                dateEpochDay: dateEpochDay,
                type: type,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                photoUri: photoUri,
                startTimeMin: startTimeMin,
                durationMin: durationMin,
                costCents: costCents,
                costCurrency: costCurrency,
                note: note,
                fromName: fromName,
                fromAddress: fromAddress,
                fromLat: fromLat,
                fromLng: fromLng,
                toName: toName,
                toAddress: toAddress,
                toLat: toLat,
                toLng: toLng,
                flightNo: flightNo,
                sortOrder: sortOrder,
                guideRef: guideRef,
                backupOf: backupOf,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                Value<int> dateEpochDay = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> photoUri = const Value.absent(),
                Value<int?> startTimeMin = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<int?> costCents = const Value.absent(),
                Value<String> costCurrency = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLng = const Value.absent(),
                Value<String> toName = const Value.absent(),
                Value<String> toAddress = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLng = const Value.absent(),
                Value<String?> flightNo = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String?> backupOf = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedTripItemsCompanion.insert(
                id: id,
                tripId: tripId,
                dateEpochDay: dateEpochDay,
                type: type,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                photoUri: photoUri,
                startTimeMin: startTimeMin,
                durationMin: durationMin,
                costCents: costCents,
                costCurrency: costCurrency,
                note: note,
                fromName: fromName,
                fromAddress: fromAddress,
                fromLat: fromLat,
                fromLng: fromLng,
                toName: toName,
                toAddress: toAddress,
                toLat: toLat,
                toLng: toLng,
                flightNo: flightNo,
                sortOrder: sortOrder,
                guideRef: guideRef,
                backupOf: backupOf,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedTripItemsTable, SharedTripItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedTripItemsTable,
                    SharedTripItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedTripItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedTripItemsTable,
      SharedTripItem,
      $$SharedTripItemsTableFilterComposer,
      $$SharedTripItemsTableOrderingComposer,
      $$SharedTripItemsTableAnnotationComposer,
      $$SharedTripItemsTableCreateCompanionBuilder,
      $$SharedTripItemsTableUpdateCompanionBuilder,
      (
        SharedTripItem,
        BaseReferences<_$AppDatabase, $SharedTripItemsTable, SharedTripItem>,
      ),
      SharedTripItem,
      PrefetchHooks Function()
    >;
typedef $$FundsTableCreateCompanionBuilder = FundsCompanion Function({
  required String id,
  required String groupId,
  required String name,
  required String managerMemberId,
  Value<int?> targetCents,
  Value<String> status,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$FundsTableUpdateCompanionBuilder = FundsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> name,
  Value<String> managerMemberId,
  Value<int?> targetCents,
  Value<String> status,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$FundsTableReferences
    extends BaseReferences<_$AppDatabase, $FundsTable, Fund> {
  $$FundsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('funds__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FundsTableFilterComposer extends Composer<_$AppDatabase, $FundsTable> {
  $$FundsTableFilterComposer({
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

  ColumnFilters<String> get managerMemberId => $composableBuilder(
    column: $table.managerMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCents => $composableBuilder(
    column: $table.targetCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FundsTableOrderingComposer
    extends Composer<_$AppDatabase, $FundsTable> {
  $$FundsTableOrderingComposer({
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

  ColumnOrderings<String> get managerMemberId => $composableBuilder(
    column: $table.managerMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCents => $composableBuilder(
    column: $table.targetCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FundsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FundsTable> {
  $$FundsTableAnnotationComposer({
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

  GeneratedColumn<String> get managerMemberId => $composableBuilder(
    column: $table.managerMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetCents => $composableBuilder(
    column: $table.targetCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FundsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FundsTable,
          Fund,
          $$FundsTableFilterComposer,
          $$FundsTableOrderingComposer,
          $$FundsTableAnnotationComposer,
          $$FundsTableCreateCompanionBuilder,
          $$FundsTableUpdateCompanionBuilder,
          (Fund, $$FundsTableReferences),
          Fund,
          PrefetchHooks Function({bool groupId})
        > {
  $$FundsTableTableManager(_$AppDatabase db, $FundsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FundsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FundsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> managerMemberId = const Value.absent(),
                Value<int?> targetCents = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FundsCompanion(
                id: id,
                groupId: groupId,
                name: name,
                managerMemberId: managerMemberId,
                targetCents: targetCents,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String name,
                required String managerMemberId,
                Value<int?> targetCents = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FundsCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                managerMemberId: managerMemberId,
                targetCents: targetCents,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FundsTable, Fund>(table),
                  $$FundsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$FundsTableReferences._groupIdTable(
                          db,
                        ),
                        referencedColumn: $$FundsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FundsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FundsTable,
      Fund,
      $$FundsTableFilterComposer,
      $$FundsTableOrderingComposer,
      $$FundsTableAnnotationComposer,
      $$FundsTableCreateCompanionBuilder,
      $$FundsTableUpdateCompanionBuilder,
      (Fund, $$FundsTableReferences),
      Fund,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$InboxItemsTableCreateCompanionBuilder = InboxItemsCompanion Function({
  required String id,
  required String groupId,
  Value<int> amountCents,
  Value<String?> note,
  required int capturedAt,
  Value<String> source,
  Value<String> status,
  Value<String?> convertedExpenseId,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$InboxItemsTableUpdateCompanionBuilder = InboxItemsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<int> amountCents,
  Value<String?> note,
  Value<int> capturedAt,
  Value<String> source,
  Value<String> status,
  Value<String?> convertedExpenseId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$InboxItemsTableReferences
    extends BaseReferences<_$AppDatabase, $InboxItemsTable, InboxItem> {
  $$InboxItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('inbox_items__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableFilterComposer({
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

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convertedExpenseId => $composableBuilder(
    column: $table.convertedExpenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableOrderingComposer({
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

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convertedExpenseId => $composableBuilder(
    column: $table.convertedExpenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InboxItemsTable> {
  $$InboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get convertedExpenseId => $composableBuilder(
    column: $table.convertedExpenseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InboxItemsTable,
          InboxItem,
          $$InboxItemsTableFilterComposer,
          $$InboxItemsTableOrderingComposer,
          $$InboxItemsTableAnnotationComposer,
          $$InboxItemsTableCreateCompanionBuilder,
          $$InboxItemsTableUpdateCompanionBuilder,
          (InboxItem, $$InboxItemsTableReferences),
          InboxItem,
          PrefetchHooks Function({bool groupId})
        > {
  $$InboxItemsTableTableManager(_$AppDatabase db, $InboxItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> capturedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> convertedExpenseId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxItemsCompanion(
                id: id,
                groupId: groupId,
                amountCents: amountCents,
                note: note,
                capturedAt: capturedAt,
                source: source,
                status: status,
                convertedExpenseId: convertedExpenseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<int> amountCents = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int capturedAt,
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> convertedExpenseId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InboxItemsCompanion.insert(
                id: id,
                groupId: groupId,
                amountCents: amountCents,
                note: note,
                capturedAt: capturedAt,
                source: source,
                status: status,
                convertedExpenseId: convertedExpenseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InboxItemsTable, InboxItem>(table),
                  $$InboxItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$InboxItemsTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$InboxItemsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InboxItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InboxItemsTable,
      InboxItem,
      $$InboxItemsTableFilterComposer,
      $$InboxItemsTableOrderingComposer,
      $$InboxItemsTableAnnotationComposer,
      $$InboxItemsTableCreateCompanionBuilder,
      $$InboxItemsTableUpdateCompanionBuilder,
      (InboxItem, $$InboxItemsTableReferences),
      InboxItem,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$AuditLogsTableCreateCompanionBuilder = AuditLogsCompanion Function({
  required String id,
  required String groupId,
  required String entity,
  required String entityId,
  required String action,
  Value<String?> actorMemberId,
  Value<String> changedFieldsJson,
  required int atMs,
  Value<int> rowid,
});
typedef $$AuditLogsTableUpdateCompanionBuilder = AuditLogsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> entity,
  Value<String> entityId,
  Value<String> action,
  Value<String?> actorMemberId,
  Value<String> changedFieldsJson,
  Value<int> atMs,
  Value<int> rowid,
});

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
          AuditLog,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> actorMemberId = const Value.absent(),
                Value<String> changedFieldsJson = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                groupId: groupId,
                entity: entity,
                entityId: entityId,
                action: action,
                actorMemberId: actorMemberId,
                changedFieldsJson: changedFieldsJson,
                atMs: atMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String entity,
                required String entityId,
                required String action,
                Value<String?> actorMemberId = const Value.absent(),
                Value<String> changedFieldsJson = const Value.absent(),
                required int atMs,
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                groupId: groupId,
                entity: entity,
                entityId: entityId,
                action: action,
                actorMemberId: actorMemberId,
                changedFieldsJson: changedFieldsJson,
                atMs: atMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AuditLogsTable, AuditLog>(table),
                  BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
      AuditLog,
      PrefetchHooks Function()
    >;
typedef $$ConflictRecordsTableCreateCompanionBuilder =
    ConflictRecordsCompanion Function({
      required String id,
      required String groupId,
      required String entity,
      required String entityId,
      required int localUpdatedMs,
      required int remoteUpdatedMs,
      required String winner,
      required int detectedAtMs,
      Value<int> acknowledged,
      Value<int> rowid,
    });
typedef $$ConflictRecordsTableUpdateCompanionBuilder =
    ConflictRecordsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> entity,
      Value<String> entityId,
      Value<int> localUpdatedMs,
      Value<int> remoteUpdatedMs,
      Value<String> winner,
      Value<int> detectedAtMs,
      Value<int> acknowledged,
      Value<int> rowid,
    });

class $$ConflictRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictRecordsTable> {
  $$ConflictRecordsTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localUpdatedMs => $composableBuilder(
    column: $table.localUpdatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteUpdatedMs => $composableBuilder(
    column: $table.remoteUpdatedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winner => $composableBuilder(
    column: $table.winner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictRecordsTable> {
  $$ConflictRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localUpdatedMs => $composableBuilder(
    column: $table.localUpdatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteUpdatedMs => $composableBuilder(
    column: $table.remoteUpdatedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winner => $composableBuilder(
    column: $table.winner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictRecordsTable> {
  $$ConflictRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get localUpdatedMs => $composableBuilder(
    column: $table.localUpdatedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteUpdatedMs => $composableBuilder(
    column: $table.remoteUpdatedMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get winner =>
      $composableBuilder(column: $table.winner, builder: (column) => column);

  GeneratedColumn<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => column,
  );
}

class $$ConflictRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConflictRecordsTable,
          ConflictRecord,
          $$ConflictRecordsTableFilterComposer,
          $$ConflictRecordsTableOrderingComposer,
          $$ConflictRecordsTableAnnotationComposer,
          $$ConflictRecordsTableCreateCompanionBuilder,
          $$ConflictRecordsTableUpdateCompanionBuilder,
          (
            ConflictRecord,
            BaseReferences<
              _$AppDatabase,
              $ConflictRecordsTable,
              ConflictRecord
            >,
          ),
          ConflictRecord,
          PrefetchHooks Function()
        > {
  $$ConflictRecordsTableTableManager(
    _$AppDatabase db,
    $ConflictRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> localUpdatedMs = const Value.absent(),
                Value<int> remoteUpdatedMs = const Value.absent(),
                Value<String> winner = const Value.absent(),
                Value<int> detectedAtMs = const Value.absent(),
                Value<int> acknowledged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictRecordsCompanion(
                id: id,
                groupId: groupId,
                entity: entity,
                entityId: entityId,
                localUpdatedMs: localUpdatedMs,
                remoteUpdatedMs: remoteUpdatedMs,
                winner: winner,
                detectedAtMs: detectedAtMs,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String entity,
                required String entityId,
                required int localUpdatedMs,
                required int remoteUpdatedMs,
                required String winner,
                required int detectedAtMs,
                Value<int> acknowledged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConflictRecordsCompanion.insert(
                id: id,
                groupId: groupId,
                entity: entity,
                entityId: entityId,
                localUpdatedMs: localUpdatedMs,
                remoteUpdatedMs: remoteUpdatedMs,
                winner: winner,
                detectedAtMs: detectedAtMs,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConflictRecordsTable, ConflictRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ConflictRecordsTable,
                    ConflictRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConflictRecordsTable,
      ConflictRecord,
      $$ConflictRecordsTableFilterComposer,
      $$ConflictRecordsTableOrderingComposer,
      $$ConflictRecordsTableAnnotationComposer,
      $$ConflictRecordsTableCreateCompanionBuilder,
      $$ConflictRecordsTableUpdateCompanionBuilder,
      (
        ConflictRecord,
        BaseReferences<_$AppDatabase, $ConflictRecordsTable, ConflictRecord>,
      ),
      ConflictRecord,
      PrefetchHooks Function()
    >;
typedef $$WishlistItemsTableCreateCompanionBuilder =
    WishlistItemsCompanion Function({
      required String id,
      required String tripId,
      Value<String> cityKey,
      Value<String> name,
      Value<String> address,
      Value<String> type,
      Value<int?> durationMin,
      Value<String?> tag,
      Value<String?> guideRef,
      Value<String> note,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$WishlistItemsTableUpdateCompanionBuilder =
    WishlistItemsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> cityKey,
      Value<String> name,
      Value<String> address,
      Value<String> type,
      Value<int?> durationMin,
      Value<String?> tag,
      Value<String?> guideRef,
      Value<String> note,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$WishlistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $WishlistItemsTable, WishlistItem> {
  $$WishlistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('wishlist_items__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WishlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableFilterComposer({
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

  ColumnFilters<String> get cityKey => $composableBuilder(
    column: $table.cityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableOrderingComposer({
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

  ColumnOrderings<String> get cityKey => $composableBuilder(
    column: $table.cityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistItemsTable> {
  $$WishlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cityKey =>
      $composableBuilder(column: $table.cityKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get guideRef =>
      $composableBuilder(column: $table.guideRef, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WishlistItemsTable,
          WishlistItem,
          $$WishlistItemsTableFilterComposer,
          $$WishlistItemsTableOrderingComposer,
          $$WishlistItemsTableAnnotationComposer,
          $$WishlistItemsTableCreateCompanionBuilder,
          $$WishlistItemsTableUpdateCompanionBuilder,
          (WishlistItem, $$WishlistItemsTableReferences),
          WishlistItem,
          PrefetchHooks Function({bool tripId})
        > {
  $$WishlistItemsTableTableManager(_$AppDatabase db, $WishlistItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> cityKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WishlistItemsCompanion(
                id: id,
                tripId: tripId,
                cityKey: cityKey,
                name: name,
                address: address,
                type: type,
                durationMin: durationMin,
                tag: tag,
                guideRef: guideRef,
                note: note,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                Value<String> cityKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WishlistItemsCompanion.insert(
                id: id,
                tripId: tripId,
                cityKey: cityKey,
                name: name,
                address: address,
                type: type,
                durationMin: durationMin,
                tag: tag,
                guideRef: guideRef,
                note: note,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WishlistItemsTable, WishlistItem>(table),
                  $$WishlistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tripId,
                        referencedTable: $$WishlistItemsTableReferences
                            ._tripIdTable(db),
                        referencedColumn: $$WishlistItemsTableReferences
                            ._tripIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WishlistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WishlistItemsTable,
      WishlistItem,
      $$WishlistItemsTableFilterComposer,
      $$WishlistItemsTableOrderingComposer,
      $$WishlistItemsTableAnnotationComposer,
      $$WishlistItemsTableCreateCompanionBuilder,
      $$WishlistItemsTableUpdateCompanionBuilder,
      (WishlistItem, $$WishlistItemsTableReferences),
      WishlistItem,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$SharedWishlistItemsTableCreateCompanionBuilder =
    SharedWishlistItemsCompanion Function({
      required String id,
      required String tripId,
      Value<String> cityKey,
      Value<String> name,
      Value<String> address,
      Value<String> type,
      Value<int?> durationMin,
      Value<String?> tag,
      Value<String?> guideRef,
      Value<String> note,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SharedWishlistItemsTableUpdateCompanionBuilder =
    SharedWishlistItemsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> cityKey,
      Value<String> name,
      Value<String> address,
      Value<String> type,
      Value<int?> durationMin,
      Value<String?> tag,
      Value<String?> guideRef,
      Value<String> note,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SharedWishlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedWishlistItemsTable> {
  $$SharedWishlistItemsTableFilterComposer({
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

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cityKey => $composableBuilder(
    column: $table.cityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedWishlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedWishlistItemsTable> {
  $$SharedWishlistItemsTableOrderingComposer({
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

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cityKey => $composableBuilder(
    column: $table.cityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guideRef => $composableBuilder(
    column: $table.guideRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedWishlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedWishlistItemsTable> {
  $$SharedWishlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get cityKey =>
      $composableBuilder(column: $table.cityKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get guideRef =>
      $composableBuilder(column: $table.guideRef, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedWishlistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedWishlistItemsTable,
          SharedWishlistItem,
          $$SharedWishlistItemsTableFilterComposer,
          $$SharedWishlistItemsTableOrderingComposer,
          $$SharedWishlistItemsTableAnnotationComposer,
          $$SharedWishlistItemsTableCreateCompanionBuilder,
          $$SharedWishlistItemsTableUpdateCompanionBuilder,
          (
            SharedWishlistItem,
            BaseReferences<
              _$AppDatabase,
              $SharedWishlistItemsTable,
              SharedWishlistItem
            >,
          ),
          SharedWishlistItem,
          PrefetchHooks Function()
        > {
  $$SharedWishlistItemsTableTableManager(
    _$AppDatabase db,
    $SharedWishlistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedWishlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedWishlistItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SharedWishlistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> cityKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedWishlistItemsCompanion(
                id: id,
                tripId: tripId,
                cityKey: cityKey,
                name: name,
                address: address,
                type: type,
                durationMin: durationMin,
                tag: tag,
                guideRef: guideRef,
                note: note,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                Value<String> cityKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> guideRef = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedWishlistItemsCompanion.insert(
                id: id,
                tripId: tripId,
                cityKey: cityKey,
                name: name,
                address: address,
                type: type,
                durationMin: durationMin,
                tag: tag,
                guideRef: guideRef,
                note: note,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SharedWishlistItemsTable, SharedWishlistItem>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SharedWishlistItemsTable,
                    SharedWishlistItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedWishlistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedWishlistItemsTable,
      SharedWishlistItem,
      $$SharedWishlistItemsTableFilterComposer,
      $$SharedWishlistItemsTableOrderingComposer,
      $$SharedWishlistItemsTableAnnotationComposer,
      $$SharedWishlistItemsTableCreateCompanionBuilder,
      $$SharedWishlistItemsTableUpdateCompanionBuilder,
      (
        SharedWishlistItem,
        BaseReferences<
          _$AppDatabase,
          $SharedWishlistItemsTable,
          SharedWishlistItem
        >,
      ),
      SharedWishlistItem,
      PrefetchHooks Function()
    >;
typedef $$SubBudgetsTableCreateCompanionBuilder = SubBudgetsCompanion Function({
  required String id,
  required String groupId,
  Value<String> categoryKey,
  required int amount,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$SubBudgetsTableUpdateCompanionBuilder = SubBudgetsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> categoryKey,
  Value<int> amount,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$SubBudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $SubBudgetsTable, SubBudget> {
  $$SubBudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) =>
      db.groups.createAlias('sub_budgets__group_id__groups__id');

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $SubBudgetsTable> {
  $$SubBudgetsTableFilterComposer({
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

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubBudgetsTable> {
  $$SubBudgetsTableOrderingComposer({
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

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubBudgetsTable> {
  $$SubBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubBudgetsTable,
          SubBudget,
          $$SubBudgetsTableFilterComposer,
          $$SubBudgetsTableOrderingComposer,
          $$SubBudgetsTableAnnotationComposer,
          $$SubBudgetsTableCreateCompanionBuilder,
          $$SubBudgetsTableUpdateCompanionBuilder,
          (SubBudget, $$SubBudgetsTableReferences),
          SubBudget,
          PrefetchHooks Function({bool groupId})
        > {
  $$SubBudgetsTableTableManager(_$AppDatabase db, $SubBudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubBudgetsCompanion(
                id: id,
                groupId: groupId,
                categoryKey: categoryKey,
                amount: amount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String> categoryKey = const Value.absent(),
                required int amount,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SubBudgetsCompanion.insert(
                id: id,
                groupId: groupId,
                categoryKey: categoryKey,
                amount: amount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubBudgetsTable, SubBudget>(table),
                  $$SubBudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$SubBudgetsTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$SubBudgetsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubBudgetsTable,
      SubBudget,
      $$SubBudgetsTableFilterComposer,
      $$SubBudgetsTableOrderingComposer,
      $$SubBudgetsTableAnnotationComposer,
      $$SubBudgetsTableCreateCompanionBuilder,
      $$SubBudgetsTableUpdateCompanionBuilder,
      (SubBudget, $$SubBudgetsTableReferences),
      SubBudget,
      PrefetchHooks Function({bool groupId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db, _db.members);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripItemsTableTableManager get tripItems =>
      $$TripItemsTableTableManager(_db, _db.tripItems);
  $$AlbumPhotosTableTableManager get albumPhotos =>
      $$AlbumPhotosTableTableManager(_db, _db.albumPhotos);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(_db, _db.checklistItems);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$SettlementsTableTableManager get settlements =>
      $$SettlementsTableTableManager(_db, _db.settlements);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$SharedGroupsTableTableManager get sharedGroups =>
      $$SharedGroupsTableTableManager(_db, _db.sharedGroups);
  $$SharedMembersTableTableManager get sharedMembers =>
      $$SharedMembersTableTableManager(_db, _db.sharedMembers);
  $$SharedExpensesTableTableManager get sharedExpenses =>
      $$SharedExpensesTableTableManager(_db, _db.sharedExpenses);
  $$SharedSettlementsTableTableManager get sharedSettlements =>
      $$SharedSettlementsTableTableManager(_db, _db.sharedSettlements);
  $$TravelSpacesTableTableManager get travelSpaces =>
      $$TravelSpacesTableTableManager(_db, _db.travelSpaces);
  $$SpaceMembersTableTableManager get spaceMembers =>
      $$SpaceMembersTableTableManager(_db, _db.spaceMembers);
  $$SpaceEventsTableTableManager get spaceEvents =>
      $$SpaceEventsTableTableManager(_db, _db.spaceEvents);
  $$SharedTripsTableTableManager get sharedTrips =>
      $$SharedTripsTableTableManager(_db, _db.sharedTrips);
  $$SharedTripItemsTableTableManager get sharedTripItems =>
      $$SharedTripItemsTableTableManager(_db, _db.sharedTripItems);
  $$FundsTableTableManager get funds =>
      $$FundsTableTableManager(_db, _db.funds);
  $$InboxItemsTableTableManager get inboxItems =>
      $$InboxItemsTableTableManager(_db, _db.inboxItems);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$ConflictRecordsTableTableManager get conflictRecords =>
      $$ConflictRecordsTableTableManager(_db, _db.conflictRecords);
  $$WishlistItemsTableTableManager get wishlistItems =>
      $$WishlistItemsTableTableManager(_db, _db.wishlistItems);
  $$SharedWishlistItemsTableTableManager get sharedWishlistItems =>
      $$SharedWishlistItemsTableTableManager(_db, _db.sharedWishlistItems);
  $$SubBudgetsTableTableManager get subBudgets =>
      $$SubBudgetsTableTableManager(_db, _db.subBudgets);
}
