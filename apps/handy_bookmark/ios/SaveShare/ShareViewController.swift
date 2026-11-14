import UIKit
import UniformTypeIdentifiers

/// No Flutter, ads, networking, or host-launch APIs run inside this extension.
final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let done = UIButton(type: .system)
    private var started = false
    private var finished = false
    private var failed = false
    private var parts: [String] = []
    private var pictures: [ShareQueue.Picture] = []
    private var count = 0
    private var sharedTitle: String?
    private let deliveryID = UUID().uuidString.lowercased()
    private func localized(_ english: String, _ vietnamese: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("vi") == true ? vietnamese : english
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.font = .preferredFont(forTextStyle: .headline)
        status.adjustsFontForContentSizeCategory = true
        status.numberOfLines = 0; status.textAlignment = .center
        status.text = localized("Queuing for Handy Bookmark…", "Đang thêm vào hàng đợi Handy Bookmark…")
        done.setTitle(localized("Done", "Xong"), for: .normal)
        done.addTarget(self, action: #selector(close), for: .touchUpInside)
        done.isHidden = true
        let stack = UIStackView(arrangedSubviews: [status, done]); stack.axis = .vertical; stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }; started = true
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        // Safari (and most browsers) name the page in the item's title or
        // content text; kept as the share's title, never fetched.
        sharedTitle = items.lazy.compactMap { item -> String? in
            let text = (item.attributedTitle?.string ?? item.attributedContentText?.string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty || text.lowercased().hasPrefix("http") || text.count > 4096 ? nil : text
        }.first
        let providers = items.flatMap { $0.attachments ?? [] }.filter {
            $0.hasItemConformingToTypeIdentifier("public.url") || $0.hasItemConformingToTypeIdentifier("public.plain-text")
                || $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
        guard !providers.isEmpty, providers.count <= ShareQueue.maxPending,
              providers.filter({ Self.isPicture($0) }).count <= ShareQueue.maxImages else { finish(false); return }
        // Providers are loaded serially; never request remote URL contents.
        load(providers, index: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self, !self.finished else { return }; self.finish(false)
        }
    }
    private func load(_ providers: [NSItemProvider], index: Int) {
        guard !finished else { return }
        if index == providers.count {
            do {
                guard !failed, !parts.isEmpty || !pictures.isEmpty else { throw ShareQueue.QueueError() }
                try ShareQueue().enqueue(text: parts.joined(separator: "\n"), title: sharedTitle, id: deliveryID, pictures: pictures)
                finish(true)
            } catch { finish(false) }
            return
        }
        let provider = providers[index]
        if Self.isPicture(provider) { loadPicture(provider, providers: providers, index: index); return }
        let type = provider.hasItemConformingToTypeIdentifier("public.url") ? "public.url" : "public.plain-text"
        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, error in
            DispatchQueue.main.async {
                guard let self = self, !self.finished else { return }
                var text: String?
                if let url = item as? URL { text = url.absoluteString }
                else if let string = item as? String { text = string }
                else if let data = item as? Data, data.count <= ShareQueue.maxCharacters * 4 { text = String(data: data, encoding: .utf8) }
                if error != nil || text == nil { self.failed = true }
                if let text = text, !text.isEmpty, !self.parts.contains(text) {
                    if self.count + text.utf16.count + self.parts.count > ShareQueue.maxCharacters { self.finish(false); return }
                    self.count += text.utf16.count; self.parts.append(text)
                }
                self.load(providers, index: index + 1)
            }
        }
    }
    /// A picture, not a link that happens to point at one.
    private static func isPicture(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            && !provider.hasItemConformingToTypeIdentifier("public.url")
    }

    private static func mime(_ provider: NSItemProvider) -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) { return "image/jpeg" }
        if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) { return "image/png" }
        if provider.hasItemConformingToTypeIdentifier(UTType.webP.identifier) { return "image/webp" }
        return nil
    }

    /// Copies one picture's bytes from the sharing app (a local file the
    /// system hands over; nothing is fetched). Other formats are refused,
    /// as are pictures over the size limit.
    private func loadPicture(_ provider: NSItemProvider, providers: [NSItemProvider], index: Int) {
        guard let mime = Self.mime(provider) else { finish(false); return }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
            var data: Data?
            if let url = url, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size <= ShareQueue.maxImageBytes { data = try? Data(contentsOf: url) }
            let name = provider.suggestedName ?? url?.lastPathComponent ?? ""
            DispatchQueue.main.async {
                guard let self = self, !self.finished else { return }
                guard error == nil, let data = data else { self.finish(false); return }
                self.pictures.append(ShareQueue.Picture(data: data, mime: mime, name: name))
                self.load(providers, index: index + 1)
            }
        }
    }

    private func finish(_ success: Bool) {
        guard !finished else { return }; finished = true; failed = !success
        status.text = success
            ? localized("Queued safely. Open Handy Bookmark to add it to Not sorted.", "Đã lưu vào hàng đợi. Mở Handy Bookmark để thêm vào Chưa xếp.")
            : localized("Could not queue this share. Try again, or open Handy Bookmark and paste the link. Limit: 262144 characters and 100 pending shares.", "Không thể thêm vào hàng đợi. Hãy thử lại hoặc mở Handy Bookmark và dán liên kết. Giới hạn: 262144 ký tự và 100 lượt chờ.")
        done.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: status.text)
    }
    @objc private func close() {
        if failed { extensionContext?.cancelRequest(withError: NSError(domain: "HandySaveShare", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to queue share"])) }
        else { extensionContext?.completeRequest(returningItems: nil, completionHandler: nil) }
    }
}
