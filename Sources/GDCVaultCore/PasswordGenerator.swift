import Foundation

/// Generator de parole. `SystemRandomNumberGenerator` e sursa criptografică a
/// sistemului — NU `arc4random_uniform` pe un alfabet concatenat manual și
/// nici `Int.random` fără generator explicit.
public enum PasswordGenerator {
    public struct Options: Equatable {
        public var length: Int
        public var includeUppercase: Bool
        public var includeDigits: Bool
        public var includeSymbols: Bool
        /// Exclude caracterele care se confundă la citit: O/0, l/1/I.
        public var avoidAmbiguous: Bool

        public init(length: Int = 20, includeUppercase: Bool = true, includeDigits: Bool = true,
                    includeSymbols: Bool = true, avoidAmbiguous: Bool = true) {
            self.length = length
            self.includeUppercase = includeUppercase
            self.includeDigits = includeDigits
            self.includeSymbols = includeSymbols
            self.avoidAmbiguous = avoidAmbiguous
        }
    }

    public static func generate(_ options: Options = Options()) -> String {
        var lower = "abcdefghijkmnopqrstuvwxyz"
        var upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        var digits = "23456789"
        let symbols = "!@#$%^&*()-_=+[]{};:,.?"

        if !options.avoidAmbiguous {
            lower += "l"; upper += "IO"; digits += "01"
        }

        var pools: [String] = [lower]
        if options.includeUppercase { pools.append(upper) }
        if options.includeDigits { pools.append(digits) }
        if options.includeSymbols { pools.append(symbols) }

        let length = max(options.length, pools.count)
        var generator = SystemRandomNumberGenerator()

        // Câte unul din FIECARE set ales, apoi restul la întâmplare: altfel o
        // parolă „cu simboluri" poate ieși fără niciun simbol, iar regula de
        // complexitate a site-ului o respinge.
        var characters = pools.compactMap { $0.randomElement(using: &generator) }
        let all = Array(pools.joined())
        while characters.count < length {
            characters.append(all.randomElement(using: &generator)!)
        }
        characters.shuffle(using: &generator)
        return String(characters)
    }
}
