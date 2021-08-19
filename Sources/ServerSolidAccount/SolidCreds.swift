//
//  SolidCreds.swift
//  Server
//
//  Created by Christopher Prince on 7/31/21.
//
//

import Foundation
import Credentials
import KituraNet
import ServerShared
import Kitura
import LoggerAPI
import ServerAccount
import SolidAuthSwiftTools

// Credentials basis for making Solid Pod endpoint calls.

public class SolidCredsConfiguration: Codable {
    public var publicKey: String
    public var privateKey: String

    // This is the public PEM key converted to a JWK. See DPoP.swift comments in SolidAuthSwift.
    public var jwk: String
}

public protocol SolidCredsConfigurable {
    var solidCredsConfiguration: SolidCredsConfiguration? { get }
}

public class SolidCreds : Account {
    enum SolidCredsError: Swift.Error {
        case noCodeParameters
        case failedTokenRequest
        case noSelf
        case errorSavingCredsToDatabase
        case failedCreatingRefreshParameters
        case noJWK
        case noConfiguration
        case noAccessToken
        case noRefreshToken
    }
    
    private var tokenRequest:TokenRequest<JWK_RSA>!
    private var jwk: JWK_RSA!
    
    // The following keys are for conversion <-> JSON (e.g., to store this into a database).

    struct JsonCoding: Codable {
        let accessToken: String?
        let refreshToken:String?
        let codeParameters: CodeParameters?
    }
    
    public var accessToken: String!
    var refreshToken: String!
    var codeParameters: CodeParameters!
        
    public var owningAccountsNeedCloudFolderName: Bool {
        return true
    }
    
    public static var accountScheme:AccountScheme {
        return .solid
    }
    
    public var accountScheme:AccountScheme {
        return SolidCreds.accountScheme
    }

    weak var delegate:AccountDelegate?
    public var accountCreationUser:AccountCreationUser?
    
    private var configuration: SolidCredsConfiguration!

    required public init?(configuration: Any? = nil, delegate:AccountDelegate?) {
        self.delegate = delegate
        guard let configuration = configuration as? SolidCredsConfigurable else {
            return nil
        }
        self.configuration = configuration.solidCredsConfiguration
        
        do {
            jwk = try JSONDecoder().decode(JWK_RSA.self, from: Data(self.configuration.jwk.utf8))
        } catch let error {
            Log.error("Could not decode JWK: \(error)")
            return nil
        }
    }
    
    static let codeParametersKey = "codeParameters"
    
    public static func getProperties(fromHeaders headers:AccountHeaders) -> [String: Any] {
        var result = [String: Any]()
        
        guard let base64CodeParametersString = headers[ServerConstants.HTTPAccountDetailsKey] else {
            return [:]
        }
        
        let codeParameters: CodeParameters
        
        do {
            codeParameters = try CodeParameters.from(fromBase64: base64CodeParametersString)
        } catch let error {
            Log.error("getProperties: failed: \(error)")
            return [:]
        }
        
        result[Self.codeParametersKey] = codeParameters
        
        return result
    }
    
    public static func fromProperties(_ properties: AccountProperties, user:AccountCreationUser?, configuration: Any?, delegate:AccountDelegate?) -> Account? {
        guard let creds = SolidCreds(configuration: configuration, delegate: delegate) else {
            return nil
        }
        
        guard let codeParameters = properties.properties[Self.codeParametersKey] as? CodeParameters else {
            Log.error("Could not get CodeParameters")
            return nil
        }
        
        creds.accountCreationUser = user
        creds.codeParameters = codeParameters

        return creds
    }
    
    public static func fromJSON(_ json:String, user:AccountCreationUser, configuration: Any?, delegate:AccountDelegate?) throws -> Account? {
    
        guard let jsonData = json.data(using: .utf8) else {
            return nil
        }
    
        let jsonCoding:JsonCoding
        
        do {
            jsonCoding = try JSONDecoder().decode(JsonCoding.self, from: jsonData)
        } catch let error {
            Log.error("Could not decode JsonCoding: \(error)")
            return nil
        }
        
        guard let result = SolidCreds(configuration: configuration, delegate: delegate) else {
            return nil
        }
        
        result.accountCreationUser = user
        
        // Only owning users have access token's in creds. Sharing users have empty creds stored in the database.
        
        switch user {
        case .user(let user) where AccountScheme(.accountName(user.accountType))?.userType == .owning:
            fallthrough
        case .userId:
            result.accessToken = jsonCoding.accessToken
            
        default:
            // Sharing users not allowed.
            assert(false)
        }
        
        result.codeParameters = jsonCoding.codeParameters
        result.refreshToken = jsonCoding.refreshToken
        result.accessToken = jsonCoding.accessToken
        
        return result
    }
    
