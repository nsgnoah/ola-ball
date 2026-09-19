import SwiftUI

/// Which "world" a deck belongs to. A player declares the world they know; their partner gets quizzed on it.
enum World: String, Codable, CaseIterable, Identifiable {
    case hers, his
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hers: return "Her World"
        case .his: return "His World"
        }
    }

    /// What a player who knows this world sees on their own card.
    var iKnowLine: String {
        switch self {
        case .hers: return "I know her world"
        case .his: return "I know his world"
        }
    }

    var blurb: String {
        switch self {
        case .hers: return "Skincare, fashion, rom-coms, reality TV, pop divas, weddings, book club, wellness, celebrity gossip. Your partner gets quizzed on these."
        case .his: return "Football, ball sports, cars, grilling, games, gear, action movies, tech, fight night. Your partner gets quizzed on these."
        }
    }

    var color: Color { self == .hers ? Theme.hers : Theme.his }

    var other: World { self == .hers ? .his : .hers }
}

struct Question: Identifiable, Hashable {
    let id: String
    let deckID: String
    let tier: Int            // 1 rookie, 2 pro, 3 legend
    let prompt: String
    let correct: String
    let wrong: [String]
    let fact: String?

    /// Options in a stable shuffled order for this question (the same on both phones).
    var options: [String] {
        var rng = SeededRNG(seed: UInt64(truncatingIfNeeded: id.stableHash) &* 0x9E3779B97F4A7C15 &+ 7)
        var all = [correct] + wrong
        all.shuffle(using: &rng)
        return all
    }

    var correctIndex: Int { options.firstIndex(of: correct) ?? 0 }
}

struct Deck: Identifiable, Hashable {
    let id: String
    let world: World
    let title: String
    let tagline: String
    let symbol: String
    let colorHex: String
    let questions: [Question]

    var color: Color { Color(hex: colorHex) }

    static func == (a: Deck, b: Deck) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Build a deck from compact question specs.
    init(id: String, world: World, title: String, tagline: String, symbol: String, colorHex: String, specs: [QSpec]) {
        self.id = id
        self.world = world
        self.title = title
        self.tagline = tagline
        self.symbol = symbol
        self.colorHex = colorHex
        self.questions = specs.enumerated().map { i, q in
            Question(id: "\(id)-\(i + 1)", deckID: id, tier: q.tier, prompt: q.prompt, correct: q.correct, wrong: q.wrong, fact: q.fact)
        }
    }
}

/// Compact question authoring: tier, prompt, correct answer, three wrong answers, optional fact.
struct QSpec {
    let tier: Int
    let prompt: String
    let correct: String
    let wrong: [String]
    let fact: String?
}

func Q(_ tier: Int, _ prompt: String, _ correct: String, _ wrong: [String], _ fact: String? = nil) -> QSpec {
    QSpec(tier: tier, prompt: prompt, correct: correct, wrong: wrong, fact: fact)
}

extension String {
    /// Deterministic across launches and devices, unlike `hashValue`.
    var stableHash: Int {
        var h: UInt64 = 1469598103934665603
        for b in utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(truncatingIfNeeded: h)
    }
}
