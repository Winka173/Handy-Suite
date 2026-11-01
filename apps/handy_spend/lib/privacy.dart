import 'capabilities.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'controller.dart';

/// Device authentication is access control, not database encryption.
class SpendPrivacy {
  final LocalAuthentication auth;
  SpendPrivacy({LocalAuthentication? auth})
    : auth = auth ?? LocalAuthentication();
  bool get supported => SpendCapabilities.current.deviceLock;
  Future<bool> available() async {
    if (!supported) return false;
    try {
      return await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock(String reason) async {
    if (!supported) return false;
    try {
      return await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } catch (_) {
      return false;
    }
  }
}

class SpendPrivacyGate extends StatefulWidget {
  final SpendController controller;
  final Widget child;
  final SpendPrivacy? authentication;
  const SpendPrivacyGate({
    super.key,
    required this.controller,
    required this.child,
    this.authentication,
  });
  @override
  State<SpendPrivacyGate> createState() => _SpendPrivacyGateState();
}

class _SpendPrivacyGateState extends State<SpendPrivacyGate>
    with WidgetsBindingObserver {
  late final auth = widget.authentication ?? SpendPrivacy();
  bool initialized = false,
      locked = false,
      obscured = false,
      authenticating = false;
  DateTime? backgroundAt;
  bool get enabled =>
      auth.supported && widget.controller.state?.settings['deviceLock'] == true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(changed);
    changed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (widget.controller.state != null && !initialized) {
      initialized = true;
      locked = enabled;
    }
    if (!enabled) locked = false;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.inactive ||
        value == AppLifecycleState.paused ||
        value == AppLifecycleState.hidden) {
      backgroundAt ??= DateTime.now().toUtc();
      if (mounted) setState(() => obscured = true);
    }
    if (value == AppLifecycleState.resumed) {
      final elapsed = backgroundAt == null
          ? Duration.zero
          : DateTime.now().toUtc().difference(backgroundAt!);
      final seconds =
          widget.controller.state?.settings['lockSeconds'] as int? ?? 60;
      if (enabled &&
          !authenticating &&
          (elapsed.isNegative || elapsed.inSeconds >= seconds))
        locked = true;
      backgroundAt = null;
      if (mounted) setState(() => obscured = false);
    }
  }

  Future<void> unlock() async {
    if (authenticating) return;
    setState(() => authenticating = true);
    final success = await auth.unlock(
      'Unlock Handy Spend / Mở khóa Handy Spend',
    );
    if (!mounted) return;
    setState(() {
      authenticating = false;
      if (success) locked = false;
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: locked || obscured, child: widget.child),
        if (locked || obscured)
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 48),
                        const Text('Handy Spend'),
                        if (locked)
                          FilledButton(
                            key: const Key('spend-unlock'),
                            onPressed: authenticating ? null : unlock,
                            child: const Text('Unlock / Mở khóa'),
                          ),
                        const Text(
                          'Device biometrics or PIN / Sinh trắc hoặc PIN thiết bị',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
