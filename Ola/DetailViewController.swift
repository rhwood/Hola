//
//  DetailViewController.swift
//  Ola
//
//  Created by Randall Wood on 9/16/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

import UIKit
import WebKit

class DetailViewController: UIViewController, WKUIDelegate {

    var webView: WKWebView!

    func configureView() {
        // Update the user interface for the detail item.
        if let service = service, let url = url {
            print("Viewing service...")
            navigationItem.title = service.name
            if let web = webView {
                print("Using webView...")
                web.load(URLRequest(url: url))
            }
        }
    }

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var url: URL? {
        didSet {
            // Update the view.
            configureView()
        }
    }

    var service: NetService? {
        didSet {
            // Update the view.
            configureView()
        }
    }

}

