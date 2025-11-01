// Event.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file defines the event system used to represent conversation turns
// in a human-readable format suitable for display in UI components.

import Foundation
import SwiftUI

/// Represents the role of a participant in a conversation.
public enum OllamaEventRole {
    /// A message from the language model.
    case model
    /// A message from the user.
    case user
    /// A message from a tool (function result).
    case tool
}

/// Represents a single event in the conversation transcript.
///
/// An event can be a message from the user, model response (including thinking and content),
/// a tool call request, or a tool response. Events are observable and designed for
/// display in SwiftUI views.
///
/// Each event tracks its role, content, and optionally tool-related information.
/// Content is automatically parsed as Markdown and stored as an `AttributedString`.
@Observable
public class OllamaEvent: Identifiable {
    /// Unique identifier for this event.
    public var id = UUID()

    /// The name of the model that generated this event.
    public var modelName: String = ""

    /// The role of the speaker for this event.
    public var role: OllamaEventRole = .model

    /// The model's thinking process (if supported and enabled).
    public var thinking: String = ""

    /// The text content of this event.
    /// When set, this automatically parses the content as Markdown and updates `contentStyled`.
    public var content: String = "" {
        didSet {
            if let update = try? AttributedString(markdown: content.data(using: .utf8)!, options: .init(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)) {
                contentStyled = update
            }
        }
    }

    /// The content parsed as a styled AttributedString with Markdown formatting.
    public var contentStyled = AttributedString()

    /// Information about a tool call request, if this event represents a tool call.
    public var toolRequest: OllamaToolCallRequestPart? = nil

    /// Information about a tool response, if this event represents a tool result.
    public var toolResponse: OllamaToolCallResponsePart? = nil

    /// Whether this event is finalized and won't receive more updates.
    public var final: Bool = false

    /// Whether this event represents a tool interaction (request or response).
    public var isTool: Bool { toolResponse != nil || toolRequest != nil }

    /// A human-readable name for the speaker of this event.
    public var speaker: String {
        switch role {
        case .model: return modelName
        case .user: return "You"
        case .tool: return "Tool"
        }
    }
    
    @MainActor
    internal static let previewThinking: OllamaEvent = {
       let e = OllamaEvent()
        e.modelName = "gpt-oss:20b"
        e.role = .model
        e.thinking = "I'm thinking pretty hard here..."
        return e
    }()
    
    @MainActor
    internal static let previewContent: OllamaEvent = {
       let e = OllamaEvent()
        e.modelName = "gpt-oss:20b"
        e.role = .model
        e.content = "I'm thinking pretty hard here..."
        return e
    }()
    
    @MainActor
    internal static let previewToolCall: OllamaEvent = {
       let e = OllamaEvent()
        e.modelName = "gpt-oss:20b"
        e.role = .model
        e.toolRequest = .init(name: "ExampleTool", arguments: "{some_key: some_value}")
        return e
    }()
    
    @MainActor
    internal static let previewToolResponse: OllamaEvent = {
       let e = OllamaEvent()
        e.modelName = "gpt-oss:20b"
        e.role = .tool
        e.toolResponse = .init(name: "ExampleTool", response: "{some_key: some_value}")
        return e
    }()

}

/// Represents the response portion of a tool interaction.
///
/// Contains the tool name and the JSON response data returned by the tool.
public struct OllamaToolCallResponsePart {
    /// The name of the tool that was called.
    public var name: String
    /// The JSON-formatted response from the tool.
    public var response: String
}

/// Represents a request to call a tool.
///
/// Contains the tool name and the JSON-formatted arguments for the call.
public struct OllamaToolCallRequestPart {
    /// The name of the tool being requested.
    public var name: String
    /// The JSON-formatted arguments for the tool call.
    public var arguments: String
}
