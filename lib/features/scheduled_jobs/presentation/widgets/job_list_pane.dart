import 'package:flutter/material.dart';
import 'package:scheduled_job/core/l10n/app_localizations_context.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';

class JobListPane extends StatelessWidget {
  const JobListPane({
    required this.jobs,
    required this.isLoading,
    required this.selectedJobId,
    required this.onNewJob,
    required this.onJobSelected,
    required this.onEnabledChanged,
    required this.onDeleteJob,
    super.key,
  });

  final List<ScheduledJob> jobs;
  final bool isLoading;
  final int? selectedJobId;
  final VoidCallback onNewJob;
  final ValueChanged<ScheduledJob> onJobSelected;
  final void Function(ScheduledJob job, bool isEnabled) onEnabledChanged;
  final ValueChanged<ScheduledJob> onDeleteJob;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 360,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('newScheduledJobButton'),
                  onPressed: onNewJob,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newScheduledJobButton),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Jobs',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : jobs.isEmpty
                  ? _EmptyJobList(colorScheme: colorScheme)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: jobs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return _JobListItem(
                          job: job,
                          isSelected: job.id == selectedJobId,
                          onSelected: () => onJobSelected(job),
                          onEnabledChanged: (isEnabled) =>
                              onEnabledChanged(job, isEnabled),
                          onDelete: () => onDeleteJob(job),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobListItem extends StatelessWidget {
  const _JobListItem({
    required this.job,
    required this.isSelected,
    required this.onSelected,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  final ScheduledJob job;
  final bool isSelected;
  final VoidCallback onSelected;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Material(
        color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                onTap: onSelected,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.onSecondaryContainer.withValues(
                                  alpha: 0.12,
                                )
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.schedule,
                          color: isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatTime(job.scheduledAt),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatNextDate(job.scheduledAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _RunModeLabel(job.runMode),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Switch(
                key: Key('jobEnabledSwitch-${job.id}'),
                value: job.isEnabled,
                onChanged: onEnabledChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_JobContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: _JobContextAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );

    if (selected == _JobContextAction.delete) {
      onDelete();
    }
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  String _formatNextDate(DateTime value) {
    return 'Next ${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

enum _JobContextAction { delete }

class _RunModeLabel extends StatelessWidget {
  const _RunModeLabel(this.runMode);

  final JobRunMode runMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              _label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (runMode) {
      JobRunMode.powershell => Icons.terminal,
      JobRunMode.python => Icons.code,
    };
  }

  String get _label {
    return switch (runMode) {
      JobRunMode.powershell => 'PowerShell',
      JobRunMode.python => 'Python',
    };
  }
}

class _EmptyJobList extends StatelessWidget {
  const _EmptyJobList({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No scheduled jobs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
