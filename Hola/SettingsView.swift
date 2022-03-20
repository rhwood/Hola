//
//  SettingsView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-16.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI
import BetterSafariView

struct SettingsView: View {
    
    @Environment(\.openURL) private var openURL
    @State private var onMail = false
    @State private var onSafari = false
    let privacyPolicyUrl = URL(string: NSLocalizedString("PRIVACY_POLICY_URL", comment: "Privacy policy URL"))!
    let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    let longVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String

    var body: some View {
        List {
            Section {
                Button(action: { openURL(URL(string: UIApplication.openSettingsURLString)!) }) {
                    Text(LocalizedStringKey("SETTINGS_APP"))
                }
            } header: {
                Text(LocalizedStringKey("PRIVACY"))
            } footer: {
                Text(LocalizedStringKey("PRIVACY_CONTROLS"))
            }
            Section {
                Button(action: {
                    if let url = URL(string: "mailto:support@alexandriasoftware.com?subject=Hola! (\(shortVersion) (\(longVersion))) Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                        openURL(url) { accepted in
                            if !accepted {
                                onMail = true
                            }
                        }
                    }
                }) {
                    Text(LocalizedStringKey("GET_HELP"))
                }
                .alert(LocalizedStringKey("GET_HELP_ERROR_TITLE"), isPresented: $onMail) {
                    Button(LocalizedStringKey("OK"), role: .cancel) { }
                    .tint(Color.accentColor)
                } message: {
                    Text(LocalizedStringKey("GET_HELP_ERROR_MESSAGE"))
                }
            } header: {
                Text(LocalizedStringKey("CONTACT_US"))
            }
            Section {
                Button(action: {
                    self.onSafari = true
                }) {
                    Text(LocalizedStringKey("PRIVACY_POLICY"))
                }
                .safariView(isPresented: $onSafari) {
                    SafariView(
                        url: privacyPolicyUrl,
                        configuration: SafariView.Configuration(
                            entersReaderIfAvailable: false,
                            barCollapsingEnabled: true
                        )
                    )
                        // https://github.com/stleamist/BetterSafariView/issues/16
                        .preferredControlTintColor(UIColor(named: "AccentColor"))
                }
                HStack {
                    Text(LocalizedStringKey("VERSION"))
                    Spacer()
                    Text("\(shortVersion) (\(longVersion))")
                }
            } header: {
                Text(LocalizedStringKey("ABOUT"))
            } footer: {
                Text(LocalizedStringKey("COPYRIGHT_STATEMENT"))
            }
        }
        .navigationTitle(LocalizedStringKey("SETTINGS"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
