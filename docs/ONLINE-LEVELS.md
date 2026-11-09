# Online level refresh

The iOS app requests `GET https://api.clashofstats.com/players/{tagWithoutHash}` with an identifying User-Agent, no credentials and a 20-second request timeout. This independently operated public lookup worked during verification on 8 November 2026. It is not an official partnership or a guaranteed service contract. The provider may cache data or change availability. The app shows request time, preserves its last successful result on failure, and does not claim that request time is the game-data timestamp.

## What is stored

`StoredDocument.playerProfile` stores the requested tag, display name, Town Hall level, successful check time and the provider-reported unit/equipment levels. Comparison uses category, village and provider ID, only for the same player. An unknown previous item is not assumed to have been level zero. The first check establishes a baseline. Locked equipment and level-zero units are excluded. Unknown future IDs display an explicit unknown label rather than a guessed name.

Timer exports, boosts, helper links and notifications are not reconciled from this profile. The provider does not supply building countdowns, full building levels, or magic-item inventory. The online feature can be used without importing any export. Automatic refresh is opt-in and happens on foreground opening at least five minutes after the previous check; it does not schedule continuous background work.

## Provider ID mapping provenance

`ios/Sources/ClashTimersCore/Resources/profile_names.json` records the factual mapping of the provider's troop, spell and hero IDs to Supercell game names. Verified against the English name dictionaries publicly served by Clash of Stats on 8 November 2026 at:

- https://www.clashofstats.com/_nuxt/7a25e1d.modern.js
- https://www.clashofstats.com

Only ID/name pairs are retained, not the site's application code. Equipment names come directly from `apiName` in its player response, and `isUnlocked` must be true before displaying an item as owned. Provider `builder` villages are normalized to `builderBase`. These IDs are **not** the IDs in the game's exported JSON or the original Android artwork. Do not derive game data IDs by adding a fixed offset.

## Privacy

An explicit download sends the public player tag to Clash of Stats over HTTPS. Automatic foreground checks occur only after the user enables them. The service sees the tag and ordinary network connection information, including the source IP. No Supercell or Apple credentials, timer export, clipboard contents, advertising ID, or analytics are sent. The local profile can be removed from the levels screen, which also disables automatic refresh. It may be included in the user's iOS backup. The widget never performs this request.

## Validation

Core tests cover provider ID mapping, both villages, owned equipment, unknown IDs, comparison boundaries, malformed/wrong-player responses, legacy document loading, timer preservation, request construction and service errors. UI tests exercise downloading without an export, persistence, a subsequent level increase and a failed refresh retaining saved data. UI tests use an injected synthetic response and never contact the service.
