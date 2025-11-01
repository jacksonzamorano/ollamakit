# OllamaKit

A Swift package for building native macOS and iOS applications with [Ollama](https://ollama.ai/), featuring streaming responses, tool calling, and ready-to-use SwiftUI components.

## Features

- **Streaming API**: Real-time response streaming for smooth user experiences
- **Tool Calling**: Define and execute Swift functions that the model can call
- **SwiftUI Views**: Pre-built, customizable chat interface components
- **Observable Architecture**: Built with Swift's Observation framework for seamless SwiftUI integration
- **Type-Safe**: Fully typed API with Swift's Codable protocol
- **Markdown Support**: Automatic markdown parsing for rich text display
- **Thinking Display**: Optional display of model reasoning processes

## Requirements

- macOS 26+ or iOS 26+
- Swift 6.2+
- Ollama running locally or on a network-accessible host

## Installation

### Swift Package Manager

Add OllamaKit to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR-USERNAME/OllamaKit.git", from: "1.0.0")
]
```

## Quick Start

### Basic Chat Interface

Create a complete chat interface with just a few lines of code:

```swift
import SwiftUI
import OllamaKit

struct ContentView: View {
    @State var session = OllamaSession<EmptyToolArgs>(
        model: "llama2",
        systemPrompt: "You are a helpful assistant."
    )

    var body: some View {
        ThreadView(session: session)
    }
}

// Define an empty tool args type if you don't need tools
struct EmptyToolArgs: Codable, Sendable {}
```

### Using Tool Calling

Define tools that the model can use during conversation:

```swift
import OllamaKit

// 1. Define your tool argument structure
struct WeatherArgs: Codable, Sendable {
    var location: String
    var units: String?
}

struct WeatherResult: Codable, Sendable {
    var temperature: Double
    var conditions: String
}

// 2. Create the tool definition
let weatherTool = OllamaToolDefinition(
    tool: OllamaFunction(
        name: "get_weather",
        description: "Get the current weather for a location",
        parameters: OllamaObject(
            properties: [
                "location": OllamaProperty(
                    type: "string",
                    description: "The city and state, e.g. San Francisco, CA"
                ),
                "units": OllamaProperty(
                    type: "string",
                    description: "Temperature units (celsius or fahrenheit)"
                )
            ],
            required: ["location"]
        )
    ),
    execute: { args in
        // Your weather fetching logic here
        return WeatherResult(temperature: 72, conditions: "Sunny")
    }
)

// 3. Add the tool to your session
session.tools.append(weatherTool)
```

### Programmatic Queries

Query the model directly without using the UI components:

```swift
let session = OllamaSession<MyToolArgs>(
    model: "llama2",
    systemPrompt: "You are a helpful assistant."
)

let result = await session.query("What's the capital of France?") {
    // This closure is called as the response streams in
    print("Response updated")
}

switch result {
case .success:
    // Access the conversation transcript
    for event in session.transcript {
        print("\(event.speaker): \(event.content)")
    }
case .failure(let error):
    print("Error: \(error.message)")
}
```

## Customization

### Configuring the ThreadView

Customize the appearance and behavior of the chat interface:

```swift
let config = ThreadViewConfiguration(
    welcome: ThreadViewWelcomeConfiguration(
        title: "AI Assistant",
        message: "How can I help you today?",
        modelPickerConfiguration: .toolEnabled,
        showMessageConfiguration: false
    ),
    input: ThreadViewInputConfiguration(
        placeholder: "Type your message...",
        focusAfterDone: true
    ),
    messages: ThreadViewMessageConfiguration(
        allowsContentSelection: true,
        toolRequestDisplay: .name,
        toolResponseDisplay: .details,
        showsThinking: true
    )
)

ThreadView(session: session, config: config)
```

### Tool Display Options

Control how tool calls are displayed:

```swift
// Hide tool calls completely
messages.toolRequestDisplay = .none
messages.toolResponseDisplay = .none

// Show simple indicator
messages.toolRequestDisplay = .exists

// Show tool name
messages.toolRequestDisplay = .name

// Show full JSON details
messages.toolRequestDisplay = .details
```

## API Reference

### Core Types

#### `OllamaSession<ToolArgs>`

Manages a conversation with an Ollama model. Generic over `ToolArgs` which defines the shape of tool arguments.

**Properties:**
- `transcript: [OllamaEvent]` - Observable conversation history
- `model: String` - The model name
- `lastStatus: OllamaStatus` - Current processing status
- `working: Bool` - Whether actively processing
- `tools: [OllamaToolDefinition<ToolArgs>]` - Available tools

**Methods:**
- `query(_:update:) async -> Result<(), OllamaError>` - Send a message and stream the response
- `stop()` - Cancel the current query

#### `OllamaEvent`

Represents a single turn in the conversation transcript.

**Properties:**
- `role: OllamaEventRole` - Who created this event (.model, .user, .tool)
- `content: String` - Text content
- `contentStyled: AttributedString` - Markdown-parsed content
- `thinking: String` - Model's reasoning process
- `toolRequest: OllamaToolCallRequestPart?` - Tool call information
- `toolResponse: OllamaToolCallResponsePart?` - Tool result

#### `OllamaFunction`

Defines a function that can be called by the model.

```swift
OllamaFunction(
    name: "function_name",
    description: "What the function does",
    parameters: OllamaObject(...)
)
```

### UI Components

#### `ThreadView<Args>`

Complete chat interface with message history, input field, and welcome screen.

```swift
ThreadView(
    session: OllamaSession<Args>,
    config: ThreadViewConfiguration
)
```

#### `ThreadViewConfiguration`

Customizes ThreadView appearance and behavior with nested configurations:
- `welcome: ThreadViewWelcomeConfiguration` - Welcome screen settings
- `input: ThreadViewInputConfiguration` - Input field settings
- `messages: ThreadViewMessageConfiguration` - Message display settings

### Utility Functions

#### `getModels(onlyToolCalling:host:) async -> [String]`

Fetch available models from an Ollama instance.

```swift
// Get all models
let models = await getModels()

// Get only models that support tool calling
let toolModels = await getModels(onlyToolCalling: true)

// Use custom host
let models = await getModels(host: "192.168.1.100:11434")
```

## Advanced Usage

### Custom Host Configuration

Connect to Ollama running on a different machine:

```swift
let session = OllamaSession<MyToolArgs>(
    model: "llama2",
    systemPrompt: "You are a helpful assistant.",
    host: "192.168.1.100:11434"
)
```

### Handling Multiple Tool Types

Use a union type for tools with different argument structures:

```swift
enum ToolArgs: Codable, Sendable {
    case weather(WeatherArgs)
    case calculator(CalculatorArgs)
    case search(SearchArgs)
}
```

### Accessing Raw Message History

The session maintains an internal message history for API communication:

```swift
// Note: messages are @ObservationIgnored
// Use transcript for UI-facing data
for event in session.transcript {
    print(event.content)
}
```

## Troubleshooting

### "Could not connect to the Ollama instance"

Make sure Ollama is running:
```bash
ollama serve
```

### No models available

Pull a model first:
```bash
ollama pull llama2
```

### Tool calling not working

Ensure you're using a model that supports tool calling. Check with:
```swift
let toolModels = await getModels(onlyToolCalling: true)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

OllamaKit is available under the MIT license. See LICENSE for details.

## Acknowledgments

Built with [Ollama](https://ollama.ai/) - Get up and running with large language models locally.
