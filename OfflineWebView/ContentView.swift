//
//  ContentView.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 27.03.20.
//  Copyright © 2020 Ernesto Elsaesser. All rights reserved.
//

import SwiftUI
import Combine
import WebKit
import WebArchiver

struct ContentView: View {
    
    class ToolbarState: NSObject, ObservableObject {
        @Published var loading = true
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            loading = change![.newKey] as! Bool // quick and dirty
        }
    }
    
    struct Popup: Identifiable {
        let message: String
        let isError: Bool
        var id: String { return message } // hack
    }
    
    let archiveURL: URL
    let webView: WKWebView
    let spinner: UIActivityIndicatorView
    
    @ObservedObject var toolbar = ToolbarState()
    @State var popup: Popup? = nil
    
    init(homeUrl: URL) {
        
        self.archiveURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("cached").appendingPathExtension("webarchive")
        
        self.spinner = UIActivityIndicatorView(style: .medium)
        self.spinner.startAnimating()
        
        self.webView = WKWebView()
        self.webView.addObserver(toolbar, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        
        let request = URLRequest(url: homeUrl)
        self.webView.load(request)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            UIViewWrapper(view: webView)
            HStack(spacing: 20) {
                if toolbar.loading {
                    Spacer()
                    UIViewWrapper(view: spinner)
                    Spacer()
                } else {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Button("Archive", action: archive)
                    Button("Unarchive", action: unarchive)
                }
            }.padding().frame(height:40.0).background(Color(white:0.9))
        }.alert(item: $popup) { p in
            Alert(
                title: Text(p.isError ? "Error" : "Success"),
                message: Text(p.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func back() {
        webView.goBack()
    }
    
    func archive() {
        guard let url = webView.url else {
            return
        }
        
        toolbar.loading = true
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            
            WebArchiver.archive(url: url, cookies: cookies) { result in
                
                self.toolbar.loading = false
                
                var err: Error? = nil
                if let data = result.plistData {
                    do {
                        try data.write(to: self.archiveURL)
                    } catch {
                        err = error
                    }
                } else {
                    err = result.errors.first
                }
                
                self.popup = Popup(message: err?.localizedDescription ?? "Web page stored offline.",
                                   isError: err != nil)
            }
        }
    }
    
    func unarchive() {
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            webView.loadFileURL(archiveURL, allowingReadAccessTo: archiveURL)
        } else {
            self.popup = Popup(message: "Nothing archived yet!", isError: true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(homeUrl: URL(string: "https://apple.com")!)
    }
}
