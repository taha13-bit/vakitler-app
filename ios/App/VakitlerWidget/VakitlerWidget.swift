import WidgetKit
import SwiftUI

// MARK: - Data written by the app (WidgetBridgePlugin → App Group)

struct VakitDay: Decodable {
    let d: String
    let t: [Double]          // six epoch-millisecond times: imsak, güneş, öğle, ikindi, akşam, yatsı
}

struct VakitPayload: Decodable {
    let loc: String
    let labels: [String]     // six prayer names in the app language
    let nextTitle: String    // e.g. "Sıradaki vakit"
    let openApp: String      // shown when there is no data yet
    let days: [VakitDay]
}

struct Prayer: Hashable {
    let idx: Int
    let name: String
    let date: Date
}

private let appGroup = "group.com.vakitler.app"

func loadPayload() -> VakitPayload? {
    guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: "widgetData"),
          let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(VakitPayload.self, from: data)
}

func allPrayers(_ p: VakitPayload) -> [Prayer] {
    var out: [Prayer] = []
    for day in p.days {
        for (i, ms) in day.t.enumerated() where i < p.labels.count && i < 6 {
            out.append(Prayer(idx: i, name: p.labels[i], date: Date(timeIntervalSince1970: ms / 1000.0)))
        }
    }
    return out.sorted { $0.date < $1.date }
}

// MARK: - Timeline

struct VakitEntry: TimelineEntry {
    let date: Date
    let payload: VakitPayload?
    let next: Prayer?
    let day: [Prayer]        // the six times of the day the next prayer belongs to
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VakitEntry {
        VakitEntry(date: Date(), payload: nil, next: nil, day: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (VakitEntry) -> Void) {
        completion(makeEntry(at: Date(), payload: loadPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VakitEntry>) -> Void) {
        let payload = loadPayload()
        let now = Date()
        var entries: [VakitEntry] = [makeEntry(at: now, payload: payload)]
        if let p = payload {
            let horizon = now.addingTimeInterval(36 * 3600)
            for pr in allPrayers(p) where pr.date > now && pr.date < horizon {
                entries.append(makeEntry(at: pr.date, payload: p))
            }
        }
        let refresh = now.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    func makeEntry(at date: Date, payload: VakitPayload?) -> VakitEntry {
        guard let p = payload else {
            return VakitEntry(date: date, payload: nil, next: nil, day: [])
        }
        let all = allPrayers(p)
        guard let nextIndex = all.firstIndex(where: { $0.date > date }) else {
            return VakitEntry(date: date, payload: p, next: nil, day: [])
        }
        let next = all[nextIndex]
        var day: [Prayer] = []
        let start = nextIndex - next.idx
        if start >= 0 && start + 6 <= all.count {
            day = Array(all[start..<(start + 6)])
        }
        return VakitEntry(date: date, payload: p, next: next, day: day)
    }
}

// MARK: - Views

private let ink = Color.white
private let soft = Color.white.opacity(0.72)
private let accent = Color(red: 1.0, green: 0.72, blue: 0.64)

struct SkyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.08, blue: 0.20), Color(red: 0.11, green: 0.19, blue: 0.43), Color(red: 0.14, green: 0.26, blue: 0.61)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

extension View {
    @ViewBuilder
    func skyBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { SkyBackground() }
        } else {
            self.padding(14).background(SkyBackground())
        }
    }

    @ViewBuilder
    func clearBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

struct SmallView: View {
    let entry: VakitEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.payload?.loc ?? "Vakitler")
                .font(.caption2.weight(.medium))
                .foregroundColor(soft)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let n = entry.next {
                Text(n.name)
                    .font(.headline)
                    .foregroundColor(ink)
                    .lineLimit(1)
                Text(n.date, style: .timer)
                    .font(.system(size: 28, weight: .light).monospacedDigit())
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(n.date, style: .time)
                    .font(.caption.weight(.medium))
                    .foregroundColor(accent)
            } else {
                Text(entry.payload?.openApp ?? "Vakitler")
                    .font(.footnote)
                    .foregroundColor(ink)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumView: View {
    let entry: VakitEntry
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SmallView(entry: entry)
            VStack(spacing: 3) {
                ForEach(entry.day, id: \.self) { p in
                    let isNext = (p == entry.next)
                    HStack {
                        Text(p.name)
                            .font(.caption.weight(isNext ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(p.date, style: .time)
                            .font(.caption.weight(isNext ? .semibold : .regular).monospacedDigit())
                    }
                    .foregroundColor(isNext ? accent : ink.opacity(p.date < entry.date ? 0.5 : 0.9))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isNext ? Color.white.opacity(0.12) : Color.clear)
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct RectangularView: View {
    let entry: VakitEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let n = entry.next {
                HStack(spacing: 4) {
                    Text(n.name).font(.headline).lineLimit(1)
                    Text(n.date, style: .time).font(.caption)
                }
                Text(n.date, style: .timer)
                    .font(.title3.weight(.light).monospacedDigit())
                    .lineLimit(1)
                Text(entry.payload?.loc ?? "")
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text("Vakitler").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineView: View {
    let entry: VakitEntry
    var body: some View {
        if let n = entry.next {
            Text("\(n.name) \(n.date, style: .time)")
        } else {
            Text("Vakitler")
        }
    }
}

struct VakitlerWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: VakitEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumView(entry: entry).skyBackground()
        case .accessoryRectangular:
            RectangularView(entry: entry).clearBackground()
        case .accessoryInline:
            InlineView(entry: entry).clearBackground()
        default:
            SmallView(entry: entry).skyBackground()
        }
    }
}

// MARK: - Widget

private func widgetDescription() -> String {
    let lang = String((Locale.preferredLanguages.first ?? "en").prefix(2))
    switch lang {
    case "tr": return "Sıradaki namaz vakti ve kalan süre"
    case "ar": return "الصلاة القادمة والوقت المتبقي"
    case "de": return "Nächstes Gebet und verbleibende Zeit"
    case "fr": return "Prochaine prière et temps restant"
    default: return "Next prayer and time remaining"
    }
}

struct VakitlerWidget: Widget {
    let kind = "VakitlerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VakitlerWidgetView(entry: entry)
        }
        .configurationDisplayName("Vakitler")
        .description(widgetDescription())
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct VakitlerWidgetBundle: WidgetBundle {
    var body: some Widget {
        VakitlerWidget()
    }
}
