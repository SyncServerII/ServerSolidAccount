//
//  AuthenticationTests.swift
//  ServerSolidAccountTests
//
//  Created by Christopher G Prince on 8/21/21.
//

import XCTest
@testable import ServerSolidAccount
import HeliumLogger

class AuthenticationTests: Common {    
    // To test this, you need recent (unused?) codeParametersBase64. I think this invalidates the current refresh token.
    func testGenerateTokens() {
        guard let solidCreds = solidCreds else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.generateTokens { error in
            if let error = error {
                XCTFail("\(error)")
                exp.fulfill()
                return
            }
            
            XCTAssert(solidCreds.refreshToken != nil)
            XCTAssert(solidCreds.accessToken != nil)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    /* 8/19/21: I just got this:
        String: Optional("{\"error\":\"invalid_grant\",\"error_description\":\"Refresh token not found\"}")
        /root/Apps/ServerSolidAccount/Tests/ServerSolidAccountTests/ServerSolidAccountTests.swift:77: error: ServerSolidAccountTests.testRefresh : failed - badStatusCode(400)
        
        I'm not sure of the conditions under which a refresh token is not found.
        
        My hypothesis is currently that you have to use the most recent refresh token that was generated from the `code` (this in the `codeParametersBase64`). It turns out that you can use the code multiple times and each time it seems to generate a new refresh token.
    */
    func testRefresh() throws {
        _ = try refreshCreds()
    }
}
