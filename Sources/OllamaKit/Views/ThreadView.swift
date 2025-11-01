// ThreadView.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides a complete chat interface for Ollama conversations,
// including message display, input field, and configuration options.

import SwiftUI

/// A complete chat interface for interacting with an Ollama model.
///
/// `ThreadView` provides a ready-to-use SwiftUI view that includes:
/// - A welcome screen with optional model picker
/// - Scrollable message history
/// - Message input field with send/stop controls
/// - Real-time streaming response display
/// - Configurable appearance and behavior
///
/// - Example:
/// ```swift
/// struct ContentView: View {
///     @State var session = OllamaSession<MyToolArgs>(
///         model: "llama2",
///         systemPrompt: "You are a helpful assistant."
///     )
///
///     var body: some View {
///         ThreadView(session: session)
///     }
/// }
/// ```
@MainActor
public struct ThreadView<Args: OllamaSendable>: View {

    /// The session managing the conversation with the Ollama model.
    @Bindable public var session: OllamaSession<Args>
    /// Configuration options for customizing the view's appearance and behavior.
    public var config: ThreadViewConfiguration
    @State private var position: ScrollPosition = .init(y: 0)
    @State private var error: String? = nil

    @State private var availableModels: [String] = []

    /// Creates a new ThreadView with the specified session and configuration.
    ///
    /// - Parameters:
    ///   - session: The `OllamaSession` to use for this conversation.
    ///   - config: Configuration options for the view. Defaults to standard configuration.
    public init(session: OllamaSession<Args>, config: ThreadViewConfiguration = .init()) {
        self.session = session
        self.config = config
    }
    
    public var body: some View {
        VStack {
            if session.transcript.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(config.welcome.title)
                            .font(.title)
                            .bold()
                        Text(config.welcome.message)
                            .foregroundStyle(.secondary)
                    }
                    if config.welcome.modelPickerConfiguration != .none {
                        Picker("", selection: $session.model) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model)
                                    .tag(model)
                            }
                        }
                    }
                    if config.welcome.showMessageConfiguration {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Tool Request")
                                    .bold()
                                Text(config.messages.toolRequestDisplay.label)
                            }
                            HStack(spacing: 4) {
                                Text("Tool Response")
                                    .bold()
                                Text(config.messages.toolResponseDisplay.label)
                            }
                            HStack(spacing: 4) {
                                Text("Thinking")
                                    .bold()
                                Text(config.messages.showsThinking ? "Showing" : "Hidden")
                            }
                        }
                    }
                }
                .transition(.opacity)
                Spacer()
            } else {
                MessagesView(session: session, scrollPosition: $position)
                    .transition(.opacity)
            }
            MessageEntryView(enabled: !session.working) { message in
                await send(message)
            } stop: {
                session.stop()
            }
        }
        .alert(isPresented: Binding {
            error != nil
        } set: {
            if $0 {
                error = ""
            } else {
                error = nil
            }
        }) {
            Alert(title: Text("Error"), message: Text("An error occured: \(error?.description ?? "Unknown error")"))
        }
        .environment(\.threadViewConfiguration, config)
        .onAppear {
            Task {
                availableModels = await getModels(onlyToolCalling: config.welcome.modelPickerConfiguration == .toolEnabled, host: session.host)
            }
        }
        .onChange(of: session.host) {
            Task {
                availableModels = await getModels(onlyToolCalling: config.welcome.modelPickerConfiguration == .toolEnabled, host: session.host)
            }
        }
    }
    
    func send(_ message: String) async {
        position.scrollTo(edge: .bottom)
        let val = await session.query(message) {
            position.scrollTo(edge: .bottom)
        }
        if case let .failure(err) = val, !err.userCancelled {
            self.error = err.message
        }
    }
}
