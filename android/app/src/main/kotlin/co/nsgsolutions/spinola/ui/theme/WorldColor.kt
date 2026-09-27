package co.nsgsolutions.spinola.ui.theme

import androidx.compose.ui.graphics.Color
import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.World

/** The colours live in the UI layer so the core module stays free of Compose. */
val World.color: Color
    get() = if (this == World.hers) Theme.hers else Theme.his

val Deck.color: Color
    get() = colorHex(colorHex)
