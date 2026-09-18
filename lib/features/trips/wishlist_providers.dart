/// 想去池 Riverpod providers（V2.7.2 S6）。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart' show wishlistRepoProvider;
import '../../domain/models.dart' show WishlistRecord;

/// 行程想去池流（领域镜像记录；条目无日期——与 Plan B 的分界线）。
final wishlistByTripProvider =
    StreamProvider.family<List<WishlistRecord>, String>((ref, tripId) {
  final repo = ref.watch(wishlistRepoProvider);
  return repo
      .watchByTrip(tripId)
      .map((rows) => [for (final r in rows) repo.toRecord(r)]);
});
