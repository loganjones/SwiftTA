//
//  CobDecompileTests.swift
//  TAassetsTests
//
//  Created by Logan Jones on 3/8/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import XCTest
@testable import TAassets

class CobDecompileTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStackBinaryOperatorParentheses() {
        let context = CobDecompile.DecodeContext()
        
        let value0 = CobDecompile.StackItem.constant(0)
        let value1 = CobDecompile.StackItem.constant(1)
        let value2 = CobDecompile.StackItem.constant(2)
        let value3 = CobDecompile.StackItem.constant(3)
        XCTAssertEqual(value0.expand(with: context), "0")
        
        let stackAdd2 = CobDecompile.StackItem.binaryOperator(.add, value1, value2)
        XCTAssertEqual(stackAdd2.expand(with: context), "1 + 2")
        let stackAdd3a = CobDecompile.StackItem.binaryOperator(.add, stackAdd2, value3)
        XCTAssertEqual(stackAdd3a.expand(with: context), "1 + 2 + 3")
        let stackAdd3b = CobDecompile.StackItem.binaryOperator(.add, value3, stackAdd2)
        XCTAssertEqual(stackAdd3b.expand(with: context), "3 + 1 + 2")
        
        let stackMult2 = CobDecompile.StackItem.binaryOperator(.multiply, value1, value2)
        XCTAssertEqual(stackMult2.expand(with: context), "1 * 2")
        let stackMult3 = CobDecompile.StackItem.binaryOperator(.multiply, stackMult2, value3)
        XCTAssertEqual(stackMult3.expand(with: context), "1 * 2 * 3")
        
        let stackMixed1 = CobDecompile.StackItem.binaryOperator(.multiply, stackAdd2, value2)
        XCTAssertEqual(stackMixed1.expand(with: context), "(1 + 2) * 2")
        let stackMixed2 = CobDecompile.StackItem.binaryOperator(.multiply, value3, stackAdd2)
        XCTAssertEqual(stackMixed2.expand(with: context), "3 * (1 + 2)")
        let stackMixed3 = CobDecompile.StackItem.binaryOperator(.add, stackMult2, value2)
        XCTAssertEqual(stackMixed3.expand(with: context), "1 * 2 + 2")
        let stackMixed4 = CobDecompile.StackItem.binaryOperator(.add, value3, stackMult2)
        XCTAssertEqual(stackMixed4.expand(with: context), "3 + 1 * 2")
    }
    
    func testStackUnaryOperatorParentheses() {
        let context = CobDecompile.DecodeContext()
        
        let value0 = CobDecompile.StackItem.constant(0)
        let value1 = CobDecompile.StackItem.constant(1)
        let value2 = CobDecompile.StackItem.constant(2)
        XCTAssertEqual(value0.expand(with: context), "0")
        
        let not1 = CobDecompile.StackItem.unaryOperator(.not, value1)
        XCTAssertEqual(not1.expand(with: context), "!1")
        
        let stackAdd2 = CobDecompile.StackItem.binaryOperator(.add, value1, value2)
        let notAddExpr = CobDecompile.StackItem.unaryOperator(.not, stackAdd2)
        XCTAssertEqual(notAddExpr.expand(with: context), "!(1 + 2)")
        let stackAnd2 = CobDecompile.StackItem.binaryOperator(.and, value1, value2)
        let notAndExpr = CobDecompile.StackItem.unaryOperator(.not, stackAnd2)
        XCTAssertEqual(notAndExpr.expand(with: context), "!(1 && 2)")
        
        let stackAddNot = CobDecompile.StackItem.binaryOperator(.add, value1, not1)
        XCTAssertEqual(stackAddNot.expand(with: context), "1 + !1")
        let stackAndNot = CobDecompile.StackItem.binaryOperator(.and, value1, not1)
        XCTAssertEqual(stackAndNot.expand(with: context), "1 && !1")
    }
    
}
