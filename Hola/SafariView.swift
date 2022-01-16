//
//  SafariView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-12.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {

    let url: URL
    @Binding var showing: Bool

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.delegate = context.coordinator
        if let color = Color("AccentColor").cgColor {
            controller.preferredControlTintColor = UIColor(cgColor: color)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // nothing to do
    }

    func makeCoordinator() -> SafariView.Coordinator {
        Coordinator(showing: $showing)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        @Binding var showing: Bool

        init(showing: Binding<Bool>) {
            self._showing = showing
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            self.showing = false
        }
    }
}

struct SafariView_Previews: PreviewProvider {
    @State static var isShowing = true

    static var previews: some View {
        SafariView(url: URL(string: "http://apple.com")!, showing: $isShowing)
    }
}
