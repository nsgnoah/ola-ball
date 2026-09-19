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

    static let all: [Team] = [
        Team(id: "mallards", city: "Minneapolis", name: "Mallards", abbreviation: "MIN", colorHex: "1E9E5A", emoji: "🦆"),
        Team(id: "dragons", city: "Duluth", name: "Dragons", abbreviation: "DUL", colorHex: "D63A3A", emoji: "🐉"),
        Team(id: "stampede", city: "St. Paul", name: "Stampede", abbreviation: "STP", colorHex: "E8792B", emoji: "🐂"),
        Team(id: "narwhals", city: "Northshore", name: "Narwhals", abbreviation: "NOR", colorHex: "1FA9C9", emoji: "🐋"),
        Team(id: "thunder", city: "Prairie", name: "Thunder", abbreviation: "PRA", colorHex: "7B4FD6", emoji: "⚡️"),
        Team(id: "ravens", city: "Iron Range", name: "Ravens", abbreviation: "IRN", colorHex: "3A4DB8", emoji: "🪶"),
    ]

    static func byID(_ id: String) -> Team? { all.first { $0.id == id } }

    static func randomOpponent(for team: Team, using rng: inout some RandomNumberGenerator) -> Team {
        all.filter { $0.id != team.id }.randomElement(using: &rng) ?? all[0]
    }
}
