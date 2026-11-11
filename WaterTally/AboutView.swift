//
//  AboutView.swift
//  Water Tally
//
//  Settings › About Water Tally: version, open-source info, feedback (bug reports, ideas,
//  App Store reviews) and the legal links.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openURL) private var openURL

    private enum FeedbackKind: Identifiable {
        case bug, idea
        var id: Self { self }
        var title: String { self == .bug ? "Report a Bug" : "Suggest a Feature" }
        var githubURL: URL { self == .bug ? AppLinks.bugReport : AppLinks.featureRequest }
    }

    @State private var feedback: FeedbackKind?

    var body: some View {
        List {
            header
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

            Section {
                Link(destination: AppLinks.repository) {
                    linkLabel("View Source on GitHub", "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: AppLinks.license) { linkLabel("License (GPL v3)", "doc.plaintext") }
            } header: {
                Text("Open source")
            } footer: {
                Text("\(AppInfo.name) is free and open source. Anyone can read the code, suggest changes, or build their own copy. It has no ads, no accounts and no tracking, and it never will.")
            }
            .listRowBackground(Color.cardFill)

            Section {
                Button { feedback = .bug } label: { rowLabel("Report a Bug", "ladybug") }
                Button { feedback = .idea } label: { rowLabel("Suggest a Feature", "lightbulb") }
                Link(destination: AppLinks.writeReview) { linkLabel("Rate on the App Store", "star") }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Reviews help other people find \(AppInfo.name). Thank you!")
            }
            .listRowBackground(Color.cardFill)

            Section {
                Link(destination: AppLinks.support) { linkLabel("Help & Support", "questionmark.circle") }
                Link(destination: AppLinks.mailto) { linkLabel("Contact", "envelope") }
                Link(destination: AppLinks.privacy) { linkLabel("Privacy Policy", "hand.raised") }
                Link(destination: AppLinks.terms) { linkLabel("Terms of Use", "doc.text") }
                Link(destination: AppLinks.medical) { linkLabel("Medical Disclaimer", "cross.case") }
            } header: {
                Text("Help & legal")
            }
            .listRowBackground(Color.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .appScreen(themeColor: appState.themeColor)
        .confirmationDialog(feedback?.title ?? "", isPresented: Binding(
            get: { feedback != nil }, set: { if !$0 { feedback = nil } }
        ), titleVisibility: .visible, presenting: feedback) { kind in
            Button("Open a GitHub Issue") { openURL(kind.githubURL) }
            Button("Send an Email") { openURL(AppLinks.mail(subject: "\(AppInfo.name): \(kind.title)", body: emailBody(for: kind))) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("GitHub issues are public and need a free GitHub account. Email goes only to the developer.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            BrandMark(size: 72)
            Text(AppInfo.name)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Version \(AppInfo.version)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    private func emailBody(for kind: FeedbackKind) -> String {
        let device = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        switch kind {
        case .bug:
            return "What happened:\n\n\nWhat you expected:\n\n\nSteps to reproduce:\n1.\n2.\n\n---\n\(AppInfo.name) \(AppInfo.version) · \(device)"
        case .idea:
            return "Your idea:\n\n\nWhy it would help:\n\n\n---\n\(AppInfo.name) \(AppInfo.version) · \(device)"
        }
    }

    private func rowLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.35))
        }
    }

    private func linkLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.35))
        }
    }
}

extension AppInfo {
    /// "1.1 (4)" from the bundle.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
