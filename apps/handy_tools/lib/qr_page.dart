import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_scan/handy_scan.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'qr_history.dart';

const _modes = [
  ('text', 'Text', 'Văn bản'),
  ('url', 'Link', 'Liên kết'),
  ('wifi', 'Wi-Fi', 'Wi-Fi'),
  ('contact', 'Contact', 'Liên hệ'),
  ('event', 'Event', 'Sự kiện'),
  ('bank', 'Bank transfer', 'Chuyển khoản'),
];

/// The code redraws as you type; saving or sharing is the only way it
/// leaves the screen (and the only time it enters the optional history).
class QrPage extends StatefulWidget {
  final HandyFiles files;
  final DocumentRepository? historyDocuments;
  final String initialText;

  /// Builds the bench header around this panel's own actions.
  final Widget Function(BuildContext, List<Widget>)? header;
  const QrPage({
    super.key,
    required this.files,
    this.historyDocuments,
    this.initialText = '',
    this.header,
  });
  @override
  State<QrPage> createState() => QrPageState();
}

class QrPageState extends State<QrPage> {
  String mode = 'text', security = 'WPA';

  /// The receiving bank's BIN for a VietQR transfer code.
  String? bankBin;

  @override
  void initState() {
    super.initState();
    final t = widget.initialText.trim();
    if (t.isNotEmpty) {
      mode = RegExp(r'^https?://', caseSensitive: false).hasMatch(t)
          ? 'url'
          : 'text';
      fields[0].text = t;
    }
  }

