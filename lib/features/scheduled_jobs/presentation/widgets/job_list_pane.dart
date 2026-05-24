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
    super.key,
  });

  final List<ScheduledJob> jobs;
  final bool isLoading;
  final int? selectedJobId;
  final VoidCallback onNewJob;
  final ValueChanged<ScheduledJob> onJobSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 320,
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
                '任务列表',
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
                        final isSelected = job.id == selectedJobId;
                        return Material(
                          color: isSelected
                              ? colorScheme.secondaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onJobSelected(job),
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
                                          ? colorScheme.onSecondaryContainer
                                                .withValues(alpha: 0.12)
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: isSelected
                                                    ? colorScheme
                                                          .onSecondaryContainer
                                                    : colorScheme.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _formatDateTime(job.scheduledAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isSelected
                                                    ? colorScheme
                                                          .onSecondaryContainer
                                                    : colorScheme
                                                          .onSurfaceVariant,
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

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
              '暂无计划任务',
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
