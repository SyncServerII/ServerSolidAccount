//
//  SolidCreds+CloudStorage+Extras.swift
//  
//
//  Created by Christopher G Prince on 8/20/21.
//

import Foundation
import LoggerAPI
import ServerShared
import ServerAccount

let basicContainer = """
    <http://www.w3.org/ns/ldp#BasicContainer>; rel="type"
    """
    
let resource = """
    <http://www.w3.org/ns/ldp#Resource>; rel="type"
    """

extension SolidCreds {
    enum CloudStorageExtrasError: Error {
        case nameIsZeroLength
        case noDataInDownload
    }
    
    /* Create a directory (aka. container). Doesn't check to see if the directory exists already. Make sure it doesn't or, apparently, you will not get the directory naming you expect.
    
        See https://github.com/solid/solid-spec/blob/master/api-rest.md#creating-documents-files
        Example:
        
        POST / HTTP/1.1
        Host: example.org
        Content-Type: text/turtle
        Link: <http://www.w3.org/ns/ldp#BasicContainer>; rel="type"
        Slug: data
    */
    func createDirectory(named name: String, completion: @escaping (Error?) -> ()) {
        guard name.count > 0 else {
            completion(CloudStorageExtrasError.nameIsZeroLength)
            return
        }
        
        let headers:  [Header: String] = [
            .contentType: "text/turtle",
            .link: basicContainer,
            .slug: name
        ]
        
        request(httpMethod: .POST, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")
                completion(nil)
            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(failure.error)")
                completion(failure.error)
            }
        }
    }
    
    /* Lookup a directory (container).
        https://www.w3.org/TR/ldp-primer/#filelookup
        
        Example:
            GET /alice/ HTTP/1.1
            Host: example.org
            Accept: text/turtle
    */
    enum LookupResult: Equatable {
        case found
        case notFound
        case error(Error?)
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch lhs {
            case .found:
                if case .found = rhs {
                    return true
                }
                return false
                
            case .notFound:
                if case .notFound = rhs {
                    return true
                }
                return false
                
            case .error:
                if case .error = rhs {
                    return true
                }
                return false
            }
        }
    }
    
    func lookupDirectory(named name: String, completion: @escaping (LookupResult) -> ()) {
        guard name.count > 0 else {
            completion(.error(CloudStorageExtrasError.nameIsZeroLength))
            return
        }
        
        let headers:  [Header: String] = [
            .accept: "text/turtle",
        ]
        
        // HEAD: Retrieve meta data: https://www.w3.org/TR/ldp-primer/#filelookup

        request(path: name, httpMethod: .HEAD, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")

                // Expecting header:
                // AnyHashable("Link"): "<.acl>; rel=\"acl\", <.meta>; rel=\"describedBy\", <http://www.w3.org/ns/ldp#Container>; rel=\"type\", <http://www.w3.org/ns/ldp#BasicContainer>; rel=\"type\"",

                if let link = success.headers[Header.link.rawValue] as? String {
                    if link.contains(basicContainer) {
                        completion(.found)
                        return
                    }
                }
                
                Log.warning("Found resource but it didn't have expected header")
                completion(.notFound)

            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(String(describing: failure.error))")
                if failure.statusCode == 404 {
                    completion(.notFound)
                    return
                }
                
                completion(.error(failure.error))
            }
        }
    }
    
    /* Upload a file. Assumes the directory exists. And that the named file doesn't already exist. Make sure to supply an extension (e.g., .txt) on the name or the Solid server seems to just give you one it likes.

        See https://github.com/solid/solid-spec/blob/master/api-rest.md#creating-documents-files
        
        Example:
        
            POST / HTTP/1.1
            Host: example.org
            Content-Type: text/turtle
            Link: <http://www.w3.org/ns/ldp#Resource>; rel="type"
            Slug: test
    */
    func uploadFile(named name: String, inDirectory directory: String?, data:Data, mimeType: MimeType, completion: @escaping (Error?) -> ()) {
        guard name.count > 0 else {
            completion(CloudStorageExtrasError.nameIsZeroLength)
            return
        }
        
        let headers:  [Header: String] = [
            .contentType: mimeType.rawValue,
            .link: resource,
            .slug: name
        ]
        
        request(path: directory, httpMethod: .POST, body: data, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")
                completion(nil)
            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(failure.error)")
                completion(failure.error)
            }
        }
    }
    
    func lookupFile(named name: String, inDirectory directory: String?, completion: @escaping (LookupResult) -> ()) {
        guard name.count > 0 else {
            completion(.error(CloudStorageExtrasError.nameIsZeroLength))
            return
        }
        
        var filePath = name
        if let directory = directory {
            filePath = directory + "/" + name
        }
        
        let headers: [Header: String] = [:]
        
        // HEAD: Retrieve meta data: https://www.w3.org/TR/ldp-primer/#filelookup

        request(path: filePath, httpMethod: .HEAD, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")

                if let link = success.headers[Header.link.rawValue] as? String {
                    if link.contains(resource) {
                        completion(.found)
                        return
                    }
                }
                
                Log.warning("Found resource but it didn't have expected header")
                completion(.notFound)

            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(String(describing: failure.error))")
                if failure.statusCode == 404 {
                    completion(.notFound)
                    return
                }
                
                completion(.error(failure.error))
            }
        }
    }
    
    func deleteFile(named name: String, inDirectory directory: String?, completion: @escaping (Error?) -> ()) {
        guard name.count > 0 else {
            completion(CloudStorageExtrasError.nameIsZeroLength)
            return
        }
        
        var filePath = name
        if let directory = directory {
            filePath = directory + "/" + name
        }
        
        let headers: [Header: String] = [:]

        request(path: filePath, httpMethod: .DELETE, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")
                completion(nil)

            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(String(describing: failure.error))")
                completion(failure.error)
            }
        }
    }
    
    func downloadFile(named name: String, inDirectory directory: String?, completion: @escaping (DownloadResult) -> ()) {
        guard name.count > 0 else {
            completion(.failure(CloudStorageExtrasError.nameIsZeroLength))
            return
        }
        
        var filePath = name
        if let directory = directory {
            filePath = directory + "/" + name
        }
        
        let headers: [Header: String] = [:]

        request(path: filePath, httpMethod: .GET, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")
                guard let data = success.data else {
                    completion(.failure(CloudStorageExtrasError.noDataInDownload))
                    return
                }
                
                // Not seeing a checksum in the result.
                completion(.success(data: data, checkSum: ""))

            case .failure(let failure):
                Log.debug("Failure Response: \(failure.debug(.all)); error: \(String(describing: failure.error))")
                if failure.statusCode == 404 {
                    completion(.fileNotFound)
                    return
                }
                
                completion(.failure(failure.error))
            }
        }
    }
}
