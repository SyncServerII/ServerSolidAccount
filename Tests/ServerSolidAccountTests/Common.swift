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
import LoggerAPI

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
    let serverParametersBase64: String
    let expiredAccessToken: String
}

// Bootstrapping:
// 1) Run Neebla, and sign in.
//   Copy serverParametersBase64 into Config.json
// 2) Run AuthenticationTests.testGenerateTokens
//   Copy refresh token into Config.json

let configURL = URL(fileURLWithPath: "/root/Apps/Private/ServerSolidAccount/Config.json")

class Common: XCTestCase {
    let existingDirectory = "NewDirectory"
    let nonExistingDirectory = "NonExistingDirectory"
    let existingFile = "2CD072D2-8321-434B-9CFF-FDBE0CEFA7DA.txt"

    var solidCreds: SolidCreds!
    var expiredAccessToken: String!
    
    static let solidCredsParamsKey = "SolidCredsParamsKey"
    static let paramsFile = "/tmp/SolidCredsParams"
    
    var solidCredsParams: SolidCreds.SolidCredsParams? {
        get {
            let url = URL(fileURLWithPath: Self.paramsFile)
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            
            do {
                return try JSONDecoder().decode(SolidCreds.SolidCredsParams.self, from: data)
            } catch let error {
                Log.error("Could not decode SolidCredsParams: \(error)")
                return nil
            }
        }
        
        set {
            guard let newValue = newValue else {
                UserDefaults.standard.set(nil, forKey: Self.solidCredsParamsKey)
                return
            }
            
            do {
                let data = try JSONEncoder().encode(newValue)
                let url = URL(fileURLWithPath: Self.paramsFile)
                try data.write(to: url)
            } catch let error {
                Log.error("Failed encoding SolidCredsParams: \(error)")
                return
            }
        }
    }
    
    override func setUpWithError() throws {
        HeliumLogger.use(.debug)
        try setupSolidCreds()
    }

    func setupSolidCreds() throws {
        let serverParameters: ServerParameters
        let configFile:ConfigFile
        
        let data = try Data(contentsOf: configURL)
        configFile = try JSONDecoder().decode(ConfigFile.self, from: data)
        serverParameters = try ServerParameters.from(fromBase64: configFile.serverParametersBase64)

        guard let _ = configFile.solidCredsConfiguration else {
            throw CommonError.noSolidCredsConfiguration
        }
        
        solidCreds = SolidCreds(configuration: configFile, delegate:nil)
        solidCreds.serverParameters = serverParameters
        expiredAccessToken = configFile.expiredAccessToken
        
        if let solidCredsParams = solidCredsParams {
            if serverParameters.refresh.refreshToken == solidCredsParams.serverParameters?.refresh.refreshToken {
                solidCreds.refreshToken = solidCredsParams.refreshToken
            }
        }
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

            self.solidCredsParams = SolidCreds.SolidCredsParams(accessToken: solidCreds.accessToken, serverParameters: solidCreds.serverParameters, accountId: solidCreds.accountId, refreshToken: solidCreds.refreshToken)
            
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
