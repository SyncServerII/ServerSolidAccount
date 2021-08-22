import XCTest
@testable import ServerSolidAccount
import SolidAuthSwiftTools
import HeliumLogger
import LoggerAPI
import ServerShared

// Run tests (on Linux):
//  swift test --enable-test-discovery

final class GeneralTests: Common {    
    func testCreateDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let newDirectory = UUID().uuidString

        solidCreds.createDirectory(named: newDirectory) { error in
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.solidCreds.deleteResource(named: newDirectory, inDirectory: nil) { error in
                XCTAssert(error == nil)
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupExistingDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupNonExistingDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: nonExistingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testUploadTextFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let mimeType: MimeType = .text
        
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }

        solidCreds.uploadFile(named: fileName, inDirectory: existingDirectory, data:uploadData, mimeType: mimeType) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.solidCreds.deleteResource(named: fileName, inDirectory: self.existingDirectory) { error in
                XCTAssert(error == nil)
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testLookupExistingFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: existingFile, inDirectory: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testLookupNonExistingFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: "FooblyWoobly.txt", inDirectory: existingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDownloadExistingFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.downloadFile(named: existingFile, inDirectory: existingDirectory) { result in
            switch result {
            case .success:
                break
    
            case .fileNotFound:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                XCTFail()
            case .failure:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testDownloadNonExistentFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.downloadFile(named: "FooblyBloobly.txt", inDirectory: existingDirectory) { result in
            switch result {
            case .success:
                XCTFail()
    
            case .fileNotFound:
                break
                
            case .accessTokenRevokedOrExpired:
                XCTFail()
            case .failure:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
