//
//  DomainView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-12.
//  Copyright © 2022 Randall Wood. All rights reserved.
//

import BetterSafariView
import SwiftUI
import UIKit

struct DomainView: View {
    
    @State var safariUrl: URL?
    @EnvironmentObject var browser: BrowserManager
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationView {
            List(browser.services.filter({ !$0.key.isEmpty }).sorted(by: { $0.name < $1.name }), id:\.key) { service in
                if let url = service.url {
                    UrlButton(url: url, name: service.name)
                } else {
                    VStack(alignment: .leading) {
                        Text(service.name)
                        Text(LocalizedStringKey("UNABLE_TO_VIEW"))
                    }
                }
            }
            .emptyState(browser.services.isEmpty) {
                VStack {
                    if let error = browser.error {
                        // wrap empty state in a static list to enable pull to refresh
                        // leave "Try Again" buttons in place anyway
                        List {
                            VStack {
                                switch error {
                                case .noNetwork:
                                    Text(LocalizedStringKey("NO_NETWORK_TITLE")).font(.headline)
                                        .padding()
                                    Text(LocalizedStringKey("NO_NETWORK_DETAIL"))
                                    Button(action: { browser.refresh() }) {
                                        Text(LocalizedStringKey("REFRESH"))
                                    }.padding()
                                case .privacyDenied:
                                    Text(LocalizedStringKey("DENIED_BY_PRIVACY_TITLE")).font(.headline)
                                        .padding()
                                    Text(LocalizedStringKey("DENIED_BY_PRIVACY_DETAIL"))
                                    Button(action: { openURL(URL(string: UIApplication.openSettingsURLString)!) }) {
                                        Text(LocalizedStringKey("DENIED_BY_PRIVACY_BUTTON"))
                                    }.padding()
                                }
                            }
                        }
                        .refreshable {
                            browser.refresh()
                        }
                    } else {
                        switch browser.state {
                        case .searching:
                            VStack {
                                ProgressView().scaleEffect(2.0).padding()
                                Spacer()
                            }
                        case .monitoring, .stopped:
                            // wrap empty state in a static list to enable pull to refresh
                            // leave "Try Again" buttons in place anyway
                            List {
                                VStack {
                                    Text(LocalizedStringKey("NO_SERVICES_TITLE")).font(.headline).padding()
                                    Text(LocalizedStringKey("NO_SERVICES_DETAIL"))
                                    Button(action: { browser.refresh() }) {
                                        Text(LocalizedStringKey("REFRESH"))
                                    }.padding()
                                }
                            }
                            .refreshable {
                                browser.refresh()
                            }
                        }
                    }
                }
            }
            .refreshable {
                browser.refresh()
            }
            .navigationBarTitle(LocalizedStringKey("VIEW_TITLE"))
            .onAppear(perform: { browser.search() })
            .onDisappear(perform: { browser.stop() })
            .toolbar {
                ToolbarItem {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct UrlButton: View {
    
    var url: URL
    var name: String
    @State var onSafari = false
    
    var body: some View {
        Button(action: {
            onSafari = true
        }) {
            VStack(alignment: .leading) {
                Text(name).font(.system(.headline))
                Text(url.absoluteString).font(.system(.subheadline))
            }
        }
        .safariView(isPresented: $onSafari) {
            SafariView(
                url: url,
                configuration: SafariView.Configuration(
                    entersReaderIfAvailable: false,
                    barCollapsingEnabled: true
                )
            )
            // https://github.com/stleamist/BetterSafariView/issues/16
            .preferredControlTintColor(UIColor(named: "AccentColor"))
        }
    }
}

struct DomainView_Previews: PreviewProvider {
    static var previews: some View {
        DomainView().environmentObject(BrowserManager())
    }
}
