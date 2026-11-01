"""Audit recorded checks/artifacts without treating builds as device certification."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
apps = {'tools', 'docs', 'media', 'dev', 'keep', 'recall'}
errors = []

def read(name):
    return json.loads((evidence / name).read_text(encoding='utf-8-sig'))

def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            value.update(chunk)
    return value.hexdigest()

source = subprocess.check_output([sys.executable, str(root / 'tooling/flutter-source-fingerprint.py')], text=True).strip()


def integration_passed(name, row):
    if row['physicalDevice']:
        return False
    if row.get('sourceSha256') and (row['sourceSha256'] != source or not row.get('sourceUnchanged')):
        return False
    if row['exitCode'] == 0:
        return True
    recovery_path = evidence / f'{name}-driver-reconnect-result.json'
    if not recovery_path.is_file():
        return False
    recovery = read(recovery_path.name)
    log_path = evidence / f'{name}-driver-reconnect.log'
    if not log_path.is_file():
        return False
    raw = log_path.read_bytes()
    log = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    return (recovery['exitCode'] == 0 and not recovery['physicalDevice'] and
            recovery['device'] == row['device'] and
            recovery['originalTransportExitCode'] == row['exitCode'] and
            recovery['sourceSha256'] == source and
            recovery['existingProcessResultsRetrieved'] and
            recovery['logSha256'] == digest(log_path) and
            'All tests passed.' in log)


subprocess.run([sys.executable, str(root / 'tooling/flutter-test-summary.py')], check=True)
tests = read('flutter-tests-summary.json')
if not tests['melosSuccess'] or tests['logSha256'] != digest(evidence / 'flutter-tests.log'):
    errors.append('Unit/widget summary does not match a successful complete raw log')
build_count = 0
for target in ['apk', 'windows', 'web']:
    records = read(f'builds-{target}.json')
    if len(records) != 6 or {row['app'] for row in records} != apps:
        errors.append(f'{target}: must have exactly six app records')
    for row in records:
        if row['exitCode'] != 0 or not row['sourceUnchanged'] or row['sourceSha256'] != source:
            errors.append(f"{row['app']}/{target}: failed or outdated source evidence")
        else:
            build_count += 1
        if target == 'apk':
            path = root / row.get('artifact', '')
            if not path.is_file() or digest(path) != row.get('artifactSha256'):
                errors.append(f"{row['app']}: preserved main APK hash mismatch")
msix_count = 0
# Font relocation must be reflected in each real PDF-capable app's bundles.
font_sources = json.loads((root / 'packages/handy_ui/assets/fonts/SOURCES.json').read_text(encoding='utf-8-sig'))
for app in ['docs', 'media']:
    apk = root / f'artifacts/flutter/handy_{app}/android/handy-{app}-pilot-debug.apk'
    with zipfile.ZipFile(apk) as archive:
        for font in font_sources:
            relative = f"packages/handy_ui/assets/fonts/{font['file']}"
            for target, prefix in [('web', f'apps/handy_{app}/build/web/assets'),
                                   ('windows', f'apps/handy_{app}/build/windows/x64/runner/Release/data/flutter_assets')]:
                path = root / prefix / relative
                if not path.is_file() or digest(path) != font['sha256']:
                    errors.append(f'{app}/{target}: shared PDF font/license missing or changed')
            member = f'assets/flutter_assets/{relative}'
            if member not in archive.namelist() or hashlib.sha256(archive.read(member)).hexdigest() != font['sha256']:
                errors.append(f'{app}/apk: shared PDF font/license missing or changed')
        if not all(f'lib/{abi}/libpdfium.so' in archive.namelist()
                   for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']):
            errors.append(f'{app}/apk: PDFium native ABI library missing')
for app in sorted(apps):
    row = read(f'{app}-msix-result.json')
    path = Path(row['artifact'])
    if (row['app'] != app or row['sourceSha256'] != source or not row['makeAppxValidated'] or
        row['signed'] or row['installed'] or row['storeApproved'] or
        not path.is_file() or digest(path) != row['sha256']):
        errors.append(f'{app}: unsigned MSIX validation/hash/source mismatch')
    else:
        msix_count += 1
    row = read(f'{app}-android-screenshots-result.json')
    if row['exitCode'] != 0 or row['physicalDevice']:
        errors.append(f'{app}: emulator integration did not pass')
for app in ['keep', 'recall']:
    rows = read(f'{app}-notifications-results.json')
    if len(rows) != 2 or {row['permission'] for row in rows} != {False, True} or any(row['exitCode'] != 0 for row in rows):
        errors.append(f'{app}: denied/granted native notification evidence incomplete')
subprocess.run([sys.executable, str(root / 'tooling/verify-fixtures.py')], check=True)
browser_tools = read('flutter-browser-tools-results.json')
if not browser_tools['success'] or browser_tools['numFailedTests'] or browser_tools['numPassedTests'] != 7:
    errors.append('Flutter RE2 / six PWA auxiliary tests did not pass')
qr_native = read('tools-qr-native-result.json')
pdf_native = read('docs-pdf-android-screenshots-result.json')
capture_native = read('media-capture-android-screenshots-result.json')
capture_consent = read('capture-consent-actions.json')
capture_decode = read('native-capture/independent-video-verification.json')
guide_native = read('media-guide-android-screenshots-result.json')
guide_decode = read('guide-native/independent-guide-verification.json')
recovery_native = read('keep-recovery-android-screenshots-result.json')
conversion_native = read('media-conversion-android-screenshots-result.json')
extra_integrations = {
    name: read(f'{name}-android-screenshots-result.json')
    for name in ['media-camera-share', 'media-large-project', 'tools-state',
                 'dev-state', 'docs-reader', 'docs-parity', 'media-parity', 'media-editor', 'media-video-transform']
}
for name, row in extra_integrations.items():
    if not integration_passed(name, row):
        errors.append(f'{name}: actual Android integration did not pass')
video_transform = read('video-transform/independent-video-transform.json')
if not video_transform['passed'] or set(video_transform['artifacts']) != {'source.mp4', 'muted-rotated.mp4', 'resized-audio.mp4'}:
    errors.append('Independent bounded MP4 transform evidence incomplete')
for name, row in video_transform['artifacts'].items():
    if name not in {'source.mp4', 'muted-rotated.mp4', 'resized-audio.mp4'}:
        errors.append('Unexpected video transform artifact path')
        continue
    path = evidence / 'video-transform' / name
    if not path.is_file() or digest(path) != row['sha256'] or path.stat().st_size != row['bytes']:
        errors.append(f'{name}: transform decoder artifact hash mismatch')
for name in ['media-editor-draft-restored', 'media-editor-zoom-pan', 'media-editor-share-review',
             'media-catalog-search', 'media-cleanup-confirm', 'media-cleanup-complete']:
    path = evidence / 'screenshots' / f'{name}.png'
    if not path.is_file() or path.stat().st_size < 1000:
        errors.append(f'{name}: actual UI screenshot missing')
camera_actions = read('camera-share-system-actions.json')
if not camera_actions['complete'] or len(camera_actions['actions']) != 3 or any(
        not action['realSystemUi'] for action in camera_actions['actions']):
    errors.append('Real Android camera cancel/capture and share dismissal evidence incomplete')
webp = read('webp/independent-webp-verification.json')
if not webp['passed'] or set(webp['outputs']) != {'20', '85', '100'}:
    errors.append('Independent WebP decode evidence incomplete')
for quality, row in webp['outputs'].items():
    path = evidence / 'webp' / f'quality-{quality}.webp'
    if not path.is_file() or digest(path) != row['sha256'] or path.stat().st_size != row['bytes']:
        errors.append(f'WebP {quality}: independent artifact hash mismatch')
large_project = read('large-project/independent-large-project-verification.json')
large_source = evidence / 'large-project/source-32m.png'
if (not large_project['passed'] or not large_project['zipAssetExact'] or
        not large_source.is_file() or digest(large_source) != large_project['sourceSha256']):
    errors.append('Original 32Mpx project compatibility evidence incomplete')
pwa = read('pwa-script-results.json')
if not pwa['success'] or pwa['numFailedTests'] or pwa['numPassedTests'] != 6:
    errors.append('Six-app PWA asset/script checks did not pass')
for app in sorted(apps):
    worker = root / f'apps/handy_{app}/build/web/handy_{app}_service_worker.js'
    bootstrap = root / f'apps/handy_{app}/build/web/flutter_bootstrap.js'
    if (not worker.is_file() or not bootstrap.is_file() or
            f'handy_{app}_service_worker.js' not in bootstrap.read_text(encoding='utf-8')):
        errors.append(f'{app}: built local offline/update assets missing')
if recovery_native['exitCode'] != 0 or recovery_native['physicalDevice']:
    errors.append('Native preserved-library recovery integration did not pass')
if conversion_native['exitCode'] != 0 or conversion_native['physicalDevice']:
    errors.append('Native JPEG/PNG conversion batch integration did not pass')
if guide_native['exitCode'] != 0 or not guide_decode['passed'] or len(guide_decode['artifacts']) != 6:
    errors.append('Native six-format guide export / independent decoding incomplete')
for name, row in guide_decode['artifacts'].items():
    if name not in {'handy-media-guide.html', 'handy-media-guide.pdf', 'handy-media-guide.md',
                    'handy-media-guide.zip', 'handy-media-long.png', 'handy-media-change-map.png'}:
        errors.append('Unexpected guide artifact path')
        continue
    path = evidence / 'guide-native' / name
    if not path.is_file() or digest(path) != row['sha256'] or path.stat().st_size != row['bytes']:
        errors.append(f'{name}: independent guide artifact hash mismatch')
schema = read('schema-conformance-summary.json')
if not integration_passed('media-capture', capture_native) or not capture_consent['complete'] or len(capture_consent['actions']) != 3:
    errors.append('Android capture system-consent/codec integration did not pass')
if not capture_decode['passed'] or len(capture_decode['artifacts']) != 5:
    errors.append('Independent native capture decoding did not pass')
for name, row in capture_decode['artifacts'].items():
    if name not in {'recording.mp4', 'trimmed.mp4', 'joined.mp4', 'frame.png', 'screenshot.png'}:
        errors.append('Unexpected capture artifact path')
        continue
    path = evidence / 'native-capture' / name
    if not path.is_file() or digest(path) != row['sha256'] or path.stat().st_size != row['bytes']:
        errors.append(f'{name}: independent capture artifact hash mismatch')
if schema['failed'] or schema['passed'] != 898 or len(schema['excludedByPolicy']) != 27:
    errors.append('Offline draft7 conformance evidence incomplete')
if qr_native['exitCode'] != 0:
    errors.append('Native QR decoder/denied-permission integration failed')
if pdf_native['exitCode'] != 0:
    errors.append('Native PDF engine/UI integration failed')
report = {'sourceSha256': source, 'unitWidgetPassed': tests['totalPassed'],
          'unitWidgetSkipped': tests.get('totalSkipped', 0),
          'currentSuccessfulBuilds': build_count,
          'validatedUnsignedMsix': msix_count, 'errors': errors,
          'passed': not errors, 'physicalDeviceVerified': False, 'iosBuilt': False,
          'browserRuntimeVerified': False, 'realStoreTransactionsVerified': False,
          'featureParityComplete': False, 'releaseReady': False,
          'currentFlutterBrowserToolTestsPassed': browser_tools['numPassedTests']}
report.update({'nativeQrDecoderAndDeniedPermissionPassed': qr_native['exitCode'] == 0,
               'nativeEditorDraftCatalogCleanupPassed': integration_passed('media-editor', extra_integrations['media-editor']),
               'nativeVideoTransformPassed': integration_passed('media-video-transform', extra_integrations['media-video-transform']),
               'independentVideoTransformPassed': video_transform['passed'],
               'nativePdfRoundtripPassed': pdf_native['exitCode'] == 0,
               'nativeAndroidCapturePassed': integration_passed('media-capture', capture_native),
               'independentCaptureDecoderPassed': capture_decode['passed'],
               'nativeSixFormatGuideExportsPassed': guide_native['exitCode'] == 0,
               'nativePreservedLibraryRecoveryPassed': recovery_native['exitCode'] == 0,
               'nativeImageConversionPassed': conversion_native['exitCode'] == 0,
               'nativeCameraSharePassed': extra_integrations['media-camera-share']['exitCode'] == 0,
               'nativeLargeProjectPassed': extra_integrations['media-large-project']['exitCode'] == 0,
               'nativeReaderLibraryPassed': integration_passed('docs-reader', extra_integrations['docs-reader']),
               'nativeSettingsWorkflowsAndBatchPassed': integration_passed('docs-parity',extra_integrations['docs-parity']),
               'nativeFlipAndAnnotationImageEditPassed': integration_passed('media-parity',extra_integrations['media-parity']),
               'nativeToolsHistoryAndDevPinsPassed': all(extra_integrations[f'{app}-state']['exitCode'] == 0 for app in ['tools', 'dev']),
               'independentWebPDecoderPassed': webp['passed'],
               'sixAppPwaScriptsPassed': pwa['numPassedTests'],
               'independentGuideDecoderPassed': guide_decode['passed'],
               'draft7ConformancePassed': schema['passed'],
               'draft7RemoteCasesSkipped': len(schema['excludedByPolicy']),
               'liveOpticalQrVerified': False})
(evidence / 'checkpoint-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(1 if errors else 0)
