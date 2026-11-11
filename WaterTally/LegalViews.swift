//
//  LegalViews.swift
//  Water Tally
//
//  Links to the hosted legal pages plus the in-app acknowledgment screen.
//

import SwiftUI

enum AppLinks {
    static let base = "https://rshamilton.github.io/watertally/"
    static let home = URL(string: base)!
    static let privacy = URL(string: base + "privacy.html")!
    static let terms = URL(string: base + "terms.html")!
    static let medical = URL(string: base + "medical-disclaimer.html")!
    static let support = URL(string: base + "support.html")!
    static let contactEmail = "watertally@googlegroups.com"
    static var mailto: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "\(AppInfo.name) Support")]
        return components.url ?? URL(string: "mailto:\(contactEmail)")!
    }
}

/// One short, plain-language summary of what the legal documents say. Used in onboarding,
/// the acknowledgment screen and Settings so the wording is identical everywhere.
enum LegalCopy {
    static let short = "\(AppInfo.name) is a simple log for the drinks you choose to record. It isn't a medical device and doesn't give medical advice. Goals are personal targets you set, not recommendations."
    static let professional = "Ask a healthcare professional how much fluid is right for you, especially if you're pregnant, take medication, or have a kidney, heart, or liver condition, or were told to limit fluids."
    static let overhydration = "Drinking too much water in a short time can be harmful."
    static let emergency = "In an emergency, contact your local emergency services."
}

struct LegalLinksRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Link("Terms", destination: AppLinks.terms)
            Text("·").foregroundColor(.white.opacity(0.4))
            Link("Privacy", destination: AppLinks.privacy)
            Text("·").foregroundColor(.white.opacity(0.4))
            Link("Medical Disclaimer", destination: AppLinks.medical)
        }
        .font(.footnote.weight(.semibold))
        .foregroundColor(.water)
    }
}

/// The bulleted "what you should know" list.
struct LegalPoints: View {
    private struct Point: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let text: String
    }

    private var points: [Point] {
        [
            Point(icon: "cross.case", color: .water, title: "Not medical advice", text: LegalCopy.short),
            Point(icon: "stethoscope", color: .water, title: "Talk to a professional", text: LegalCopy.professional),
            Point(icon: "exclamationmark.triangle", color: .orange, title: "More isn't always better", text: LegalCopy.overhydration),
            Point(icon: "lock", color: .water, title: "Your data stays with you", text: "Everything is stored on your device. \(AppInfo.name) has no account and no analytics or advertising.")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(points) { point in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: point.icon)
                        .font(.body.weight(.medium))
                        .foregroundColor(point.color)
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(point.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text(point.text)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Full-screen acknowledgment shown to returning users when the legal version changes.
/// (New users see the same content as the last onboarding page.)
struct LegalConsentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            AppBackground(themeColor: appState.themeColor)

            ScrollView {
                VStack(spacing: 22) {
                    Text("Before you continue")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                        .accessibilityAddTraits(.isHeader)

                    LegalPoints()
                        .padding(20)
                        .card(cornerRadius: 20)

                    LegalConsentActions { appState.acceptLegal() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}

struct LegalConsentActions: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button("I Understand and Agree", action: onAccept)
                .buttonStyle(PrimaryButtonStyle())

            Text("By continuing you agree to the Terms of Use, acknowledge the Privacy Policy and Medical Disclaimer, and confirm you are at least 13 years old.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            LegalLinksRow()
        }
    }
}
