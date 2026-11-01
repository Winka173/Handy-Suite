import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';

/// Sign-in for one request. Secret values are kept for this session only and
/// never saved or exported.
class AuthFields extends StatelessWidget {
  final ApiAuth auth;
  final ValueChanged<ApiAuth> onChanged;
  const AuthFields({super.key, required this.auth, required this.onChanged});

  Widget field(
    BuildContext context,
    String label,
    String value,
    ValueChanged<String> set, {
    bool secret = false,
    String? key,
  }) => HandyField(
    label: label,
    help: secret
        ? tr(
            context,
            'Secret · kept in this session only',
            'Bí mật · chỉ giữ trong phiên này',
          )
        : null,
    child: TextFormField(
      key: Key(key ?? label),
      initialValue: value,
      obscureText: secret,
      onChanged: set,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = auth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'none',
              label: Text(tr(context, 'None', 'Không')),
            ),
            const ButtonSegment(value: 'bearer', label: Text('Bearer')),
            const ButtonSegment(value: 'basic', label: Text('Basic')),
            const ButtonSegment(value: 'api-key', label: Text('API key')),
          ],
          selected: {a.type},
          onSelectionChanged: (s) => onChanged(switch (s.first) {
            'bearer' => const ApiAuth.bearer(''),
            'basic' => const ApiAuth.basic(username: '', password: ''),
            'api-key' => const ApiAuth.apiKey(name: 'X-API-Key', value: ''),
            _ => const ApiAuth.none(),
          }),
        ),
        const SizedBox(height: HandySpace.l),
        ...switch (a.type) {
          'bearer' => [
            field(
              context,
              'Token',
              a.token,
              (v) => onChanged(ApiAuth.bearer(v)),
              secret: true,
              key: 'auth-token',
            ),
          ],
          'basic' => [
            field(
              context,
              tr(context, 'Username', 'Tên đăng nhập'),
              a.username,
              (v) =>
                  onChanged(ApiAuth.basic(username: v, password: a.password)),
              key: 'auth-user',
            ),
            field(
              context,
              tr(context, 'Password', 'Mật khẩu'),
              a.password,
              (v) =>
                  onChanged(ApiAuth.basic(username: a.username, password: v)),
              secret: true,
              key: 'auth-password',
            ),
          ],
          'api-key' => [
            field(
              context,
              tr(context, 'Key name', 'Tên khóa'),
              a.name,
              (v) => onChanged(
                ApiAuth.apiKey(name: v, value: a.value, location: a.location),
              ),
              key: 'auth-key-name',
            ),
            field(
              context,
              tr(context, 'Value', 'Giá trị'),
              a.value,
              (v) => onChanged(
                ApiAuth.apiKey(name: a.name, value: v, location: a.location),
              ),
              secret: true,
              key: 'auth-key-value',
            ),
          ],
          _ => [
            Text(
              tr(
                context,
                'No sign-in is sent.',
                'Không gửi thông tin xác thực.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HandyColors.of(context).muted,
              ),
            ),
          ],
        },
      ],
    );
  }
}
