//
//  TdfParseTests.swift
//  TAassetsTests
//
//  Created by Logan Jones on 3/21/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import XCTest
@testable import TAassets

class TdfParseTests: XCTestCase {
    
    func testRawParsePerformance() throws {
        guard let data1 = TdfSample1.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        guard let data2 = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        var dict1: [String: String] = [:]
        var dict2: [String: String] = [:]
        measure {
//            Tdf.parse(data) { e in
//                guard case let .keyValue(_, key, value) = e else { return }
//                dict[key] = value
//            }
            TdfParser.parse(data1) { token in
                guard case let .property(key, value) = token else { return }
                dict1[key] = value
            }
            TdfParser.parse(data2) { token in
                guard case let .property(key, value) = token else { return }
                dict2[key] = value
            }
        }
        XCTAssertEqual(dict1, TdfSample1FlatDict)
        XCTAssertEqual(dict2, TdfSample2FlatDict)
    }
    
    func testNextTokenPerformance() throws {
        guard let data1 = TdfSample1.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        guard let data2 = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        var dict1: [String: String] = [:]
        var dict2: [String: String] = [:]
        measure {
            
            let parser1 = TdfParser(data1)
            while let token = parser1.nextToken() {
                guard case let .property(key, value) = token else { continue }
                dict1[key] = value
            }
            
            let parser2 = TdfParser(data2)
            while let token = parser2.nextToken() {
                guard case let .property(key, value) = token else { continue }
                dict2[key] = value
            }
            
        }
        XCTAssertEqual(dict1, TdfSample1FlatDict)
        XCTAssertEqual(dict2, TdfSample2FlatDict)
    }
    
    func testReadToNextToken() throws {
        guard let data = TdfSample1.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        
        let parser = TdfParser(data)
        XCTAssertEqual(parser.depth, 0)
        XCTAssertToken(parser.nextToken(), .objectBegin("SIMPLE"))
        XCTAssertEqual(parser.depth, 1)
        XCTAssertToken(parser.nextToken(), .property("field1","value"))
        XCTAssertToken(parser.nextToken(), .property("field2","other"))
        XCTAssertToken(parser.nextToken(), .objectBegin("DIVERSION"))
        XCTAssertEqual(parser.depth, 2)
        XCTAssertToken(parser.nextToken(), .property("field2","value"))
        XCTAssertToken(parser.nextToken(), .objectEnd("DIVERSION"))
        XCTAssertEqual(parser.depth, 1)
        XCTAssertToken(parser.nextToken(), .objectEnd("SIMPLE"))
        XCTAssertEqual(parser.depth, 0)
        XCTAssertNil(parser.nextToken())
    }
    
    func testSkipToSection() throws {
        guard let data = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        let parser = TdfParser(data)
        XCTAssertTrue(parser.skipToObject(named: "TOP2"))
        XCTAssertEqual(parser.depth, 1)
        XCTAssertToken(parser.nextToken(), .property("field1","123"))
        parser.skipObject()
        XCTAssertEqual(parser.depth, 0)
        XCTAssertToken(parser.nextToken(), .objectBegin("TOP3"))
    }
    
    func testIterateSections() throws {
        guard let data = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        let parser = TdfParser(data)
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP1")
        XCTAssertEqual(parser.depth, 1)
        XCTAssertToken(parser.nextToken(), .property("field1","value"))
        parser.skipObject()
        XCTAssertEqual(parser.depth, 0)
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP2")
        XCTAssertToken(parser.nextToken(), .property("field1","123"))
        parser.skipObject()
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP3")
        XCTAssertToken(parser.nextToken(), .property("field1","value"))
        parser.skipObject()
        
        XCTAssertNil(parser.skipToNextObject())
    }
    
    func testParseSectionKeyValuesOnly() throws {
        guard let data = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        let parser = TdfParser(data)
        XCTAssertTrue(parser.skipToObject(named: "TOP2"))
        XCTAssertEqual(parser.depth, 1)
        
        var dict: [String: String] = [:]
        parser.forEachProperty() { (key, value) in
            dict[key] = value
        }
        XCTAssertEqual(dict["field1"], "123")
        XCTAssertEqual(dict["field2"], "sssddd")
        XCTAssertEqual(dict["field3"], "value")
        XCTAssertEqual(dict["field0"], "other2")
        XCTAssertNil(dict["fielda"])
    }
    
