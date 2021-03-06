//
//  CloudStorageTests.swift
//  ServerSolidAccountTests
//
//  Created by Christopher G Prince on 8/21/21.
//

import XCTest
@testable import ServerSolidAccount
import HeliumLogger
import ServerShared
import ServerAccount
import LoggerAPI

// swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests

class CloudStorageTests: Common {
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testUploadFile_NewDirectory
    func testUploadFile_NewDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let newDirectory = UUID().uuidString
        
        let mimeType: MimeType = .text
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let options = CloudStorageFileNameOptions(cloudFolderName:newDirectory, mimeType: mimeType.rawValue)
        
        solidCreds.uploadFile(cloudFileName:fileName, data:uploadData, options:options) { result in
        
            switch result {
            case .success:
                self.solidCreds.deleteResource(named: fileName, inDirectory: newDirectory) { error in
                    guard error == nil else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                    
                    self.solidCreds.deleteResource(named: newDirectory, inDirectory: nil) { error in
                        guard error == nil else {
                            XCTFail()
                            exp.fulfill()
                            return
                        }
                        
                        exp.fulfill()
                    }
                }
                
            default:
                XCTFail()
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testUploadFile_NewFile_ExistingDirectory
    func testUploadFile_NewFile_ExistingDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
                
        let mimeType: MimeType = .text
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)
        
        solidCreds.uploadFile(cloudFileName:fileName, data:uploadData, options:options) { result in
        
            switch result {
            case .success:
                self.solidCreds.deleteResource(named: fileName, inDirectory: self.existingDirectory) { error in
                    guard error == nil else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                        
                    exp.fulfill()
                }
                
            default:
                XCTFail()
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testUploadFile_ExistingFile_ExistingDirectory
    func testUploadFile_ExistingFile_ExistingDirectory() throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
                
        let mimeType: MimeType = .text
        let fileName = existingFile
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)
        
        solidCreds.uploadFile(cloudFileName:fileName, data:uploadData, options:options) { result in
        
            switch result {
            case .success:
                XCTFail()
                
            case .failure(let error):
                guard let error = error as? CloudStorageError else {
                    XCTFail()
                    exp.fulfill()
                    return
                }
                
                XCTAssert(error == .alreadyUploaded)
                
                exp.fulfill()

            default:
                XCTFail()
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testDownloadFile_FileExists
    func testDownloadFile_FileExists() throws {
        try refreshCreds()

        let mimeType: MimeType = .text
        let fileName = existingFile
        
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)

        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "exp")

        solidCreds.downloadFile(cloudFileName:fileName, options:options) { result in
            switch result {
            case .success(data: let data, checkSum: _):
                XCTAssert(uploadData == data)
                
            default:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testDownloadFile_FileDoesNotExist
    func testDownloadFile_FileDoesNotExist() throws {
        try refreshCreds()

        let mimeType: MimeType = .text
        
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)
        
        let exp = expectation(description: "exp")
        
        solidCreds.downloadFile(cloudFileName:"FooblyWoobly.txt", options:options) { result in
            switch result {
            case .success:
                XCTFail()
                
            default:
                break
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testDeleteFile_FileExists
    func testDeleteFile_FileExists() throws {
        try refreshCreds()

        let exp = expectation(description: "exp")
        
        let mimeType: MimeType = .text
        
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)
        
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        
        guard let uploadData = "Hello, World!".data(using: .utf8) else {
            XCTFail()
            return
        }

        solidCreds.uploadFile(named: fileName, inDirectory: existingDirectory, data:uploadData, mimeType: mimeType.rawValue) { error in
            
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            self.solidCreds.deleteFile(cloudFileName:fileName, options:options) { result in
                switch result {
                case .success:
                    break
                default:
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testDeleteFile_FileDoesNotExist
    func testDeleteFile_FileDoesNotExist() throws {
        try refreshCreds()

        let mimeType: MimeType = .text
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)

        let exp = expectation(description: "exp")

        self.solidCreds.deleteFile(cloudFileName: "FooblyWoobly.txt", options:options) { result in
            switch result {
            case .success:
                XCTFail()
            default:
                break
            }

            exp.fulfill()
        }
            
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testLookupFile_FileExists
    func testLookupFile_FileExists() throws {
        try refreshCreds()

        let mimeType: MimeType = .text
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)

        let exp = expectation(description: "exp")
        
        self.solidCreds.lookupFile(cloudFileName: existingFile, options:options) { result in
            switch result {
            case .success(let found):
                XCTAssert(found)
            default:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageTests/testLookupFile_FileDoesNotExist
    func testLookupFile_FileDoesNotExist() throws {
        try refreshCreds()

        let mimeType: MimeType = .text
        let options = CloudStorageFileNameOptions(cloudFolderName:existingDirectory, mimeType: mimeType.rawValue)

        let exp = expectation(description: "exp")
        
        self.solidCreds.lookupFile(cloudFileName: "FooblyWoobly.txt", options: options) { result in
            switch result {
            case .success(let found):
                XCTAssert(!found)
            default:
                XCTFail()
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
