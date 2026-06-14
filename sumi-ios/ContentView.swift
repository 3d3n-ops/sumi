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
    @AppStorage(SumiPrefKey.onboardingComplete) private var onboardingComplete = false

    var body: some View {
        Group {
            if onboardingComplete {
                main
            } else {
                OnboardingView {
                    withAnimation(.easeInOut) { onboardingComplete = true }
                }
                .transition(.opacity)
            }
        }
    }

    private var main: some View {
        NavigationStack {
            ConversationView()
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
