//
//  ToolRegistryTests.swift
//  sumi-iosTests
//
//  Registry registration, lookup, and LLM-facing catalog.
//

import Foundation
import Testing
@testable import sumi_ios

/// Minimal tool used to exercise the registry.
struct FakeTool: SumiTool {
    let toolID: String
    let description: String
}

struct ToolRegistryTests {

    @Test func initialToolsAreRegistered() async {
        let registry = ToolRegistry(tools: [
            FakeTool(toolID: "a", description: "Tool A"),
            FakeTool(toolID: "b", description: "Tool B"),
        ])
        #expect(await registry.all().count == 2)
        #expect(await registry.tool(id: "a")?.description == "Tool A")
        #expect(await registry.tool(id: "missing") == nil)
    }

    @Test func registerAddsAndReplaces() async {
        let registry = ToolRegistry()
        await registry.register(FakeTool(toolID: "a", description: "first"))
        #expect(await registry.tool(id: "a")?.description == "first")

        await registry.register(FakeTool(toolID: "a", description: "second"))
        #expect(await registry.all().count == 1)
        #expect(await registry.tool(id: "a")?.description == "second")
    }

    @Test func catalogMapsIDsToDescriptions() async {
        let registry = ToolRegistry(tools: [
            FakeTool(toolID: "calendar", description: "reads calendar"),
            FakeTool(toolID: "reminders", description: "manages reminders"),
        ])
        let catalog = await registry.catalog()
        #expect(catalog["calendar"] == "reads calendar")
        #expect(catalog["reminders"] == "manages reminders")
        #expect(catalog.count == 2)
    }
}