  bool hidden = false, showPassword = false, busy = false;
  final fields = List.generate(4, (_) => TextEditingController());
  DateTime? start, end;
  late final history = QrHistoryController(
    widget.historyDocuments ??
        localDocuments('handy-tools-qr-history', maxBytes: 300000),
  )..load();
  String _payloadFor = '';
  Uint8List? _png;

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    history.dispose();
    super.dispose();
  }

  static String _utc(DateTime d) =>
      '${d.toUtc().toIso8601String().substring(0, 19)}Z';

  /// Payload for the current form, '' while required fields are empty.
  String payload() {
    final v = fields.map((f) => f.text).toList();
    switch (mode) {
      case 'wifi':
        return v[0].trim().isEmpty ? '' : wifiQr(v[0], v[1], security, hidden);
      case 'contact':
        return v[0].trim().isEmpty
            ? ''
            : contactQr(v[0], v[1].trim(), v[2].trim());
      case 'event':
        if (v[0].trim().isEmpty || start == null || end == null) return '';
        return eventQr(v[0], _utc(start!), _utc(end!), v[3]);
      case 'bank':
        if (bankBin == null || v[0].trim().isEmpty) return '';
        return vietQr(
          bin: bankBin!,
          account: v[0].trim(),
          amount: v[1].trim(),
          message: v[2],
        );
      case 'url':
        final s = v[0].trim();
        if (s.isEmpty) return '';
        final uri = Uri.tryParse(s);
        if (uri == null ||
            !['https', 'http'].contains(uri.scheme) ||
            uri.host.isEmpty)
          throw const FormatException('url');
        return s;
      default:
        return v[0];
    }
  }

  Uint8List png(String value) {
    if (value != _payloadFor) {
      _png = qrPng(value);
      _payloadFor = value;
    }
    return _png!;
  }

  Future<void> save(String value, String format) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final bytes = switch (format) {
        'png' => qrPng(value),
        'svg' => Uint8List.fromList(utf8.encode(qrSvg(value))),
        _ => await qrPdf(value),
      };
      final uri = await widget.files.exportBytes(
        'handy-qr.$format',
        bytes,
        mimeType: switch (format) {
          'png' => 'image/png',
          'svg' => 'image/svg+xml',
          _ => 'application/pdf',
        },
      );
      if (!mounted) return;
      showHandyMessage(
        context,
        uri == null
            ? tr(context, 'Not saved.', 'Chưa lưu.')
            : tr(context, 'Saved', 'Đã lưu'),
      );
      if (uri != null) await history.record(value);
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not save the file.', 'Chưa lưu được file.'),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void setMode(String next) => setState(() {
    mode = next;
    for (final f in fields) {
      f.clear();
    }
    start = end = null;
    bankBin = null;
  });

  Future<void> openHistory() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrHistoryPage(controller: history)),
    );
    if (text != null && mounted) {
      setMode('text');
      setState(() => fields[0].text = text);
    }
  }

  Future<void> scan() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (text != null && mounted) {
      setMode('text');
      setState(() => fields[0].text = text);
    }
  }

  Future<void> pickTime(bool isStart) async {
    final base = (isStart ? start : end) ?? start ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        start = value;
        if (end == null || !end!.isAfter(value))
          end = value.add(const Duration(hours: 1));
      } else {
        end = value;
      }
    });
  }

  List<Widget> form(BuildContext context) {
    Widget text(
      int i,
      String label, {
      String? hint,
      String? helper,
      TextInputType? keyboard,
      bool secret = false,
      int maxLength = 1200,
    }) => HandyField(
      label: label,
      child: TextField(
        key: ValueKey('qr-field-$i'),
        controller: fields[i],
        maxLength: maxLength,
        keyboardType: keyboard,
        obscureText: secret && !showPassword,
        minLines: mode == 'text' ? 3 : 1,
        maxLines: mode == 'text' ? 6 : 1,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          counterText: maxLength < 1200 ? null : '',
          suffixIcon: secret
              ? IconButton(
                  tooltip: showPassword
                      ? tr(context, 'Hide', 'Ẩn')
                      : tr(context, 'Show', 'Hiện'),
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => showPassword = !showPassword),
                )
              : null,
        ),
      ),
    );
    Widget when(String label, DateTime? value, bool isStart) => HandyField(
      label: label,
      child: InkWell(
        key: Key(isStart ? 'qr-start' : 'qr-end'),
        onTap: () => pickTime(isStart),
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.schedule, size: 18),
          ),
          child: Text(
            value == null
                ? tr(context, 'Choose date and time', 'Chọn ngày giờ')
                : MaterialLocalizations.of(context).formatMediumDate(value) +
                      ' · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}',
          ),
        ),
      ),
    );
    return switch (mode) {
      'url' => [
        text(
          0,
          tr(context, 'Web address', 'Địa chỉ web'),
          hint: 'https://',
          keyboard: TextInputType.url,
        ),
      ],
      'wifi' => [
        text(0, tr(context, 'Network name', 'Tên mạng')),
        if (security != 'nopass')
          text(1, tr(context, 'Password', 'Mật khẩu'), secret: true),
        HandyField(
          label: tr(context, 'Security', 'Bảo mật'),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: 'WPA', label: Text('WPA')),
              const ButtonSegment(value: 'WEP', label: Text('WEP')),
              ButtonSegment(
                value: 'nopass',
                label: Text(tr(context, 'None', 'Không')),
              ),
            ],
            selected: {security},
            onSelectionChanged: (s) => setState(() => security = s.first),
          ),
        ),
        HandyGroup(
          children: [
            SwitchListTile.adaptive(
              title: Text(tr(context, 'Hidden network', 'Mạng ẩn')),
              value: hidden,
              onChanged: (v) => setState(() => hidden = v),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
      ],
      'contact' => [
        text(0, tr(context, 'Name', 'Họ tên')),
        text(
          1,
          tr(context, 'Phone', 'Số điện thoại'),
          keyboard: TextInputType.phone,
        ),
        text(2, 'Email', keyboard: TextInputType.emailAddress),
      ],
      'event' => [
        text(0, tr(context, 'Title', 'Tên sự kiện')),
        when(tr(context, 'Starts', 'Bắt đầu'), start, true),
        when(tr(context, 'Ends', 'Kết thúc'), end, false),
        text(3, tr(context, 'Place', 'Địa điểm')),
      ],
      'bank' => [
        HandyField(
          label: tr(context, 'Bank', 'Ngân hàng'),
          child: LayoutBuilder(
            builder: (context, box) => DropdownMenu<String>(
              key: const Key('qr-bank'),
              width: box.maxWidth,
              menuHeight: 320,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: bankBin,
              hintText: tr(
                context,
                'Type to find a bank',
                'Gõ để tìm ngân hàng',
              ),
              dropdownMenuEntries: [
                for (final b in vietQrBanks)
                  DropdownMenuEntry(
                    value: b.bin,
                    label: '${b.shortName} · ${b.code}',
                  ),
              ],
              onSelected: (bin) => setState(() => bankBin = bin),
            ),
          ),
        ),
        text(
          0,
          tr(context, 'Account number', 'Số tài khoản'),
          keyboard: TextInputType.number,
          maxLength: 19,
        ),
        text(
          1,
          tr(context, 'Amount (đ, optional)', 'Số tiền (đ, không bắt buộc)'),
          hint: '150.000',
          keyboard: TextInputType.number,
        ),
        text(
          2,
          tr(context, 'Message (optional)', 'Nội dung (không bắt buộc)'),
          helper: tr(
            context,
            'Accents are removed; letters, digits and spaces.',
            'Tự bỏ dấu; chỉ chữ, số và khoảng trắng.',
          ),
          maxLength: 25,
        ),
      ],
      _ => [text(0, tr(context, 'Text', 'Nội dung'))],
    };
  }

  /// What the code will pay, read back from the payload itself.
  String? transferReadback(BuildContext context, String value) {
    final t = readVietQr(value);
    if (t == null) return null;
    final bank = vietQrBank(t.bin);
    return [
      bank == null ? t.bin : bank.shortName,
      t.account,
      if (t.amount.isNotEmpty) '${formatFigure(context, t.amount)} đ',
      if (t.message.isNotEmpty) '"${t.message}"',
    ].join(' · ');
  }

  String? warning(BuildContext context, String value) => switch (mode) {
    'wifi' => tr(
      context,
      'Holds the Wi-Fi password. Share only with people you trust.',
      'Chứa mật khẩu Wi-Fi. Chỉ chia sẻ với người bạn tin.',
    ),
    'contact' => tr(
      context,
      'Holds personal contact details.',
      'Chứa thông tin liên hệ cá nhân.',
    ),
    'url' => tr(
      context,
      'Opens ${Uri.parse(value).host}. Check the address before sharing.',
      'Mở ${Uri.parse(value).host}. Kiểm tra địa chỉ trước khi chia sẻ.',
    ),
    'bank' => tr(
      context,
      "Whoever scans it should check the account holder's name in their bank app before sending.",
      'Người quét nên kiểm tra tên chủ tài khoản trong app ngân hàng trước khi chuyển.',
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    String value = '', problem = '';
    try {
      value = payload();
      if (value.isNotEmpty) png(value);
    } on FormatException catch (e) {
      value = '';
      problem = e.message == 'url'
          ? tr(
              context,
              'Enter a full address starting with https://',
              'Nhập địa chỉ đầy đủ, bắt đầu bằng https://',
            )
          : e.message;
    }
    final ready = value.isNotEmpty && !busy;
    final note = value.isEmpty ? null : warning(context, value);
    final readback = mode == 'bank' && value.isNotEmpty
        ? transferReadback(context, value)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          widget.header!(context, headerActions(context)),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final m in _modes)
              ChoiceChip(
                key: Key('qr-mode-${m.$1}'),
                label: Text(tr(context, m.$2, m.$3)),
                selected: mode == m.$1,
                onSelected: busy ? null : (_) => setMode(m.$1),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.xl),
        ...form(context),
        const SizedBox(height: HandySpace.s),
        if (problem.isNotEmpty)
          HandyNotice(problem, tone: HandyTone.error)
        else if (value.isEmpty)
          HandyEmpty(
            title: tr(
              context,
              'Fill in the form — the code draws itself here.',
              'Điền thông tin — mã tự vẽ ở đây.',
            ),
          )
        else ...[
          Card(
            color: HandyColors.of(context).lead,
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.xl),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(HandyRadius.control),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(HandySpace.m),
                    child: Image.memory(
                      png(value),
                      width: 220,
                      height: 220,
                      filterQuality: FilterQuality.none,
                      gaplessPlayback: true,
                      semanticLabel: tr(
                        context,
                        'QR code preview',
                        'Xem trước mã QR',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (readback != null) ...[
            const SizedBox(height: HandySpace.s),
            Text(
              readback,
              key: const Key('qr-readback'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontFeatures: tabular),
            ),
          ],
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              FilledButton.icon(
                key: const Key('qr-save'),
                onPressed: ready ? () => save(value, 'png') : null,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(tr(context, 'Save image', 'Lưu ảnh')),
              ),
              HandyShareButton(
                name: 'handy-qr.png',
                mimeType: 'image/png',
                bytes: ready
                    ? () {
                        history.record(value);
                        return png(value);
                      }
                    : null,
              ),
            ],
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: HandySpace.m),
          HandyNotice(
            note,
            tone: mode == 'url' || mode == 'bank'
                ? HandyTone.info
                : HandyTone.warning,
          ),
        ],
        ListenableBuilder(
          listenable: history,
          builder: (context, _) => history.error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: HandySpace.m),
                  child: HandyNotice(
                    tr(context, history.error!.$1, history.error!.$2),
                    tone: HandyTone.error,
                  ),
                ),
        ),
      ],
    );
  }

  /// Header actions for the bench: scan, history and the other formats.
  List<Widget> headerActions(BuildContext context) {
    String value = '';
    try {
      value = payload();
    } on FormatException {
      value = '';
    }
    final ready = value.isNotEmpty && !busy;
    return [
      if (nativeQrScanningSupported)
        IconButton(
          key: const Key('qr-camera'),
          tooltip: tr(context, 'Scan a code', 'Quét mã'),
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: busy ? null : scan,
        ),
      IconButton(
        key: const Key('qr-history'),
        tooltip: tr(context, 'History', 'Lịch sử'),
        icon: const Icon(Icons.history),
        onPressed: openHistory,
      ),
      HandyMenuButton(
        items: [
          HandyMenuItem(
            Icons.code,
            tr(context, 'Save as SVG', 'Lưu dạng SVG'),
            ready ? () => save(value, 'svg') : null,
            key: const Key('qr-svg'),
          ),
          HandyMenuItem(
            Icons.picture_as_pdf_outlined,
            tr(context, 'Save as PDF', 'Lưu dạng PDF'),
            ready ? () => save(value, 'pdf') : null,
            key: const Key('qr-pdf'),
          ),
          HandyMenuItem(
            Icons.copy_rounded,
            tr(context, 'Copy content', 'Sao chép nội dung'),
            ready ? () => copyToClipboard(context, value) : null,
          ),
        ],
      ),
    ];
  }
}
