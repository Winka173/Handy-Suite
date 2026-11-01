import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/schedule.dart';
import 'forecast_strip.dart';

/// The answer to "how much today, and can I start now?": the due count set
/// large, the minutes it takes, the one button, then the two weeks ahead.
class TodayPanel extends StatelessWidget {
  final RecallScope scope;
  const TodayPanel({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final now = scope.now;
    final ahead = forecast(scope.state, now);
    final due = ahead.first;
    final tomorrow = ahead.length > 1 ? ahead[1] : 0;
    return HandyGroup(
      color: c.lead,
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Due today', 'Cần ôn hôm nay'),
                style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
              ),
              HandySwap(
                child: Text.rich(
                  key: ValueKey('due-$due'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatFigure(context, '$due'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      TextSpan(
                        text: due == 0
                            ? tr(context, '  all done', '  xong rồi')
                            : tr(
                                context,
                                '  cards · about ${minutesFor(due)} min',
                                '  thẻ · khoảng ${minutesFor(due)} phút',
                              ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                  semanticsLabel: tr(
                    context,
                    '$due cards due today',
                    '$due thẻ cần ôn hôm nay',
                  ),
                ),
              ),
              const SizedBox(height: HandySpace.l),
              if (due > 0)
                FilledButton.icon(
                  key: const Key('study-start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => scope.review(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(tr(context, 'Start review', 'Bắt đầu ôn')),
                )
              else
                Text(
                  tomorrow == 0
                      ? tr(
                          context,
                          'Nothing due tomorrow either.',
                          'Ngày mai cũng chưa có thẻ nào.',
                        )
                      : tr(
                          context,
                          'Tomorrow: $tomorrow cards.',
                          'Ngày mai: $tomorrow thẻ.',
                        ),
                  style: theme.textTheme.bodyLarge,
                ),
              const SizedBox(height: HandySpace.xl),
              Text(
                tr(context, 'Next two weeks', 'Hai tuần tới'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: HandySpace.m),
              ForecastStrip(days: ahead, today: now),
            ],
          ),
        ),
      ],
    );
  }
}
