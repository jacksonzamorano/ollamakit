// ToolCallDetailsView.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides the view for displaying tool call details and results.

import SwiftUI

/// Displays information about a tool call or tool response.
///
/// This view shows tool interactions with varying levels of detail based on the
/// configuration, from simple indicators to full JSON argument/response display.
struct ToolCallDetailsView: View {
    var name: String
    var json: String
    var isCalling: Bool = false
    var displayMode: ToolCallDisplayConfiguration
    var previewText: String {
        if json.count > 10_000 {
            return "JSON is too long to preview."
        }
        return json
    }
    @State var showingDetails: Bool = false
    @Environment(\.threadViewConfiguration) var config

    var body: some View {
        Button {
            if displayMode == .details {
                showingDetails = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: isCalling ? "arrow.right" : "arrow.left")
                        .font(.caption)
                    HStack(spacing: 3) {
                        if displayMode.rawValue >= ToolCallDisplayConfiguration.name.rawValue {
                            Text(isCalling ? "Requested" : "Responded to")
                            Text(name)
                                .bold()
                        } else {
                            Text(isCalling ? "Used a tool" : "Responded to the model")
                        }
                    }
                }
            }
        }.buttonStyle(.plain)
            .popover(isPresented: $showingDetails) {
                ScrollView(.vertical) {
                    Text(previewText)
                        .font(.caption)
                        .monospaced()
                        .multilineTextAlignment(.leading)
                        .frame(alignment: .topLeading)
                        .scenePadding()
                }
                .frame(minWidth: 400, alignment: .topLeading)
            }
    }
}
