//
//  ContentView.swift
//  sumi-ios
//
//  Placeholder root screen. Sumi is proactive-first — it surfaces through
//  notifications and Siri, not by being opened. The real (minimal) Settings
//  screen lands in Sprint 6; until then this just reassures the user the app
//  is running in the background.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.primary)
            Text("Sumi")
                .font(.largeTitle.weight(.semibold))
            Text("Sumi works in the background. You'll hear from it through Siri and notifications — you don't need to open this app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
