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

extension SolidCreds : CloudStorage {
    // On success, String in result gives checksum of file on server.
    // Returns .failure(CloudStorageError.alreadyUploaded) in completion if the named file already exists.
    public func uploadFile(cloudFileName:String, data:Data, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<String>)->()) {
        
    }
    
    public func downloadFile(cloudFileName:String, options:CloudStorageFileNameOptions?, completion:@escaping (DownloadResult)->()) {
    
    }
    
    public func deleteFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<()>)->()) {
        
    }

    // On success, returns true iff the file was found.
    // Used primarily for testing.
    public func lookupFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<Bool>)->()) {
        
    }
}

