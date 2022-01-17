//
//  SettingsView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-16.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
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
                        onMail.toggle()
                    }) {
                        HStack {
                            Text("Email")
                            Text("support@alexandriasoftware.com")
                        }
                    }.sheet(isPresented: $onMail) { MailComposeViewController(toReceipents: ["support@alexandriasoftware.com"], messageBody: "", didFinish: {})
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
            .listStyle(.grouped)
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
