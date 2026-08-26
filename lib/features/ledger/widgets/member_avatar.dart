import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';

/// 成员头像：colorIndex → 八色盘轮换取色（与仓储分配规则一致）。
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 40,
    this.showBorder = false,
  });

  final LedgerMemberView member;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AvatarPalette.colors;
    final color = palette[member.colorIndex % palette.length];
    final initial = member.name.trim().isEmpty
        ? '?'
        : String.fromCharCode(member.name.trim().runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: showBorder ? Border.all(color: scheme.surface, width: 2) : null,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AvatarPalette.onColor,
        ),
      ),
    );
  }
}

/// 成员头像叠放排（当前团卡顶部用），溢出折叠成 +N
class MemberAvatarStack extends StatelessWidget {
  const MemberAvatarStack({
    super.key,
    required this.members,
    this.size = 30,
    this.maxVisible = 5,
  });

  final List<LedgerMemberView> members;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = members.take(maxVisible).toList();
    final overflow = members.length - visible.length;

    final shownCount = visible.length + (overflow > 0 ? 1 : 0);
    final step = size * 0.68;
    return SizedBox(
      width: shownCount == 0 ? 0 : size + (shownCount - 1) * step,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * step,
              top: 0,
              child: MemberAvatar(member: visible[i], size: size, showBorder: true),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * step,
              top: 0,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
