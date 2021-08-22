import XCTest
@testable import ServerSolidAccount
import SolidAuthSwiftTools
import HeliumLogger
import LoggerAPI
import ServerShared

// Run tests (on Linux):
//  swift test --enable-test-discovery

// NOTE: I don't run all of these tests together in an automatic manner. I run them each manually.

struct ConfigFile: Codable, SolidCredsConfigurable {
    let solidCredsConfiguration: SolidCredsConfiguration?
    let codeParametersBase64: String
    let refreshToken: String
    let hostURL: URL
}

final class ServerSolidAccountTests: XCTestCase {
    let configURL = URL(fileURLWithPath: "/root/Apps/Private/ServerSolidAccount/Config.json")
    var solidCreds: SolidCreds!
    
    override func setUp() {
        super.setUp()
        
        HeliumLogger.use(.debug)

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
        solidCreds.hostURL = configFile.hostURL
    }
    
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
    func testRefresh() {
        XCTAssert(refreshCreds() != nil)
    }
    
    func testStub() {
    }
    
    func testCreateDirectory() {        
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.createDirectory(named: "NewDirectory") { error in
            XCTAssert(error == nil)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupExistingDirectory() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: "NewDirectory") { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupNonExistingDirectory() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: "NonExistingDirectory") { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testUploadTextFile() {
         guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")
        
        let mimeType: MimeType = .text
        
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }

        solidCreds.uploadFile(named: fileName, inDirectory: "NewDirectory", data:uploadData, mimeType: mimeType) { error in
            XCTAssert(error == nil)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testLookupExistingFile() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: "8D280443-F893-471F-AA40-08AC399AB2AE.txt", inDirectory: "NewDirectory") { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupNonExistingFile() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: "FooblyWoobly.txt", inDirectory: "NewDirectory") { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDeleteFile() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.deleteFile(named: "CE88BDD5-BD6F-495D-956A-CFA61C8C7A37.txt", inDirectory: "NewDirectory") { error in
            XCTAssert(error == nil)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDownloadExistingFile() {
        guard let solidCreds = refreshCreds() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.downloadFile(named: "8D280443-F893-471F-AA40-08AC399AB2AE.txt", inDirectory: "NewDirectory") { result in
            switch result {
            case .success(let data, let checkSum):
                break
    
            case .fileNotFound:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                XCTFail()
            case .failure(let error):
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDownloadNonExistentFile() {
    }

    // MARK: Utilities
    func refreshCreds() -> SolidCreds? {
        var result: SolidCreds?
        
        guard let solidCreds = solidCreds else {
            XCTFail()
            return nil
        }
        
        let exp = expectation(description: "exp")

        solidCreds.refresh { error in
            if let error = error {
                XCTFail("\(error)")
                exp.fulfill()
                return
            }
            
            guard solidCreds.accessToken != nil else {
                XCTFail()
                return
            }
            
            result = solidCreds
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        
        return result
    }
}
