//
//  SettingsView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-16.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.openURL) private var openURL
    @State var onMail = false
    @State var safariUrl: URL?
    let privacyPolicyUrl = URL(string: NSLocalizedString("PRIVACY_POLICY_URL", comment: "Privacy policy URL"))!
    let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    let longVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    

    var body: some View {
        if let url = safariUrl {
            SafariView(url: url, showing: $safariUrl)
                .navigationBarHidden(true)
        } else {
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
                    .alert("Unable to use email.", isPresented: $onMail) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Cannot open app to send email to support@alexandriasoftware.com.")
                    }

                } header: {
                    Text("Contact Us")
                }
                Section {
                    Button(action: {
                        safariUrl = privacyPolicyUrl
                    }) {
                        Text("Privacy Policy")
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(shortVersion) (\(longVersion))")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
