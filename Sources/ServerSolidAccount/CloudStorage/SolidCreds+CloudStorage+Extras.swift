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
        case error(Swift.Error)
        
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
        Log.debug("Request: Attempting to lookup directory...")

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
    
    private func filePath(name: String, directory: String?) -> String {
        var path = ""

        if let directory = directory {
            path = "\(directory)/"
        }
        
        path += name
        
        return path
    }
    
    /* Upload a file. Creates the directory if needed, if one is given. See https://github.com/solid/solid-spec/blob/master/api-rest.md#creating-documents-files
    Currently, at least for the NSS v5.6.8, the If-None-Match header (see https://solidproject.org/TR/protocol#writing-resources) sis *not* supported. See https://github.com/solid/node-solid-server/issues/1431. So make sure to check to see if the file exists already if you want to make sure not to overwrite.
    */
    func uploadFile(named name: String, inDirectory directory: String?, data:Data, mimeType: MimeType, completion: @escaping (Error?) -> ()) {
        guard name.count > 0 else {
            completion(CloudStorageExtrasError.nameIsZeroLength)
            return
        }
        
        /* It was a little confusing to me initially, but PUT requests don't use the "Slug" header; the directory/file name is just in the URI.
        https://solidproject.org/TR/protocol#writing-resources
        "When a successful PUT or PATCH request creates a resource, the server MUST use the effective request URI to assign the URI to that resource."
        */
        let headers:  [Header: String] = [
            .contentType: mimeType.rawValue,
            .link: resource
        ]
        
        let path = filePath(name: name, directory: directory)
        
        // I specifically need to use a `PUT` here. This lets the client have control over the URI: https://solidproject.org/TR/protocol "Clients can use PUT and PATCH requests to assign a URI to a resource. Clients can use POST requests to have the server assign a URI to a resource." (see also https://github.com/solid/node-solid-server/issues/1612).
        request(path: path, httpMethod: .PUT, body: data, headers: headers) { result in
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
        
        let path = filePath(name: name, directory: directory)
        
        let headers: [Header: String] = [:]
        
        // HEAD: Retrieve meta data: https://www.w3.org/TR/ldp-primer/#filelookup

        request(path: path, httpMethod: .HEAD, headers: headers) { result in
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
    
    // This can delete a directory or a file. To delete a directory, it must be empty.
    func deleteResource(named name: String, inDirectory directory: String?, completion: @escaping (Error?) -> ()) {
        guard name.count > 0 else {
            completion(CloudStorageExtrasError.nameIsZeroLength)
            return
        }
        
        let path = filePath(name: name, directory: directory)
        
        let headers: [Header: String] = [:]

        request(path: path, httpMethod: .DELETE, headers: headers) { result in
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
        
        let path = filePath(name: name, directory: directory)
        
        let headers: [Header: String] = [:]

        request(path: path, httpMethod: .GET, headers: headers) { result in
            switch result {
            case .success(let success):
                Log.debug("Success Response: \(success.debug(.all))")
                guard let data = success.data else {
                    completion(.failure(CloudStorageExtrasError.noDataInDownload))
                    return
                }
                
                // Not seeing a checksum in the result. See also https://forum.solidproject.org/t/checksum-for-file-resource-stored-in-solid/4606
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
