import Foundation
import AppKit
import UserNotifications
import GDCVaultCore

/// Notificări locale de reînnoire + export în calendar.
///
/// DE CE .ics ȘI notificări, nu doar una: notificarea locală apare pe ACEST
/// Mac și doar dacă aplicația a rulat ca să o programeze. Fișierul .ics intră
/// în Calendarul tău și se sincronizează pe telefon — acolo îl vezi și când
/// Mac-ul e închis. Sunt complementare, nu alternative.
enum RenewalReminders {

    // MARK: Notificări locale

    /// Cere permisiunea o singură dată. Fără ea, programarea eșuează tăcut,
    /// deci se cere ÎNAINTE de prima programare, nu la pornirea aplicației.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private static func identifier(entryID: UUID, days: Int) -> String {
        "gdcvault.renewal.\(entryID.uuidString).\(days)"
    }

    /// Reprogramează TOATE notificările unei intrări: întâi le șterge pe cele
    /// vechi. Fără asta, mutarea datei de expirare ar lăsa în urmă avertismente
    /// pentru data veche, iar utilizatorul ar primi alerte care nu mai au sens.
    static func reschedule(for entry: VaultEntry) async {
        let center = UNUserNotificationCenter.current()
        let allIDs = (0...400).map { identifier(entryID: entry.id, days: $0) }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        guard entry.reminderEnabled, let expiresAt = entry.expiresAt else { return }
        guard await requestAuthorization() else { return }

        for days in entry.reminderDaysBefore {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -days, to: expiresAt),
                  fireDate > Date() else { continue }  // o dată trecută nu se poate programa

            let content = UNMutableNotificationContent()
            content.title = entry.name
            content.body = days == 0
                ? "Abonamentul expiră azi."
                : "Abonamentul expiră în \(days) \(days == 1 ? "zi" : "zile")."
            content.sound = .default

            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: identifier(entryID: entry.id, days: days),
                content: content, trigger: trigger))
        }
    }

    static func cancelAll(for entryID: UUID) {
        let allIDs = (0...400).map { identifier(entryID: entryID, days: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    // MARK: Export în calendar (.ics)

    /// Eveniment pe toată ziua, cu alarme relative pentru fiecare prag.
    ///
    /// .ics în loc de EventKit deliberat: EventKit cere permisiune la
    /// calendarul TĂU întreg și scrie direct în el. Un fișier .ics îl deschizi
    /// tu, vezi ce conține și alegi în ce calendar intră — aceeași
    /// sincronizare pe telefon, fără ca aplicația să capete acces la tot.
    static func icsText(for entry: VaultEntry) -> String? {
        guard let expiresAt = entry.expiresAt else { return nil }

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        stamp.timeZone = TimeZone(identifier: "UTC")
        let day = DateFormatter()
        day.dateFormat = "yyyyMMdd"

        var lines = [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//GDC//Vault//RO",
            "BEGIN:VEVENT",
            "UID:\(entry.id.uuidString)@gdcvault",
            "DTSTAMP:\(stamp.string(from: Date()))",
            "DTSTART;VALUE=DATE:\(day.string(from: expiresAt))",
            "SUMMARY:Reînnoire \(icsEscaped(entry.name))",
        ]
        if let price = entry.priceDisplay {
            lines.append("DESCRIPTION:Cost: \(icsEscaped(price))")
        }
        for days in entry.reminderDaysBefore.sorted(by: >) {
            lines += ["BEGIN:VALARM", "ACTION:DISPLAY",
                      "DESCRIPTION:\(icsEscaped(entry.name)) expiră în \(days) zile",
                      "TRIGGER:-P\(days)D", "END:VALARM"]
        }
        lines += ["END:VEVENT", "END:VCALENDAR"]
        // CRLF, nu \n: cerut de RFC 5545, iar unele calendare refuză fișierul altfel.
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// `,` `;` `\` și newline au înțeles sintactic în .ics — netratate, rup fișierul.
    private static func icsEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    @MainActor
    static func exportICS(for entry: VaultEntry) {
        guard let text = icsText(for: entry) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "ics")!]
        panel.nameFieldStringValue = "Reinnoire-\(entry.name).ics"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)   // se deschide în Calendar, gata de adăugat
    }
}
