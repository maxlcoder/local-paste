import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let copiedAt: Date
    let kind: ClipboardItemKind
    let text: String?
    let imageFileName: String?
    let imageWidth: Double?
    let imageHeight: Double?
    let imageHash: String?

    init(id: UUID = UUID(), text: String, copiedAt: Date = Date()) {
        self.id = id
        self.copiedAt = copiedAt
        self.kind = .text
        self.text = text
        self.imageFileName = nil
        self.imageWidth = nil
        self.imageHeight = nil
        self.imageHash = nil
    }

    init(
        id: UUID = UUID(),
        imageFileName: String,
        imageWidth: Double,
        imageHeight: Double,
        imageHash: String,
        copiedAt: Date = Date()
    ) {
        self.id = id
        self.copiedAt = copiedAt
        self.kind = .image
        self.text = nil
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageHash = imageHash
    }

    var searchableText: String {
        switch kind {
        case .text:
            return text ?? ""
        case .image:
            return L10n.tr("clipboard.image_search_label", pixelDescription)
        }
    }

    var menuDisplayText: String {
        switch kind {
        case .text:
            return (text ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .image:
            return L10n.tr("clipboard.image_menu_prefix", pixelDescription)
        }
    }

    var pixelDescription: String {
        let width = Int(imageWidth ?? 0)
        let height = Int(imageHeight ?? 0)
        if width > 0, height > 0 {
            return "\(width)x\(height)"
        }
        return L10n.tr("clipboard.unknown_size")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case copiedAt
        case kind
        case text
        case imageFileName
        case imageWidth
        case imageHeight
        case imageHash

        // legacy key
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        copiedAt = try container.decodeIfPresent(Date.self, forKey: .copiedAt) ?? Date()

        if let kind = try container.decodeIfPresent(ClipboardItemKind.self, forKey: .kind) {
            self.kind = kind
            text = try container.decodeIfPresent(String.self, forKey: .text)
            imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
            imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
            imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
            imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash)
            return
        }

        // backward compatibility with old text-only model
        let legacyContent = try container.decodeIfPresent(String.self, forKey: .content)
        let legacyText = try container.decodeIfPresent(String.self, forKey: .text)
        let finalLegacyText = legacyContent ?? legacyText ?? ""
        kind = .text
        text = finalLegacyText
        imageFileName = nil
        imageWidth = nil
        imageHeight = nil
        imageHash = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(copiedAt, forKey: .copiedAt)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(imageHash, forKey: .imageHash)
    }
}
