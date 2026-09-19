import SwiftUI

/// A fictional team. No real franchises, no real players.
struct Team: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let city: String
    let name: String
    let abbreviation: String
    let colorHex: String
    let emoji: String

    var fullName: String { "\(city) \(name)" }
    var color: Color { Color(hex: colorHex) }
    /// Typographic crest: the first letter of the club name.
    var monogram: String { String(name.prefix(1)) }

    static let all: [Team] = [
        Team(id: "mallards", city: "Minneapolis", name: "Mallards", abbreviation: "MIN", colorHex: "1E6F45", emoji: "🦆"),
        Team(id: "dragons", city: "Duluth", name: "Dragons", abbreviation: "DUL", colorHex: "A8262B", emoji: "🐉"),
        Team(id: "stampede", city: "St. Paul", name: "Stampede", abbreviation: "STP", colorHex: "B85A1C", emoji: "🐂"),
        Team(id: "narwhals", city: "Northshore", name: "Narwhals", abbreviation: "NOR", colorHex: "167C93", emoji: "🐋"),
        Team(id: "thunder", city: "Prairie", name: "Thunder", abbreviation: "PRA", colorHex: "4E3A9C", emoji: "⚡️"),
        Team(id: "ravens", city: "Iron Range", name: "Ravens", abbreviation: "IRN", colorHex: "24357F", emoji: "🪶"),
    ]

    static func byID(_ id: String) -> Team? { all.first { $0.id == id } }

    static func randomOpponent(for team: Team, using rng: inout some RandomNumberGenerator) -> Team {
        all.filter { $0.id != team.id }.randomElement(using: &rng) ?? all[0]
    }
}
