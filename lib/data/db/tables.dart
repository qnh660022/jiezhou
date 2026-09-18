/// drift 表定义：9 张业务表 + V2.6 同步层 6 张表（outbox/meta + 4 张共享镜像）。
library;
import "package:drift/drift.dart";

class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(Constant("📁"))();
  BoolColumn get budgetEnabled => boolean().withDefault(Constant(false))();
  IntColumn get budgetCents => integer().nullable()();
  // 团归档（结束团）：软标记，数据不锁死，可随时恢复继续记账
  BoolColumn get archived => boolean().withDefault(Constant(false))();
  IntColumn get archivedAtMs => integer().nullable()();
  // 账本类型（V2.7.1 S4）：travel（默认，AA 旅行账本）/ personal（个人账本）；
  // loan 仅在领域模型与解析层预留取值，不开放创建入口。
  TextColumn get kind => text().withDefault(Constant("travel"))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class Members extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(Constant(0))();
  // 成员软删除（V2.7.1 S2 G1）：行级 LWW 随 createdAt 承载（本表无 updatedAt 列）。
  // archived 成员不进选择器，但历史账单照常参与净额计算与展示。
  BoolColumn get archived => boolean().withDefault(Constant(false))();
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
  // 装配节奏（V2.7.2 S7）：relaxed 360 / standard 480 / tight 600（分钟/天）；
  // 随 trips 整行 LWW 同步，无独立开关。
  TextColumn get pace => text().withDefault(Constant("standard"))();
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
  // 攻略弱关联（V2.7.2 S5）："<cityKey>#<栏>#<序号>"（栏 ∈ spots|food）；
  // 不做外键、不做内容快照，反查失败一律静默降级。
  TextColumn get guideRef => text().nullable()();
  // Plan B 备选（V2.7.2 S8）：非空非''=有主备胎（指向同行程正式卡 id）；
  // ''=无主备胎；null=正式卡。至多一层。
  TextColumn get backupOf => text().nullable()();
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
  // 所属公款池（V2.7.1 S8）：非空即属池；入金 prepay / 出金 normal 共用。
  TextColumn get fundId => text().nullable()();
  // 支付方式纯标签（V2.7.1 S11）：cash/credit/debit/ewallet/fund/other 或自定义串；
  // 不跟踪账户余额，不参与净额与分摊。
  TextColumn get payMethod => text().nullable()();
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
  // 创建本轮所用结算策略（V2.7.1 S9）：minTransfers（默认）/ minParticipants。
  TextColumn get strategy => text().withDefault(Constant("minTransfers"))();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// ===== V2.7.1 新增业务表 =====

/// 公款池（旅行基金，S8）：一池一管理人；入金走 prepay、出金走 normal，
/// 池余额为派生展示量（不入库、不参与净额）。
class Funds extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get name => text()();
  TextColumn get managerMemberId => text()();
  IntColumn get targetCents => integer().nullable()();
  TextColumn get status => text().withDefault(Constant("open"))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

/// 记账收件箱（S10）：独立暂存表，pending 条目不得参与任何金额口径。
class InboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  IntColumn get amountCents => integer().withDefault(Constant(0))();
  TextColumn get note => text().nullable()();
  IntColumn get capturedAt => integer()();
  TextColumn get source => text().withDefault(Constant("manual"))();
  TextColumn get status => text().withDefault(Constant("pending"))();
  TextColumn get convertedExpenseId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

/// 审计轨迹（S12）：**仅本地**，禁止登记 SyncEntity / 上云 / 进快照 / 进备份。
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get actorMemberId => text().nullable()();
  TextColumn get changedFieldsJson => text().withDefault(Constant("{}"))();
  IntColumn get atMs => integer()();
  @override Set<Column> get primaryKey => {id};
}

/// 冲突回执（S12）：**仅本地**，只提示不回选（不存被覆盖版本体）。
class ConflictRecords extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  IntColumn get localUpdatedMs => integer()();
  IntColumn get remoteUpdatedMs => integer()();
  TextColumn get winner => text()();
  IntColumn get detectedAtMs => integer()();
  IntColumn get acknowledged => integer().withDefault(Constant(0))();
  @override Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get name => text().withDefault(Constant(""))();
  TextColumn get icon => text().withDefault(Constant("📦"))();
  BoolColumn get builtin => boolean().withDefault(Constant(false))();
  @override Set<Column> get primaryKey => {key};
}

// ===== V2.6 同步层 =====

/// 上行发件箱：一实体一行、覆盖式合并（同 (entity,rowId) 新事件覆盖旧事件）。
/// [entity] 取值见 lib/data/sync/sync_models.dart 的 SyncEntity；
/// [op]：upsert=本地行存在（镜像整行），delete=本地行已删（云端标 deleted=true）。
class SyncOutbox extends Table {
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  TextColumn get op => text()();
  IntColumn get updatedMs => integer()();
  IntColumn get attemptCount => integer().withDefault(Constant(0))();
  @override Set<Column> get primaryKey => {entity, rowId};
}

