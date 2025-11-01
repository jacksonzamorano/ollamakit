// TurnView.swift (MessageView)
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides the individual message/event display component.

import SwiftUI
import FoundationModels

/// Displays a single event (message, thinking, or tool interaction) in the conversation.
///
/// This view handles rendering different types of events based on their content and
/// respects the configuration options for visibility of thinking, tool calls, etc.
struct MessageView: View {
    @State var turn: OllamaEvent
    @State var showThinking = true
    @Environment(\.threadViewConfiguration) var config
    var canShow: Bool {
        if turn.toolResponse != nil && config.messages.toolResponseDisplay == .none {
             return false
        }
        if turn.toolRequest != nil && config.messages.toolRequestDisplay == .none {
             return false
        }
        if !config.messages.showsThinking && !turn.thinking.isEmpty && turn.content.isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        if canShow {
            VStack(alignment: .leading, spacing: 2) {
                Text(turn.speaker)
                    .bold()
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .transition(.opacity)
                if !turn.thinking.isEmpty && config.messages.showsThinking {
                    HStack(alignment: .top, spacing: 6) {
                        Text(turn.thinking)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(showThinking ? nil : 3)
                            .transition(.opacity)
                            .contentTransition(.opacity)
                            .italic()
                        Spacer()
                        Button("", systemImage: showThinking ? "chevron.up" : "chevron.down") {
                            withAnimation {
                                showThinking.toggle()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .onChange(of: turn.final) {
                            withAnimation {
                                showThinking = false
                            }
                        }
                    }
                }
                if !turn.content.isEmpty {
                    Text(turn.contentStyled)
                        .contentTransition(.opacity)
                        .transition(.opacity)
                        .enableTextSelection(config.messages.allowsContentSelection)
                }
                if let tr = turn.toolRequest {
                    ToolCallDetailsView(name: tr.name, json: tr.arguments, isCalling: true, displayMode: config.messages.toolRequestDisplay)
                }
                if let tr = turn.toolResponse {
                    ToolCallDetailsView(name: tr.name, json: tr.response, isCalling: false, displayMode: config.messages.toolResponseDisplay)
                }
            }
        }
    }
}

extension View {
    func enableTextSelection(_ enabled: Bool) -> some View {
        if enabled {
            AnyView(self.textSelection(.enabled))
        } else {
            AnyView(self.textSelection(.disabled))
        }
    }
}

#Preview {
    LazyVStack(alignment: .leading, spacing: 10) {
        MessageView(turn: .previewThinking)
        MessageView(turn: .previewContent)
        MessageView(turn: .previewToolCall)
        MessageView(turn: .previewToolResponse)
    }
    .scenePadding()
}
