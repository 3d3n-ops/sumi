//
//  SettingsView.swift
//  sumi-ios
//
//  Sumi's settings: personal context, awareness & proactive toggles, history
//  retention, the voice warmth dial, and the on-device assurance — in Sumi's
//  visual language. The interim Worker connection config lives behind "Advanced".
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SumiPrefKey.onscreenAwareness) private var onscreenAwareness = true
    @AppStorage(SumiPrefKey.proactiveSuggestions) private var proactiveSuggestions = true
    @AppStorage(SumiPrefKey.voiceWarmth) private var voiceWarmth = 0.7
    @AppStorage(SumiPrefKey.keepHistoryDays) private var keepHistoryDays = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    personalContextCard
                    controlsCard
                    voiceCard
                    onDeviceBadge
                    advancedCard
                }
                .padding(SumiTheme.screenMargin)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Cards

    private var personalContextCard: some View {
        NavigationLink {
            PersonalContextDetailView()
        } label: {
            HStack(spacing: 14) {
                LivingLightOrb(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal context").font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text("What sumi knows about you").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .sumiCard()
        }
        .buttonStyle(.plain)
    }

    private var controlsCard: some View {
        VStack(spacing: 0) {
            Toggle("On-screen awareness", isOn: $onscreenAwareness)
                .tint(SumiTheme.tileGreen)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .sensoryFeedback(.selection, trigger: onscreenAwareness)

            Divider().padding(.leading, 16)

            Toggle("Proactive suggestions", isOn: $proactiveSuggestions)
                .tint(SumiTheme.tileGreen)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .sensoryFeedback(.selection, trigger: proactiveSuggestions)

            Divider().padding(.leading, 16)

            Menu {
                Button("30 days") { keepHistoryDays = 30 }
                Button("60 days") { keepHistoryDays = 60 }
                Button("90 days") { keepHistoryDays = 90 }
                Button("Forever") { keepHistoryDays = 0 }
            } label: {
                HStack {
                    Text("Keep history").foregroundStyle(.primary)
                    Spacer()
                    Text(historyLabel).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
        .font(.body.weight(.medium))
        .sumiCard(padding: 0)
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Voice & warmth").font(.body.weight(.semibold))
                Spacer()
                Text("Calm — Warm").font(.subheadline).foregroundStyle(.secondary)
            }
            Slider(value: $voiceWarmth).tint(.primary)
        }
        .sumiCard()
    }

    private var onDeviceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.footnote.weight(.semibold))
            Text("Processed on-device · independently verified").font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(SumiTheme.tileGreen)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: SumiTheme.cardRadius, style: .continuous)
                .fill(SumiTheme.tileGreen.opacity(0.12))
        )
    }

    private var advancedCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ConnectionSettingsView()
            } label: {
                HStack {
                    Text("Connection").foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .font(.body.weight(.medium))
        .sumiCard(padding: 0)
    }

    private var historyLabel: String {
        keepHistoryDays <= 0 ? "Forever" : "\(keepHistoryDays) days"
    }
}

#Preview {
    SettingsView()
}
