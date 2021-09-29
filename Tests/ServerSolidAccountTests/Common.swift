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
import SolidResourcesSwift

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
    var solidCredsConfiguration: SolidCredsConfiguration?

    let serverParametersBase64: String

    let expiredAccessToken: String?
}

struct SolidCredsParams: Codable {
    let accessToken: String?
    let serverParameters: ServerParameters?

    // This is non-nil only if the refresh token changed after use in a refresh operation. If nil, use the refresh token in serverParamters.refresh
    let refreshToken: String?
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
    
    static let solidCredsParamsKey = "SolidCredsParamsKey"
    static let paramsFile = "/tmp/SolidCredsParams"

    var serverParameters: ServerParameters!
    var solidCreds: SolidCreds!
    
    var expiredAccessToken: String?
    
    var solidCredsParams: SolidCredsParams? {
        get {
            let url = URL(fileURLWithPath: Self.paramsFile)
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            
            do {
                return try JSONDecoder().decode(SolidCredsParams.self, from: data)
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

    enum SetupError: Error {
        case noStorageIRI
        case noJWK
        case noConfiguration
    }
    
    func setupSolidCreds() throws {
        let configFile:ConfigFile
        
        let data = try Data(contentsOf: configURL)
        configFile = try JSONDecoder().decode(ConfigFile.self, from: data)
        let serverParameters = try ServerParameters.from(fromBase64: configFile.serverParametersBase64)
        self.serverParameters = serverParameters
        
        solidCreds = SolidCreds(configuration: configFile, delegate:nil)
        solidCreds.serverParameters = serverParameters
        
        self.expiredAccessToken = configFile.expiredAccessToken
        
        // Use a previously generated refresh token if there is one -- because sometimes servers, e.g., ESS, update their refresh token every time it is used to refresh the access token.
        if let solidCredsParams = solidCredsParams {
            if serverParameters.refresh.refreshToken == solidCredsParams.serverParameters?.refresh.refreshToken {
                solidCreds.refreshToken = solidCredsParams.refreshToken
            }
        }
        
        if solidCreds.refreshToken == nil {
            solidCreds.refreshToken = serverParameters.refresh.refreshToken
        }
        
        guard let jwk = solidCreds.jwk else {
            throw SetupError.noJWK
        }
                
        guard let storageIRI = serverParameters.storageIRI else {
            throw SetupError.noStorageIRI
        }
        
        guard let configuration = solidCreds.configuration else {
            throw SetupError.noConfiguration
        }

        let resourceConfigurable = ResourceConfiguration(jwk: jwk, privateKey: configuration.privateKey, clientId: serverParameters.refresh.clientId, clientSecret: serverParameters.refresh.clientSecret, storageIRI: storageIRI, tokenEndpoint: serverParameters.refresh.tokenEndpoint, authenticationMethod: serverParameters.refresh.authenticationMethod, refreshDelegate: nil)
        
        solidCreds.resourceConfigurable = resourceConfigurable
    }
    
    func refreshCreds() throws {
        var resultError: Error?
        
        guard let solidCreds = solidCreds else {
            throw CommonError.noSolidCreds
        }
        
        let exp = expectation(description: "exp")

        solidCreds.refresh { [weak solidCreds, weak self] error in
            guard let credentials = solidCreds, let self = self else { return }
            if let error = error {
                resultError = error
                exp.fulfill()
                return
            }
            
            guard credentials.accessToken != nil else {
                resultError = CommonError.noAccessToken
                exp.fulfill()
                return
            }

            self.solidCredsParams = SolidCredsParams(accessToken: credentials.accessToken, serverParameters: self.serverParameters, refreshToken: credentials.refreshToken)

            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        
        if let error = resultError {
            throw error
        }
    }
}

