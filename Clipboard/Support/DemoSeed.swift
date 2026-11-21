import Foundation

/// The twelve sample items from the design, used by `--demo` so screenshots
/// and UI tests are deterministic. Items 1 and 5 are pinned.
enum DemoSeed {
    static let launchArgument = "--demo"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// `--demo-count N` pads the demo history to N items (for performance work).
    static var requestedCount: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--demo-count"), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }

    /// The twelve design items followed by synthetic variations of them,
    /// each a minute older than the last, up to `count` items.
    static func snapshots(count: Int, now: Date = .now) -> [ClipSnapshot] {
        let base = snapshots(now: now)
        guard count > base.count else { return Array(base.prefix(count)) }
        var result = base
        result.reserveCapacity(count)
        for index in base.count..<count {
            let template = base[index % base.count]
            result.append(ClipSnapshot(
                title: "\(template.title) #\(index)",
                content: template.content,
                source: template.source,
                createdAt: now.addingTimeInterval(-Double(index) * 60 - 7_200),
                isPinned: false
            ))
        }
        return result
    }

    static func snapshots(now: Date = .now) -> [ClipSnapshot] {
        let notes = SourceApp(name: "Notes", bundleID: "com.apple.Notes", tint: RGBColor(0xF5C518))
        let safari = SourceApp(name: "Safari", bundleID: "com.apple.Safari", tint: RGBColor(0x1A86FF))
        let screenshot = SourceApp(name: "Screenshot", bundleID: "com.apple.screenshot.launcher", tint: RGBColor(0xFF375F))
        let finder = SourceApp(name: "Finder", bundleID: "com.apple.finder", tint: RGBColor(0x3BA7FF))
        let vsCode = SourceApp(name: "VS Code", bundleID: "com.microsoft.VSCode", tint: RGBColor(0x1A86FF))
        let mail = SourceApp(name: "Mail", bundleID: "com.apple.mail", tint: RGBColor(0x1A86FF))
        let preview = SourceApp(name: "Preview", bundleID: "com.apple.Preview", tint: RGBColor(0x0A84FF))
        let contacts = SourceApp(name: "Contacts", bundleID: "com.apple.AddressBook", tint: RGBColor(0xFF9500))

        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        func id(_ index: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        }
        let demoFolder = URL(filePath: "/Users/Shared/Clipboard Demo", directoryHint: .isDirectory)

        return [
            ClipSnapshot(
                id: id(1),
                title: "Ship v2.3 by Friday",
                content: .text(.init("Meeting notes: ship v2.3 by Friday, QA runs Thursday. Assign the perf audit to Dana and loop in design for the empty states.")),
                source: notes,
                createdAt: ago(0.1),
                isPinned: true
            ),
            ClipSnapshot(
                id: id(2),
                title: "Framer Motion — layout animations",
                content: .link(.init(
                    url: URL(string: "https://framer.com/motion/layout-animations")!,
                    title: "Framer Motion — layout animations",
                    artwork: GradientPair(0x0A84FF, 0x5E5CE6)
                )),
                source: safari,
                createdAt: ago(2)
            ),
            ClipSnapshot(
                id: id(3),
                title: "Screenshot 2026-07-22 at 10.14.png",
                content: .image(.init(pixelWidth: 2880, pixelHeight: 1620, format: "PNG", artwork: GradientPair(0xFF6A3D, 0xFF2D78))),
                source: screenshot,
                createdAt: ago(5)
            ),
            ClipSnapshot(
                id: id(4),
                title: "Q3-forecast.numbers",
                content: .file(.init(
                    urls: [demoFolder.appending(path: "Q3-forecast.numbers")],
                    isDirectory: false,
                    byteCount: 1_200_000,
                    kindDescription: "Numbers spreadsheet",
                    accent: RGBColor(0x30D158)
                )),
                source: finder,
                createdAt: ago(11)
            ),
            ClipSnapshot(
                id: id(5),
                title: "debounce()",
                content: .text(.init("""
                const debounce = (fn, ms) => {
                  let t;
                  return (...a) => {
                    clearTimeout(t);
                    t = setTimeout(() => fn(...a), ms);
                  };
                };
                """, isCode: true)),
                source: vsCode,
                createdAt: ago(18),
                isPinned: true
            ),
            ClipSnapshot(
                id: id(6),
                title: "Dribbble — Clipboard UI inspiration",
                content: .link(.init(
                    url: URL(string: "https://dribbble.com/search/clipboard-app")!,
                    title: "Dribbble — Clipboard UI inspiration",
                    artwork: GradientPair(0xEA4C89, 0xFF7EB3)
                )),
                source: safari,
                createdAt: ago(24)
            ),
            ClipSnapshot(
                id: id(7),
                title: "Brand Assets",
                content: .file(.init(
                    urls: [demoFolder.appending(path: "Brand Assets", directoryHint: .isDirectory)],
                    isDirectory: true,
                    itemCount: 48,
                    kindDescription: "Folder",
                    accent: RGBColor(0x0A84FF)
                )),
                source: finder,
                createdAt: ago(31)
            ),
            ClipSnapshot(
                id: id(8),
                title: "hello@studioform.co",
                content: .text(.init("hello@studioform.co")),
                source: mail,
                createdAt: ago(40)
            ),
            ClipSnapshot(
                id: id(9),
                title: "design-ref.jpg",
                content: .image(.init(pixelWidth: 1440, pixelHeight: 900, format: "JPEG", artwork: GradientPair(0x5E5CE6, 0x32D0F0))),
                source: preview,
                createdAt: ago(52)
            ),
            ClipSnapshot(
                id: id(10),
                title: "Linear — ENG-482 Vibrancy blur perf",
                content: .link(.init(
                    url: URL(string: "https://linear.app/eng/issue/ENG-482")!,
                    title: "Linear — ENG-482 Vibrancy blur perf",
                    artwork: GradientPair(0x5E6AD2, 0x8A91F5)
                )),
                source: safari,
                createdAt: ago(65)
            ),
            ClipSnapshot(
                id: id(11),
                title: "Address",
                content: .text(.init("415 Natoma St, Suite 200\nSan Francisco, CA 94103")),
                source: contacts,
                createdAt: ago(80)
            ),
            ClipSnapshot(
                id: id(12),
                title: "contract-final.pdf",
                content: .file(.init(
                    urls: [demoFolder.appending(path: "contract-final.pdf")],
                    isDirectory: false,
                    byteCount: 340_000,
                    kindDescription: "PDF Document",
                    accent: RGBColor(0xFF453A)
                )),
                source: finder,
                createdAt: ago(130)
            ),
        ]
    }
}
