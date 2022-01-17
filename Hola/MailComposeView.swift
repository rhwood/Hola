//
//  MailComposeView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-16.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI
import MessageUI

struct MailComposeViewController: UIViewControllerRepresentable {

    var toReceipents: [String]
    var messageBody: String
    
    var didFinish: () -> ()

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(toReceipents)
        controller.setMessageBody(messageBody, isHTML: true)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // nothing to do
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    typealias UIViewControllerType = MFMailComposeViewController

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        
        var parent: MailComposeViewController
        
        init(_ controller: MailComposeViewController) {
            self.parent = controller
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.didFinish()
            controller.dismiss(animated: true)
        }
    }
}
