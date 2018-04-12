//
//  PrivacyPolicyViewController.swift
//  Roster Decoder
//
//  Created by Randall Wood on 9/24/16.
//  Copyright © 2016 Alexandria Software. All rights reserved.
//

import Foundation
import UIKit

class PrivacyPolicyViewController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        if let webView = self.webView {
            // bitly-based redirection to policy
            webView.loadRequest(URLRequest(url: URL(string: "https://axsw.co/2cBJtzZ")!))
        }
    }
    
    @IBAction func activty(_ sender: UIButton) {
        if let webView = self.webView, let request = webView.request, let url = request.url {
            // actual policy
            if url.absoluteString == "https://www.iubenda.com/privacy-policy/7912713" {
                // bitly-based redirection to policy on AXSW site
                UIApplication.shared.openURL(URL(string:"https://axsw.co/2dfh5G9")!)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
}
