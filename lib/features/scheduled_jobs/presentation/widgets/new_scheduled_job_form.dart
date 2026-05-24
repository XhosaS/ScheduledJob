import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scheduled_job/core/l10n/app_localizations_context.dart';
import 'package:scheduled_job/features/scheduled_jobs/domain/scheduled_job.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';

class NewScheduledJobForm extends StatefulWidget {
  const NewScheduledJobForm({super.key});

  @override
  State<NewScheduledJobForm> createState() => _NewScheduledJobFormState();
}

class _NewScheduledJobFormState extends State<NewScheduledJobForm> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  int? _loadedJobId;

  @override
  void dispose() {
    _minutesController.dispose();
    _descriptionController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = context.watch<ScheduledJobsViewModel>();
    _syncControllers(viewModel);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 36, 48, 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    viewModel.isEditingExistingJob
                        ? Icons.edit_calendar
                        : Icons.add_task,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.newScheduledJobTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SegmentedButton<ScheduleMode>(
              segments: [
                ButtonSegment(
                  value: ScheduleMode.afterMinutes,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(l10n.afterMinutes),
                ),
                ButtonSegment(
                  value: ScheduleMode.atTime,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(l10n.atTime),
                ),
              ],
              selected: {viewModel.scheduleMode},
              onSelectionChanged: (selection) {
                context.read<ScheduledJobsViewModel>().selectScheduleMode(
                  selection.first,
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 72,
              child: viewModel.scheduleMode == ScheduleMode.afterMinutes
                  ? TextField(
                      key: const Key('minutesField'),
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.minutesFromNow,
                        prefixIcon: const Icon(Icons.timer_outlined),
                        errorText: viewModel.minutesError,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            key: const Key('selectDateTimeButton'),
                            onPressed: _selectDateTime,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              viewModel.selectedDateTime == null
                                  ? l10n.selectDateAndTime
                                  : _formatDateTime(
                                      viewModel.selectedDateTime!,
                                    ),
                            ),
                          ),
                        ),
                        if (viewModel.timeError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            viewModel.timeError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.error),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<JobRunMode>(
              segments: const [
                ButtonSegment(
                  value: JobRunMode.powershell,
                  icon: Icon(Icons.terminal),
                  label: Text('PowerShell'),
                ),
                ButtonSegment(
                  value: JobRunMode.python,
                  icon: Icon(Icons.code),
                  label: Text('Python'),
                ),
              ],
              selected: {viewModel.runMode},
              onSelectionChanged: (selection) {
                context.read<ScheduledJobsViewModel>().selectRunMode(
                  selection.first,
                );
              },
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('commandField'),
              controller: _commandController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Command',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.terminal),
                ),
                errorText: viewModel.commandError,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('descriptionField'),
              controller: _descriptionController,
              minLines: 5,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.description,
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 88),
                  child: Icon(Icons.notes_outlined),
                ),
                errorText: viewModel.descriptionError,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton(
                  key: const Key('saveScheduledJobButton'),
                  onPressed: () {
                    context.read<ScheduledJobsViewModel>().saveJob(
                      minutesText: _minutesController.text,
                      descriptionText: _descriptionController.text,
                      commandText: _commandController.text,
                      validationMessages: ScheduledJobValidationMessages(
                        descriptionRequired: l10n.descriptionRequired,
                        positiveMinutesRequired: l10n.positiveMinutesRequired,
                        dateTimeRequired: l10n.dateTimeRequired,
                        commandRequired: 'Command is required',
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check),
                      const SizedBox(width: 8),
                      Text(l10n.save),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: context
                      .read<ScheduledJobsViewModel>()
                      .cancelCreating,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final viewModel = context.read<ScheduledJobsViewModel>();
    final now = DateTime.now();
    final current = viewModel.selectedDateTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }

    viewModel.setSelectedDateTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  String _formatDateTime(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  void _syncControllers(ScheduledJobsViewModel viewModel) {
    final selectedJob = viewModel.selectedJob;
    if (selectedJob == null) {
      if (_loadedJobId != null) {
        _minutesController.clear();
        _descriptionController.clear();
        _commandController.clear();
      }
      _loadedJobId = null;
      return;
    }

    if (_loadedJobId == selectedJob.id) {
      return;
    }

    _loadedJobId = selectedJob.id;
    _minutesController.clear();
    _descriptionController.text = selectedJob.description;
    _commandController.text = selectedJob.command;
  }
}
