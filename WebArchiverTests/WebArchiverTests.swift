//
//  WebArchiverTests.swift
//  WebArchiverTests
//
//  Created by Ernesto Elsäßer on 29.01.19.
//  Copyright © 2019 Ernesto Elsäßer. All rights reserved.
//

import XCTest
@testable import WebArchiver

class WebArchiverTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testArchiving() {
        
        let url = URL(string: "https://nshipster.com/wkwebview/")!
        let expectation = self.expectation(description: "Archiving job finishes")
        
        WebArchiver.archive(url: url) { result in
            
            expectation.fulfill()
            
            guard let data = result.plistData else {
                XCTFail("No data returned!")
                return
            }
            
            XCTAssertTrue(data.count > 0)
            XCTAssertTrue(result.errors.isEmpty)
        }
        
        waitForExpectations(timeout: 60, handler: nil)
    }
}


