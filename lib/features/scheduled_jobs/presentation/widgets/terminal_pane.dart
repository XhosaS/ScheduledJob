import 'package:flutter/material.dart';
import 'package:scheduled_job/core/l10n/app_localizations_context.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';

class TerminalPane extends StatefulWidget {
  const TerminalPane({
    required this.isExpanded,
    required this.lines,
    required this.inputError,
    required this.onToggleExpanded,
    required this.onSubmitCommand,
    required this.onClear,
    super.key,
  });

  final bool isExpanded;
  final List<TerminalLine> lines;
  final String? inputError;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSubmitCommand;
  final VoidCallback onClear;

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.isExpanded) {
      return SizedBox(
        width: 52,
        child: Material(
          color: colorScheme.surfaceContainerLow,
          child: InkWell(
            key: const Key('terminalCollapsedToggle'),
            onTap: widget.onToggleExpanded,
            child: Tooltip(
              message: l10n.showTerminal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terminal, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      l10n.terminal,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 420,
      child: Material(
        color: colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.terminal, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.terminal,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('terminalClearButton'),
                    tooltip: l10n.clearTerminal,
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                  IconButton(
                    key: const Key('terminalExpandedToggle'),
                    tooltip: l10n.hideTerminal,
                    onPressed: widget.onToggleExpanded,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: widget.lines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noTerminalOutput,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: const Key('terminalOutputList'),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.lines.length,
                      itemBuilder: (context, index) {
                        final line = widget.lines[index];
                        return _TerminalLineText(line: line);
                      },
                    ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('terminalCommandField'),
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.terminalCommand,
                        errorText: widget.inputError,
                        prefixIcon: const Icon(Icons.keyboard),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('terminalSendButton'),
                    tooltip: l10n.sendTerminalCommand,
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final text = _controller.text;
    widget.onSubmitCommand(text);
    if (text.trim().isNotEmpty) {
      _controller.clear();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }
}

class _TerminalLineText extends StatelessWidget {
  const _TerminalLineText({required this.line});

  final TerminalLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final time =
        '${line.timestamp.hour.toString().padLeft(2, '0')}:'
        '${line.timestamp.minute.toString().padLeft(2, '0')}:'
        '${line.timestamp.second.toString().padLeft(2, '0')}';
    final prefix = line.jobId == null ? time : '$time #${line.jobId}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText(
        '[$prefix] ${line.text}',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Cascadia Mono', 'monospace'],
          fontSize: 12,
          color: line.isError ? colorScheme.error : colorScheme.onSurface,
        ),
      ),
    );
  }
}
