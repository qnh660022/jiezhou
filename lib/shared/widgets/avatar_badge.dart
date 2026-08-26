import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 首字头像徽章：按姓名稳定取 8 色盘之一
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.name,
    this.size = 40,
    this.fontSize,
  });

  final String name;
  final double size;
  final double? fontSize;

  /// 取首个字形（runes 处理，兼容中文与 emoji）
  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AvatarPalette.colorForName(name),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: fontSize ?? size * 0.42,
          fontWeight: FontWeight.w700,
          color: AvatarPalette.onColor,
        ),
      ),
    );
  }
}
