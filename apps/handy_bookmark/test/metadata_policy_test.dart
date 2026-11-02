import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/metadata_policy.dart';
import 'package:handy_bookmark/services/metadata_types.dart';

void main() {
  test('rejects private, special, and ambiguous IPv4 addresses', () {
    for (final value in [
      '0.0.0.0',
      '10.255.255.255',
      '127.0.0.1',
      '169.254.169.254',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.1.1',
      '100.64.0.1',
      '100.127.255.255',
      '192.0.0.1',
      '192.0.2.1',
      '192.88.99.1',
      '198.18.0.1',
      '198.19.255.255',
      '198.51.100.1',
      '203.0.113.1',
      '224.0.0.1',
      '239.255.255.255',
      '240.0.0.1',
      '255.255.255.255',
      '2130706433',
      '0177.0.0.1',
      '0x7f.0.0.1',
      '127.1',
      '8.8.8.256',
    ]) {
      expect(isPublicMetadataAddress(value), isFalse, reason: value);
    }
    for (final value in [
      '8.8.8.8',
      '1.1.1.1',
      '100.63.255.255',
      '100.128.0.0',
      '172.15.255.255',
      '172.32.0.0',
      '198.20.0.0',
    ]) {
      expect(isPublicMetadataAddress(value), isTrue, reason: value);
    }
  });
  test(
    'rejects IPv6 local, mapped, translated, multicast and reserved ranges',
    () {
      for (final value in [
        '::',
        '::1',
        '::ffff:127.0.0.1',
        '::ffff:7f00:1',
        '64:ff9b::a00:1',
        '64:ff9b:1::1',
        'fc00::1',
        'fdff::1',
        'fe80::1',
        'fec0::1',
        'ff02::1',
        '2001:db8::1',
        '2001::1',
        '2001:20::1',
        '2002:7f00:1::1',
        '3fff::1',
        'fe80::1%eth0',
        '2001:::1',
        '::1::2',
        '2001:4860:4860:0:0:0:0:0:1',
      ]) {
        expect(isPublicMetadataAddress(value), isFalse, reason: value);
      }
      for (final value in [
        '2001:4860:4860::8888',
        '2606:4700:4700::1111',
        '[2001:4860:4860:0000:0000:0000:0000:8888]',
      ]) {
        expect(isPublicMetadataAddress(value), isTrue, reason: value);
      }
    },
  );
  test(
    'URL gate blocks credentials, schemes, local domains and numeric aliases',
    () {
      for (final value in [
        'file:///etc/passwd',
        'javascript:alert(1)',
        'https://user:pass@public.org',
        'http://localhost',
        'http://foo.local',
        'http://foo.internal',
        'http://localhost.',
        'http://single',
        'http://127.0.0.1',
        'http://2130706433',
        'http://0x7f000001',
        'http://0177.0.0.1',
        'http://[::ffff:7f00:1]',
        'http://public.org:8080',
        'https://public.org/\\@127.0.0.1',
        'https://public.org/\npath',
        'https://public.org/${'a' * metadataMaxUrlLength}',
      ]) {
        expect(publicMetadataUri(value), isNull, reason: value);
      }
      expect(publicMetadataUri('https://public.org/a?b=1'), isNotNull);
      expect(publicMetadataUri('https://8.8.8.8/'), isNotNull);
      expect(publicMetadataUri('https://[2001:4860:4860::8888]/'), isNotNull);
      final prefix = 'https://public.org/';
      expect(
        publicMetadataUri(
          prefix + 'a' * (metadataMaxUrlLength - prefix.length),
        ),
        isNotNull,
      );
    },
  );
}
