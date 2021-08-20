import XCTest
@testable import ServerSolidAccount
import SolidAuthSwiftTools

// Run tests (on Linux):
//  swift test --enable-test-discovery

struct ConfigFile: Codable, SolidCredsConfigurable {
    let solidCredsConfiguration: SolidCredsConfiguration?
    let codeParametersBase64: String
    let refreshToken: String
}

final class ServerSolidAccountTests: XCTestCase {
    let configURL = URL(fileURLWithPath: "/root/Apps/Private/ServerSolidAccount/Config.json")
    var solidCreds: SolidCreds!
    
    override func setUp() {
        super.setUp()
        
        let configFile:ConfigFile
        let codeParameters: CodeParameters
        
        do {
            let data = try Data(contentsOf: configURL)
            configFile = try JSONDecoder().decode(ConfigFile.self, from: data)
            codeParameters = try CodeParameters.from(fromBase64: configFile.codeParametersBase64)
        } catch {
            XCTFail()
            return
        }
        
        guard let _ = configFile.solidCredsConfiguration else {
            XCTFail()
            return
        }
        
        solidCreds = SolidCreds(configuration: configFile, delegate:nil)
        solidCreds.codeParameters = codeParameters
        solidCreds.refreshToken = configFile.refreshToken
    }
    
    // To test this, you need recent (unused?) codeParametersBase64
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
    func testRefresh() {
        guard let solidCreds = solidCreds else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.refresh { error in
            if let error = error {
                XCTFail("\(error)")
                exp.fulfill()
                return
            }
            
            XCTAssert(solidCreds.accessToken != nil)
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
