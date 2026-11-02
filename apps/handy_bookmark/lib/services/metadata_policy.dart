import 'metadata_types.dart';

/// Conservative public-network policy shared by URL parsing and DNS checks.
/// IPv6 is restricted to globally routable unicast, excluding special ranges.
bool isPublicMetadataAddress(String address) {
  var host = address.toLowerCase();
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  if (host.contains('%')) return false;
  if (!host.contains(':')) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final bytes = <int>[];
    for (final part in parts) {
      if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part)) return false;
      final value = int.parse(part);
      if (value > 255) return false;
      bytes.add(value);
    }
    final a = bytes[0], b = bytes[1], c = bytes[2];
    return !(a == 0 ||
        a == 10 ||
        a == 127 ||
        a >= 224 ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 &&
            (b == 168 ||
                (b == 0 && (c == 0 || c == 2)) ||
                (b == 88 && c == 99))) ||
        (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) ||
        (a == 203 && b == 0 && c == 113));
  }
  if (host.contains('.') || !RegExp(r'^[0-9a-f:]+$').hasMatch(host))
    return false;
  final halves = host.split('::');
  if (halves.length > 2) return false;
  List<String> groups(String value) => value.isEmpty ? [] : value.split(':');
  final left = groups(halves.first);
  final right = halves.length == 2 ? groups(halves.last) : <String>[];
  if (halves.length == 1 && left.length != 8) return false;
  if (halves.length == 2 && left.length + right.length >= 8) return false;
  final all = [
    ...left,
    if (halves.length == 2) ...List.filled(8 - left.length - right.length, '0'),
    ...right,
  ];
  if (all.any((v) => v.isEmpty || v.length > 4)) return false;
  final words = all.map((v) => int.parse(v, radix: 16)).toList();
  if (words.length != 8 || words[0] < 0x2000 || words[0] > 0x3fff) return false;
  if (words[0] == 0x2001 && words[1] < 0x0200) return false;
  if (words[0] == 0x2001 && words[1] == 0x0db8) return false;
  if (words[0] == 0x2002) return false; // 6to4 embeds IPv4 destinations.
  if (words[0] == 0x3fff && words[1] < 0x1000) return false;
  return true;
}

Uri? publicMetadataUri(String input, {Uri? base}) {
  if (input.isEmpty ||
      input.length > metadataMaxUrlLength ||
      input.contains(RegExp(r'[\x00-\x20\x7f\\]')))
    return null;
  try {
    var uri = Uri.parse(input);
    if (base != null) uri = base.resolveUri(uri);
    if (uri.toString().length > metadataMaxUrlLength ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        (uri.port != 80 && uri.port != 443))
      return null;
    var host = uri.host.toLowerCase();
    if (host.startsWith('[')) host = host.substring(1, host.length - 1);
    if (host.contains(':')) return isPublicMetadataAddress(host) ? uri : null;
    if (RegExp(r'^[0-9.]+$').hasMatch(host)) {
      return isPublicMetadataAddress(host) ? uri : null;
    }
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    final labels = host.split('.');
    if (labels.length < 2 ||
        labels.any(
          (v) => !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(v),
        ) ||
        labels.any((v) => v.startsWith('0x')) ||
        !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(labels.last) ||
        [
          'localhost',
          'local',
          'internal',
          'lan',
          'home',
          'test',
          'invalid',
          'example',
          'onion',
          'arpa',
        ].contains(labels.last))
      return null;
    return uri;
  } on FormatException {
    return null;
  }
}
