import XCTest
@testable import ServerSolidAccount
import SolidAuthSwiftTools
import HeliumLogger
import LoggerAPI
import ServerShared

// Run tests (on Linux):
//  swift test --enable-test-discovery

// swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests

final class GeneralTests: Common {
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testLookupExistingDirectory
    func testLookupExistingDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testLookupNonExistingDirectory
    func testLookupNonExistingDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupDirectory(named: nonExistingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testUploadNewFile_ExistingDirectory
    func testUploadNewFile_ExistingDirectory() throws {
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

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testUploadNewFile_NewDirectory
    // Upload a file to a new directory. Make sure to remove that file and the directory afterwards, to cleanup.
    func testUploadNewFile_NewDirectory() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let mimeType: MimeType = .text
        
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let newDirectory = UUID().uuidString

        solidCreds.uploadFile(named: fileName, inDirectory: newDirectory, data:uploadData, mimeType: mimeType) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.solidCreds.deleteResource(named: fileName, inDirectory: newDirectory) { error in
                XCTAssert(error == nil)
                
                self.solidCreds.deleteResource(named: newDirectory, inDirectory: nil) { error in
                    XCTAssert(error == nil)

                    exp.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testDeleteFile
    /*
    func testDeleteFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        solidCreds.deleteResource(named: "567714D1-BEB0-4F1E-A415-0A7285EADF6C.txt", inDirectory: nil) { error in
            XCTAssert(error == nil)
            exp.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
    */
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testLookupExistingFile
    func testLookupExistingFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: existingFile, inDirectory: existingDirectory) { result in
            XCTAssert(result == .found)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testLookupNonExistingFile
    func testLookupNonExistingFile() throws {
        solidCreds = try refreshCreds()
        
        let exp = expectation(description: "exp")

        solidCreds.lookupFile(named: "FooblyWoobly.txt", inDirectory: existingDirectory) { result in
            XCTAssert(result == .notFound)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testDownloadExistingFile
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
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.GeneralTests/testDownloadNonExistentFile
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
