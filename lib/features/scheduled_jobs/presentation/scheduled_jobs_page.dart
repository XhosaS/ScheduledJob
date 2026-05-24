import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scheduled_job/core/l10n/app_localizations_context.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/widgets/job_list_pane.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/widgets/new_scheduled_job_form.dart';

class ScheduledJobsPage extends StatelessWidget {
  const ScheduledJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            Icon(Icons.event_note, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(l10n.appTitle),
          ],
        ),
      ),
      body: Consumer<ScheduledJobsViewModel>(
        builder: (context, viewModel, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
            ),
            child: Row(
              children: [
                JobListPane(
                  jobs: viewModel.jobs,
                  isLoading: viewModel.isLoading,
                  selectedJobId: viewModel.selectedJob?.id,
                  onNewJob: viewModel.startCreating,
                  onJobSelected: viewModel.startEditing,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: viewModel.isCreating
                      ? const NewScheduledJobForm()
                      : const _EmptyDetailsPane(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDetailsPane extends StatelessWidget {
  const _EmptyDetailsPane();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_calendar_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '选择任务或新建计划任务',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