    func testExtractAll() throws {
        guard let data = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        let dict = TdfParser.extractAll(from: data)

        XCTAssertEqual(dict.count, 3)
        XCTAssertNotNil(dict["TOP1"])
        XCTAssertNotNil(dict["TOP2"])
        XCTAssertNotNil(dict["TOP3"])
        XCTAssertNil(dict["TOP4"])
        
        XCTAssertEqual(dict["TOP2"]?.count, 11)
        XCTAssertEqual(dict["TOP2"]?.properties.count, 10)
        XCTAssertEqual(dict["TOP2"]?.subobjects.count, 1)
        
        XCTAssertEqual(dict["TOP1"]?["field1"], "value")
        XCTAssertEqual(dict["TOP1"]?["field7"], "value")
        XCTAssertNotNil(dict["TOP1"]?[object: "DIVERSION"])
        XCTAssertEqual(dict["TOP1"]?[object: "DIVERSION"]?["fieldf"], "value")
        
        XCTAssertEqual(dict["TOP2"]?["field2"], "sssddd")
        XCTAssertEqual(dict["TOP2"]?[object: "DIVERSION"]?["fieldb"], "5813")
    }
    
    func testExtractObject() throws {
        guard let data = TdfSample2.data(using: .utf8) else { throw TdfTestError.failedToCreateSampleData }
        let parser = TdfParser(data)
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP1")
        let top1 = parser.extractObject()
        XCTAssertEqual(top1.count, 11)
        XCTAssertEqual(top1.properties.count, 10)
        XCTAssertEqual(top1.subobjects.count, 1)
        XCTAssertEqual(parser.depth, 0)
        XCTAssertEqual(top1["field1"], "value")
        XCTAssertEqual(top1["field7"], "value")
        XCTAssertNotNil(top1[object: "DIVERSION"])
        XCTAssertEqual(top1[object: "DIVERSION"]?["fieldf"], "value")
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP2")
        let top2 = parser.extractObject()
        XCTAssertEqual(top2["field2"], "sssddd")
        XCTAssertEqual(top2[object: "DIVERSION"]?["fieldb"], "5813")
        
        XCTAssertEqual(parser.skipToNextObject(), "TOP3")
        parser.skipObject()
        
        XCTAssertNil(parser.nextToken())
    }

}

extension TdfParseTests {
    
    func XCTAssertToken(_ token: TdfParser.Token?, _ match: TdfParser.Token) {
        guard let token = token else {
            XCTFail("Token was nil")
            return
        }
        XCTAssertEqual(token, match)
    }
    
}

private let TdfSample1 = """
[SIMPLE] {
    field1=value;
    field2=other;
    [DIVERSION] {
        field2=value;
    }
}
"""

private let TdfSample1FlatDict = ["field1": "value", "field2": "value"]

private let TdfSample2 = """

[TOP1] {
    field1=value;
    field2=other;
    field3=value;
    field4=other;
    field5=value;
    field6=other;
    field7=value;
    field8=other;
    field9=value;
    [DIVERSION] {
        fielda=value;
        fieldb=value;
        fieldc=value;
        fieldd=value;
        fielde=value;
        fieldf=value;
        fieldg=value;
        fieldh=value;
        fieldi=value;
        fieldj=value;
    }
    field0=other;
}

[TOP2] {
    field1=123;
    field2=sssddd;
    field3=value;
    field4=other;
    field5=value;
    field6=other;
    field7=value;
    field8=other;
    field9=value;
    [DIVERSION] {
        fielda=1123;
        fieldb=5813;
        fieldc=value;
        fieldd=value;
        fielde=value;
        fieldf=value;
        fieldg=value;
        fieldh=value;
        fieldi=value;
        fieldj=value;
    }
    field0=other2;
}

[TOP3] {
    field1=value;
    field2=other;
    field3=value;
    field4=other;
    field5=value;
    field6=other;
    field7=value;
    field8=other;
    field9=value;
    [DIVERSION] {
        fielda=value;
        fieldb=value;
        fieldc=value;
        fieldd=value;
        fielde=value;
        fieldf=value;
        fieldg=value;
        fieldh=value;
        fieldi=value;
        fieldj=value;
    }
    field0=other3;
}

"""

private let TdfSample2FlatDict: [String: String] = [
    "field1": "value",
    "field2": "other",
    "field3": "value",
    "field4": "other",
    "field5": "value",
    "field6": "other",
    "field7": "value",
    "field8": "other",
    "field9": "value",
    "fielda": "value",
    "fieldb": "value",
    "fieldc": "value",
    "fieldd": "value",
    "fielde": "value",
    "fieldf": "value",
    "fieldg": "value",
    "fieldh": "value",
    "fieldi": "value",
    "fieldj": "value",
    "field0": "other3",
]

private enum TdfTestError: Error {
    case failedToCreateSampleData
    case unexpectedParseEvent(TdfParser.Token)
}
