/// 行程模板存储：SharedPreferences JSON 持久化（纯本地，随备份无关）。
///
/// 模板结构：
/// {id, name, destination, emoji, days, items: [{day(1起), name, type, startTimeMin?, costCents?, address?, note?}]}
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';

const _kStoreKey = 'trip_templates';

class TripTemplateItem {
  const TripTemplateItem({
    required this.day,
    required this.name,
    required this.type,
    this.startTimeMin,
    this.costCents,
    this.address = '',
    this.note = '',
  });

  /// 第几天（1 起）
  final int day;
  final String name;
  final String type;
  final int? startTimeMin;
  final int? costCents;
  final String address;
  final String note;

  Map<String, dynamic> toJson() => {
        'day': day,
        'name': name,
        'type': type,
        if (startTimeMin != null) 'startTimeMin': startTimeMin,
        if (costCents != null) 'costCents': costCents,
        'address': address,
        'note': note,
      };

  static TripTemplateItem fromJson(Map<String, dynamic> j) => TripTemplateItem(
        day: (j['day'] as num?)?.toInt() ?? 1,
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'attraction',
        startTimeMin: (j['startTimeMin'] as num?)?.toInt(),
        costCents: (j['costCents'] as num?)?.toInt(),
        address: j['address'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

class TripTemplate {
  const TripTemplate({
    required this.id,
    required this.name,
    required this.destination,
    required this.emoji,
    required this.items,
    this.createdAtMs = 0,
  });

  final String id;
  final String name;
  final String destination;
  final String emoji;
  final List<TripTemplateItem> items;
  final int createdAtMs;

  /// 模板覆盖天数
  int get dayCount =>
      items.isEmpty ? 0 : items.map((i) => i.day).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'destination': destination,
        'emoji': emoji,
        'createdAtMs': createdAtMs,
        'items': [for (final i in items) i.toJson()],
      };

  static TripTemplate fromJson(Map<String, dynamic> j) => TripTemplate(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        destination: j['destination'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '✈️',
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
        items: [
          for (final i in (j['items'] as List? ?? const []))
            TripTemplateItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
      );
}

Future<List<TripTemplate>> loadTemplates() async {
  final sp = await SharedPreferences.getInstance();
  final s = sp.getString(_kStoreKey);
  if (s == null) return const [];
  try {
    final list = jsonDecode(s) as List;
    return [
      for (final e in list) TripTemplate.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> saveTemplate(TripTemplate template) async {
  final sp = await SharedPreferences.getInstance();
  final list = await loadTemplates();
  // 同名覆盖（按 name 幂等，避免模板越积越多）
  final kept = list.where((t) => t.name != template.name).toList();
  kept.add(template);
  kept.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  await sp.setString(_kStoreKey, jsonEncode([for (final t in kept) t.toJson()]));
}

Future<void> deleteTemplate(String id) async {
  final sp = await SharedPreferences.getInstance();
  final list = await loadTemplates();
  final kept = list.where((t) => t.id != id).toList();
  await sp.setString(_kStoreKey, jsonEncode([for (final t in kept) t.toJson()]));
}

final tripTemplatesProvider = FutureProvider<List<TripTemplate>>((_) => loadTemplates());
