//
//  ViewController.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 11.11.18.
//  Copyright © 2018 Ernesto Elsäßer. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var loadingView: UIView!
    
    let homepageURL = URL(string: "https://nshipster.com/wkwebview")!
    var archiveURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.archiveURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("cached").appendingPathExtension("webarchive")
        
        webView.navigationDelegate = self
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
        
        WebArchiver.archive(url: url) { result in
            
            self.loadingView.isHidden = true
            
            switch result {
            case .success(let plistData):
                do {
                    try plistData.write(to: self.archiveURL)
                    self.popup("Web page successfully archived!", isError: false)
                } catch {
                    self.popup("Failed to write archive to disk!", isError: true)
                }
            case .failure(let error):
                self.popup(error.localizedDescription, isError: true)
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
