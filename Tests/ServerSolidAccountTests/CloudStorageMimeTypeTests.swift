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
        solidCreds = try refreshCreds()
        
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
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testUploadAndDownloadJPEG() throws {
        try uploadAndDownload(mimeType: .jpeg, url: exampleJPEG)
    }
    
    func testUploadAndDownloadPNG() throws {
        try uploadAndDownload(mimeType: .png, url: examplePNG)
    }
    
    func testUploadAndDownloadURL() throws {
        try uploadAndDownload(mimeType: .url, url: exampleURLFile)
    }
    
    func testUploadAndDownloadMOV() throws {
        try uploadAndDownload(mimeType: .mov, url: exampleMOV)
    }
    
    func testUploadAndDownloadGIF() throws {
        try uploadAndDownload(mimeType: .gif, url: exampleGIF)
    }
}
