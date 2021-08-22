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
}

let configURL = URL(fileURLWithPath: "/root/Apps/Private/ServerSolidAccount/Config.json")

class Common: XCTestCase {
    let existingDirectory = "NewDirectory"
    let nonExistingDirectory = "NonExistingDirectory"
    let existingFile = "8D280443-F893-471F-AA40-08AC399AB2AE.txt"
    
    var solidCreds: SolidCreds!
    
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
