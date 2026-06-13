//
//  SumiTool.swift
//  sumi-ios
//
//  The tool abstraction the agent reasons over, plus the registry that holds them.
//  Tools wrap a single capability (calendar, contacts, reminders, …) behind a
//  stable id and a natural-language description the LLM uses to pick one.
//

import Foundation

/// A single capability the agent can invoke.
///
/// `description` is written for the model: a plain-English summary of what the
/// tool does, used when selecting a tool to satisfy a request.
protocol SumiTool: Sendable {
    /// Stable identifier, unique within the registry.
    var toolID: String { get }
    /// Natural-language description of the tool's capability, for LLM selection.
    var description: String { get }
}

/// Holds the registered tools and exposes them by id and as an LLM-facing catalog.
actor ToolRegistry {
    private var tools: [String: any SumiTool]

    init(tools: [any SumiTool] = []) {
        self.tools = Dictionary(tools.map { ($0.toolID, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Registers (or replaces) a tool.
    func register(_ tool: any SumiTool) {
        tools[tool.toolID] = tool
    }

    /// The tool with `id`, if registered.
    func tool(id: String) -> (any SumiTool)? {
        tools[id]
    }

    /// All registered tools.
    func all() -> [any SumiTool] {
        Array(tools.values)
    }

    /// `toolID → description` map for prompting the model with available tools.
    func catalog() -> [String: String] {
        tools.mapValues(\.description)
    }
}
