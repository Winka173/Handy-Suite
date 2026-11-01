import 'package:flutter/material.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// The app's data could not be read. Says that nothing was changed, shows
/// why, and offers a retry plus the app's [recovery] action.
class HandyLoadError extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;
  final Widget? recovery;
  const HandyLoadError({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
    this.recovery,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: HandyContent(
        maxWidth: 520,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: HandySpace.m),
              Text(
                tr(
                  context,
                  'Nothing was changed or deleted.',
                  'Không có gì bị thay đổi hay xóa.',
                ),
              ),
              const SizedBox(height: HandySpace.l),
              HandyNotice(errorText(context, error), tone: HandyTone.error),
              const SizedBox(height: HandySpace.l),
              FilledButton(
                onPressed: onRetry,
                child: Text(tr(context, 'Try again', 'Thử lại')),
              ),
              if (recovery != null) ...[
                const SizedBox(height: HandySpace.s),
                recovery!,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
