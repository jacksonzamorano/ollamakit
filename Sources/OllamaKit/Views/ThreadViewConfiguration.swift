// ThreadViewConfiguration.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file defines configuration options for customizing the appearance
// and behavior of ThreadView components.

import SwiftUI

extension EnvironmentValues {
    @Entry var threadViewConfiguration: ThreadViewConfiguration = .init()
}

/// Configures which models to show in the model picker.
public enum ModelPickerConfiguration {
    /// Don't show a model picker.
    case none
    /// Show all available models.
    case all
    /// Show only models that support tool calling.
    case toolEnabled
}

/// Configures how tool calls are displayed in the conversation.
public enum ToolCallDisplayConfiguration: Int, CaseIterable {
    /// Don't show tool calls at all.
    case none = 0
    /// Show a simple indicator when a tool is called.
    case exists = 1
    /// Show the tool name when called.
    case name = 2
    /// Show full details including arguments and results.
    case details = 3

    /// A human-readable label for this configuration option.
    public var label: String {
        switch self {
        case .none:
            return "Hidden"
        case .exists:
            return "Show when called"
        case .name:
            return "Show name when called"
        case .details:
            return "Show full details when called"
        }
    }
}

/// Main configuration object for customizing a ThreadView.
///
/// This structure combines all configuration options for welcome screen,
/// input field, and message display behavior.
///
/// - Example:
/// ```swift
/// let config = ThreadViewConfiguration(
///     welcome: ThreadViewWelcomeConfiguration(
///         title: "AI Assistant",
///         message: "How can I help you today?",
///         modelPickerConfiguration: .all
///     ),
///     messages: ThreadViewMessageConfiguration(
///         toolRequestDisplay: .name,
///         toolResponseDisplay: .details,
///         showsThinking: true
///     )
/// )
/// ```
public struct ThreadViewConfiguration {
    /// Configuration for the welcome screen shown before the first message.
    public var welcome: ThreadViewWelcomeConfiguration
    /// Configuration for the message input field.
    public var input: ThreadViewInputConfiguration
    /// Configuration for how messages are displayed.
    public var messages: ThreadViewMessageConfiguration

    public init(welcome: ThreadViewWelcomeConfiguration = .init(), input: ThreadViewInputConfiguration = .init(), messages: ThreadViewMessageConfiguration = .init()) {
        self.welcome = welcome
        self.input = input
        self.messages = messages
    }
}

/// Configuration for the welcome screen displayed before any messages.
public struct ThreadViewWelcomeConfiguration {
    /// The title text shown on the welcome screen.
    public var title = "Welcome"
    /// The message text shown below the title.
    public var message = "How can I help you today?"
    /// Controls which models appear in the model picker.
    public var modelPickerConfiguration: ModelPickerConfiguration = .toolEnabled
    /// Whether to show the current message display configuration on the welcome screen.
    public var showMessageConfiguration: Bool = false

    public init(title: String = "Welcome", message: String = "Start chatting...", modelPickerConfiguration: ModelPickerConfiguration = .toolEnabled, showMessageConfiguration: Bool = false) {
        self.title = title
        self.message = message
        self.modelPickerConfiguration = modelPickerConfiguration
        self.showMessageConfiguration = showMessageConfiguration
    }
}

/// Configuration for the message input field.
public struct ThreadViewInputConfiguration {
    public init(placeholder: String = "Ask anything...", focusAfterDone: Bool = true) {
        self.placeholder = placeholder
        self.focusAfterDone = focusAfterDone
    }

    /// The placeholder text shown in the input field.
    public var placeholder = "Ask anything..."
    /// Whether to automatically focus the input field after a query completes.
    public var focusAfterDone = true
}

/// Default function for generating status messages based on OllamaStatus.
///
/// - Parameter status: The current status of the session.
/// - Returns: A human-readable status message.
public func defaultStatusMessage(_ status: OllamaStatus) -> String {
    switch status {
    case .calling:
        "Using a tool..."
    case .starting:
        "Preparing..."
    case .writing:
        "Writing..."
    case .thinking:
        "Thinking..."
    }
}

/// Configuration for message display behavior and appearance.
public struct ThreadViewMessageConfiguration {
    public init(allowsContentSelection: Bool = true, statusMessage: @escaping (OllamaStatus) -> String = defaultStatusMessage, toolRequestDisplay: ToolCallDisplayConfiguration = .none, toolResponseDisplay: ToolCallDisplayConfiguration = .none, showsThinking: Bool = false) {
        self.allowsContentSelection = allowsContentSelection
        self.statusMessage = statusMessage
        self.toolRequestDisplay = toolRequestDisplay
        self.toolResponseDisplay = toolResponseDisplay
        self.showsThinking = showsThinking
    }

    public init(allowsContentSelection: Bool = true) {
        self.allowsContentSelection = allowsContentSelection
    }

    /// Whether users can select and copy message content.
    public var allowsContentSelection = true
    /// A function that generates status messages based on the current session status.
    public var statusMessage: (OllamaStatus) -> String = defaultStatusMessage
    /// How to display tool call requests in the conversation.
    public var toolRequestDisplay: ToolCallDisplayConfiguration = .none
    /// How to display tool responses in the conversation.
    public var toolResponseDisplay: ToolCallDisplayConfiguration = .none
    /// Whether to show the model's thinking process (if available).
    public var showsThinking: Bool = false
}
