import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'sensitive_review.dart';

String sensitiveKindName(BuildContext context, SensitiveKind kind) =>
    switch (kind) {
      SensitiveKind.email => tr(context, 'Email', 'Email'),
      SensitiveKind.phone => tr(context, 'Phone number', 'Số điện thoại'),
      SensitiveKind.card => tr(context, 'Card number', 'Số thẻ'),
      SensitiveKind.iban => tr(context, 'IBAN', 'IBAN'),
      SensitiveKind.account => tr(context, 'Account number', 'Số tài khoản'),
      SensitiveKind.otp => tr(context, 'One-time code', 'Mã OTP'),
      SensitiveKind.token => tr(context, 'Key or token', 'Khóa hoặc token'),
      SensitiveKind.secret => tr(
        context,
        'Password or key',
        'Mật khẩu hoặc khóa',
      ),
    };

/// The places found on this step, each to keep or drop before anything is
/// hidden. Its question: "which of these should be covered?"
class ReviewPanel extends StatelessWidget {
  final SensitiveReview review;
  const ReviewPanel({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final n = review.findings.length;
    return Column(
      key: const Key('sensitive-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr(
              context,
              n == 1 ? '1 place to hide?' : '$n places to hide?',
              '$n chỗ cần che?',
            ),
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        Text(
          tr(
            context,
            'Read from the words in this picture. Chosen places show black on the picture; nothing changes until you hide them. Reading can miss words, so look over the rest yourself.',
            'Đọc từ chữ trong ảnh này. Chỗ được chọn hiện màu đen trên ảnh; chưa có gì thay đổi tới khi bạn bấm che. Việc đọc có thể sót chữ, hãy tự xem phần còn lại.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('sensitive-all'),
            // On the heading's left edge, still a full-size target.
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => review.chooseAll(!review.allChosen),
            child: Text(
              review.allChosen
                  ? tr(context, 'Choose none', 'Bỏ chọn hết')
                  : tr(context, 'Choose all', 'Chọn hết'),
            ),
          ),
        ),
        for (final (i, f) in review.findings.indexed)
          CheckboxListTile(
            key: Key('sensitive-row-$i'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            selected: review.focus == i,
            value: review.chosen(i),
            onChanged: (_) => review.toggle(i),
            title: Text(sensitiveKindName(context, f.kind)),
            subtitle: Text(
              f.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// The two ways out of the review, along the foot of the editor.
class ReviewBar extends StatelessWidget {
  final SensitiveReview review;
  final VoidCallback onApply, onCancel;
  const ReviewBar({
    super.key,
    required this.review,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final n = review.count;
    return HandyBottomBar(
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(
                context,
                '$n of ${review.findings.length} chosen',
                'Đã chọn $n/${review.findings.length}',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            key: const Key('sensitive-cancel'),
            onPressed: onCancel,
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          const SizedBox(width: HandySpace.s),
          FilledButton.icon(
            key: const Key('sensitive-apply'),
            onPressed: n == 0 ? null : onApply,
            icon: const Icon(Icons.visibility_off_outlined),
            label: Text(tr(context, 'Hide $n', 'Che $n chỗ')),
          ),
        ],
      ),
    );
  }
}
