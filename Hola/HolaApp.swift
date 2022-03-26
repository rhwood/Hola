//
//  HolaApp.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-12.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI

@main
struct HolaApp: App {

    var body: some Scene {
        WindowGroup {
            DomainView().environmentObject(BrowserManager())
        }
    }
}
