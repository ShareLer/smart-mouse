import Foundation

struct SmartAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var symbolName: String
    var promptTemplate: String
    var isBuiltIn: Bool
    var isNew: Bool

    static let selectedTextPlaceholder = "{{selected_text}}"
}

struct ModelConfiguration: Codable, Equatable {
    var endpoint: String
    var apiKey: String
    var model: String
    var temperature: Double

    static let empty = ModelConfiguration(
        endpoint: "https://api.openai.com/v1/chat/completions",
        apiKey: "",
        model: "gpt-4.1-mini",
        temperature: 0.2
    )
}

struct AppSettings: Codable, Equatable {
    var model: ModelConfiguration
    var actions: [SmartAction]

    static let defaults = AppSettings(
        model: .empty,
        actions: [
            SmartAction(
                id: UUID(uuidString: "86F7C6E4-8808-45F6-843D-82055F29F002")!,
                title: "翻译",
                symbolName: "character.book.closed",
                promptTemplate: "请将下面内容翻译成简体中文，保留原意和格式：\n\n{{selected_text}}",
                isBuiltIn: true,
                isNew: false
            ),
            SmartAction(
                id: UUID(uuidString: "86F7C6E4-8808-45F6-843D-82055F29F003")!,
                title: "解释",
                symbolName: "text.magnifyingglass",
                promptTemplate: "请解释下面内容。先给出一句话结论，再用要点说明关键概念：\n\n{{selected_text}}",
                isBuiltIn: true,
                isNew: false
            )
        ]
    )
}

enum ConversationRole: String, Codable {
    case user
    case assistant
}

struct ConversationMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var role: ConversationRole
    var content: String
    var isFirstPrompt: Bool = false
}
