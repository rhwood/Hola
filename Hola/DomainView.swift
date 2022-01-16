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
    @EnvironmentObject var browser: BrowserManager

    var body: some View {
        NavigationView {
            List(browser.services.filter({ !$0.key.isEmpty }).sorted(by: { $0.name < $1.name }), id:\.key) { service in
                if let url = service.url {
                    NavigationLink(isActive: $onSafari,
                                   destination: {
                        SafariView(url: url, showing: $onSafari)
                            .navigationBarHidden(true)
                    },
                                   label: {
                        VStack(alignment: .leading) {
                            Text(service.name).font(.system(.headline))
                            Text(url.absoluteString).font(.system(.subheadline))
                        }
                    })
                } else {
                    VStack(alignment: .leading) {
                        Text(service.name)
                        Text("Unable to view.")
                    }
                }
            }
            .navigationBarTitle("Services")
            .listStyle(PlainListStyle())
            .navigationBarItems(trailing:
                                    NavigationLink(destination: SettingsView()) {
                Image(systemName: "gear")
            })
            .onAppear(perform: { browser.search() })
            .onDisappear(perform: { browser.stop() })
        }
    }
}

struct DomainView_Previews: PreviewProvider {
    static var previews: some View {
        DomainView().environmentObject(BrowserManager())
    }
}
