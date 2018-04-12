//
//  SettingsViewController.swift
//  Roster Decoder
//
//  Created by Randall Wood on 9/24/16.
//  Copyright © 2016 Alexandria Software. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UITableViewController {
    
    @IBOutlet weak var showEmptySwitch: UISwitch!
    @IBOutlet weak var versionLabel: UILabel!

    override func viewDidLoad() {
        if let version = self.versionLabel {
            let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
            let longVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")!
            version.text = "\(shortVersion) (\(longVersion))"
        }
        if let showEmptySwitch = self.showEmptySwitch {
            showEmptySwitch.isOn = UserDefaults.standard.bool(forKey: "showEmptyDomains")
        }
    }
    
    @IBAction func showEmpty(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "showEmptyDomains")
    }
}
