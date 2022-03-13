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
                Button(action: {
                    if let url = URL(string: "mailto:support@alexandriasoftware.com?subject=Hola! (\(shortVersion) (\(longVersion))) Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                        openURL(url) { accepted in
                            if !accepted {
                                onMail = true
                            }
                        }
                    }
                }) {
                    Text("Get Help")
                }
                .alert("Unable to get help.", isPresented: $onMail) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Cannot send email to support@alexandriasoftware.com.")
                }
                
            } header: {
                Text("Contact Us")
            }
            Section {
                Button(action: {
                    self.onSafari = true
                }) {
                    Text("Privacy Policy")
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
                    Text("Version")
                    Spacer()
                    Text("\(shortVersion) (\(longVersion))")
                }
            } header: {
                Text("About")
            } footer: {
                Text("Copyright © 2018, 2022 Randall Wood DBA Alexandria Software. All rights reserved.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
