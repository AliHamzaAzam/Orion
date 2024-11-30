//
//  KeyExchange.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation
import CryptoKit

class KeyExchange {
    private var privateKey: SecKey
    private var publicKey: SecKey

    init() {
        let keyPair = KeyExchange.generateKeyPair()
        self.privateKey = keyPair.privateKey
        self.publicKey = keyPair.publicKey
    }

    static func generateKeyPair() -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            fatalError("Unable to create private key: \(error!.takeRetainedValue() as Error)")
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            fatalError("Unable to create public key")
        }

        return (privateKey, publicKey)
    }

    func getPublicKeyData() -> Data {
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            fatalError("Unable to get public key data: \(error!.takeRetainedValue() as Error)")
        }
        return publicKeyData as Data
    }

    func encryptKey(_ symmetricKey: SymmetricKey, with publicKey: SecKey) -> Data? {
        let keyData = symmetricKey.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionOAEPSHA256, keyData as CFData, &error) else {
            print("Unable to encrypt key: \(error!.takeRetainedValue() as Error)")
            return nil
        }
        return encryptedKey as Data
    }

    func decryptKey(_ encryptedKey: Data) -> SymmetricKey? {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA256, encryptedKey as CFData, &error) else {
            print("Unable to decrypt key: \(error!.takeRetainedValue() as Error)")
            return nil
        }
        return SymmetricKey(data: decryptedData as Data)
    }
}
