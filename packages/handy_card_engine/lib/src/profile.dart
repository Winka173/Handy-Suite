part of '../handy_card_engine.dart';

/// A labelled value (a phone, an email, a link, a custom field). Private
/// values stay out of exports unless the person includes them.
class ProfileValue {
  final String label, value;
  final bool private;
  const ProfileValue(this.label, this.value, {this.private = false});
  factory ProfileValue.fromJson(Object? raw) {
    final j = _map(raw, 'profile value');
    return ProfileValue(
      _text(j['label'] ?? '', max: 60),
      _text(j['value'] ?? '', max: 2000),
      private: j['private'] == true,
    );
  }
  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    if (private) 'private': true,
  };
}

/// One identity: a person, a company, a speaker, a shop.
class CardProfile {
  final String id, kind, displayName, legalName, role, organization, bio;
  final List<ProfileValue> phones, emails, websites, addresses, socials, custom;
  final String? photo, logo;
  final String updatedAt;
  CardProfile({
    required this.id,
    this.kind = 'personal',
    this.displayName = '',
    this.legalName = '',
    this.role = '',
    this.organization = '',
    this.bio = '',
    List<ProfileValue> phones = const [],
    List<ProfileValue> emails = const [],
    List<ProfileValue> websites = const [],
    List<ProfileValue> addresses = const [],
    List<ProfileValue> socials = const [],
    List<ProfileValue> custom = const [],
    this.photo,
    this.logo,
    this.updatedAt = '',
  }) : phones = List.unmodifiable(phones),
       emails = List.unmodifiable(emails),
       websites = List.unmodifiable(websites),
       addresses = List.unmodifiable(addresses),
       socials = List.unmodifiable(socials),
       custom = List.unmodifiable(custom);

  static const kinds = {
    'personal',
    'company',
    'freelance',
    'creator',
    'speaker',
    'shop',
  };

  factory CardProfile.fromJson(Object? raw) {
    final j = _map(raw, 'profile');
    List<ProfileValue> list(String k) {
      final v = j[k] ?? const [];
      if (v is! List || v.length > 30) throw FormatException('Invalid $k');
      return [for (final x in v) ProfileValue.fromJson(x)];
    }

    String? ref(String k) {
      final v = j[k];
      if (v == null) return null;
      if (v is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(v))
        throw FormatException('Invalid $k');
      return v;
    }

    final kind = j['kind'] ?? 'personal';
    if (!kinds.contains(kind))
      throw const FormatException('Invalid profile kind');
    return CardProfile(
      id: _id(j['id']),
      kind: kind as String,
      displayName: _text(j['displayName'] ?? '', max: 120),
      legalName: _text(j['legalName'] ?? '', max: 120),
      role: _text(j['role'] ?? '', max: 120),
      organization: _text(j['organization'] ?? '', max: 160),
      bio: _text(j['bio'] ?? '', max: 2000),
      phones: list('phones'),
      emails: list('emails'),
      websites: list('websites'),
      addresses: list('addresses'),
      socials: list('socials'),
      custom: list('custom'),
      photo: ref('photo'),
      logo: ref('logo'),
      updatedAt: _text(j['updatedAt'] ?? '', max: 40),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'displayName': displayName,
    'legalName': legalName,
    'role': role,
    'organization': organization,
    'bio': bio,
    'phones': [for (final v in phones) v.toJson()],
    'emails': [for (final v in emails) v.toJson()],
    'websites': [for (final v in websites) v.toJson()],
    'addresses': [for (final v in addresses) v.toJson()],
    'socials': [for (final v in socials) v.toJson()],
    'custom': [for (final v in custom) v.toJson()],
    'photo': photo,
    'logo': logo,
    'updatedAt': updatedAt,
  };

  /// Problems with links and addresses, as (field, message) pairs; an empty
  /// list means everything can be exported as a working link.
  List<(String, String)> problems() => [
    for (final e in emails)
      if (e.value.isNotEmpty && !isEmail(e.value)) ('email', e.value),
    for (final p in phones)
      if (p.value.isNotEmpty && telUri(p.value) == null) ('phone', p.value),
    for (final w in [...websites, ...socials])
      if (w.value.isNotEmpty && safeHttpsUrl(w.value) == null)
        ('link', w.value),
  ];
}

bool isEmail(String v) => RegExp(
  r'^[^\s@<>"]{1,64}@[A-Za-z0-9.-]{1,253}\.[A-Za-z]{2,}$',
).hasMatch(v.trim());

/// `tel:` with digits and a leading +, or null when there are no digits.
String? telUri(String v) {
  final digits = v.replaceAll(RegExp(r'[^\d+]'), '');
  if (!RegExp(r'^\+?\d{3,20}$').hasMatch(digits)) return null;
  return 'tel:$digits';
}

/// The link as https (a bare host gets https://), or null when it is not a
/// plain web address: no other schemes, no spaces, no credentials.
String? safeHttpsUrl(String v) {
  var s = v.trim();
  if (s.isEmpty || s.length > 2000) return null;
  if (!s.contains('://')) s = 'https://$s';
  final u = Uri.tryParse(s);
  if (u == null ||
      u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      s.contains(RegExp(r'\s')))
    return null;
  return u.toString();
}

/// The fields an element can bind to, with their labels.
const bindableFields = <String, (String, String)>{
  'name': ('Name', 'Tên'),
  'role': ('Role', 'Chức danh'),
  'org': ('Organization', 'Tổ chức'),
  'phone': ('Phone', 'Điện thoại'),
  'email': ('Email', 'Email'),
  'website': ('Website', 'Trang web'),
  'address': ('Address', 'Địa chỉ'),
  'bio': ('About', 'Giới thiệu'),
  'social': ('Social link', 'Mạng xã hội'),
  'vcard': ('Contact card (QR)', 'Danh thiếp (QR)'),
  'url': ('First link (QR)', 'Liên kết đầu (QR)'),
};

/// The value of [field] in [p] ("phone:2" is the second phone), or '' when
/// the profile has none. Private values are left out.
String profileValue(CardProfile? p, String field) {
  if (p == null) return '';
  final parts = field.split(':');
  final key = parts.first;
  final n = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) - 1 : 0;
  String nth(List<ProfileValue> list) {
    final open = list
        .where((v) => !v.private && v.value.trim().isNotEmpty)
        .toList();
    return n >= 0 && n < open.length ? open[n].value.trim() : '';
  }

