//
//  ViewController.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 11.11.18.
//  Copyright © 2018 Ernesto Elsäßer. All rights reserved.
//

import UIKit
import WebKit
import WebArchiver

class ViewController: UIViewController {

    @IBOutlet weak var webViewContainer: UIView!
    @IBOutlet weak var loadingView: UIView!
    
    var webView: WKWebView!
    let homepageURL = URL(string: "https://nshipster.com/wkwebview")!
    var archiveURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        archiveURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("cached").appendingPathExtension("webarchive")
        
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        webViewContainer.addSubview(webView)
        webViewContainer.addConstraints([
            webViewContainer.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            webViewContainer.topAnchor.constraint(equalTo: webView.topAnchor),
            webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
            ])
        
        let request = URLRequest(url: homepageURL)
        webView.load(request)
    }
    
    @IBAction func backTapped(_ sender: Any) {
        webView.goBack()
    }
    
    @IBAction func exportTapped(_ sender: Any) {
        
        guard let url = webView.url else {
            self.popup("No web page loaded!", isError: true)
            return
        }
        
        loadingView.isHidden = false
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            
            WebArchiver.archive(url: url, cookies: cookies) { result in
                
                self.loadingView.isHidden = true
                
                if let data = result.plistData {
                    do {
                        try data.write(to: self.archiveURL)
                        self.popup("Web page successfully archived!", isError: false)
                    } catch {
                        self.popup("Failed to write archive to disk!", isError: true)
                    }
                } else if let firstError = result.errors.first {
                    self.popup(firstError.localizedDescription, isError: true)
                }
            }
        }
    }
    
    @IBAction func importTapped(_ sender: Any) {
        
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            self.popup("Nothing archived yet!", isError: true)
            return
        }
        
        webView.loadFileURL(archiveURL, allowingReadAccessTo: archiveURL)
    }
    
    private func popup(_ message: String, isError: Bool) {
        
        let alert = UIAlertController(title: isError ? "Error" : "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingView.isHidden = false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingView.isHidden = true
    }
}
