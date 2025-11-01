// OllamaKit
// Copyright (c) 2025 OllamaKit Contributors
//
// This file provides the main API functions for interacting with Ollama,
// a local large language model runtime.

import Foundation

/// The default host address for the Ollama API server.
///
/// This constant points to the standard localhost address where Ollama runs by default.
/// You can override this by passing a custom host parameter to the API functions.
public let DEFAULT_OLLAMA_HOST = "localhost:11434"

/// Retrieves a list of available models from the Ollama instance.
///
/// This function queries the Ollama API to fetch all available models. Optionally,
/// you can filter to only return models that support tool calling functionality.
///
/// - Parameters:
///   - onlyToolCalling: If `true`, only returns models that support tool calling.
///                      If `false` (default), returns all available models.
///   - host: The Ollama host address. Defaults to `DEFAULT_OLLAMA_HOST`.
///
/// - Returns: An array of model names available on the Ollama instance.
///            Returns an empty array if the request fails or no models are found.
///
/// - Example:
/// ```swift
/// // Get all models
/// let allModels = await getModels()
///
/// // Get only models that support tool calling
/// let toolModels = await getModels(onlyToolCalling: true)
///
/// // Use a custom host
/// let models = await getModels(host: "192.168.1.100:11434")
/// ```
public func getModels(onlyToolCalling: Bool = false, host: String = DEFAULT_OLLAMA_HOST) async -> [String] {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let session = URLSession.shared
    let request = URLRequest(url: URL(string: "http://\(host)/api/tags")!)
    guard let (allModelsData, _) = try? await session.data(for: request) else { return [] }
    guard let allModels = try? decoder.decode(OllamaTagResponse.self, from: allModelsData) else { return [] }
    
    if !onlyToolCalling {
        return allModels.models.map(\.name)
    }
    
    var eligbleModels: [String] = []
    for m in allModels.models {
        var request = URLRequest(url: URL(string: "http://\(host)/api/show")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(OllamaShowModelRequest(model: m.name))
        guard let (modelData, _) = try? await session.data(for: request) else { continue }
        guard let model = try? decoder.decode(OllamaShowModelResponse.self, from: modelData) else { continue }
        if model.capabilities.contains("tools") {
            eligbleModels.append(m.name)
        }
    }
    return eligbleModels
}
