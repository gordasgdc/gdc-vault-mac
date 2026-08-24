import Foundation
import CryptoKit

/// PBKDF2-HMAC-SHA256, implementat manual peste CryptoKit — CryptoKit
/// n-are PBKDF2 nativ, iar CommonCrypto (care il are) complica inutil
/// build-ul intr-un pachet SPM. E acelasi algoritm standard pe care
/// .NET il expune direct prin `Rfc2898DeriveBytes` — vezi PBKDF2.cs
/// (Windows), tinut cu ACEIASI parametri (iteratii, lungime cheie) ca
/// backup-urile exportate de pe Mac sa poata fi importate pe Windows
/// si invers.
public enum PBKDF2 {
    /// 200k iteratii — peste minimul OWASP recomandat pentru
    /// PBKDF2-HMAC-SHA256 (2023: 600k pentru login-uri, dar aici cheia
    /// deriva un backup local, nu un hash de autentificare online; 200k
    /// tine timpul de export/import sub o secunda pe hardware modern
    /// fara sa slabeasca practic rezistenta la brute-force offline).
    public static func deriveKey(password: String, salt: Data, iterations: Int = 200_000, keyLength: Int = 32) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        var derivedKey = Data()
        var blockIndex: UInt32 = 1

        while derivedKey.count < keyLength {
            var saltPlusIndex = salt
            withUnsafeBytes(of: blockIndex.bigEndian) { saltPlusIndex.append(contentsOf: $0) }

            var u = Data(HMAC<SHA256>.authenticationCode(for: saltPlusIndex, using: passwordKey))
            var block = u
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                for i in 0..<block.count { block[i] ^= u[i] }
            }
            derivedKey.append(block)
            blockIndex += 1
        }

        return SymmetricKey(data: derivedKey.prefix(keyLength))
    }
}
