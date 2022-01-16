//
//  SettingsView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-16.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI

struct SettingsView: View {

    @State var onSafari = false
    let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    let longVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String

    var body: some View {
        List {
            Section {
                NavigationLink {
                    
                } label: {
                    HStack {
                        Text("Email")
                        Text("support@alexandriasoftware.com")
                    }
                }
            } header: {
                Text("Contact Us")
            }
            Section {
                NavigationLink(isActive: $onSafari,
                               destination: {
                    SafariView(url: URL(string: NSLocalizedString("PRIVACY_POLICY_URL", comment: "Privacy policy URL"))!, showing: $onSafari)
                        .navigationBarHidden(true)
                },
                               label: {
                    Text("Privacy Policy")
                })
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(shortVersion) (\(longVersion))")
                }
            } header: {
                Text("About")
            }
        }.listStyle(.grouped)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
