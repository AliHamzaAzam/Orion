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
        let data = message.data(using: .utf8)!
        return try? ChaChaPoly.seal(data, using: key).combined
    }

    func decrypt(data: Data, using key: SymmetricKey) -> String? {
        guard let sealedBox = try? ChaChaPoly.SealedBox(combined: data),
              let decryptedData = try? ChaChaPoly.open(sealedBox, using: key) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
}
