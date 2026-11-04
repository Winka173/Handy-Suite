import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/schedule.dart';
import 'review_page.dart';

/// The end of a session, or nothing to do: what was done, and when the next
/// cards come due, so the person knows when to come back.
class ReviewDone extends StatelessWidget {
  final RecallScope scope;
  final String? deckId;
  final int done, forgot;

  /// The session was practice: nothing moved in the schedule.
  final bool practice;

  /// Cards forgotten this session, offered for practice straight away.
  final List<String> forgotten;
  const ReviewDone({
    super.key,
    required this.scope,
    required this.deckId,
    required this.done,
    required this.forgot,
    this.practice = false,
    this.forgotten = const [],
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final ahead = forecast(scope.state, scope.now, deckId: deckId);
    final next = ahead.indexed.skip(1).where((e) => e.$2 > 0).firstOrNull;
    final when = next == null
        ? tr(
            context,
            'Nothing due in the next two weeks.',
            'Hai tuần tới chưa có thẻ nào đến hạn.',
          )
        : next.$1 == 1
        ? tr(
            context,
            'Next: ${next.$2} cards tomorrow.',
            'Lần tới: ngày mai, ${next.$2} thẻ.',
          )
        : tr(
            context,
            'Next: ${next.$2} cards in ${next.$1} days.',
            'Lần tới: còn ${next.$1} ngày, ${next.$2} thẻ.',
          );
    if (practice) {
      return Center(
        child: HandyContent(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.all(HandySpace.xl),
            child: Column(
              key: const Key('practice-done'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Practice done', 'Luyện xong'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: HandySpace.s),
                Text(
                  tr(
                    context,
                    'Practice does not change when cards come due. $when',
                    'Luyện thêm không đổi lịch ôn của thẻ. $when',
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
                ),
                const SizedBox(height: HandySpace.xl),
                FilledButton(
                  key: const Key('review-close'),
                  onPressed: () => Navigator.maybePop(context),
                  child: Text(tr(context, 'Back', 'Quay lại')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: HandyContent(
        maxWidth: 520,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.xl),
          child: Column(
            key: const Key('review-done'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                done == 0
                    ? tr(
                        context,
                        'Nothing due right now',
                        'Chưa có thẻ nào đến hạn',
                      )
                    : tr(context, 'Done for now', 'Xong cho lúc này'),
                style: theme.textTheme.headlineMedium,
              ),
              if (done > 0) ...[
                const SizedBox(height: HandySpace.m),
                Text(
                  tr(
                    context,
                    '$done cards reviewed · forgot $forgot',
                    'Đã ôn $done thẻ · quên $forgot',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: tabular,
                  ),
                ),
              ],
              const SizedBox(height: HandySpace.s),
              Text(
                done == 0
                    ? tr(
                        context,
                        'Nothing due until later. $when',
                        'Chưa có gì cần ôn. $when',
                      )
                    : when,
                style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
              ),
              const SizedBox(height: HandySpace.xl),
              // Right after forgetting is when another look helps most.
              if (forgotten.isNotEmpty) ...[
                OutlinedButton(
                  key: const Key('practice-forgotten'),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewPage(
                        scope: scope,
                        deckId: deckId,
                        practice: forgotten,
                        practiceTitle: tr(
                          context,
                          'The ones you forgot',
                          'Thẻ vừa quên',
                        ),
                      ),
                    ),
                  ),
                  child: Text(
                    tr(
                      context,
                      'Go over the ${forgotten.length} you forgot',
                      'Ôn lại ${forgotten.length} thẻ vừa quên',
                    ),
                  ),
                ),
                const SizedBox(height: HandySpace.s),
              ],
              FilledButton(
                key: const Key('review-close'),
                onPressed: () => Navigator.maybePop(context),
                child: Text(tr(context, 'Back to today', 'Về trang Hôm nay')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
