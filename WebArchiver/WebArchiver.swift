//
//  WebArchiver.swift
//  OfflineWebView
//
//  Created by Ernesto Elsäßer on 11.11.18.
//  Copyright © 2018 Ernesto Elsäßer. All rights reserved.
//

import Foundation
import Fuzi

public struct ArchivingResult {
    public let plistData: Data?
    public let errors: [Error]
}

public enum ArchivingError: LocalizedError {
    case unsupportedUrl
    case requestFailed(resource: URL, error: Error)
    case invalidResponse(resource: URL)
    case unsupportedEncoding
    case invalidReferenceUrl(string: String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedUrl: return "Unsupported URL"
        case .requestFailed(let res, _): return "Failed to load " + res.absoluteString
        case .invalidResponse(let res): return "Invalid response for " + res.absoluteString
        case .unsupportedEncoding: return "Unsupported encoding"
        case .invalidReferenceUrl(let string): return "Invalid reference URL: " + string
        }
    }
}

public class WebArchiver {
    
    public static func archive(url: URL, includeJavascript: Bool = true, skipCache: Bool = false, completion: @escaping (ArchivingResult) -> ()) {
        
        guard let scheme = url.scheme, scheme == "https" else {
            let result = ArchivingResult(plistData: nil, errors: [ArchivingError.unsupportedUrl])
            completion(result)
            return
        }
        
        let cachePolicy: URLRequest.CachePolicy = skipCache ? .reloadIgnoringLocalAndRemoteCacheData : .returnCacheDataElseLoad
        let session = ArchivingSession(cachePolicy: cachePolicy, completion: completion)
        
        session.load(url: url, fallback: nil) { mainResource in
            
            var archive = WebArchive(resource: mainResource)
            
            let references = try self.extractHTMLReferences(from: mainResource, includeJavascript: includeJavascript)
            for reference in references {
                
                session.load(url: reference, fallback: archive) { resource in
                    
                    archive.addSubresource(resource)
                    
                    if reference.pathExtension == "css" {
                        
                        let cssReferences = try self.extractCSSReferences(from: resource)
                        for cssReference in cssReferences {
                            
                            session.load(url: cssReference, fallback: archive) { cssResource in
                                
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

private class ArchivingSession {
    
    static var encoder: PropertyListEncoder = {
        let plistEncoder = PropertyListEncoder()
        plistEncoder.outputFormat = .binary
        return plistEncoder
    }()
    
    private let urlSession: URLSession
    private let completion: (ArchivingResult) -> ()
    private let cachePolicy: URLRequest.CachePolicy
    private var errors: [Error] = []
    private var pendingTaskCount: Int = 0 // TODO: use urlSession.delegateQueue.operationCount?
    
    init(cachePolicy: URLRequest.CachePolicy, completion: @escaping (ArchivingResult) -> ()) {
        let sessionQueue = OperationQueue()
        sessionQueue.maxConcurrentOperationCount = 1
        sessionQueue.name = "WebArchiverWorkQueue"
        self.urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: sessionQueue)
        self.cachePolicy = cachePolicy
        self.completion = completion
    }
    
    func load(url: URL, fallback: WebArchive?, expand: @escaping (WebArchiveResource) throws -> WebArchive ) {
        pendingTaskCount = pendingTaskCount + 1
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            self.pendingTaskCount = self.pendingTaskCount - 1
            
            var archive = fallback
            if let error = error {
                self.errors.append(ArchivingError.requestFailed(resource: url, error: error))
            } else if let data = data, let mimeType = (response as? HTTPURLResponse)?.mimeType {
                let resource = WebArchiveResource(url: url, data: data, mimeType: mimeType)
                do {
                    archive = try expand(resource)
                } catch {
                    self.errors.append(error)
                }
            } else {
                self.errors.append(ArchivingError.invalidResponse(resource: url))
            }
            
            self.finish(with: archive)
        }
        task.resume()
    }
    
    private func finish(with archive: WebArchive?) {
        
        guard self.pendingTaskCount == 0 else {
            return
        }
        
        var plistData: Data?
        if let archive = archive {
            do {
                plistData = try ArchivingSession.encoder.encode(archive)
            } catch {
                errors.append(error)
            }
        }
        
        let result = ArchivingResult(plistData: plistData, errors: errors)
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}
