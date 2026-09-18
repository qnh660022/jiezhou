/// 应用元信息：产品名 / 版本号 / 官网地址 —— 全 App 统一来源。
library;

/// 产品名：芥舟。
const String kAppName = '芥舟';

/// 界面展示用的版本号（与 pubspec version 保持一致）。
const String kAppVersionLabel = 'v2.7.1';

/// 芥舟官网：发布页 / 最新版本下载入口。
const String kOfficialWebsite = 'https://jiezhou.22006.dpdns.org/';

/// Web 应用（芥舟）站点：只读分享链接 /s/<token> 的 URL 前缀。
const String kWebAppUrl = 'https://purser.22006.dpdns.org';

/// 拼只读分享链接的完整 URL。
String shareLinkUrl(String token) => '$kWebAppUrl/s/$token';

/// 拼「邀请旅伴」链接的完整 URL（对方登录后自动加入该团）。
String inviteLinkUrl(String code) => '$kWebAppUrl/invite?c=$code';