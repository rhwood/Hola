//
//  DomainView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-12.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI

struct DomainView: View {
    
    @State var onSafari = false
    @State var safariUrl: URL?
    @EnvironmentObject var browser: BrowserManager
    
    var body: some View {
        NavigationView {
            if let url = safariUrl {
                SafariView(url: url, showing: $safariUrl)
                    .navigationBarHidden(true)
            } else {
                List(browser.services.filter({ !$0.key.isEmpty }).sorted(by: { $0.name < $1.name }), id:\.key) { service in
                    if let url = service.url {
                        Button(action: {
                            safariUrl = url
                        }) {
                            VStack(alignment: .leading) {
                                Text(service.name).font(.system(.headline))
                                Text(url.absoluteString).font(.system(.subheadline))
                            }
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text(service.name)
                            Text("Unable to view.")
                        }
                    }
                }
                .navigationBarTitle("Services")
                .listStyle(PlainListStyle())
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
        }
    }
}

struct DomainView_Previews: PreviewProvider {
    static var previews: some View {
        DomainView().environmentObject(BrowserManager())
    }
}
