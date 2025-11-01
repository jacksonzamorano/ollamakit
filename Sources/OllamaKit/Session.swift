// Session.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file defines the OllamaSession class, which manages conversations
// with the Ollama API including tool calling and streaming responses.

import Foundation
import SwiftUI

/// Represents the current status of an Ollama query operation.
///
/// Use this enum to display appropriate UI feedback to users during conversations.
public enum OllamaStatus {
    /// The session is initializing and preparing to send a request.
    case starting
    /// The model is in its thinking phase (if supported by the model).
    case thinking
    /// The model is generating text content.
    case writing
    /// The model is calling a tool or processing tool results.
    case calling
}

/// Represents an error that occurred during Ollama operations.
///
/// Errors can indicate network issues, API problems, or user-initiated cancellations.
public struct OllamaError: Error, Equatable {
    /// A human-readable description of what went wrong.
    var message: String
    /// Whether this error was caused by user cancellation rather than a system error.
    var userCancelled: Bool = false

    /// A predefined error for user-initiated cancellations.
    static let cancelled: OllamaError = .init(message: "User cancelled", userCancelled: true)
}

/// Defines a tool that can be called by the language model during conversations.
///
/// A tool definition includes the function signature (name, description, parameters)
/// and the actual Swift code to execute when the model calls the tool.
///
/// - Example:
/// ```swift
/// let weatherTool = OllamaToolDefinition(
///     tool: OllamaFunction(
///         name: "get_weather",
///         description: "Get current weather for a location",
///         parameters: OllamaObject(
///             properties: ["location": OllamaProperty(type: "string", description: "City name")],
///             required: ["location"]
///         )
///     ),
///     execute: { args in
///         // Your weather fetching logic here
///         return WeatherResult(temperature: 72, conditions: "Sunny")
///     }
/// )
/// ```
public class OllamaToolDefinition<ToolArgs: Codable> {
    /// The name of the tool, matching the function name.
    public var name: String
    /// The function signature exposed to the model.
    public var tool: OllamaFunction
    /// The closure to execute when the model calls this tool.
    /// Returns `nil` if the tool execution fails.
    public var execute: (ToolArgs) async -> OllamaSendable?

    /// Creates a new tool definition.
    ///
    /// - Parameters:
    ///   - tool: The function signature describing the tool to the model.
    ///   - execute: An async closure that executes the tool logic and returns results.
    public init(tool: OllamaFunction, execute: @escaping (ToolArgs) async -> Codable?) {
        self.name = tool.name
        self.execute = execute
        self.tool = tool
    }
}

/// Manages a conversation session with an Ollama language model.
///
/// `OllamaSession` maintains the conversation history, handles streaming responses,
/// executes tool calls, and provides an observable interface for SwiftUI integration.
///
/// The generic `ToolArgs` parameter defines the shape of arguments for tool calls.
/// Use a single struct that encompasses all possible tool argument types, or use
/// a simple type like `AnyCodable` for flexibility.
///
/// - Example:
/// ```swift
/// // Define your tool arguments type
/// struct MyToolArgs: Codable, Sendable {
///     // Define all possible tool parameters here
/// }
///
/// // Create a session
/// let session = OllamaSession<MyToolArgs>(
///     model: "llama2",
///     systemPrompt: "You are a helpful assistant."
/// )
///
/// // Add tools to the session
/// session.tools.append(weatherTool)
///
/// // Query the model
/// await session.query("What's the weather in San Francisco?") {
///     // This closure is called as the response streams in
///     updateUI()
/// }
/// ```
@MainActor
@Observable
open class OllamaSession<ToolArgs: OllamaSendable>{
    /// The internal message history sent to the API (not exposed for observation).
    @ObservationIgnored var messages: [OllamaMessage<ToolArgs>]

    /// The public-facing conversation transcript containing all events.
    /// This array is observable and can be used to drive UI updates.
    public var transcript: [OllamaEvent] = []

    /// The most recent status of the session.
    public var lastStatus: OllamaStatus = .starting

    /// Whether the session is currently processing a query.
    public var working: Bool {
       (runningTask?.isCancelled ?? true) == false
    }

    /// The tools available for the model to call during conversation.
    @ObservationIgnored public var tools: [OllamaToolDefinition<ToolArgs>] = []

    /// The name of the model to use for this session.
    public var model: String

