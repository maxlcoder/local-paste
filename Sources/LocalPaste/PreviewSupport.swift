#if DEBUG
import SwiftUI

@MainActor
enum PreviewFixtures {
    static let defaultItems: [ClipboardItem] = [
        ClipboardItem(
            text: "2026-03-16 ~ 2026-03-20 周报",
            copiedAt: Date().addingTimeInterval(-90)
        ),
        ClipboardItem(
            text: "2. fdsf 数据中空格问题处理",
            copiedAt: Date().addingTimeInterval(-7_200)
        ),
        ClipboardItem(
            imageFileName: "preview-image.png",
            imageWidth: 1645,
            imageHeight: 471,
            imageHash: "preview-image-hash",
            copiedAt: Date().addingTimeInterval(-172_800)
        ),
        ClipboardItem(
            text: "Translated Report (Full Report Below)\n\nProcess: LocalPaste\nPath: /Users/USER/*/LocalPaste.app/Contents/MacOS/LocalPaste",
            copiedAt: Date().addingTimeInterval(-320_000)
        )
    ]

    static let menuItems: [ClipboardItem] = [
        ClipboardItem(text: "fdsfds"),
        ClipboardItem(text: "待处理事项：修复快捷键录制"),
        ClipboardItem(text: "用户反馈：顶部工具栏需要更紧凑")
    ]

    static let hotkeyConfiguration = HotkeyConfiguration(
        keyCode: 9,
        command: true,
        option: false,
        control: false,
        shift: true
    )
}

@MainActor
struct ContentViewPreviewScene: View {
    let position: HistoryWindowPosition
    let items: [ClipboardItem]
    let clickAction: RecordClickAction

    var body: some View {
        ContentView(
            store: .preview(items: items, clickAction: clickAction),
            hotkeyManager: .preview(configuration: PreviewFixtures.hotkeyConfiguration)
        )
        .task {
            setHistoryWindowPosition(position)
        }
    }
}
#endif
