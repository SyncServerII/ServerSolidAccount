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

enum SolidCredsCloudStorageError: Error {
    case noOptions
    case cannotConvertMimeType
}

extension SolidCreds : CloudStorage {
    // On success, String in result gives checksum of file on server.
    // Returns .failure(CloudStorageError.alreadyUploaded) in completion if the named file already exists.
    // I don't have a check sum yet with this: https://forum.solidproject.org/t/checksum-for-file-resource-stored-in-solid/4606
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
        
        createDirectoryIfDoesNotExist(folderName: folder) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Don't try to overwrite an existing file. Apparently you won't get the intended file name.
            self.lookupFile(named: cloudFileName, inDirectory: folder) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .found:
                    completion(.failure(CloudStorageError.alreadyUploaded))
                    
                case .notFound:
                    self.uploadFile(named: cloudFileName, inDirectory: folder, data: data, mimeType: mimeType) { error in
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
    }

    public func downloadFile(cloudFileName:String, options:CloudStorageFileNameOptions?, completion:@escaping (DownloadResult)->()) {

        guard let options = options,
            let folder = options.cloudFolderName else {
            completion(.failure(SolidCredsCloudStorageError.noOptions))
            return
        }
        
        downloadFile(named: cloudFileName, inDirectory: folder) { result in
            completion(result)
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

