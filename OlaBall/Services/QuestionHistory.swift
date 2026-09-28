import Foundation

/// Every question this phone has shown, oldest first, so the next draw can prefer ones nobody here
/// has seen. Only the answering phone draws a round (the other side reads the ids from the state),
/// so a history that differs per phone can't split a match.
final class QuestionHistory {
    static let key = "ola.seenQuestions.v1"
    static let shared = QuestionHistory(defaults: .standard)

    private let defaults: UserDefaults?
    private(set) var order: [String]

    /// `defaults: nil` keeps the history in memory (tests).
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.key), let ids = try? JSONDecoder().decode([String].self, from: data) {
            order = ids
        } else {
            order = []
        }
    }

    /// Mark questions as just seen: each moves to the newest end. Ids are unique, so the list never
    /// outgrows the question bank.
    func record(_ ids: [String]) {
        let fresh = Set(ids)
        order = order.filter { !fresh.contains($0) } + ids
        if let data = try? JSONEncoder().encode(order) { defaults?.set(data, forKey: Self.key) }
    }
}
