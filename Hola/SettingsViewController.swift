//
//  SettingsViewController.swift
//  Roster Decoder
//
//  Created by Randall Wood on 9/24/16.
//  Copyright © 2016 Alexandria Software. All rights reserved.
//

import Foundation
import UIKit
import MessageUI
import SafariServices

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {

    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
    let longVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")!

    @IBOutlet weak var showEmptySwitch: UISwitch!
    @IBOutlet weak var emailCell: UITableViewCell!
    @IBOutlet weak var privacyPolicyCell: UITableViewCell!
    @IBOutlet weak var versionLabel: UILabel!

    override func viewDidLoad() {
        if let version = self.versionLabel {
            version.text = "\(shortVersion) (\(longVersion))"
        }
        if let showEmptySwitch = self.showEmptySwitch {
            showEmptySwitch.isOn = UserDefaults.standard.bool(forKey: "showEmptyDomains")
        }
    }
    
    @IBAction func showEmpty(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "showEmptyDomains")
    }
    
    // MARK: - Table View
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case emailCell:
            if (!MFMailComposeViewController.canSendMail()) {
                let alert = UIAlertController(
                    title: NSLocalizedString("NO_EMAIL_TITLE", comment: "Alert title with no email"),
                    message: NSString.localizedStringWithFormat(NSLocalizedString("NO_EMAIL_MESSAGE", comment: "Alert message with no email") as NSString, UIDevice.current.model) as String,
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(
                    title: NSLocalizedString("OK", comment: "Default action"),
                    style: .default,
                    handler: {_ in
                        // do nothing
                }))
                self.present(alert, animated: true, completion: nil)
                return
            }
            let controller = MFMailComposeViewController()
            controller.mailComposeDelegate = self
            controller.setToRecipients(["support@alexandriasoftware.com"])
            controller.setSubject("Hola! (\(shortVersion) (\(longVersion))) Feedback")
            controller.navigationBar.tintColor = self.view.tintColor
            present(controller, animated: true)
            break
        case privacyPolicyCell:
            let url = URL(string: NSLocalizedString("PRIVACY_POLICY_URL", comment: "Privacy policy URL"))!
            let controller: SFSafariViewController
            if #available(iOS 11.0, *) {
                let configuration = SFSafariViewController.Configuration()
                configuration.barCollapsingEnabled = true
                controller = SFSafariViewController.init(url: url, configuration: configuration)
            } else {
                controller = SFSafariViewController.init(url: url)
            }
            if #available(iOS 10.0, *) {
                controller.preferredControlTintColor = self.view.tintColor
            }
            present(controller, animated: true)
            break
        default:
            // nothing to do
            break
        }
    }
    
    // MARK: - Mail Delegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.
        
        // Dismiss the mail compose view controller.
        controller.dismiss(animated: true, completion: nil)
    }

}
