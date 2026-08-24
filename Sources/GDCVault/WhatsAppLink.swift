import Foundation

/// Port 1:1 al WhatsAppLink.swift din DataMover — acelasi numar de
/// contact (reconstruit la rulare din bucati, nu ca literal simplu, ca
/// sa nu apara ca sir contiguu intr-un repo public usor de scanat de
/// crawlere care aduna numere pentru spam).
enum WhatsAppLink {
    private static let parts = ["34", "643", "109", "970"]

    private static var number: String { parts.joined() }

    static func url(text: String? = nil) -> URL {
        var comps = URLComponents(string: "https://wa.me/\(number)")!
        if let text {
            comps.queryItems = [URLQueryItem(name: "text", value: text)]
        }
        return comps.url!
    }
}