    @ObservationIgnored let encoder: JSONEncoder
    @ObservationIgnored let prettyEncoder: JSONEncoder
    @ObservationIgnored let decoder: JSONDecoder
    @ObservationIgnored let session = URLSession.shared

    /// The currently running query task, if any.
    public var runningTask: Task<Result<(), OllamaError>, Never>? = nil

    /// The Ollama host address.
    @ObservationIgnored var host: String

    /// Creates a new Ollama session.
    ///
    /// - Parameters:
    ///   - model: The name of the Ollama model to use (e.g., "llama2", "mistral").
    ///   - systemPrompt: An optional system prompt to set the model's behavior.
    ///   - host: The Ollama host address. Defaults to "localhost:11434".
    public init(model: String, systemPrompt: String = "", host: String = "localhost:11434") {
        messages = [
            .init(role: "system", content: systemPrompt)
        ]
        self.model = model
        encoder = .init()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        prettyEncoder = .init()
        prettyEncoder.keyEncodingStrategy = .convertToSnakeCase
        prettyEncoder.outputFormatting = .prettyPrinted
        decoder = .init()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.host = host
    }
    
    func addMessage(_ msg: OllamaMessage<ToolArgs>) {
        messages.append(msg)
         if msg.role == "assistant", let tcs = msg.toolCalls, tcs.isEmpty == false {
            for t in tcs {
                transcript.last?.final = true
                let part = OllamaEvent()
                part.modelName = model
                part.role = .model
                let data = try! prettyEncoder.encode(t.arguments)
                part.toolRequest = .init(name: t.name, arguments: String(data: data, encoding: .utf8)!)
                transcript.append(part)
            }
        } else if msg.role == "user" {
            let part = OllamaEvent()
            part.modelName = model
            part.role = .user
            part.content = msg.content!
            transcript.last?.final = true
            transcript.append(part)
        }
    }
    func addSuccessfulToolResponse(_ tc: OllamaToolCall<ToolArgs>, data: OllamaSendable) {
        let responseData = try! encoder.encode(data)
        messages.append(.init(role: "tool", content: String(data: responseData, encoding: .utf8), toolName: tc.name))
        let part = OllamaEvent()
        part.modelName = model
        part.role = .tool
        let json = try! prettyEncoder.encode(data)
        part.toolResponse = .init(name: tc.name, response: String(data: json, encoding: .utf8)!)
        transcript.append(part)
    }
    func addErrorToolResponse(_ tc: OllamaToolCall<ToolArgs>, data: String) {
        messages.append(.init(role: "tool", content: data, toolName: tc.name))
        let part = OllamaEvent()
        part.modelName = model
        part.role = .tool
        part.toolResponse = .init(name: tc.name, response: data)
        transcript.append(part)
    }
    func addToolCall(_ tc: OllamaToolCall<ToolArgs>) {
        messages.append(.init(role: "assistant", toolCalls: [.init(index: 0, name: tc.name, arguments: tc.arguments)]))
        let part = OllamaEvent()
        part.modelName = model
        part.role = .model
        let data = try! prettyEncoder.encode(tc.arguments)
        part.toolRequest = .init(name: tc.name, arguments: String(data: data, encoding: .utf8)!)
        transcript.last?.final = true
        transcript.append(part)
    }
    func addContent(_ content: String) {
        if messages.last!.role != "assistant" || messages.last!.toolCalls != nil || messages.last!.toolCalls?.isEmpty == false {
            messages.append(OllamaMessage(role: "assistant", thinking: "", content: ""))
        }
        messages[messages.count - 1].content! += content
        
        if (
            transcript.last!.final ||
            transcript.last!.role != .model
        ) && !content.trimmingCharacters(in: .whitespaces).isEmpty {
            transcript.last?.final = true
            let part = OllamaEvent()
            part.role = .model
            part.modelName = model
            transcript.append(part)
        }
        transcript.last!.content += content
    }
    func addThinking(_ thinking: String) {
        if messages.last!.role != "assistant" {
            messages.append(OllamaMessage(role: "assistant", thinking: "", content: ""))
        }
        messages[messages.count - 1].thinking! += thinking
        
        if transcript.last!.final || transcript.last!.role != .model {
            let part = OllamaEvent()
            part.role = .model
            part.modelName = model
            transcript.append(part)
        }
        transcript.last!.thinking += thinking
    }