    public func toJSON() -> String? {
        let jsonCoding = JsonCoding(accessToken: accessToken, refreshToken: refreshToken, codeParameters: codeParameters)
        
        let data: Data
        do {
            data = try JSONEncoder().encode(jsonCoding)
        } catch let error {
            Log.error("Failed encoding JsonCoding: \(error)")
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
        
    public func needToGenerateTokens(dbCreds:Account? = nil) -> Bool {
        var result = codeParameters?.code != nil
            
        // If no dbCreds, then we generate tokens.
        if let dbCreds = dbCreds {
            if let dbSolidCreds = dbCreds as? SolidCreds {
                result = result && codeParameters?.code != dbSolidCreds.codeParameters?.code
            }
            else {
                Log.error("Did not get SolidCreds as dbCreds!")
            }
        }
        
        Log.debug("needToGenerateTokens: \(result); code: \(String(describing: codeParameters?.code))")
        return result
    }
    
    // Use the code to generate a refresh and access token if there is one.
    public func generateTokens(completion:@escaping (Swift.Error?)->()) {
        guard let codeParameters = codeParameters else {
            completion(SolidCredsError.noCodeParameters)
            return
        }
        
        guard let configuration = configuration else {
            completion(SolidCredsError.noConfiguration)
            return
        }

        guard let jwk = jwk else {
            completion(SolidCredsError.noJWK)
            return
        }
        
        tokenRequest = TokenRequest(requestType: .code(codeParameters), jwk: jwk, privateKey: configuration.privateKey)
        tokenRequest.send(queue: .global()) { [weak self] result in
            guard let self = self else {
                completion(SolidCredsError.noSelf)
                return
            }

            switch result {
            case .failure(let error):
                completion(error)
                
            case .success(let response):
                guard let accessToken = response.access_token,
                    let refreshToken = response.refresh_token else {
                    completion(SolidCredsError.failedTokenRequest)
                    return
                }
                
                self.accessToken = accessToken
                self.refreshToken = refreshToken
                
                guard let delegate = self.delegate else {
                    Log.warning("No SolidCreds delegate.")
                    completion(nil)
                    return
                }
                
                guard delegate.saveToDatabase(account: self) else {
                    completion(SolidCredsError.errorSavingCredsToDatabase)
                    return
                }
                
                completion(nil)
            }
        }
    }
    
    public func merge(withNewer newerAccount:Account) {
        assert(newerAccount is SolidCreds, "Wrong other type of creds!")
        let newerCreds = newerAccount as! SolidCreds
        
        if newerCreds.refreshToken != nil {
            self.refreshToken = newerCreds.refreshToken
        }
        
        if newerCreds.codeParameters != nil {
            self.codeParameters = newerCreds.codeParameters
        }
        
        self.accessToken = newerCreds.accessToken
    }
    
    // Use the refresh token to generate a new access token.
    // If error is nil when the completion handler is called, then the accessToken of this object has been refreshed. Uses delegate, if one is defined, to save refreshed creds to database.
    // This depends on `codeParameters`, and `refreshToken`.
    func refresh(completion:@escaping (Swift.Error?)->()) {
        guard let refreshToken = refreshToken else {
            completion(SolidCredsError.noRefreshToken)
            return
        }
        
        guard let codeParameters = codeParameters else {
            completion(SolidCredsError.noCodeParameters)
            return
        }
        
        guard let jwk = jwk else {
            completion(SolidCredsError.noJWK)
            return
        }
        
        guard let configuration = configuration else {
            completion(SolidCredsError.noConfiguration)
            return
        }

        let refreshParams = RefreshParameters(tokenEndpoint: codeParameters.tokenEndpoint, refreshToken: refreshToken, clientId: codeParameters.clientId)
        
        tokenRequest = TokenRequest(requestType: .refresh(refreshParams), jwk: jwk, privateKey: configuration.privateKey)
        tokenRequest.send(queue: .global()) { result in
            switch result {
            case .failure(let error):
                completion(error)
                
            case .success(let response):
                guard let accessToken = response.access_token else {
                    completion(SolidCredsError.noAccessToken)
                    return
                }
                
                self.accessToken = accessToken

                guard let delegate = self.delegate else {
                    Log.warning("No SolidCreds delegate.")
                    completion(nil)
                    return
                }
                
                guard delegate.saveToDatabase(account: self) else {
                    completion(SolidCredsError.errorSavingCredsToDatabase)
                    return
                }
                
                completion(nil)
            }
        }
    }
}
