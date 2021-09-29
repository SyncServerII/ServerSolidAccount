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
import SolidResourcesSwift

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

public class SolidCreds : Account, ResourceCredentials {
    enum SolidCredsError: Swift.Error {
        case noServerParameters
        case failedTokenRequest
        case noSelf
        case errorSavingCredsToDatabase
        case failedCreatingRefreshParameters
        case noJWK
        case noConfiguration
        case noAccessToken
        case noRefreshToken
    }
    
    public var resourceConfigurable: ResourceConfigurable!
    public var tokenRequest:TokenRequest<JWK_RSA>?
    
    // The following keys are for conversion <-> JSON (e.g., to store this into a database).

    struct SolidCredsParams: Codable {
        let accessToken: String?
        let serverParameters: ServerParameters?
        let accountId: String?
        
        // This is non-nil only if the refresh token changed after use in a refresh operation. If nil, use the refresh token in serverParamters.refresh
        let refreshToken: String?
    }
    
    public var accessToken: String!
    var serverParameters: ServerParameters?
    var accountId: String?
    
    // Making a separate `refreshToken` because some Solid pod issuers update the refresh token after every /token endpoint request to create a new refresh token.
    public var refreshToken: String!
    
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
    var configuration:SolidCredsConfiguration!
    var jwk: JWK_RSA!
    
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
    
    static let serverParametersKey = "serverParameters"
    static let accountIdKey = "accountId"
    
    public static func getProperties(fromHeaders headers:AccountHeaders) -> [String: Any] {
        var result = [String: Any]()
        
        guard let base64ServerParametersString = headers[ServerConstants.HTTPAccountDetailsKey] else {
            return [:]
        }
        
        guard let accountId = headers[ServerConstants.HTTPAccountIdKey] else {
            return [:]
        }
        
        let serverParameters: ServerParameters
        
        do {
            serverParameters = try ServerParameters.from(fromBase64: base64ServerParametersString)
        } catch let error {
            Log.error("getProperties: failed: \(error)")
            return [:]
        }
        
        result[Self.serverParametersKey] = serverParameters
        result[Self.accountIdKey] = accountId
       
        return result
    }
    
    public static func fromProperties(_ properties: AccountProperties, user:AccountCreationUser?, configuration: Any?, delegate:AccountDelegate?) -> Account? {
        guard let creds = SolidCreds(configuration: configuration, delegate: delegate) else {
            return nil
        }
        
        guard let serverParameters = properties.properties[Self.serverParametersKey] as? ServerParameters else {
            Log.error("Could not get ServerParameters")
            return nil
        }
        
        creds.accountCreationUser = user
        
        guard let accountId = properties.properties[Self.accountIdKey] as? String else {
            Log.error("Could not get account id")
            return nil
        }
        
        creds.accountId = accountId
        creds.serverParameters = serverParameters
        creds.accessToken = serverParameters.accessToken
        
        guard let jwk = creds.jwk,
            let privateKey = creds.configuration?.privateKey,
            let storageIRI = serverParameters.storageIRI else {
            return nil
        }

        creds.resourceConfigurable = ResourceConfiguration(jwk: jwk, privateKey: privateKey, clientId: serverParameters.refresh.clientId, clientSecret: serverParameters.refresh.clientSecret, storageIRI: storageIRI, tokenEndpoint: serverParameters.refresh.tokenEndpoint, authenticationMethod: serverParameters.refresh.authenticationMethod, refreshDelegate: creds)

        return creds
    }
    
    public static func fromJSON(_ json:String, user:AccountCreationUser, configuration: Any?, delegate:AccountDelegate?) throws -> Account? {
    
        guard let jsonData = json.data(using: .utf8) else {
            return nil
        }
    
        let params:SolidCredsParams
        
        do {
            params = try JSONDecoder().decode(SolidCredsParams.self, from: jsonData)
        } catch let error {
            Log.error("Could not decode SolidCredsParams: \(error)")
            return nil
        }
        
        guard let result = SolidCreds(configuration: configuration, delegate: delegate) else {
            return nil
        }
        
        result.accountCreationUser = user
                
        switch user {
        case .user(let user) where AccountScheme(.accountName(user.accountType))?.userType == .owning:
            fallthrough
        case .userId:
            break
            
        default:
            // Sharing users not allowed.
            assert(false)
        }
        
        result.serverParameters = params.serverParameters
        result.accessToken = params.accessToken
        result.accountId = params.accountId
        
        return result
    }
    
    public func toJSON() -> String? {
        let params = SolidCredsParams(accessToken: accessToken, serverParameters: serverParameters, accountId: accountId, refreshToken: refreshToken)
        
        let data: Data
        do {
            data = try JSONEncoder().encode(params)
        } catch let error {
            Log.error("Failed encoding SolidCredsParams: \(error)")
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
        
    public func needToGenerateTokens(dbCreds:Account? = nil) -> Bool {
        // The server doesn't get the authorization code; no need to generate tokens.
        return false
    }
    
    // A no-op. We already have a refresh token.
    public func generateTokens(completion:@escaping (Swift.Error?)->()) {
        completion(nil)
    }
    
    public func merge(withNewer newerAccount:Account) {
        assert(newerAccount is SolidCreds, "Wrong other type of creds!")
        let newerCreds = newerAccount as! SolidCreds
        
        if newerCreds.serverParameters != nil {
            self.serverParameters = newerCreds.serverParameters
        }
        
        if newerCreds.accessToken != nil {
            self.accessToken = newerCreds.accessToken
        }
    }
}

extension SolidCreds: RefreshDelegate {
    public func accessTokenRefreshed(_ credentials: ResourceCredentials, completion:(Bool)->()) {
        guard let delegate = self.delegate else {
            Log.warning("No SolidCreds delegate.")
            completion(true)
            return
        }
        
        guard delegate.saveToDatabase(account: self) else {
            Log.error("Failed saving creds to database.")
            completion(false)
            return
        }
    }
}