  return switch (key) {
    'name' => p.displayName,
    'role' => p.role,
    'org' => p.organization,
    'phone' => nth(p.phones),
    'email' => nth(p.emails),
    'website' => nth(p.websites),
    'address' => nth(p.addresses),
    'social' => nth(p.socials),
    'bio' => p.bio,
    'custom' =>
      p.custom
              .where(
                (c) =>
                    !c.private && c.label == (parts.length > 1 ? parts[1] : ''),
              )
              .map((c) => c.value)
              .firstOrNull ??
          '',
    'vcard' => vcardFor(p),
    'url' => safeHttpsUrl(nth(p.websites)) ?? '',
    _ => '',
  };
}

/// What an element shows: its bound profile value (live), its stored text
/// (snapshot, or no binding), with an upper-case transform if styled so.
String displayText(CardElement e, CardProfile? profile) {
  final b = e.binding;
  var text = e.prop<String>('text', '');
  if (b != null && b.mode == 'live') {
    final v = profileValue(profile, b.field);
    if (v.isNotEmpty) text = v;
  }
  final prefix = e.prop<String>('prefix', '');
  if (prefix.isNotEmpty && text.isNotEmpty) text = '$prefix$text';
  return e.prop<bool>('upper', false) ? text.toUpperCase() : text;
}

/// The payload a QR element encodes: its bound value when live, else the
/// stored payload.
String qrPayload(CardElement e, CardProfile? profile) {
  final b = e.binding;
  if (b != null && b.mode == 'live') {
    final v = profileValue(profile, b.field);
    if (v.isNotEmpty) return v;
  }
  return e.prop<String>('payload', '');
}

/// Elements on any side bound live to the profile: what a profile edit
/// changes.
List<(String page, CardElement element)> boundElements(CardDocument doc) => [
  for (final p in doc.pages)
    for (final e in p.all)
      if (e.binding?.mode == 'live') (p.id, e),
];

/// The element unlinked: it keeps the text it shows now and stops
/// following the profile.
CardElement unlinkElement(CardElement e, CardProfile? profile) {
  final b = e.binding;
  if (b == null) return e;
  final now = e.type == 'qr'
      ? qrPayload(e, profile)
      : profileValue(profile, b.field);
  return e.copyWith(
    props: {
      ...e.props,
      if (e.type == 'qr')
        'payload': now
      else
        'text': now.isEmpty ? e.prop<String>('text', '') : now,
    },
    binding: ElementBinding(b.field, mode: 'snapshot'),
  );
}
