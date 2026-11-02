import SwiftUI
import WidgetKit

struct BoardsEntry: TimelineEntry {
  let date: Date
  let payload: [String: Any]
}
struct BoardsProvider: TimelineProvider {
  func placeholder(in context: Context) -> BoardsEntry {
    BoardsEntry(date: Date(), payload: [:])
  }
  func getSnapshot(in context: Context, completion: @escaping (BoardsEntry) -> Void) { completion(load()) }
  func getTimeline(in context: Context, completion: @escaping (Timeline<BoardsEntry>) -> Void) {
    completion(Timeline(entries: [load()], policy: .never))
  }
  private func load() -> BoardsEntry {
    guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.handysuite.boards"),
          let bytes = try? Data(contentsOf: group.appendingPathComponent("boards-widget.json")),
          let payload = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] else {
      return BoardsEntry(date: Date(), payload: [:])
    }
    return BoardsEntry(date: Date(), payload: payload)
  }
}
struct BoardsWidgetView: View {
  let entry: BoardsEntry
  @Environment(\.widgetFamily) var family
  private var vi: Bool { (entry.payload["vi"] as? Bool) ?? (Locale.current.languageCode == "vi") }
  @ViewBuilder
  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    } else { content.background(Color(UIColor.systemBackground)) }
  }
  private var content: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Handy Boards").font(.caption).foregroundColor(.secondary)
      Text(entry.payload["value"] as? String ?? (vi ? "Mở bảng của bạn" : "Open your boards"))
        .font(.headline).lineLimit(2)
      Text(entry.payload["detail"] as? String ?? (vi ? "Bật nội dung trong Cài đặt" : "Enable content in Settings"))
        .font(.caption).foregroundColor(.secondary).lineLimit(2)
      if family != .systemSmall {
        ForEach(0..<3, id: \.self) { index in
          if let text = entry.payload["row\(index)_text"] as? String,
             let value = entry.payload["row\(index)_uri"] as? String, let url = URL(string: value) {
            Link(destination: url) { Text(text).font(.subheadline).lineLimit(1) }
          }
        }
      }
      Spacer(minLength: 0)
      if let updated = entry.payload["updated"] as? Double {
        Text(Date(timeIntervalSince1970: updated), style: .time).font(.caption2).foregroundColor(.secondary)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(URL(string: "handy-boards://today"))
  }
}
@main
struct BoardsDueWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BoardsDueWidget", provider: BoardsProvider()) { entry in BoardsWidgetView(entry: entry) }
      .configurationDisplayName("Handy Boards")
      .description(Locale.current.languageCode == "vi" ? "Việc đến hạn; cập nhật khi mở hoặc sửa trong app." : "Due tasks; updated when opening or editing in the app.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
