/// 汇率实现：open.er-api.com 免 key 接口（基准 CNY），结果缓存进 SharedPreferences。
///
/// 约定：App 内 rate 表示「1 外币 = ? CNY」；接口返回「1 CNY = ? 外币」，
/// 落盘时取倒数。
library;
import "dart:convert";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../exchange_rate_service.dart";
import "../../seed/currencies.dart";
import "../../repo/prefs_repo.dart";

class ExchangeRateServiceImpl implements ExchangeRateService {
  ExchangeRateServiceImpl(this._prefs, [Dio? dio]) : _dio = dio ?? Dio();
  final PrefsRepository _prefs;
  final Dio _dio;

  static const _cacheKey = 'exchange_rates_cache';
  static const _staleHours = 12;

  @override
  Future<int?> hoursSinceLastFetch() async {
    final cache = await _readCache();
    if (cache == null) return null;
    final at = (cache['fetchedAtMs'] as num?)?.toInt() ?? 0;
    if (at <= 0) return null;
    return ((DateTime.now().millisecondsSinceEpoch - at) / 3600000).floor();
  }

  @override
  Future<bool> refreshIfStale({bool force = false}) async {
    if (!force) {
      final hours = await hoursSinceLastFetch();
      if (hours != null && hours < _staleHours) return false;
    }
    try {
      final resp = await _dio.get(
        'https://open.er-api.com/v6/latest/CNY',
        options: Options(sendTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)),
      );
      final data = resp.data;
      if (data is! Map || data['rates'] is! Map) return false;
      final rates = (data['rates'] as Map).cast<String, dynamic>();
      final supported = {for (final c in kCurrencies) c.code: c};
      var updated = 0;
      final memo = await _prefs.getCurrencyRates();
      for (final entry in rates.entries) {
        final code = entry.key.toUpperCase();
        final currency = supported[code];
        if (currency == null) continue;
        final perCny = (entry.value as num?)?.toDouble();
        // 1 CNY = perCny 外币 → 1 外币 = 1/perCny CNY
        if (perCny == null || perCny <= 0) continue;
        final rate = 1 / perCny;
        // 记忆汇率是用户手动填的：只在偏离种子默认值（即曾被更新过）或
        // 尚无记忆时覆盖，避免把用户刚填的精确值冲掉的行为其实无法区分，
        // 因此约定：自动汇率每次刷新都覆盖（用户手填后会被下次刷新盖掉，
        // 可在记账页手动改回）。
        memo[code] = double.parse(rate.toStringAsFixed(6));
        updated++;
      }
      if (updated == 0) return false;
      await _prefs.setCurrencyRates(memo);
      await SharedPreferences.getInstance().then((sp) => sp.setString(_cacheKey, jsonEncode({
            'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
          })));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _readCache() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_cacheKey);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
