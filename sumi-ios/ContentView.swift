//
//  ContentView.swift
//  sumi-ios
//
//  Root screen: the conversation surface (talk or type to Sumi directly).
//  Settings — including the interim Worker connection config — is a sheet behind
//  the toolbar gear. Sumi also surfaces proactively via Siri/notifications.
//

import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ConversationView()
                .navigationTitle("Sumi")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
    }
}

#Preview {
    ContentView()
}
