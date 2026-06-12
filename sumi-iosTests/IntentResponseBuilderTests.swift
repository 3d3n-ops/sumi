//
//  IntentResponseBuilderTests.swift
//  sumi-iosTests
//
//  The spoken() transform must produce clean, short prose — every intent
//  response passes through it before Siri speaks it.
//

import Testing
@testable import sumi_ios

struct IntentResponseBuilderTests {

    @Test func stripsMarkdownEmphasisAndCode() {
        let out = IntentResponseBuilder.spoken("You have **two** meetings and a `standup`.")
        #expect(out == "You have two meetings and a standup.")
    }

    @Test func stripsHeadersAndBulletMarkers() {
        let input = "# Today\n- First meeting\n- Second meeting"
        let out = IntentResponseBuilder.spoken(input)
        #expect(!out.contains("#"))
        #expect(!out.contains("- "))
        #expect(out.contains("First meeting"))
    }

    @Test func unwrapsMarkdownLinks() {
        let out = IntentResponseBuilder.stripMarkdown("See [the deck](https://x.com/deck) please.")
        #expect(out == "See the deck please.")
    }

    @Test func removesRoboticLeadIn() {
        let out = IntentResponseBuilder.spoken("Here is your summary: You are free today.")
        #expect(out == "You are free today.")
    }

    @Test func clampsToThreeSentences() {
        let input = "One. Two. Three. Four. Five."
        let out = IntentResponseBuilder.spoken(input)
        #expect(out == "One. Two. Three.")
    }

    @Test func keepsShortQuestionIntact() {
        let out = IntentResponseBuilder.spoken("Want me to remind you?")
        #expect(out == "Want me to remind you?")
    }

    @Test func collapsesWhitespace() {
        let out = IntentResponseBuilder.spoken("You   have\n\ntwo    meetings.")
        #expect(out == "You have two meetings.")
    }
}
