// MessagesView.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides the scrollable message list view for displaying conversation history.

import SwiftUI

/// A scrollable view displaying the conversation transcript.
///
/// This view renders all events in the session's transcript as individual message views,
/// with a progress indicator when the session is actively processing.
public struct MessagesView<T: OllamaSendable>: View {

    public var session: OllamaSession<T>
    @Binding public var scrollPosition: ScrollPosition
    @Environment(\.threadViewConfiguration) var config

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(session.transcript) { t in
                    MessageView(turn: t)
                }
                if session.working {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(config.messages.statusMessage(session.lastStatus))
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition, anchor: .bottom)
    }
    
}
