// NetworkTypes.swift
// Copyright (c) 2025 OllamaKit Contributors
//
// This file defines all the network request and response types used
// for communication with the Ollama API.

import Foundation

/// A type alias for types that can be encoded/decoded and safely sent across concurrency boundaries.
///
/// This combines the `Codable` protocol for JSON serialization with `Sendable` for
/// safe concurrent access, making it suitable for use in async contexts with the Ollama API.
public typealias OllamaSendable = Codable & Sendable

/// Represents a chat request to the Ollama API.
///
/// This internal structure encapsulates all the information needed to make a chat
/// completion request, including the model, conversation history, available tools,
/// and streaming preference.
struct OllamaRequest<Args: OllamaSendable>: Codable {
    var model: String
    var messages: [OllamaMessage<Args>]
    var tools: [OllamaTool]
    var stream: Bool = true
}

/// Represents a tool definition for the Ollama API.
///
/// Tools allow the language model to call external functions during conversation.
/// This structure wraps a function definition with metadata about its type.
struct OllamaTool: Codable {
    /// The type of tool, always "function" for function calling.
    var type = "function"
    /// The function definition containing the tool's interface.
    var function: OllamaFunction
}

/// Defines a function that can be called by the language model.
///
/// This structure describes a tool's interface, including its name, purpose,
/// and parameter schema. The model uses this information to decide when and
/// how to call the function.
///
/// - Example:
/// ```swift
/// let weatherTool = OllamaFunction(
///     name: "get_weather",
///     description: "Get the current weather for a location",
///     parameters: OllamaObject(
///         properties: [
///             "location": OllamaProperty(type: "string", description: "City name"),
///             "units": OllamaProperty(type: "string", description: "Temperature units (celsius/fahrenheit)")
///         ],
///         required: ["location"]
///     )
/// )
/// ```
public struct OllamaFunction: Codable {
    public init(name: String, description: String, parameters: OllamaObject) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    /// The name of the function. Must be unique within a session.
    public var name: String
    /// A clear description of what the function does, used by the model to decide when to call it.
    public var description: String
    /// The parameter schema defining the function's inputs.
    public var parameters: OllamaObject
}

/// Represents a JSON Schema object for function parameters.
///
/// This structure defines the shape of data that a function accepts, including
/// property definitions and which properties are required.
///
/// - Note: Currently only supports "object" type for the root schema.
public struct OllamaObject: Codable {
    public init(type: String = "object", properties: [String : OllamaProperty], required: [String]) {
        self.type = type
        self.properties = properties
        self.required = required
    }

    /// The JSON Schema type, typically "object".
    public var type: String = "object"
    /// A dictionary mapping property names to their definitions.
    public var properties: [String: OllamaProperty]
    /// An array of property names that must be provided.
    public var required: [String]
}

/// Describes a single property in a function parameter schema.
///
/// Each property has a type (e.g., "string", "number", "boolean") and a
/// description that helps the model understand how to use it.
public struct OllamaProperty: Codable {
    public init(type: String, description: String) {
        self.type = type
        self.description = description
    }

    /// The JSON Schema type of this property (e.g., "string", "number", "boolean", "array", "object").
    public var type: String
    /// A description of this property's purpose and expected values.
    public var description: String
}

/// Represents a message in a conversation with the Ollama API.
///
/// Messages can come from different roles (user, assistant, tool, system) and
/// may contain text content, thinking processes, or tool call information.
struct OllamaMessage<Args: OllamaSendable>: Codable {
    var role: String
    var thinking: String?
    var content: String?
    var toolName: String?
    var toolCalls: [OllamaToolCall<Args>]?
}
/// Wraps a tool call within a function call context.
///
/// This is an intermediate structure used during API communication
/// to properly nest tool call information.
struct OllamaFunctionCall<Args: OllamaSendable>: Codable {
    var function: OllamaToolCall<Args>
}

/// Represents a request from the model to call a specific tool.
///
/// When the model determines it needs to use a tool, it generates a tool call
/// with the function name and parsed arguments. Your code can then execute the
/// tool and return results using the `respond` methods.
struct OllamaToolCall<Args: OllamaSendable>: Codable {
    /// The index of this tool call in a batch of calls.
    var index: Int
    /// The name of the function being called.
    var name: String
    /// The parsed arguments for the function call.
    var arguments: Args

    /// Creates a tool response message with encoded data.
    ///
    /// - Parameter data: A Codable object to be JSON-encoded as the response.
    /// - Returns: An `OllamaMessage` representing the tool's response.
    func respond(data: Codable) async -> OllamaMessage<Args> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try! encoder.encode(data)
        return OllamaMessage<Args>(role: "tool", content: String(data: data, encoding: .utf8)!, toolName: name)
    }
    
    /// Creates a tool response message with a plain string.
    ///
    /// - Parameter message: A string message to return as the response.
    /// - Returns: An `OllamaMessage` representing the tool's response.
    func respond(message: String) -> OllamaMessage<Args> {
        return OllamaMessage<Args>(role: "tool", content: message, toolName: name)
    }
}

/// Represents a complete response from the Ollama API.
///
/// This wraps a single message in the response payload.
struct OllamaResponse<Args: OllamaSendable>: Codable {
    var message: OllamaMessage<Args>
}

/// Represents a chunk of a streaming response from the Ollama API.
///
/// When streaming is enabled, the API sends responses incrementally as chunks.
/// Each chunk contains a partial message and a flag indicating if this is the final chunk.
struct OllamaChunk<Args: OllamaSendable>: Codable {
    /// The partial message content in this chunk.
    var message: OllamaMessageChunk<Args>
    /// Whether this is the final chunk in the stream.
    var done: Bool
}

/// Represents the partial content within a streaming chunk.
///
/// Chunks may contain incremental thinking, content, or tool call information
/// as the model generates its response.
struct OllamaMessageChunk<Args: OllamaSendable>: Codable {
    /// Incremental thinking process, if available.
    var thinking: String?
    /// Incremental text content.
    var content: String?
    /// Tool calls made by the model.
    var toolCalls: [OllamaFunctionCall<Args>]?
}

/// Response from the `/api/tags` endpoint listing available models.
struct OllamaTagResponse: Codable {
    var models: [OllamaTag]
}

/// Represents metadata about a single Ollama model.
struct OllamaTag: Codable {
    /// The name of the model.
    var name: String
    /// The size of the model in bytes.
    var size: Int
}

/// Request body for the `/api/show` endpoint to get model details.
struct OllamaShowModelRequest: Codable {
    var model: String
}

/// Response from the `/api/show` endpoint containing model capabilities.
struct OllamaShowModelResponse: Codable {
    /// Array of capability strings (e.g., "tools" for tool calling support).
    var capabilities: [String]
}
