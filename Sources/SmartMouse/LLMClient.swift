import Foundation

// MARK: - Errors

enum LLMClientError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case requestFailed(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "API key 为空。请先在设置中配置模型信息。"
        case .invalidEndpoint:
            "请求地址无效。请填写完整的 chat completions endpoint。"
        case let .requestFailed(statusCode, message):
            "请求失败（HTTP \(statusCode)）：\(message)"
        case .emptyResponse:
            "模型没有返回内容。"
        }
    }
}

// MARK: - Protocol

protocol LLMStreamProvider {
    func stream(
        messages: [ConversationMessage],
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String
}

// MARK: - Implementation

struct LLMClient: LLMStreamProvider {
    let configuration: ModelConfiguration

    func stream(
        messages: [ConversationMessage],
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMClientError.missingAPIKey
        }

        guard let url = URL(string: configuration.endpoint) else {
            throw LLMClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let payload = ChatCompletionRequest(
            model: configuration.model,
            temperature: configuration.temperature,
            stream: true,
            messages: messages.map {
                ChatCompletionMessage(role: $0.role.rawValue, content: $0.content)
            }
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let session = URLSession.shared
        let (bytes, response) = try await session.bytes(for: request)

        // Propagate task cancellation to the URLSession
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMClientError.emptyResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw LLMClientError.requestFailed(httpResponse.statusCode, errorBody)
        }

        var fullText = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            guard let delta = chunk?.choices.first?.delta.content, !delta.isEmpty else { continue }
            fullText += delta
            await onDelta(delta)
        }

        guard !fullText.isEmpty else { throw LLMClientError.emptyResponse }
        return fullText
    }
}

// MARK: - OpenAI-compatible request/response types

private struct ChatCompletionRequest: Encodable {
    var model: String
    var temperature: Double
    var stream: Bool
    var messages: [ChatCompletionMessage]
}

private struct ChatCompletionMessage: Encodable {
    var role: String
    var content: String
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            var content: String?
        }

        var delta: Delta
    }

    var choices: [Choice]
}
