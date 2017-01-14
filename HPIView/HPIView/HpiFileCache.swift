//
//  HpiFileCache.swift
//  HPIView
//
//  Created by Logan Jones on 12/31/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation


class HpiFileCache {
    
    let hpiURL: URL
    let containerURL: URL
    
    init(hpiURL: URL) throws {
        self.hpiURL = hpiURL
        let fm = FileManager.default
        
        let sourceDate: Date
        do {
            let attributes = try fm.attributesOfItem(atPath: hpiURL.path)
            if let date = attributes[.modificationDate] as? Date {
                sourceDate = date
            }
            else {
                sourceDate = Date()
            }
        }
        catch {
            throw InitError.failedToReadFromHpi(error)
        }
        
        let archiveIdentifier = String(format: "%08X", hpiURL.hashValue)
        
        guard let cachesURL = try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { throw InitError.badCachesURL }
        
        guard let bundleIdentifier = Bundle.main.bundleIdentifier
            else { throw InitError.badBundleIdentifier }
        
        let containerURL = cachesURL
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent(archiveIdentifier, isDirectory: true)
        
        print("Cache container for \(hpiURL.lastPathComponent): \(containerURL)")
        
        let containerDate: Date
        do {
            let attributes = try fm.attributesOfItem(atPath: containerURL.path)
            if let date = attributes[.modificationDate] as? Date {
                containerDate = date
            }
            else {
                containerDate = Date.distantPast
            }
        }
        catch {
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSFileReadNoSuchFileError {
                try HpiFileCache.makeContainer(containerURL)
                containerDate = Date()
            }
            else {
                throw InitError.failedToReadFromContainer(error)
            }
        }
        
        if containerDate < sourceDate {
            try fm.removeItem(at: containerURL)
            try HpiFileCache.makeContainer(containerURL)
        }
        
        self.containerURL = containerURL
    }
    
    enum InitError: Error {
        case failedToReadFromHpi(Error)
        case badBundleIdentifier
        case badCachesURL
        case failedToReadFromContainer(Error)
    }
    
    func url(for file: HpiItem.File, atHpiPath hpiPath: String) throws -> URL {
        
        let fileURL = containerURL.appendingPathComponent(hpiPath, isDirectory: false)
        let fm = FileManager.default
        
        if let attributes = try? fm.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? Int {
            
            if size == file.size {
                return fileURL
            }
            else {
                try fm.removeItem(at: fileURL)
            }
        }
        
        let fileDirectoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: fileDirectoryURL, withIntermediateDirectories: true)
        
        let data = try HpiItem.extract(file: file, fromHPI: hpiURL)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }
    
    private static func makeContainer(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
}
