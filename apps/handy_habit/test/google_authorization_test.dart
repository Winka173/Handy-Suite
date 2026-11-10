import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:handy_habit/sync/drive_provider.dart';

class GooglePlatform extends GoogleSignInPlatform {
  final calls = <ClientAuthorizationTokensForScopesParameters>[];
  bool denied = false, expired = false, disconnected = false;
  String? forgotten;
  @override
  Future<void> init(InitParameters params) async {
    expect(params.serverClientId, isNull);
    expect(params.clientId, isNull);
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    calls.add(params);
    expect(params.request.scopes, [GoogleDriveAuth.scope]);
    if (denied) throw StateError('denied');
    return expired
        ? null
        : const ClientAuthorizationTokenData(accessToken: 'session-only');
  }

  @override
  Future<void> clearAuthorizationToken(
    ClearAuthorizationTokenParams params,
  ) async {
    forgotten = params.accessToken;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {
    disconnected = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authorization-only flow needs no Web client, handles denial/expiry/revoke',
    () async {
      final old = GoogleSignInPlatform.instance, platform = GooglePlatform();
      GoogleSignInPlatform.instance = platform;
      addTearDown(() => GoogleSignInPlatform.instance = old);
      expect(await GoogleDriveAuth.authorize(), true);
      expect(platform.calls.single.request.promptIfUnauthorized, true);
      const auth = GoogleDriveAuth();
      expect(await auth.token(), 'session-only');
      expect(platform.calls.last.request.promptIfUnauthorized, false);
      await auth.forget('rejected-token');
      expect(platform.forgotten, 'rejected-token');
      platform.expired = true;
      await expectLater(auth.token(), throwsA(isA<DriveException>()));
      platform.denied = true;
      expect(await GoogleDriveAuth.authorize(), false);
      await GoogleDriveAuth.revoke();
      expect(platform.disconnected, true);
      expect(GoogleDriveAuth.account, isNull);
    },
  );
}
