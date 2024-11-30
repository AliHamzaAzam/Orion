//
//  EncryptionManager.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import Foundation
import CryptoKit

class EncryptionManager {
    func encrypt(message: String, using key: SymmetricKey) -> Data? {
        guard let data = message.data(using: .utf8) else { return nil }
        do {
            let sealedBox = try ChaChaPoly.seal(data, using: key)
            print("Encrypted data: \(sealedBox.combined.base64EncodedString())")
            return sealedBox.combined
        } catch {
            print("Error encrypting message: \(error)")
            return nil
        }
    }

    func decrypt(data: Data, using key: SymmetricKey) -> String? {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: key)
            let decryptedString = String(data: decryptedData, encoding: .utf8)
            print("Decrypted data: \(decryptedString ?? "")")
            return decryptedString
        } catch {
            print("Error decrypting data: \(error)")
            return nil
        }
    }
}



