//
//  SolidCreds+CloudStorage+Requests.swift
//  
//
//  Created by Christopher G Prince on 8/20/21.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import SolidAuthSwiftTools
import LoggerAPI
import HeliumLogger

enum HttpMethod: String {
    case POST
    case GET
    case DELETE
    case HEAD
    case PUT
}

enum Header: String {
    case contentType = "Content-Type"
    case slug // resource name
    case authorization
    case dpop
    case link = "Link" // Upper case "L" because response headers have it this way.
    case host
    case accept
}

protocol DebugResponse {
    var data: Data? { get }
    var headers: [AnyHashable : Any] { get }
    var statusCode: Int? { get }
}

struct DebugOptions: OptionSet {
    let rawValue: Int

    static let data = DebugOptions(rawValue: 1 << 0)
    static let headers = DebugOptions(rawValue: 1 << 1)
    static let statusCode = DebugOptions(rawValue: 1 << 2)

    static let all: DebugOptions = [.data, .headers, .statusCode]
}

extension DebugResponse {
    func debug(_ options: DebugOptions = [.data], heading: String? = nil) -> String {
        var result = ""
        
        if options.contains(.data) {
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                result += "Data: \(dataString)"
            }
        }
        
        if options.contains(.headers) {
            result += "Headers: \(headers)"
        }
        
        if options.contains(.statusCode) {
            if let statusCode = statusCode {
                result += "Status Code: \(statusCode)"
            }
        }
        
        if let heading = heading, result.count > 0 {
            result = "\(heading):\n\(result)"
        }
        
        return result
    }
}
    
extension SolidCreds {
    enum RequestError: Error {
        case noHTTPURLResponse
        case badStatusCode
        case noJWK
        case noConfiguration
        case noAccessToken
        case headersAlreadyHaveAuth
        case headersAlreadyHaveHost
        case noHostURL
        case couldNotGetURLHost
    }
    
    /* Returns DPoP and access token headers. Format is:
        Headers: {
            authorization: "DPoP ACCESS TOKEN",
            dpop: "DPOP TOKEN"
        }
        See https://solid.github.io/solid-oidc/primer/
        Depends on the `jwk`, `configuration`, and the current `accessToken`
        
        `url` is the actual endpoint used in the HTTP request.
    */
    func createAuthenticationHeaders(url: URL, httpMethod: HttpMethod) throws -> [Header: String] {
        guard let jwk = jwk else {
            throw RequestError.noJWK
        }
        
        guard let configuration = configuration else {
            throw RequestError.noConfiguration
        }
        
        guard let accessToken = accessToken else {
            throw RequestError.noAccessToken
        }
        
        let jti = UUID().uuidString
        
        /* I thought initially, I should append a "/" to the htu because I was getting the following in the http response (despite having a 200 status code):
            
            AnyHashable("Www-Authenticate"): "Bearer realm=\"https://inrupt.net\", error=\"invalid_token\", error_description=\"htu https://crspybits.inrupt.net/NewDirectory does not match https://crspybits.inrupt.net/NewDirectory/\""
            
            But that response header doesn't always occur: https://github.com/solid/node-solid-server/issues/1572#issuecomment-903193101
        */
        let htu = url.absoluteString
        Log.debug("htu: \(htu)")
        
        let body = BodyClaims(htu: htu, htm: httpMethod.rawValue, jti: jti)
        let dpop = DPoP(jwk: jwk, privateKey: configuration.privateKey, body: body)
        let signed = try dpop.generate()
        
        return [
            .authorization: "DPoP \(accessToken)",
            .dpop: signed
        ]
    }
    
    struct Success: DebugResponse {
        let data: Data?
        let headers: [AnyHashable : Any]
        let statusCode: Int?
    }

    struct Failure: DebugResponse {
        let error: Error
        let data: Data?
        let headers: [AnyHashable : Any]
        let statusCode: Int?
        
        init(_ error: Error, data: Data? = nil, headers: [AnyHashable : Any] = [:], statusCode: Int? = nil) {
            self.error = error
            self.data = data
            self.headers = headers
            self.statusCode = statusCode
        }
    }
    
    enum RequestResult {
        case success(Success)
        case failure(Failure)
    }
    
    // The headers must not include authorization or dpop-- That will cause the request to fail.
    // Depends on `hostURL`.
    // Parameters:
    //  - path: appended to the hostURL, if given.
    //  - body: Body data for outgoing request. Typically only used for POST's.
    func request(path: String? = nil, httpMethod: HttpMethod, body: Data? = nil, headers: [Header: String], completion: @escaping (RequestResult) -> ()) {

        guard var requestURL = hostURL else {
            completion(.failure(Failure(RequestError.noHostURL)))
            return
        }
        
        if let path = path {
            requestURL.appendPathComponent(path)
        }
        
        guard headers[Header.authorization] == nil,
            headers[Header.dpop] == nil else {
            completion(.failure(Failure(RequestError.headersAlreadyHaveAuth)))
            return
        }

        guard headers[Header.host] == nil else {
            completion(.failure(Failure(RequestError.headersAlreadyHaveHost)))
            return
        }
                
        var request = URLRequest(url: requestURL)
        request.httpMethod = httpMethod.rawValue
        request.httpBody = body
        
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key.rawValue)
        }

        do {
            let authHeaders = try createAuthenticationHeaders(url: requestURL, httpMethod: httpMethod)
            for (key, value) in authHeaders {
                request.addValue(value, forHTTPHeaderField: key.rawValue)
            }
        } catch let error {
            completion(.failure(Failure(error)))
            return
        }
        
        guard let urlHost = requestURL.host else {
            completion(.failure(Failure(RequestError.couldNotGetURLHost)))
            return
        }
        
        request.addValue(urlHost, forHTTPHeaderField: Header.host.rawValue)

        Log.debug("Request: method: \(httpMethod)")
        Log.debug("Request: url.host: \(urlHost)")
        Log.debug("Request: Request headers: \(String(describing:request.allHTTPHeaderFields))")
        Log.debug("Request: URL: \(requestURL)")

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        session.dataTask(with: request, completionHandler: { data, response, error in
            if let error = error {
                completion(.failure(Failure(error)))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completion(.failure(Failure(RequestError.noHTTPURLResponse, data: data)))
                return
            }
            
            guard NetworkingExtras.statusCodeOK(response.statusCode) else {
                completion(.failure(
                    Failure(RequestError.badStatusCode, data: data, headers:response.allHeaderFields, statusCode: response.statusCode)))
                return
            }

            let success = Success(data: data, headers: response.allHeaderFields, statusCode: response.statusCode)
            
            completion(.success(success))
        }).resume()
    }
}
