import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_models.dart';
import 'analytics_providers.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        actions: [
          IconButton(
              tooltip: 'Refresh analytics',
              onPressed: () =>
                  ref.read(analyticsControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Log focus session',
              onPressed: () => _captureSession(context, ref),
              icon: const Icon(Icons.timer_outlined)),
          const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(
                  avatar: Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text('Local data'))),
        ],
      ),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Analytics could not load: $error')),
        data: (state) => _AnalyticsContent(state: state),
      ),
    );
  }
}

class _AnalyticsContent extends ConsumerWidget {
  const _AnalyticsContent({required this.state});
  final AnalyticsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = state.dashboard;
    final controller = ref.read(analyticsControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Productivity control center',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                      'Understand the signals behind your work without sending data to a cloud model.'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Day')),
                ButtonSegment(value: 'weekly', label: Text('Week')),
                ButtonSegment(value: 'monthly', label: Text('Month')),
                ButtonSegment(value: 'yearly', label: Text('Year')),
              ],
              selected: {state.period},
              onSelectionChanged: (value) => controller.setPeriod(value.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _MetricGrid(dashboard: dashboard),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _ScoreCard(dashboard: dashboard)),
          const SizedBox(width: 16),
          Expanded(child: _TrendCard(series: dashboard.dailySeries))
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _BreakdownCard(
                  title: 'Task completion', items: dashboard.taskBreakdown)),
          const SizedBox(width: 16),
          Expanded(
              child: _BreakdownCard(
                  title: 'Focus and time', items: dashboard.focusBreakdown))
        ]),
        const SizedBox(height: 16),
        _SummaryCard(dashboard: dashboard),
        const SizedBox(height: 16),
        _InsightsCard(recommendations: dashboard.recommendations),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.dashboard});
  final AnalyticsDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
            label: 'Productivity',
            value: dashboard.productivityScore.toStringAsFixed(0),
            suffix: '/100',
            icon: Icons.speed_rounded,
            color: const Color(0xFF4F46E5)),
        _MetricCard(
            label: 'Focus score',
            value: dashboard.focusScore.toStringAsFixed(0),
            suffix: '/100',
            icon: Icons.center_focus_strong_rounded,
            color: const Color(0xFF0F766E)),
        _MetricCard(
            label: 'Completion rate',
            value: '${dashboard.completionRate.toStringAsFixed(0)}%',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF047857)),
        _MetricCard(
            label: 'Goal progress',
            value: '${dashboard.goalProgress.toStringAsFixed(0)}%',
            icon: Icons.flag_outlined,
            color: const Color(0xFFB45309)),
        _MetricCard(
            label: 'Overdue tasks',
            value: '${dashboard.overdueTasks}',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFBE123C)),
        _MetricCard(
            label: 'Deep work',
            value: '${dashboard.deepWorkMinutes}',
            suffix: ' min',
            icon: Icons.timer_outlined,
            color: const Color(0xFF0369A1)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.suffix = ''});
  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text.rich(TextSpan(
                  text: value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: color),
                  children: [
                    TextSpan(
                        text: suffix,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: color))
                  ])),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.dashboard});
  final AnalyticsDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How the score is calculated',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                          value: dashboard.productivityScore / 100,
                          strokeWidth: 10,
                          color: const Color(0xFF4F46E5),
                          backgroundColor: const Color(0xFFE0E7FF)),
                      Text(dashboard.productivityScore.toStringAsFixed(0),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(dashboard.scoreExplanation,
                        style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 16),
            _ScoreLegend(
                label: 'Completion',
                value: dashboard.completionRate,
                color: const Color(0xFF047857)),
            _ScoreLegend(
                label: 'Focus',
                value: dashboard.focusScore,
                color: const Color(0xFF0F766E)),
            _ScoreLegend(
                label: 'Goals',
                value: dashboard.goalProgress,
                color: const Color(0xFFB45309)),
          ],
        ),
      ),
    );
  }
}

class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend(
      {required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
              child: LinearProgressIndicator(
                  value: (value / 100).clamp(0, 1),
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.14))),
          const SizedBox(width: 8),
          SizedBox(
              width: 42,
              child: Text('${value.toStringAsFixed(0)}%',
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series});
  final List<AnalyticsMetricPoint> series;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var index = 0; index < series.length; index++)
        FlSpot(index.toDouble(), series[index].secondaryValue)
    ];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus trend',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Minutes of focus by day',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                        spots: spots.isEmpty ? const [FlSpot(0, 0)] : spots,
                        isCurved: false,
                        color: const Color(0xFF0F766E),
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                            show: true, color: const Color(0x1A0F766E)))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.items});
  final String title;
  final List<AnalyticsBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No local data in this range.')
            else
              ...items.take(6).map((item) => _BreakdownRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});
  final AnalyticsBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 86,
              child: Text(item.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
              child: LinearProgressIndicator(
                  value: (item.percentage / 100).clamp(0, 1),
                  color: item.color,
                  backgroundColor: item.color.withValues(alpha: 0.14))),
          const SizedBox(width: 8),
          SizedBox(
              width: 42,
              child: Text('${item.percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.dashboard});
  final AnalyticsDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FAFC),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period summary',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(dashboard.weeklySummary),
            const SizedBox(height: 6),
            Text(dashboard.monthlySummary,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Wrap(spacing: 18, runSpacing: 8, children: [
              Text('${dashboard.meetingMinutes} meeting min'),
              Text('${dashboard.learningMinutes} learning min'),
              Text('${dashboard.notesCreated} notes'),
              Text('${dashboard.focusSessions} focus sessions')
            ]),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.recommendations});
  final List<String> recommendations;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explainable local insights',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'These recommendations are derived from your local records. Review them before changing your plan.'),
            const SizedBox(height: 12),
            for (final recommendation in recommendations)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb_outline_rounded,
                      color: Color(0xFFB45309)),
                  title: Text(recommendation)),
          ],
        ),
      ),
    );
  }
}

Future<void> _captureSession(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(text: '25');
  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log focus session'),
      content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Minutes', border: OutlineInputBorder())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('Save')),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result > 0) {
    await ref
        .read(analyticsControllerProvider.notifier)
        .saveFocusSession(result);
  }
}
