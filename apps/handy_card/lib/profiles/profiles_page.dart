import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

Future<void> openProfiles(BuildContext context, CardScope scope) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/profiles'),
        builder: (_) => ProfilesPage(scope: scope),
      ),
    );

Future<void> editProfile(
  BuildContext context,
  CardScope scope,
  CardProfile? p,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ProfileEditor(scope: scope, profile: p),
  ),
);

/// The identities cards speak for.
class ProfilesPage extends StatelessWidget {
  final CardScope scope;
  const ProfilesPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.library,
    builder: (context, _) {
      final list = scope.library.profiles.values.toList();
      return HandyPage(
        title: tr(context, 'Profiles', 'Hồ sơ'),
        bottom: FilledButton.icon(
          key: const Key('profile-new'),
          onPressed: () => editProfile(context, scope, null),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'New profile', 'Hồ sơ mới')),
        ),
        children: [
          if (list.isEmpty)
            HandyEmpty(
              title: tr(context, 'No profiles yet', 'Chưa có hồ sơ'),
              message: tr(
                context,
                'One per identity: personal, company, freelance, a shop. Cards read their contact fields from it.',
                'Mỗi danh tính một hồ sơ: cá nhân, công ty, tự do, cửa hàng. Thẻ lấy trường liên hệ từ đó.',
              ),
            )
          else
            HandyGroup(
              children: [
                for (final p in list)
                  HandyTile(
                    icon: Icons.person_outline,
                    title: p.displayName.isEmpty
                        ? p.organization
                        : p.displayName,
                    subtitle:
                        '${[p.role, p.organization].where((s) => s.isNotEmpty).join(' · ')}${p.problems().isEmpty ? '' : ' · ${tr(context, '${p.problems().length} links to fix', '${p.problems().length} liên kết cần sửa')}'}',
                    navigates: true,
                    onTap: () => editProfile(context, scope, p),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

/// One identity's fields: each list (phones, emails, links…) grows as
/// needed; a value can be private (left out of every export); links that
/// would not work as tel:, mailto: or https: are flagged beside the field.
class ProfileEditor extends StatefulWidget {
  final CardScope scope;
  final CardProfile? profile;
  const ProfileEditor({super.key, required this.scope, this.profile});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late CardProfile p = widget.profile ?? CardProfile(id: newCardId());
  bool busy = false;

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.scope.library.saveProfile(p);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showHandyMessage(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  CardProfile copy(Map<String, Object?> changes) =>
      CardProfile.fromJson({...p.toJson(), ...changes});

  Widget field(
    String label,
    String value,
    String key, {
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.m),
    child: TextFormField(
      key: Key('profile-$key'),
      initialValue: value,
      minLines: 1,
      maxLines: lines,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      onChanged: (v) => setState(() => p = copy({key: v})),
    ),
  );

  Widget list(
    String title,
    String key,
    List<ProfileValue> values, {
    TextInputType? type,
    String Function(String)? check,
  }) {
    void set(List<ProfileValue> next) => setState(
      () => p = copy({
        key: [for (final v in next) v.toJson()],
      }),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          title,
          trailing: values.length >= 30
              ? null
              : TextButton(
                  onPressed: () => set([...values, const ProfileValue('', '')]),
                  child: Text(tr(context, 'Add', 'Thêm')),
                ),
        ),
        for (final (i, v) in values.indexed)
          Padding(
            key: ObjectKey((key, i)),
            padding: const EdgeInsets.only(bottom: HandySpace.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: v.label,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Label', 'Nhãn'),
                    ),
                    onChanged: (x) => set([
                      for (final (j, o) in values.indexed)
                        j == i
                            ? ProfileValue(x, o.value, private: o.private)
                            : o,
                    ]),
                  ),
                ),
                const SizedBox(width: HandySpace.s),
                Expanded(
                  child: TextFormField(
                    initialValue: v.value,
                    keyboardType: type,
                    decoration: InputDecoration(
                      errorText: v.value.isEmpty || check == null
                          ? null
                          : (check(v.value).isEmpty ? null : check(v.value)),
                    ),
                    onChanged: (x) => set([
                      for (final (j, o) in values.indexed)
                        j == i
                            ? ProfileValue(o.label, x, private: o.private)
                            : o,
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: v.private
                      ? tr(
                          context,
                          'Private: left out of exports',
                          'Riêng tư: không xuất ra',
                        )
                      : tr(context, 'Shown in exports', 'Có trong bản xuất'),
                  icon: Icon(
                    v.private
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => set([
                    for (final (j, o) in values.indexed)
                      j == i
                          ? ProfileValue(o.label, o.value, private: !o.private)
                          : o,
                  ]),
                ),
                IconButton(
                  tooltip: tr(context, 'Remove', 'Bỏ'),
                  icon: const Icon(Icons.close),
                  onPressed: () => set([
                    for (final (j, o) in values.indexed)
                      if (j != i) o,
                  ]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkCheck = (String v) => safeHttpsUrl(v) == null
        ? tr(context, 'Use an https:// address', 'Dùng địa chỉ https://')
        : '';
    return HandyPage(
      title: widget.profile == null
          ? tr(context, 'New profile', 'Hồ sơ mới')
          : tr(context, 'Profile', 'Hồ sơ'),
      actions: [
        if (widget.profile != null)
          IconButton(
            tooltip: tr(context, 'Delete profile', 'Xóa hồ sơ'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmHandy(
                context,
                title: tr(context, 'Delete this profile?', 'Xóa hồ sơ này?'),
                message: tr(
                  context,
                  'Cards that used it keep their layout; their contact fields show their stored text.',
                  'Thẻ đã dùng hồ sơ vẫn giữ bố cục; trường liên hệ hiện chữ đã lưu.',
                ),
                confirmLabel: tr(context, 'Delete', 'Xóa'),
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              await widget.scope.library.deleteProfile(p.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
      bottom: FilledButton(
        key: const Key('profile-save'),
        onPressed: busy ? null : save,
        child: Text(tr(context, 'Save profile', 'Lưu hồ sơ')),
      ),
      children: [
        Wrap(
          spacing: HandySpace.s,
          children: [
            for (final (k, en, vi) in const [
              ('personal', 'Personal', 'Cá nhân'),
              ('company', 'Company', 'Công ty'),
              ('freelance', 'Freelance', 'Tự do'),
              ('creator', 'Creator', 'Sáng tạo'),
              ('speaker', 'Speaker', 'Diễn giả'),
              ('shop', 'Shop', 'Cửa hàng'),
            ])
              ChoiceChip(
                label: Text(tr(context, en, vi)),
                selected: p.kind == k,
                onSelected: (_) => setState(() => p = copy({'kind': k})),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        field(
          tr(context, 'Name shown', 'Tên hiển thị'),
          p.displayName,
          'displayName',
        ),
        field(
          tr(context, 'Legal name (optional)', 'Tên pháp lý (tùy chọn)'),
          p.legalName,
          'legalName',
        ),
        field(tr(context, 'Role', 'Chức danh'), p.role, 'role'),
        field(
          tr(context, 'Organization', 'Tổ chức'),
          p.organization,
          'organization',
        ),
        field(tr(context, 'About', 'Giới thiệu'), p.bio, 'bio', lines: 4),
        list(
          tr(context, 'Phones', 'Điện thoại'),
          'phones',
          p.phones,
          type: TextInputType.phone,
          check: (v) => telUri(v) == null
              ? tr(context, 'Not a phone number', 'Không phải số điện thoại')
              : '',
        ),
        list(
          tr(context, 'Emails', 'Email'),
          'emails',
          p.emails,
          type: TextInputType.emailAddress,
          check: (v) => isEmail(v)
              ? ''
              : tr(context, 'Not an email address', 'Không phải email'),
        ),
        list(
          tr(context, 'Websites', 'Trang web'),
          'websites',
          p.websites,
          type: TextInputType.url,
          check: linkCheck,
        ),
        list(
          tr(context, 'Social links', 'Mạng xã hội'),
          'socials',
          p.socials,
          type: TextInputType.url,
          check: linkCheck,
        ),
        list(tr(context, 'Addresses', 'Địa chỉ'), 'addresses', p.addresses),
        list(tr(context, 'Other fields', 'Trường khác'), 'custom', p.custom),
      ],
    );
  }
}
