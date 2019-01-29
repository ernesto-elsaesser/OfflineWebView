//
//  WebArchiver.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 11.11.18.
//  Copyright © 2018 Ernesto Elsäßer. All rights reserved.
//

import Foundation
import Fuzi

enum ArchivingResult {
    case success(plistData: Data)
    case failure(error: Error)
}

enum ArchivingError: LocalizedError {
    case unsupportedUrl
    case requestFailed(resource: URL, error: Error)
    case invalidResponse(resource: URL)
    case unsupportedEncoding
    case invalidReferenceUrl(string: String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedUrl: return "Unsupported URL"
        case .requestFailed(let res, _): return "Failed to load " + res.absoluteString
        case .invalidResponse(let res): return "Invalid response for " + res.absoluteString
        case .unsupportedEncoding: return "Unsupported encoding"
        case .invalidReferenceUrl(let string): return "Invalid reference URL: " + string
        }
    }
}

private class ArchivingSession {
    private let urlSession: URLSession
    private let completion: (ArchivingResult) -> ()
    private var lastError: Error? = nil
    private var pendingTaskCount: Int = 0 // TODO: use urlSession.delegateQueue.operationCount?
    
    init(completion: @escaping (ArchivingResult) -> ()) {
        let sessionQueue = OperationQueue()
        sessionQueue.maxConcurrentOperationCount = 1
        sessionQueue.name = "WebArchiverWorkQueue"
        self.urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: sessionQueue)
        self.completion = completion
    }
    
    func load(url: URL, resourceHandler: @escaping (WebArchiveResource) throws -> WebArchive ) {
        pendingTaskCount = pendingTaskCount + 1
        let task = urlSession.dataTask(with: url) { (data, response, error) in
            self.pendingTaskCount = self.pendingTaskCount - 1
            
            if let error = error {
                self.onError(ArchivingError.requestFailed(resource: url, error: error))
                return
            }
            
            guard let data = data, let mimeType = (response as? HTTPURLResponse)?.mimeType else {
                self.onError(ArchivingError.invalidResponse(resource: url))
                return
            }
            
            let resource = WebArchiveResource(url: url, data: data, mimeType: mimeType)
            do {
                let newArchive = try resourceHandler(resource)
                self.onSuccess(newArchive)
            } catch {
                self.onError(error)
            }
        }
        task.resume()
    }
    
    private func onError(_ error: Error) {
        if pendingTaskCount == 0 {
            returnOnMain(result: .failure(error: error))
        } else {
            lastError = error
        }
    }
    
    private func onSuccess(_ archive: WebArchive) {
        
        guard self.pendingTaskCount == 0 else {
            return
        }
        
        if let error = lastError {
            returnOnMain(result: .failure(error: error))
            return
        }
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        do {
            let data = try encoder.encode(archive)
            returnOnMain(result: .success(plistData: data))
        } catch {
            returnOnMain(result: .failure(error: error))
        }
    }
    
    private func returnOnMain(result: ArchivingResult) {
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

public class WebArchiver {
    
    static func archive(url: URL, includeJavascript: Bool = true, completion: @escaping (ArchivingResult) -> ()) {
        
        guard let scheme = url.scheme, scheme == "https" else {
            completion(.failure(error: ArchivingError.unsupportedUrl))
            return
        }
        
        let session = ArchivingSession(completion: completion)
        
        session.load(url: url) { mainResource in
            
            var archive = WebArchive(resource: mainResource)
            
            let references = try self.extractHTMLReferences(from: mainResource, includeJavascript: includeJavascript)
            for reference in references {
                
                session.load(url: reference) { resource in
                    
                    archive.addSubresource(resource)
                    
                    if reference.pathExtension == "css" {
                        
                        let cssReferences = try self.extractCSSReferences(from: resource)
                        for cssReference in cssReferences {
                            
                            session.load(url: cssReference) { cssResource in
                                
                                archive.addSubresource(cssResource)
                                return archive
                            }
                        }
                    }
                    
                    return archive
                }
            }
            
            return archive
        }
    }
    
    private static func extractHTMLReferences(from resource: WebArchiveResource, includeJavascript: Bool) throws -> Set<URL> {
        
        guard let htmlString = String(data: resource.data, encoding: .utf8) else {
            throw ArchivingError.unsupportedEncoding
        }
        
        let doc = try HTMLDocument(string: htmlString, encoding: .utf8)
        
        var references: [String] = []
        references += doc.xpath("//img[@src]").compactMap{ $0["src"] } // images
        references += doc.xpath("//link[@rel='stylesheet'][@href]").compactMap{ $0["href"] } // css
        if includeJavascript {
            references += doc.xpath("//script[@src]").compactMap{ $0["src"] } // javascript
        }
        
        return self.absoluteUniqueUrls(references: references, resource: resource)
    }
    
    private static func extractCSSReferences(from resource: WebArchiveResource) throws -> Set<URL> {
        
        guard let cssString = String(data: resource.data, encoding: .utf8) else {
            throw ArchivingError.unsupportedEncoding
        }
        
        let regex = try NSRegularExpression(pattern: "url\\(\\'(.+?)\\'\\)", options: [])
        let fullRange = NSRange(location: 0, length: cssString.count)
        let matches = regex.matches(in: cssString, options: [], range: fullRange)
        
        let objcString = cssString as NSString
        let references = matches.map{ objcString.substring(with: $0.range(at: 1)) }
        
        return self.absoluteUniqueUrls(references: references, resource: resource)
    }
    
    private static func absoluteUniqueUrls(references: [String], resource: WebArchiveResource) -> Set<URL> {
        let absoluteReferences = references.compactMap { URL(string: $0, relativeTo: resource.url) }
        return Set(absoluteReferences)
    }
}
