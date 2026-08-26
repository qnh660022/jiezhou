// 📍 行程地图：flutter_map 按天标注 + polyline + 交通衔接 + 选点模式
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/services/poi_service.dart';
import '../../../data/services/travel_time_service.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 行程地图页
class TripMapScreen extends ConsumerStatefulWidget {
  const TripMapScreen({super.key});

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final MapController _mapCtrl = MapController();
  String? _tripId;
  int? _selectedDay; // null = show all
  bool _pickMode = false;
  LatLng? _pickedLocation;
  TravelMode _travelMode = TravelMode.drive;

  // 流与 build 解耦（防反复刷新）：tripId 固定，流只建一次
  Stream<Trip?>? _tripStream;
  Stream<List<TripItem>>? _itemsStream;

  @override
  Widget build(BuildContext context) {
    if (_tripId == null) {
      final arg = GoRouterState.of(context).extra;
      if (arg is Map<String, dynamic>) {
        _tripId = arg['tripId'] as String?;
        _pickMode = arg['mode'] == 'pick';
      } else if (arg is String) {
        _tripId = arg;
      }
    }
    final tripId = _tripId;
    if (tripId == null) {
      return Scaffold(
        appBar: GlassAppBar(title: '行程地图'),
        body: const Center(child: Text('未找到行程')),
      );
    }
    return Scaffold(
      appBar: GlassAppBar(
        title: _pickMode ? '地图选点' : '行程地图',
        actions: [
          if (!_pickMode)
            PopupMenuButton<TravelMode>(
              icon: const Icon(Icons.directions_rounded),
              onSelected: (m) => setState(() => _travelMode = m),
              itemBuilder: (_) => [
                for (final m in TravelMode.values)
                  PopupMenuItem(value: m, child: Text(_modeLabel(m))),
              ],
            ),
        ],
      ),
      body: StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(tripId),
        builder: (context, tripSnap) {
          final trip = tripSnap.data;
          if (trip == null) return const Center(child: Text('行程不存在'));
          return StreamBuilder<List<TripItem>>(
            stream: _itemsStream ??= ref.read(tripsRepoProvider).watchItems(tripId),
            builder: (context, itemsSnap) {
              final items = itemsSnap.data ?? const <TripItem>[];
              return _buildBody(trip, items);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(Trip trip, List<TripItem> items) {
    // Filter by day if selected
    final filtered = _selectedDay != null
        ? items.where((i) => i.dateEpochDay == _selectedDay).toList()
        : items;

    // Collect points with coordinates
    final points = <_MapPoint>[];
    for (final it in filtered) {
      if (it.lat != null && it.lng != null) {
        points.add(_MapPoint(it, LatLng(it.lat!, it.lng!)));
      }
    }
    points.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));

    // Determine initial center（WGS-84 -> GCJ-02 以对齐 GeoQ 底图）
    final center = points.isNotEmpty
        ? _wgs84ToGcj02(LatLng(
          points.map((p) => p.latlng.latitude).reduce((a, b) => a + b) / points.length,
          points.map((p) => p.latlng.longitude).reduce((a, b) => a + b) / points.length,
        ))
        : _wgs84ToGcj02(const LatLng(35.6762, 139.6503)); // Default: Tokyo

    // Build markers
    final markers = <Marker>[];
    final polylines = <Polyline>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final visual = tripTypeVisual(p.item.type);
      markers.add(Marker(
        point: _wgs84ToGcj02(p.latlng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showItemInfo(p.item),
          child: Container(
            decoration: BoxDecoration(
              color: visual.color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: visual.color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ));
    }

    // Connect consecutive points
    if (points.length >= 2) {
      for (var i = 0; i < points.length - 1; i++) {
        polylines.add(Polyline(
          points: [_wgs84ToGcj02(points[i].latlng), _wgs84ToGcj02(points[i + 1].latlng)],
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          strokeWidth: 3,
        ));
      }
    }

    // Day chips
    final days = <int>{};
    for (final it in items) {
      if (it.lat != null && it.lng != null) days.add(it.dateEpochDay);
    }
    final sortedDays = days.toList()..sort();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: points.isEmpty ? 5.0 : 12.0,
            onTap: _pickMode ? (tapPos, latlng) {
              setState(() => _pickedLocation = latlng);
              HapticFeedback.lightImpact();
            } : null,
          ),
          children: [
            TileLayer(
              // GeoQ 智图（易智瑞/Esri 中国）公开栅格瓦片：大陆可直连、无需 Key、
              // 使用中国坐标系（GCJ-02），符合中国地图标准。
              // 注意：本 App 存储坐标为 WGS-84，绘制点/线时统一转换为 GCJ-02 以对齐底图。
              urlTemplate:
                  'https://map.geoq.cn/ArcGIS/rest/services/ChinaOnlineCommunity/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.travel.assistant.v2',
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
            if (_pickedLocation != null)
              MarkerLayer(markers: [
                Marker(
                  point: _wgs84ToGcj02(_pickedLocation!),
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on_rounded, color: Theme.of(context).colorScheme.error, size: 36),
                ),
              ]),
          ],
        ),

        // Day filter chips
        if (sortedDays.length > 1 && !_pickMode)
          Positioned(
            top: Spacing.md,
            left: 0, right: 0,
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                itemCount: sortedDays.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return ChoiceChip(
                      label: const Text('全部'),
                      selected: _selectedDay == null,
                      onSelected: (_) => setState(() => _selectedDay = null),
                    );
                  }
                  final day = sortedDays[i - 1];
                  final dayIdx = day - trip.startEpochDay + 1;
                  return ChoiceChip(
                    avatar: Text('D$dayIdx', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                    label: Text(cnMonthDay(day)),
                    selected: _selectedDay == day,
                    onSelected: (_) => setState(() => _selectedDay = day),
                  );
                },
              ),
            ),
          ),

        // Pick mode bottom bar
        if (_pickMode)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxxl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pickedLocation != null)
                    Text('${_pickedLocation!.latitude.toStringAsFixed(4)}, ${_pickedLocation!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: AppFontSizes.caption, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: Spacing.sm),
                  FilledButton.icon(
                    onPressed: _pickedLocation == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop({
                              'lat': _pickedLocation!.latitude,
                              'lng': _pickedLocation!.longitude,
                            });
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('确认选点'),
                  ),
                ],
              ),
            ),
          ),

        // "Insert transport" FAB
        if (!_pickMode && points.length >= 2)
          Positioned(
            bottom: 88 + MediaQuery.paddingOf(context).bottom,
            right: Spacing.lg,
            child: FloatingActionButton.extended(
              heroTag: 'map-insert-transport',
              onPressed: () => _insertTransportBetweenPoints(trip, points),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              icon: const Icon(Icons.add_road_rounded, size: 18),
              label: const Text('插入交通衔接', style: TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }

  void _showItemInfo(TripItem item) {
    HapticFeedback.lightImpact();
    final visual = tripTypeVisual(item.type);
    showDraggableSheet(
      context: context,
      initialChildSize: 0.35,
      minChildSize: 0.25,
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TypeDot(color: visual.color, icon: visual.icon, size: 36),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppFontSizes.bodyLarge)),
                      if (item.address.isNotEmpty)
                        Text(item.address, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppFontSizes.caption, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _insertTransportBetweenPoints(Trip trip, List<_MapPoint> points) async {
    HapticFeedback.selectionClick();
    final repo = ref.read(tripsRepoProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    var count = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final id = newId("item");
      await repo.insertItem(TripItemsCompanion(
        id: Value(id), tripId: Value(trip.id),
        dateEpochDay: Value(from.item.dateEpochDay),
        type: Value('transport'),
        name: Value('${from.item.name} → ${to.item.name}'),
        fromName: Value(from.item.name), fromAddress: Value(from.item.address),
        fromLat: Value(from.latlng.latitude), fromLng: Value(from.latlng.longitude),
        toName: Value(to.item.name), toAddress: Value(to.item.address),
        toLat: Value(to.latlng.latitude), toLng: Value(to.latlng.longitude),
        sortOrder: Value(from.item.sortOrder + 1),
        createdAt: Value(now), updatedAt: Value(now),
      ));
      count++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已插入 $count 条交通衔接')));
    }
  }

  String _modeLabel(TravelMode m) {
    switch (m) {
      case TravelMode.walk: return '步行 🚶';
      case TravelMode.drive: return '驾车 🚗';
      case TravelMode.transit: return '公交 🚌';
    }
  }
}

class _MapPoint {
  const _MapPoint(this.item, this.latlng);
  final TripItem item;
  final LatLng latlng;
}

/// WGS-84（GPS / OSM / 本 App 存储约定）→ GCJ-02（火星坐标，GeoQ/高德/腾讯底图坐标系）。
/// 仅用于地图绘制对齐，不改动任何存储值。误差 < 2m，满足旅行规划精度。
LatLng _wgs84ToGcj02(LatLng wgs) {
  const a = 6378245.0;
  const ee = 0.00669342162296594323;
  double tLat(double x, double y) {
    double r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    r += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    r += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    r += (160.0 * math.sin(y / 12.0 * math.pi) + 320.0 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return r;
  }

  double tLng(double x, double y) {
    double r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    r += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    r += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    r += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    return r;
  }

  final lat = wgs.latitude;
  final lng = wgs.longitude;
  final dLat = tLat(lng - 105.0, lat - 35.0);
  final dLng = tLng(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  final offsetLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
  final offsetLng = (dLng * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
  return LatLng(lat + offsetLat, lng + offsetLng);
}
