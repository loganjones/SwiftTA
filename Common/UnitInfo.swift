//
//  UnitInfo.swift
//  TAassets
//
//  Created by Logan Jones on 5/7/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitInfo {
    var name: String = ""
    var side: String = ""
    var object: String = ""
    
    var title: String = ""
    var description: String = ""
    
    var categories: Set<String> = []
    var tedClass: String = ""
}

extension UnitInfo {
    
    init(contentsOf file: FileSystem.FileHandle) {
        UnitInfo.processFbi(file) { field, value in
            switch field {
            case "UnitName":
                name = value
            case "Side":
                side = value
            case "Objectname":
                object = value
            case "Name":
                title = value
            case "Description":
                description = value
            case "Category":
                categories = Set(value.components(separatedBy: " "))
            case "TEDClass":
                tedClass = value
            default:
                () // Unhandled field
            }
        }
    }
    
    static func processFbi(_ file: FileSystem.FileHandle, item: (String, String) -> Void) {
        
        let data = file.readDataToEndOfFile()
        
        guard let contents = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8)
            else { return }
        
        let scanner = Scanner(string: contents)
        //scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "\r\n\t=;{}")
        
        scanner.scanUpTo("[UNITINFO]", into: nil)
        scanner.scanUpTo("{", into: nil)
        
        while !scanner.isAtEnd {
            var field: NSString?
            var value: NSString?
            scanner.scanUpTo("=", into: &field)
            scanner.scanUpTo(";", into: &value)
            
            if let field = field, let value = value {
                item(field as String, value as String)
            }
        }
        
    }
    
}
