package co.nsgsolutions.spinola.model

import kotlinx.serialization.Serializable

/** Who you are on this phone. Stored locally; Play Games (Game Center on iOS) supplies the real identity for online matches. */
@Serializable
data class Profile(
    val name: String,
    val world: World,
    /** Couples mode: who's on your team and which lane each of you answers. Remembered between matches. */
    val teamPartnerName: String? = null,
    val teamMyLane: World? = null,
    val teamPartnerLane: World? = null,
)
