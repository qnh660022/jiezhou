/// 品牌文案令牌（V2.6 任务2）：全库唯一取用入口 `copy(id)`。
///
/// 风格底线：舟/山海/烟波意象；温文克制、短句；不卖萌、不用网络梗；
/// 破坏性操作保持明确。新页面文案一律从 copy 取；既有文案仅收敛 8 触点。
library;

class CopyToken {
  const CopyToken(this.id, this.text, {this.context});
  final String id;
  final String text;
  final String? context;
}

const Map<String, CopyToken> _tokens = {
  // ===== 任务2：8 个品牌触点 =====
  CopyTokens.splashSubtitle: CopyToken(CopyTokens.splashSubtitle, '以芥为舟 · 泛于万顷烟波'),
  CopyTokens.profileQuotesNote: CopyToken(CopyTokens.profileQuotesNote, '路上拾得的话，也说给后来的旅程听'),
  CopyTokens.tripsEmpty: CopyToken(CopyTokens.tripsEmpty, '舟已备好，只差航向了'),
  CopyTokens.tripsEmptyAction: CopyToken(CopyTokens.tripsEmptyAction, '新建一程，即刻启帆'),
  CopyTokens.ledgerEmpty: CopyToken(CopyTokens.ledgerEmpty, '还没有账本。众人同舟，账目共清'),
  CopyTokens.ledgerEmptyAction: CopyToken(CopyTokens.ledgerEmptyAction, '记下第一笔，旅程就有归处'),
  CopyTokens.checklistEmpty: CopyToken(CopyTokens.checklistEmpty, '行囊尚未装点。挑一个行程，让清单为出发打点'),
  CopyTokens.exportDone: CopyToken(CopyTokens.exportDone, '航程已打包，随时带走'),
  CopyTokens.shareDone: CopyToken(CopyTokens.shareDone, '这份旅程，分享给了同舟的人'),
  CopyTokens.cloudLoginIntro: CopyToken(CopyTokens.cloudLoginIntro, '登录后，行程与账目便跟你在每一台设备间同行'),
  CopyTokens.themeSubtitle: CopyToken(CopyTokens.themeSubtitle, '十二种航夜，换一套心境上路的颜色'),

  // ===== 云同步（同步中心 / 账号页 / 胶囊） =====
  'sync.status.unconfigured': CopyToken('sync.status.unconfigured', '端点未配置'),
  'sync.status.signedOut': CopyToken('sync.status.signedOut', '未登录'),
  'sync.status.syncing': CopyToken('sync.status.syncing', '同步中'),
  'sync.status.idle': CopyToken('sync.status.idle', '云端已同步'),
  'sync.status.offline': CopyToken('sync.status.offline', '离线'),
  'sync.lastSynced': CopyToken('sync.lastSynced', '刚刚同步'),
  'sync.now': CopyToken('sync.now', '立即同步'),
  'sync.center': CopyToken('sync.center', '同步中心'),
  'sync.errorRecent': CopyToken('sync.errorRecent', '最近错误'),
  'sync.pending': CopyToken('sync.pending', '待同步'),
  'sync.deadLetter': CopyToken('sync.deadLetter', '待处理'),
  'sync.retryDead': CopyToken('sync.retryDead', '重试'),
  'sync.freq.title': CopyToken('sync.freq.title', '同步频率'),
  'sync.freq.economy': CopyToken('sync.freq.economy', '经济 60s'),
  'sync.freq.standard': CopyToken('sync.freq.standard', '标准 15s'),
  'sync.freq.realtime': CopyToken('sync.freq.realtime', '实时 5s'),
  'sync.freq.realtimeNote': CopyToken('sync.freq.realtimeNote', '更耗流量，适合协作频繁场景'),
  'sync.lan': CopyToken('sync.lan', '离线局域网同步'),
  'sync.cloudUsage': CopyToken('sync.cloudUsage', '云端约占用'),
  'sync.release': CopyToken('sync.release', '释放云端空间'),
  'sync.releaseAutoNote': CopyToken('sync.releaseAutoNote', '自动清理预计 V2.7 开放'),
  'sync.released': CopyToken('sync.released', '已释放'),
  'sync.rows': CopyToken('sync.rows', '行'),
  'sync.toggles.trips': CopyToken('sync.toggles.trips', '行程'),
  'sync.toggles.ledger': CopyToken('sync.toggles.ledger', '账本'),
  'sync.toggles.categories': CopyToken('sync.toggles.categories', '分类（内置字典）'),
  'sync.toggles.categoriesNote': CopyToken('sync.toggles.categoriesNote', '随账号自动同步'),
  'sync.pauseTitle': CopyToken('sync.pauseTitle', '关闭同步'),
  'sync.pauseKeep': CopyToken('sync.pauseKeep', '仅暂停同步'),
  'sync.pausePurge': CopyToken('sync.pausePurge', '同时删除云端数据'),
  'sync.pausePurgeWarn':
      CopyToken('sync.pausePurgeWarn', '云端将清空，重开需全量重传；若他人正在共享将无法删除'),
  'sync.cancel': CopyToken('sync.cancel', '取消'),
  'sync.links': CopyToken('sync.links', '分享链接'),
  'sync.linksEmpty': CopyToken('sync.linksEmpty', '暂无分享链接'),
  'sync.invites': CopyToken('sync.invites', '邀请码管理'),
  'sync.auto.title': CopyToken('sync.auto.title', '自动同步'),
  'sync.auto.onNote': CopyToken('sync.auto.onNote', '改动即刻上传，无需手动'),
  'sync.auto.offNote': CopyToken('sync.auto.offNote', '已关闭自动同步；改动仍会排队，点「立即同步」上传'),
  'sync.auto.wifiOnly': CopyToken('sync.auto.wifiOnly', '仅 Wi-Fi 同步'),
  'sync.auto.wifiOnlyNote':
      CopyToken('sync.auto.wifiOnlyNote', '移动网络下暂停自动同步；仍可手动同步'),
  'sync.auto.wifiUnknown':
      CopyToken('sync.auto.wifiUnknown', '当前网络类型无法判断，已按允许同步处理'),
  'sync.deadLetterHint':
      CopyToken('sync.deadLetterHint', '多次失败，已暂停自动重试，点「立即同步」强制重试'),
  'sync.collabCenter': CopyToken('sync.collabCenter', '分享与协作'),
  'sync.collabCenterNote':
      CopyToken('sync.collabCenterNote', '邀请旅伴、只读链接、邀请码与局域网同步'),
  'sync.wifiBlocked': CopyToken('sync.wifiBlocked', '已按「仅 Wi-Fi」暂停自动同步（当前为移动网络）'),

  // ===== 云端账号页 =====
  'cloud.title': CopyToken('cloud.title', '云端账号'),
  'cloud.tabLogin': CopyToken('cloud.tabLogin', '登录'),
  'cloud.tabSignup': CopyToken('cloud.tabSignup', '注册'),
  'cloud.email': CopyToken('cloud.email', '邮箱'),
  'cloud.password': CopyToken('cloud.password', '密码（至少 8 位，须含字母和数字）'),
  'cloud.submitLogin': CopyToken('cloud.submitLogin', '登录'),
  'cloud.submitSignup': CopyToken('cloud.submitSignup', '注册并登录'),
  'cloud.signedInAs': CopyToken('cloud.signedInAs', '当前账号'),
  'cloud.signOut': CopyToken('cloud.signOut', '退出登录'),
  'cloud.signOutConfirm': CopyToken('cloud.signOutConfirm', '退出后本地数据不受影响，云同步将暂停'),
  'cloud.purge': CopyToken('cloud.purge', '清除云端数据'),
  'cloud.purgeConfirm1': CopyToken('cloud.purgeConfirm1', '将删除该账号云端全部数据（本地数据保留），确定？'),
  'cloud.purgeConfirm2': CopyToken('cloud.purgeConfirm2', '再次确认：此操作不可恢复，确定清除？'),
  'cloud.purged': CopyToken('cloud.purged', '云端数据已清除'),
  'cloud.notConfigured':
      CopyToken('cloud.notConfigured', '云端服务未启用：后端密钥由构建时默认注入，请使用官方发布版本安装'),
  'cloud.aiSection': CopyToken('cloud.aiSection', 'AI 配置（云端仅存 baseUrl/model）'),
  'cloud.aiBaseUrl': CopyToken('cloud.aiBaseUrl', '接口地址 baseUrl'),
  'cloud.aiModel': CopyToken('cloud.aiModel', '模型 model'),
  'cloud.aiKeyLocal': CopyToken('cloud.aiKeyLocal', 'API Key 仅存本机'),
  'cloud.errEmailTaken': CopyToken('cloud.errEmailTaken', '该邮箱已注册，请直接登录'),
  'cloud.errPasswordShort': CopyToken('cloud.errPasswordShort', '密码至少 8 位'),
  'cloud.errPasswordWeak': CopyToken('cloud.errPasswordWeak', '密码须同时包含字母和数字'),
  'cloud.errBadCredentials': CopyToken('cloud.errBadCredentials', '账号或密码错误'),
  'cloud.errNetwork': CopyToken('cloud.errNetwork', '网络失败，请稍后重试'),
  'cloud.errGeneric': CopyToken('cloud.errGeneric', '操作失败，请稍后重试'),
  'cloud.uploadAskTitle': CopyToken('cloud.uploadAskTitle', '首次接入该账号'),
  'cloud.uploadAskBody': CopyToken('cloud.uploadAskBody', '将本地数据上传到该账号的云端空间？'),
  'cloud.uploadYes': CopyToken('cloud.uploadYes', '上传'),
  'cloud.uploadNo': CopyToken('cloud.uploadNo', '只拉取，不上传'),
  'cloud.startUpload': CopyToken('cloud.startUpload', '开始上传本地数据'),

  // ===== 共享账本 =====
  'share.sectionTitle': CopyToken('share.sectionTitle', '共享账本'),
  'share.collabBadge': CopyToken('share.collabBadge', '协作中'),
  'share.offlineBadge': CopyToken('share.offlineBadge', '离线仅可查看'),
  'share.invite': CopyToken('share.invite', '邀请旅伴'),
  'share.inviteCode': CopyToken('share.inviteCode', '邀请码'),
  'share.inviteRegen': CopyToken('share.inviteRegen', '重新生成'),
  'share.inviteLink': CopyToken('share.inviteLink', '邀请链接'),
  'share.joinTitle': CopyToken('share.joinTitle', '加入共享账本'),
  'share.joinBody': CopyToken('share.joinBody', '输入 6 位邀请码'),
  'share.joinOk': CopyToken('share.joinOk', '已加入共享账本'),
  'share.joinInvalid': CopyToken('share.joinInvalid', '邀请码无效，请联系团长重新生成'),
  'share.leave': CopyToken('share.leave', '退出共享'),
  'share.leaveConfirm': CopyToken('share.leaveConfirm', '退出后本机的共享镜像将清除，确定退出？'),
  'share.removed': CopyToken('share.removed', '你已退出共享'),
  'share.ownerOnly': CopyToken('share.ownerOnly', '仅团长可操作'),
  'share.readonlyLink': CopyToken('share.readonlyLink', '只读分享'),
  'share.readonlyPass': CopyToken('share.readonlyPass', '设置查看口令（4 位数字，可空）'),
  'share.readonlyCreated': CopyToken('share.readonlyCreated', '链接已生成'),
  'share.pageFooter': CopyToken('share.pageFooter', '由芥舟 · 旅途助手生成，内容来自分享者'),
  'share.passTitle': CopyToken('share.passTitle', '输入 4 位口令'),
  'share.passBad': CopyToken('share.passBad', '口令不正确'),
  'share.notFound': CopyToken('share.notFound', '分享不存在或已被撤销'),
  'share.needLogin': CopyToken('share.needLogin', '先登录，再加入共享账本'),
  'share.centerTitle': CopyToken('share.centerTitle', '分享与协作'),
  'share.myShared': CopyToken('share.myShared', '我的共享账本'),
  'share.mySharedEmpty': CopyToken('share.mySharedEmpty', '还没有共享账本：邀请旅伴，或输入邀请码加入'),
  'share.copyCode': CopyToken('share.copyCode', '复制邀请码'),
  'share.copyLink': CopyToken('share.copyLink', '复制邀请链接'),
  'share.shareLink': CopyToken('share.shareLink', '分享'),
  'share.copied': CopyToken('share.copied', '已复制'),
  'share.addBill': CopyToken('share.addBill', '记一笔'),
  'share.ownerOnlyTap': CopyToken('share.ownerOnlyTap', '仅团长可操作'),
  'share.readonlyEmpty': CopyToken('share.readonlyEmpty', '还没有只读分享链接'),
  'share.createReadonly': CopyToken('share.createReadonly', '生成只读链接'),
  'share.joinEntry': CopyToken('share.joinEntry', '输入邀请码加入'),
  'share.lanEntry': CopyToken('share.lanEntry', '局域网同步（同 Wi-Fi 快照合并）'),
  'share.myLedgers': CopyToken('share.myLedgers', '我创建的账本（邀请旅伴）'),
  'share.myLedgersEmpty':
      CopyToken('share.myLedgersEmpty', '还没有账本：先到「账本」页创建一个'),
  'share.inviteCodeLabel': CopyToken('share.inviteCodeLabel', '邀请码'),
  'share.inviteNone': CopyToken('share.inviteNone', '点右侧「邀请」生成邀请码'),
  'share.signInHint': CopyToken('share.signInHint', '登录后即可邀请旅伴、生成只读分享链接'),
  'share.readonlyNote':
      CopyToken('share.readonlyNote', '任何人不登录即可查看，只能看不能改，可随时撤销'),
  'share.createReadonlyEmpty':
      CopyToken('share.createReadonlyEmpty', '还没有可分享的行程或账本'),
  'share.tripLinkTitle': CopyToken('share.tripLinkTitle', '分享行程（只读链接）'),
  'share.tripLinkNote':
      CopyToken('share.tripLinkNote', '任何人不登录即可查看行程安排，只能看不能改'),
  'share.groupLinkTitle': CopyToken('share.groupLinkTitle', '分享账本（只读链接）'),
  'share.groupLinkNote':
      CopyToken('share.groupLinkNote', '任何人不登录即可查看成员与账单，只能看不能改'),

  // ===== 通知 =====
  'notify.syncFailTitle': CopyToken('notify.syncFailTitle', '云端失联'),
  'notify.syncFailBody': CopyToken('notify.syncFailBody', '改动已妥善留在本机，网络恢复后自动续传'),
  'notify.syncOkTitle': CopyToken('notify.syncOkTitle', '云端已同步'),
  'notify.syncOkBody': CopyToken('notify.syncOkBody', '跨设备账目已一致'),

  // ===== 攻略（任务5） =====
  'guide.entry': CopyToken('guide.entry', '目的地攻略'),
  'guide.entrySub': CopyToken('guide.entrySub', '行前准备 · 景点 · 美食 · 避坑'),
  'guide.title': CopyToken('guide.title', '目的地攻略'),
  'guide.badgeOffline': CopyToken('guide.badgeOffline', '离线可用'),
  'guide.badgeNetwork': CopyToken('guide.badgeNetwork', '来自网络·轻缓存'),
  'guide.empty': CopyToken('guide.empty', '暂无该目的地攻略'),
  'guide.retry': CopyToken('guide.retry', '重试'),
  'guide.badDestination': CopyToken('guide.badDestination', '无法识别目的地，可试试改行程目的地'),
  'guide.article': CopyToken('guide.article', '精选文章'),
  'guide.source': CopyToken('guide.source', '攻略数据来源：内置精选 + 穷游/马蜂窝/知乎等公开内容，版权归原作者'),
  'guide.addPlan': CopyToken('guide.addPlan', '加入安排'),
  'guide.added': CopyToken('guide.added', '已加入'),
  'guide.sectionPrep': CopyToken('guide.sectionPrep', '行前准备'),
  'guide.sectionSpots': CopyToken('guide.sectionSpots', '景点推荐'),
  'guide.sectionFood': CopyToken('guide.sectionFood', '美食'),
  'guide.sectionTransport': CopyToken('guide.sectionTransport', '交通'),
  'guide.sectionTips': CopyToken('guide.sectionTips', '避坑注意'),
  'guide.sectionBudget': CopyToken('guide.sectionBudget', '预算参考'),
  'guide.missSection': CopyToken('guide.missSection', '信息暂未获取'),
  'guide.flightNone': CopyToken('guide.flightNone', '航班信息暂未收录，可手动填写'),

  // ===== 攻略（2026-09 UI 重设计 + 多入口 + AI 导入） =====
  'guide.homeTitle': CopyToken('guide.homeTitle', '目的地攻略'),
  'guide.homeSub': CopyToken('guide.homeSub', '50 座热门城市 · 每城 15 分钟精读'),
  'guide.homeMore': CopyToken('guide.homeMore', '更多城市'),
  'guide.switchCity': CopyToken('guide.switchCity', '换城市'),
  'guide.pickCity': CopyToken('guide.pickCity', '选择城市'),
  'guide.gotIt': CopyToken('guide.gotIt', '知道了'),
  'guide.sourceAi': CopyToken('guide.sourceAi', '我的 AI 生成'),
  'guide.sourceNetwork': CopyToken('guide.sourceNetwork', '已联网补充'),
  'guide.sourceBuiltin': CopyToken('guide.sourceBuiltin', '内置精选·离线可读'),
  'guide.onlineFail': CopyToken('guide.onlineFail', '在线内容暂时不可用，已展示离线攻略'),
  'guide.secCountUnit': CopyToken('guide.secCountUnit', '条'),
  'guide.readMinutes': CopyToken('guide.readMinutes', '约 {n} 分钟读完'),
  'guide.noCityPicked': CopyToken('guide.noCityPicked', '还没有选择城市'),
  'guide.addCity': CopyToken('guide.addCity', '加城市'),
  'guide.aiImportedTitle': CopyToken('guide.aiImportedTitle', '内容来自你的 AI 生成'),
  'guide.aiImportedNote':
      CopyToken('guide.aiImportedNote', 'AI 生成内容仅供参考，票价与预约规则请以官方为准'),
  'guide.clearAi': CopyToken('guide.clearAi', '删除本城 AI 内容'),
  'guide.clearAiDone': CopyToken('guide.clearAiDone', '已删除，回落到内置攻略'),
  'guide.clearAiConfirm': CopyToken('guide.clearAiConfirm', '删除这城的 AI 生成内容？'),
  'guide.clearAiConfirmBody':
      CopyToken('guide.clearAiConfirmBody', '删除后会显示内置攻略，已导入的内容无法恢复'),
  'guide.aiImportTitle': CopyToken('guide.aiImportTitle', '导入 AI 生成的攻略'),
  'guide.aiImportNote':
      CopyToken('guide.aiImportNote', '导入后会覆盖内置内容，成为这城攻略的优先内容源'),
  'guide.aiImportAction': CopyToken('guide.aiImportAction', '导入攻略'),
  'guide.aiImported': CopyToken('guide.aiImported', '已导入'),
  'guide.aiImportedGo': CopyToken('guide.aiImportedGo', '去查看'),
  'guide.pasteImport': CopyToken('guide.pasteImport', '粘贴导入'),
  'guide.pasteImportHint': CopyToken('guide.pasteImportHint',
      '把外部 AI 生成的攻略 JSON 贴进来即可：六栏结构、汉字 3000 字以上才收。已导入内容会成为这城攻略的优先来源。'),
  'guide.pasteImportPreview': CopyToken('guide.pasteImportPreview', '检查内容'),
  'guide.pasteImportAction': CopyToken('guide.pasteImportAction', '导入并覆盖'),
  'guide.pasteImportOverwrite':
      CopyToken('guide.pasteImportOverwrite', '导入后会覆盖内置内容，可在攻略页菜单里删除'),
  'guide.cancel': CopyToken('guide.cancel', '取消'),

  // ===== 外部服务空态（任务4） =====
  'svc.cityNoCoord': CopyToken('svc.cityNoCoord', '城市无坐标'),
  'svc.loadFail': CopyToken('svc.loadFail', '加载失败'),
  'svc.retry': CopyToken('svc.retry', '重试'),
};

abstract final class CopyTokens {
  // 8 触点 id
  static const splashSubtitle = 'splash.subtitle';
  static const profileQuotesNote = 'profile.quotes.note';
  static const tripsEmpty = 'trips.empty';
  static const tripsEmptyAction = 'trips.empty.action';
  static const ledgerEmpty = 'ledger.empty';
  static const ledgerEmptyAction = 'ledger.empty.action';
  static const checklistEmpty = 'checklist.empty';
  static const exportDone = 'share.export.done';
  static const shareDone = 'share.export.share';
  static const cloudLoginIntro = 'cloud.login.intro';
  static const themeSubtitle = 'theme.subtitle';
}

/// 唯一取用入口；缺 id 抛断言（测试兜底全库完整性）。
String copy(String id) {
  final t = _tokens[id];
  assert(t != null, 'copy token 缺失：$id');
  return t?.text ?? id;
}

/// 全部 token（测试遍历用）。
Iterable<CopyToken> get allCopyTokens => _tokens.values;
