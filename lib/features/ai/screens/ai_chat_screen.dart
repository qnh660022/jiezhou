/// 🤖 AI 助手 Tab 主页：对话气泡 + 工具活动标签 + 未配置引导。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/travel_quotes.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../theme/tokens.dart';
import '../../ledger/widgets/stagger_in.dart';
import '../ai_chat_providers.dart';
import '../widgets/ai_cards.dart';

/// AI 助手聊天页
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _suggestions = [
    '帮我记一笔午饭 45 元，我付的钱大家平摊',
    '这个月谁还欠钱？',
    '帮我建一个成都 5 日游行程',
    '查一下清单还缺什么没带',
    '把预算设为 5000 元',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send(String text) async {
    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    await ref.read(aiChatProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = ref.watch(aiConfigProvider);
    final chat = ref.watch(aiChatProvider);

    // 配置状态分三态处理
    Widget body;
    if (config.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if ((config.value?['baseUrl'] as String? ?? '').trim().isEmpty) {
      body = EmptyState(
        emoji: '🤖',
        title: 'AI 管家还没上线',
        message: '填入任意 OpenAI 兼容服务的接口地址和 API Key，\n就能让 AI 帮你记账、排行程、算账。',
        actionLabel: '去配置 AI',
        onAction: () => context.push('/ai/settings'),
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.sm),
              children: [
                if (chat.turns.isEmpty) ...[
                  const _WelcomeCard(),
                  const SizedBox(height: Spacing.lg),
                  for (final s in _suggestions)
                    _SuggestionChip(text: s, onTap: () => _send(s)),
                ],
                for (var i = 0; i < chat.turns.length; i++)
                  _TurnBubble(turn: chat.turns[i]),
                if (chat.busy) const _ThinkingBubble(),
              ],
            ),
          ),
          _InputBar(
            controller: _inputCtrl,
            enabled: !chat.busy,
            onSend: () => _send(_inputCtrl.text),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: GlassAppBar(title: 'AI 助手', actions: [
        HeaderIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'AI 设置',
          onTap: () async {
            await context.push('/ai/settings');
            if (context.mounted) ref.invalidate(aiConfigProvider);
          },
        ),
        HeaderIconButton(
          icon: Icons.refresh_rounded,
          tooltip: '清空对话',
          onTap: () => ref.read(aiChatProvider.notifier).clear(),
        ),
      ]),
      body: ColoredBox(color: scheme.surface, child: body),
    );
  }
}

// ---------------------------------------------------------------------------
// 首屏欢迎与建议
// ---------------------------------------------------------------------------

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Row(
          children: [
            Text('🤖', style: const TextStyle(fontSize: 34)),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我是你的旅途管家',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppFontSizes.bodyLarge)),
                  SizedBox(height: Spacing.xs),
                  Text(
                    '可以让我记账、查余额、排行程、管清单、改设置。我只能操作本应用内的数据。',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: AppRadius.capsule,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: AppRadius.capsule,
            ),
            child: Text(text, style: TextStyle(fontSize: AppFontSizes.caption)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 气泡
// ---------------------------------------------------------------------------

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment:
            turn.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          for (final action in turn.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Align(
                alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.capsule,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(action,
                          style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: turn.cardType != null && turn.cardData != null
                ? AiCardView(type: turn.cardType!, data: turn.cardData!)
                : Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                color: turn.isUser
                    ? scheme.primary
                    : turn.isError
                        ? scheme.errorContainer
                        : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(turn.isUser ? 18 : 4),
                  bottomRight: Radius.circular(turn.isUser ? 4 : 18),
                ),
              ),
              child: SelectableText(
                turn.text,
                style: TextStyle(
                  fontSize: AppFontSizes.body,
                  height: 1.5,
                  color: turn.isUser
                      ? scheme.onPrimary
                      : turn.isError
                          ? scheme.onErrorContainer
                          : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  static const _dots = ['·  ', '·· ', '···'];

  /// 旅途哲思：每次出现换一条，仅 UI 展示，不进任何模型上下文
  late var _quote = randomTravelQuote();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '思考中${_dots[(_ctrl.value * 3).floor().clamp(0, 2)]}',
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '“${_quote.text}” · 旅途哲思',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.outline,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 输入栏
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.input,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '说点什么，比如「记一笔打车 30 元」',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: Icon(Icons.send_rounded, color: scheme.primary),
              tooltip: '发送',
            ),
          ],
        ),
      ),
    );
  }
}
