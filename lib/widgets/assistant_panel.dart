import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/assistant_service.dart';
import '../services/click_sound.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'icon_badge.dart';

/// Floating assistant panel: shows the conversation, live status, the light
/// areas the assistant controls, and an input to type commands.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    super.key,
    required this.service,
    required this.onClose,
  });

  final AssistantService service;
  final VoidCallback onClose;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onUpdate);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.duration,
          curve: AppMotion.curve,
        );
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.service.sendText(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return SizedBox(
      width: 440,
      height: 560,
      child: AppCard(
        glow: true,
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(status: s.status, onClose: widget.onClose, onReset: s.reset),
            const SizedBox(height: AppSpacing.s16),
            _LightsRow(lights: s.lights),
            const SizedBox(height: AppSpacing.s16),
            Expanded(child: _Conversation(scroll: _scroll, service: s)),
            if (s.lastAction != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text('· ${s.lastAction}', style: AppText.secondary),
            ],
            const SizedBox(height: AppSpacing.s16),
            _InputBar(
              controller: _input,
              enabled: s.connected,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.onClose, required this.onReset});

  final AssistantStatus status;
  final VoidCallback onClose;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const IconBadge(icon: Symbols.smart_toy, accent: AppColors.blue),
        const SizedBox(width: AppSpacing.iconText),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Asistente', style: AppText.sectionTitle),
              const SizedBox(height: 2),
              _StatusLine(status: status),
            ],
          ),
        ),
        _IconButton(icon: Symbols.delete_sweep, tooltip: 'Limpiar', onTap: onReset),
        const SizedBox(width: AppSpacing.s8),
        _IconButton(icon: Symbols.close, tooltip: 'Cerrar', onTap: onClose),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});
  final AssistantStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      AssistantStatus.offline => ('Sin conexión', AppColors.textTertiary),
      AssistantStatus.error => ('Error', AppColors.red),
      AssistantStatus.idle => ('Listo', AppColors.green),
      AssistantStatus.thinking => ('Pensando…', AppColors.amber),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: AppText.secondary.copyWith(color: color)),
      ],
    );
  }
}

class _LightsRow extends StatelessWidget {
  const _LightsRow({required this.lights});
  final Map<String, bool> lights;

  static const _labels = {'living': 'Living', 'comedor': 'Comedor', 'patio': 'Patio'};

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in lights.entries) ...[
          Expanded(child: _LightChip(label: _labels[entry.key] ?? entry.key, on: entry.value)),
          if (entry.key != lights.keys.last) const SizedBox(width: AppSpacing.s8),
        ],
      ],
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.amber : AppColors.textTertiary;
    return AnimatedContainer(
      duration: AppMotion.duration,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.mini),
        color: on ? AppColors.amber.withValues(alpha: 0.10) : Colors.transparent,
        border: Border.all(
          color: on ? AppColors.amber.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(on ? Symbols.lightbulb : Symbols.lightbulb_outline,
              size: 18, color: color, fill: on ? 1 : 0),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: AppText.chipLabel.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.scroll, required this.service});
  final ScrollController scroll;
  final AssistantService service;

  @override
  Widget build(BuildContext context) {
    if (service.turns.isEmpty) {
      return Center(
        child: Text(
          service.connected
              ? 'Escribí un comando, por ejemplo:\n"¿va a llover a la noche?"\n"prendé las luces del living"'
              : 'Esperando al asistente…\n(¿está corriendo el servicio?)',
          textAlign: TextAlign.center,
          style: AppText.secondary,
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: service.turns.length,
      itemBuilder: (context, i) => _Bubble(turn: service.turns[i]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final AssistantTurn turn;

  @override
  Widget build(BuildContext context) {
    final fromUser = turn.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.mini),
          color: fromUser
              ? AppColors.blue.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: fromUser ? AppColors.blue.withValues(alpha: 0.28) : AppColors.border,
          ),
        ),
        child: Text(
          turn.text,
          style: AppText.body.copyWith(
            color: fromUser ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

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
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.mini),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppText.body,
              cursorColor: AppColors.blueBright,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: enabled ? 'Escribí un comando…' : 'Sin conexión',
                hintStyle: AppText.secondary,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        _RoundButton(icon: Symbols.send, accent: AppColors.blue, onTap: enabled ? onSend : null),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.accent, this.onTap});
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: withClick(onTap),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.mini),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: disabled ? 0.06 : 0.22),
              accent.withValues(alpha: disabled ? 0.02 : 0.05),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: disabled ? 0.12 : 0.30)),
        ),
        child: Icon(icon, size: 22, weight: 600,
            color: disabled ? AppColors.textTertiary : accent),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: withClick(onTap),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
