//
//  DomainView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-12.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI
import BetterSafariView

struct DomainView: View {
    
    @State var safariUrl: URL?
    @EnvironmentObject var browser: BrowserManager
    
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
                    if browser.searching > 0 { // is searching
                        Text(LocalizedStringKey("SEARCHING"))
                    } else { // not searching
                        Text(LocalizedStringKey("NO_SERVICES_CELL_TITLE"))
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
