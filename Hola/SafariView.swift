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
    @Binding var showing: URL?

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.delegate = context.coordinator
        controller.preferredControlTintColor = UIColor(Color.accentColor)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // nothing to do
    }

    func makeCoordinator() -> SafariView.Coordinator {
        Coordinator(showing: $showing)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        @Binding var showing: URL?

        init(showing: Binding<URL?>) {
            self._showing = showing
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            self.showing = nil
        }
    }
}

struct SafariView_Previews: PreviewProvider {
    static let url = URL(string: "http://apple.com")!
    @State static var isShowing: URL? = url

    static var previews: some View {
        SafariView(url: url, showing: $isShowing)
    }
}
