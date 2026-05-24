import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scheduled_job/core/l10n/app_localizations_context.dart';
import 'package:scheduled_job/features/scheduled_jobs/application/scheduled_job_scheduler.dart';
import 'package:scheduled_job/features/scheduled_jobs/data/scheduled_job_repository.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_page.dart';
import 'package:scheduled_job/features/scheduled_jobs/presentation/scheduled_jobs_view_model.dart';
import 'package:scheduled_job/l10n/generated/app_localizations.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    required this.repository,
    super.key,
    this.locale,
    this.scheduler,
  });

  final ScheduledJobRepository repository;
  final Locale? locale;
  final ScheduledJobScheduler? scheduler;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ScheduledJobsViewModel(repository, scheduler: scheduler)..loadJobs(),
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: _buildTheme(),
        home: const ScheduledJobsPage(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F6F6B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Microsoft YaHei UI',
      fontFamilyFallback: const ['Microsoft YaHei', 'Segoe UI'],
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