    /// Stops the currently running query.
    ///
    /// This cancels the active task and will cause the query to return
    /// with an `OllamaError.cancelled` error.
    public func stop() {
        runningTask?.cancel()
    }

    func handleTool(fun: OllamaToolCall<ToolArgs>) async -> OllamaSendable? {
        if let tool = tools.first(where: { $0.name == fun.name }) {
            return await tool.execute(fun.arguments)
        } else {
            return nil
        }
    }
    
    func buildRequest(model: String, messages: [OllamaMessage<ToolArgs>]) -> OllamaRequest<ToolArgs> {
        return OllamaRequest(model: model, messages: messages, tools: tools.map({ OllamaTool(function: $0.tool) }))
    }

    /// Sends a query to the Ollama model and streams back the response.
    ///
    /// This method sends a user message to the model and handles the streaming response,
    /// including automatic tool execution. The model may make multiple tool calls and
    /// continue generating responses until it's satisfied with the result.
    ///
    /// The `update` closure is called periodically as new content arrives, allowing you
    /// to update your UI in real-time during the response.
    ///
    /// - Parameters:
    ///   - input: The user's message or query.
    ///   - update: A closure called whenever new content is received. Use this to update your UI.
    ///
    /// - Returns: A `Result` indicating success or containing an `OllamaError` on failure.
    ///
    /// - Example:
    /// ```swift
    /// let result = await session.query("What's the capital of France?") {
    ///     // Update UI as response streams in
    ///     self.objectWillChange.send()
    /// }
    ///
    /// switch result {
    /// case .success:
    ///     print("Query completed successfully")
    /// case .failure(let error):
    ///     print("Error: \(error.message)")
    /// }
    /// ```
    public func query(_ input: String, update: @escaping () -> Void) async -> Result<(), OllamaError> {
        runningTask = Task<Result<(), OllamaError>, Never> {
            addMessage(.init(role: "user", content: input))
            lastStatus = .starting
            while true {
                if Task.isCancelled { return .failure(.cancelled) }
                let payload = buildRequest(model: model, messages: messages)
                var request = URLRequest(url: URL(string: "http://\(host)/api/chat")!)
                request.httpMethod = "POST"
                request.httpBody = try! JSONEncoder().encode(payload)
                request.timeoutInterval = 20
                guard let (stream, response) = try? await URLSession.shared.bytes(for: request) else {
                    return .failure(.init(message: "Could not connect to the Ollama instance."))
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return .failure(OllamaError(message: "Ollama didn't send the expected data."))
                }
                var toolsCalledThisTurn = false
                do {
                    for try await line in stream.lines {
                        if Task.isCancelled { return .failure(.cancelled) }
                        guard let data = line.data(using: .utf8) else {
                            return .failure(OllamaError(message: "Ollama disconnected."))
                        }
                        
                        guard let chunk = try? decoder.decode(OllamaChunk<ToolArgs>.self, from: data) else {
                            return .failure(OllamaError(message: "Ollama sent unexpected data."))
                        }
                        if let content = chunk.message.content {
                            lastStatus = .writing
                            addContent(content)
                        }
                        if let thinking = chunk.message.thinking {
                            lastStatus = .thinking
                            addThinking(thinking)
                        }
                        if let toolCalls = chunk.message.toolCalls, !toolCalls.isEmpty {
                            lastStatus = .calling
                            for t in toolCalls {
                                addToolCall(t.function)
                                toolsCalledThisTurn = true
                                if let response = await handleTool(fun: t.function) {
                                    addSuccessfulToolResponse(t.function, data: response)
                                } else {
                                    addErrorToolResponse(t.function, data: "Tool call failed.")
                                }
                            }
                        } else {
                            if chunk.done {
                                if messages.last!.role == "assistant"
                                    && (messages.last!.toolCalls?.isEmpty ?? true) == true
                                    && (messages.last!.content?.isEmpty ?? true) == true
                                    && (messages.last!.thinking?.isEmpty ?? true) == true {
                                    self.messages.removeLast()
                                }
                            }
                            if chunk.done && !toolsCalledThisTurn {
                                update()
                                return .success(())
                            }
                        }
                        update()
                    }
                } catch {
                    return .failure(.init(message: error.localizedDescription))
                }
            }
        }
        let value = await runningTask!.value
        runningTask = nil
        return value
    }
}
