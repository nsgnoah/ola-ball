import Testing
import SwiftUI
import UIKit
@testable import OlaBall

/// Renders every drawn icon to a contact sheet so the art can be reviewed at a glance.
/// Writes ola-icon-sheet.png to the test host's temp directory and prints the path.
@MainActor
struct IconSheetTests {
    @Test func contactSheet() throws {
        let sheet = IconSheet()
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width > 100)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ola-icon-sheet.png")
        try image.pngData()?.write(to: url)
        print("ICON SHEET: \(url.path)")
    }
}

private struct IconSheet: View {
    let columns = Array(repeating: GridItem(.fixed(96), spacing: 8), count: 6)
    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Decks.all) { deck in
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(deck.color)
                        DeckIcon(deck: deck, fill: .white, ink: Art.darker(deck.color, 0.45)).padding(18)
                    }
                    .frame(width: 96, height: 96)
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Decks.all) { deck in
                    Mascot(deck: deck, size: 90)
                        .frame(width: 96, height: 96)
                }
            }
            HStack(spacing: 8) {
                ZStack { RoundedRectangle(cornerRadius: 16).fill(Theme.violet); CrownIcon(size: 70) }.frame(width: 96, height: 96)
                ZStack { RoundedRectangle(cornerRadius: 16).fill(Theme.violet); TrophyIcon(size: 80) }.frame(width: 96, height: 96)
                ZStack { RoundedRectangle(cornerRadius: 16).fill(Theme.violet); HandoffIcon(size: 80) }.frame(width: 96, height: 96)
                ZStack { RoundedRectangle(cornerRadius: 16).fill(Theme.panel); Crowns(count: 2, size: 20) }.frame(width: 96, height: 96)
                ZStack { RoundedRectangle(cornerRadius: 16).fill(Theme.violet); OlaBadge(size: 70) }.frame(width: 96, height: 96)
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.violet)
                    VStack(spacing: 6) {
                        HStack(spacing: 8) { Glyph(kind: .close, size: 18); Glyph(kind: .check, size: 18); Glyph(kind: .arrowRight, size: 18); Glyph(kind: .trash, size: 18) }
                        HStack(spacing: 8) { Glyph(kind: .more, size: 18); Glyph(kind: .spin, size: 18); Glyph(kind: .send, size: 18); Glyph(kind: .people, size: 18) }
                        HStack(spacing: 8) { Glyph(kind: .star, size: 18); Glyph(kind: .controller, size: 18) }
                    }
                }.frame(width: 96, height: 96)
            }
        }
        .padding(12)
        .background(Theme.night)
    }
}
