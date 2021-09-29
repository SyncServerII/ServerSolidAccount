//
//  SolidCreds+CloudStorage.swift
//  
//
//  Created by Christopher G Prince on 8/19/21.
//

import LoggerAPI
import Foundation
import ServerShared
import ServerAccount
import SolidResourcesSwift

enum SolidCredsCloudStorageError: Error {
    case noOptions
    case cannotConvertMimeType
}

extension SolidResourcesSwift.DownloadResult {
    func toServerAccount() -> ServerAccount.DownloadResult {
        switch self {
        case .success(data: let data, attributes: _):
            // I don't have a check sum yet with Solid: https://forum.solidproject.org/t/checksum-for-file-resource-stored-in-solid/4606
            return .success(data: data, checkSum: "")
            
        case .failure(let error):
            return .failure(error)
            
        case .fileNotFound:
            return .fileNotFound
        }
    }
}

extension SolidCreds : CloudStorage {
    // On success, String in result gives checksum of file on server.
    // Returns .failure(CloudStorageError.alreadyUploaded) in completion if the named file already exists.
    public func uploadFile(cloudFileName:String, data:Data, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<String>)->()) {

        guard let options = options,
            let folder = options.cloudFolderName else {
            completion(.failure(SolidCredsCloudStorageError.noOptions))
            return
        }
        
        guard let mimeType = MimeType(rawValue: options.mimeType) else {
            completion(.failure(SolidCredsCloudStorageError.cannotConvertMimeType))
            return
        }
        
        // Don't need to create the directory first if it doesn't exist. The "PUT" we're using in the upload will do that.

        // BUT: Currently (as of 9/4/21), at least the NSS *does* allow you to overwrite an existing file. The SyncServerII protocol requires that we report an existing file, so don't allow that.
        // TODO(https://github.com/SyncServerII/ServerSolidAccount/issues/3): Take file lookup out if the If-None-Match header implemented.
        self.lookupFile(named: cloudFileName, inDirectory: folder) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .found:
                completion(.failure(CloudStorageError.alreadyUploaded))
                
            case .notFound:
                self.uploadFile(named: cloudFileName, inDirectory: folder, data: data, mimeType: mimeType.rawValue) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(""))
                }
    
            case .error(let error):
                completion(.failure(error))
            }
        }
    }

    public func downloadFile(cloudFileName:String, options:CloudStorageFileNameOptions?, completion:@escaping (ServerAccount.DownloadResult)->()) {

        guard let options = options,
            let folder = options.cloudFolderName else {
            completion(.failure(SolidCredsCloudStorageError.noOptions))
            return
        }
        
        downloadFile(named: cloudFileName, inDirectory: folder) { result in
            completion(result.toServerAccount())
        }
    }
    
    public func deleteFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<()>)->()) {

        guard let options = options,
            let folder = options.cloudFolderName else {
            completion(.failure(SolidCredsCloudStorageError.noOptions))
            return
        }
        
        deleteResource(named: cloudFileName, inDirectory: folder) { error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    // On success, returns true iff the file was found.
    // Used primarily for testing.
    public func lookupFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<Bool>)->()) {
        
        guard let options = options,
            let folder = options.cloudFolderName else {
            completion(.failure(SolidCredsCloudStorageError.noOptions))
            return
        }
        
        lookupFile(named: cloudFileName, inDirectory: folder) { result in
            switch result {
            case .found:
                completion(.success(true))
                
            case .notFound:
                completion(.success(false))
                
            case .error(let error):
                completion(.failure(error))
            }
        }
    }
}

