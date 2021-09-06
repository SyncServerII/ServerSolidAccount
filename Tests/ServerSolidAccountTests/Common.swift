//
//  Common.swift
//  ServerSolidAccountTests
//
//  Created by Christopher G Prince on 8/21/21.
//

import XCTest
@testable import ServerSolidAccount
import SolidAuthSwiftTools
import HeliumLogger

public struct TestingFile {
    // A bit of a hack from
    // https://stackoverflow.com/questions/47177036
    // but it seems portable across command line tests and Xcode tests.
    //
    public static func directoryOfFile(_ path: String = #file) -> URL {
        let thisSourceFile = URL(fileURLWithPath: path)
        return thisSourceFile.deletingLastPathComponent()
    }
}

enum CommonError: Error {
    case noSolidCredsConfiguration
    case noSolidCreds
    case noAccessToken
}

struct ConfigFile: Codable, SolidCredsConfigurable {
    let solidCredsConfiguration: SolidCredsConfiguration?
    let codeParametersBase64: String
    let refreshToken: String
    let hostURL: URL
    let expiredAccessToken: String
}

// Bootstrapping:
// 1) Run Neebla, and sign in.
//   Copy codeParametersBase64 and hostURL into Config.json
// 2) Run AuthenticationTests.testGenerateTokens
//   Copy refresh token into Config.json

let configURL = URL(fileURLWithPath: "/root/Apps/Private/ServerSolidAccount/Config.json")

class Common: XCTestCase {
    let existingDirectory = "NewDirectory"
    let nonExistingDirectory = "NonExistingDirectory"
    let existingFile = "2CD072D2-8321-434B-9CFF-FDBE0CEFA7DA.txt"

    var solidCreds: SolidCreds!
    var expiredAccessToken: String!
    
    override func setUpWithError() throws {
        HeliumLogger.use(.debug)
        try setupSolidCreds()
    }

    func setupSolidCreds() throws {
        let configFile:ConfigFile
        let codeParameters: CodeParameters
        
        let data = try Data(contentsOf: configURL)
        configFile = try JSONDecoder().decode(ConfigFile.self, from: data)
        codeParameters = try CodeParameters.from(fromBase64: configFile.codeParametersBase64)

        guard let _ = configFile.solidCredsConfiguration else {
            throw CommonError.noSolidCredsConfiguration
        }
        
        solidCreds = SolidCreds(configuration: configFile, delegate:nil)
        solidCreds.codeParameters = codeParameters
        solidCreds.refreshToken = configFile.refreshToken
        solidCreds.hostURL = configFile.hostURL
        expiredAccessToken = configFile.expiredAccessToken
    }
    
    func refreshCreds() throws -> SolidCreds {
        var result: SolidCreds?
        var resultError: Error?
        
        guard let solidCreds = solidCreds else {
            throw CommonError.noSolidCreds
        }
        
        let exp = expectation(description: "exp")

        solidCreds.refresh { error in
            if let error = error {
                resultError = error
                exp.fulfill()
                return
            }
            
            guard solidCreds.accessToken != nil else {
                resultError = CommonError.noAccessToken
                exp.fulfill()
                return
            }
            
            result = solidCreds
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        
        if let error = resultError {
            throw error
        }
        
        guard let finalResult = result else {
            throw CommonError.noSolidCreds
        }
        
        return finalResult
    }
}
