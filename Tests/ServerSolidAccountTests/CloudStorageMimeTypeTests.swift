//
//  CloudStorageMimeTypeTests.swift
//  ServerSolidAccountTests
//
//  Created by Christopher G Prince on 8/21/21.
//

import XCTest
@testable import ServerSolidAccount
import HeliumLogger
import ServerShared
import ServerAccount

class CloudStorageMimeTypeTests: Common {
    func filePath(_ file: String) -> URL {
        let directory = TestingFile.directoryOfFile(#file)
        return directory.appendingPathComponent(file)
    }
    
    var exampleJPEG: URL { filePath("Cat.jpg") }
    var examplePNG: URL { filePath("Sake.png") }
    var exampleURLFile: URL { filePath("Website.url") }
    var exampleMOV: URL { filePath("Squidly.mov") }
    var exampleGIF: URL { filePath("Example.gif") }
    
    func loadData(from url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }

    func uploadAndDownload(mimeType: MimeType, url: URL) throws {
        try refreshCreds()
        
        let exp = expectation(description: "exp")
        
        let fileName = UUID().uuidString + "." + mimeType.fileNameExtension
        let uploadData = try loadData(from: url)
        
        let options = CloudStorageFileNameOptions(cloudFolderName: existingDirectory, mimeType: mimeType.rawValue)
        
        solidCreds.uploadFile(cloudFileName:fileName, data:uploadData, options:options) { result in
            switch result {
            case .success:
                self.solidCreds.downloadFile(cloudFileName:fileName, options:options) { result in
                    switch result {
                    case .success(data: let data, checkSum: _):
                        XCTAssert(uploadData == data)
                        
                        self.solidCreds.deleteFile(cloudFileName: fileName, options: options) { result in
                            switch result {
                            case .success:
                                break
                            default:
                                XCTFail()
                            }
                            
                            exp.fulfill()
                        }
                        
                    default:
                        XCTFail()
                        exp.fulfill()
                    }
                }
                
            default:
                XCTFail()
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageMimeTypeTests/testUploadAndDownloadJPEG
    func testUploadAndDownloadJPEG() throws {
        try uploadAndDownload(mimeType: .jpeg, url: exampleJPEG)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageMimeTypeTests/testUploadAndDownloadPNG
    func testUploadAndDownloadPNG() throws {
        try uploadAndDownload(mimeType: .png, url: examplePNG)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageMimeTypeTests/testUploadAndDownloadURL
    func testUploadAndDownloadURL() throws {
        try uploadAndDownload(mimeType: .url, url: exampleURLFile)
    }

    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageMimeTypeTests/testUploadAndDownloadMOV
    // This seems to take considerable time to upload and/or download. I had to bump up the time out to 20s. This is with https://crspybits.solidcommunity.net, NSS, v5.6.8
    func testUploadAndDownloadMOV() throws {
        try uploadAndDownload(mimeType: .mov, url: exampleMOV)
    }
    
    // swift test --enable-test-discovery --filter ServerSolidAccountTests.CloudStorageMimeTypeTests/testUploadAndDownloadGIF
    func testUploadAndDownloadGIF() throws {
        try uploadAndDownload(mimeType: .gif, url: exampleGIF)
    }
}