/// 同步游标：每实体一条（含 shared_* 四件套与 collab 名单外的常规实体）。
class SyncMeta extends Table {
  TextColumn get entity => text()();
  IntColumn get lastPulledMs => integer().withDefault(Constant(0))();
  @override Set<Column> get primaryKey => {entity};
}

// ===== 受邀端共享镜像表（列定义与对应业务表完全一致，云端下行落这里） =====

class SharedGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(Constant("📁"))();
  BoolColumn get budgetEnabled => boolean().withDefault(Constant(false))();
  IntColumn get budgetCents => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(Constant(false))();
  IntColumn get archivedAtMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class SharedMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(Constant(0))();
  IntColumn get createdAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class SharedExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
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

class SharedSettlements extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get status => text().withDefault(Constant("active"))();
  TextColumn get transfersJson => text().withDefault(Constant("[]"))();
  TextColumn get expenseIdsJson => text().withDefault(Constant("[]"))();
  IntColumn get roundNo => integer().withDefault(Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// ===== V2.6.6.2 旅伴空间（列与云端 spaces_sync / space_members_sync / space_events_sync 同构） =====

/// 空间主表（一程一空间：0~1 行程 + 0~1 账本）。
/// 我创建与我加入的空间都落这一张表（云端 RLS 已限定只下发我可见的行）。
class TravelSpaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tripId => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(Constant("active"))();
  IntColumn get createdMs => integer()();
  IntColumn get updatedMs => integer()();
  IntColumn get deletedMs => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

/// 空间成员（三级权限 owner/editor/viewer）。
/// [updatedMs] 是合流基准（云端该表无业务 updated 语义，但引擎统一以它判新旧）。
class SpaceMembers extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text().withDefault(Constant("viewer"))();
  TextColumn get displayName => text().withDefault(Constant("旅伴"))();
  IntColumn get joinedMs => integer()();
  IntColumn get createdMs => integer()();
  IntColumn get updatedMs => integer()();
  IntColumn get deletedMs => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}

/// 协作动态流（append-only：本地只插入、只在云端软删时移除）。
class SpaceEvents extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get actorUser => text()();
  TextColumn get action => text()();
  TextColumn get entityKind => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get summary => text().withDefault(Constant(""))();
  IntColumn get createdMs => integer()();
  IntColumn get updatedMs => integer()();
  @override Set<Column> get primaryKey => {id};
}

// ===== V2.6.6.2 共享行程镜像（受邀编辑者拉的「别人的行程」，与 shared_groups 同构） =====
//
// 为什么不直接落业务表 trips/trip_items：受邀者若把他人行程写进「我的行程」Tab，
// 既污染个人主线（§1.1：个人主数据不迁移），又会在 assemble 时被再次上行——
// 与历史 bug H7（他人共享账本数据串进本地账本）同构。故一律走镜像表。

class SharedTrips extends Table {
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
  // 与业务表 Trips 保持「列同构」（V2.7.2：装配节奏档随整行 LWW 下行）。
  TextColumn get pace => text().withDefault(Constant("standard"))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class SharedTripItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
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
  // V2.7.2：镜像列与 TripItems 同步增列（guideRef / backupOf）
  TextColumn get guideRef => text().nullable()();
  TextColumn get backupOf => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

// ===== V2.7.2 想去池（行程内候选区，条目无日期） =====

/// 想去池：候选存储区。条目**无日期**是与 Plan B 的分界线；
/// 落卡（装配落点 / 手动「排到第 N 天」）即在同一事务内从池中移除。
class WishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get cityKey => text().withDefault(Constant(""))();
  TextColumn get name => text().withDefault(Constant(""))();
  TextColumn get address => text().withDefault(Constant(""))();
  // 五类同 TripItems：attraction|food|transport|stay|note
  TextColumn get type => text().withDefault(Constant("attraction"))();
  IntColumn get durationMin => integer().nullable()();
  TextColumn get tag => text().nullable()();
  TextColumn get guideRef => text().nullable()();
  TextColumn get note => text().withDefault(Constant(""))();
  IntColumn get sortOrder => integer().withDefault(Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

/// 受邀端镜像（列集与 WishlistItems 完全一致；镜像表不带 references，
/// 与 SharedTripItems 同范式——下行落这里，绝不进业务表防 H7 串数据）。
class SharedWishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get cityKey => text().withDefault(Constant(""))();
  TextColumn get name => text().withDefault(Constant(""))();
  TextColumn get address => text().withDefault(Constant(""))();
  TextColumn get type => text().withDefault(Constant("attraction"))();
  IntColumn get durationMin => integer().nullable()();
  TextColumn get tag => text().nullable()();
  TextColumn get guideRef => text().nullable()();
  TextColumn get note => text().withDefault(Constant(""))();
  IntColumn get sortOrder => integer().withDefault(Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}
