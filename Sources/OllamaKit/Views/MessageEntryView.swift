// MessageEntryView.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides the message input field component with send/stop controls.

import SwiftUI

/// A text input field with send/stop button for message entry.
///
/// This view provides a text field for user input and automatically switches between
/// a send button (when idle) and a stop button (when processing). It supports multi-line
/// input and keyboard shortcuts.
public struct MessageEntryView: View {
    var enabled: Bool
    var send: (String) async -> Void
    var stop: () -> Void

    @State var question: String = ""
    @Environment(\.threadViewConfiguration) var config
    @FocusState var textInputFocus

    public var body: some View {
        HStack(alignment: .bottom) {
            TextField(config.input.placeholder, text: $question, axis: .vertical)
                .font(.default)
                .focused($textInputFocus)
                .onAppear {
                    textInputFocus = true
                }
            Spacer()
            if enabled {
                Button("Send", systemImage: "paperplane", role: .confirm) {
                    handleSubmit()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
            } else {
                Button("Stop", systemImage: "stop", role: .cancel) {
                    stop()
                }
                .keyboardShortcut(".", modifiers: .command)
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
            }
        }
        .padding()
    }
    
    func handleSubmit() {
        Task {
            let newQ = question
            question = ""
            await send(newQ)
            if config.input.focusAfterDone {
                textInputFocus = true
            }
        }
    }
}

