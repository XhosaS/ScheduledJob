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
  static const _shutdownCommand = 'Stop-Computer -Force';
  static const _shutdownDescription = 'Shutdown this computer';

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
                  icon: const Icon(Icons.access_time),
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
                  : _ClockTimePicker(
                      value: viewModel.selectedClockTime,
                      errorText: viewModel.timeError,
                      onChanged: context
                          .read<ScheduledJobsViewModel>()
                          .setSelectedClockTime,
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
            _RecommendedCommands(
              title: l10n.recommendedCommands,
              onShutdownSelected: _applyShutdownRecommendation,
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('commandField'),
              controller: _commandController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.command,
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
                        commandRequired: l10n.commandRequired,
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

  void _applyShutdownRecommendation() {
    context.read<ScheduledJobsViewModel>().selectRunMode(JobRunMode.powershell);
    _commandController.text = _shutdownCommand;
    _descriptionController.text = _shutdownDescription;
  }
}

class _RecommendedCommands extends StatelessWidget {
  const _RecommendedCommands({
    required this.title,
    required this.onShutdownSelected,
  });

  final String title;
  final VoidCallback onShutdownSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const Key('recommendedShutdownCommandChip'),
                  avatar: const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('PowerShell shutdown'),
                  onPressed: onShutdownSelected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockTimePicker extends StatelessWidget {
  const _ClockTimePicker({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final ClockTime? value;
  final ValueChanged<ClockTime> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = value ?? const ClockTime(hour: 0, minute: 0, second: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const Key('clockTimePicker'),
          children: [
            Expanded(
              child: _TimePartDropdown(
                key: const Key('hourDropdown'),
                label: 'HH',
                value: selected.hour,
                max: 23,
                onChanged: (hour) => onChanged(
                  ClockTime(
                    hour: hour,
                    minute: selected.minute,
                    second: selected.second,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimePartDropdown(
                key: const Key('minuteDropdown'),
                label: 'MM',
                value: selected.minute,
                max: 59,
                onChanged: (minute) => onChanged(
                  ClockTime(
                    hour: selected.hour,
                    minute: minute,
                    second: selected.second,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimePartDropdown(
                key: const Key('secondDropdown'),
                label: 'SS',
                value: selected.second,
                max: 59,
                onChanged: (second) => onChanged(
                  ClockTime(
                    hour: selected.hour,
                    minute: selected.minute,
                    second: second,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _TimePartDropdown extends StatelessWidget {
  const _TimePartDropdown({
    required super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      items: [
        for (var item = 0; item <= max; item++)
          DropdownMenuItem(
            value: item,
            child: Text(item.toString().padLeft(2, '0')),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
