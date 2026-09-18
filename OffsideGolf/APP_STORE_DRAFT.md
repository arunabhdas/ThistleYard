# OffsideGolf App Store draft

Prepared 2026-09-17. **Unpublished draft for owner review.** The copy describes the implemented product direction; final art, gameplay, accessibility, saves, performance and physical-device acceptance gates remain open in `RELEASE_CHECKLIST.md`. Do not publish before the final candidate passes those gates. No availability, review approval, download counts or performance figures are claimed.

## English metadata

| Field | Draft | Count / limit |
|---|---|---|
| Name | OffsideGolf: Coastal Golf | 25 / 30 characters |
| Subtitle | Relaxing rounds. Play offline | 29 / 30 characters |
| Primary language | English; owner to choose the App Store English locale | Unresolved locale |
| Primary category | Games | Recommendation |
| Game subcategory | Sports; consider Simulation as the optional second subcategory | Recommendation |
| Business model | One paid download; no in-app purchases or ads | Price unresolved |

The title states the game and setting; the subtitle adds the pace and offline use. Name availability and ownership have not been checked. Games → Sports is the closest fit to the actual play; avoid implying this is a live sports companion or a multiplayer title. [Apple category guidance](https://developer.apple.com/app-store/categories/)

Name/subtitle limits verified against [Apple app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information). Description is plain text, maximum 4,000 characters; promotional text maximum 170 characters; keywords maximum **100 bytes**. [Apple version metadata fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

### Promotional text (133 / 170 characters)

```text
Find your line along Whispering Coast. Play nine gentle holes, practice a favorite, and return to your saved round whenever you like.
```

### Description (1219 / 4,000 characters)

```text
A little golf. A little sea air.

Take a quiet round along Whispering Coast, a nine-hole course of meadows, gardens and coastal views. Choose a club, find your line and set your power. Let the wind, slopes and lie shape the next shot.

PLAY AT YOUR PACE
Pull back and release to swing, or use untimed power controls and a Swing button. Practice a single hole or play all nine. Save your round locally and return when you are ready.

MAKE EACH SHOT YOUR OWN
Choose from six clubs, from Driver to Putter. Read the flight guide, watch the breeze and work your way around sand and water. Follow your scorecard and try to improve your personal bests.

A SMALL COASTAL ESCAPE
Choose your golfer's skin tone, hairstyle and outfit. Settle into birdsong, soft surf and sparse music, with separate controls for music, nature, golf sounds and interface sounds. Haptics are optional.

ROOM TO PLAY YOUR WAY
Use left-handed controls, green slope guides, high-contrast aiming and reduced motion. Menus follow your device's text size. Play on iPhone or iPad in portrait or landscape.

One paid download. No ads, in-app purchases or account required. Play offline, with your progress saved on your device.

Small swings. Brighter days.
```

### Keywords (90 / 100 UTF-8 bytes)

```text
putting,casual,singleplayer,landscape,wind,clubs,scorecard,practice,peaceful,short,session
```

These are relevant starting terms, not measured search-volume or ranking claims. They contain no competing app names. Revisit after real listing/search data becomes available.

### Optional metadata alternatives

- Brand-only name: `OffsideGolf` — preserves the shortest identity, with less explicit category context.
- Subtitle: `A quiet nine-hole escape` — emphasizes the setting and session feel.
- Subtitle: `Coastal rounds at your pace` — emphasizes player control; use with the brand-only name to avoid repeating “coastal.”

No “What's New” submission text is needed for the first release. For a later version, write it from that version's actual changes. [Apple version metadata fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## Privacy policy draft for the owner's website

**Status:** app behavior text only. The owner must insert the legal operator, effective date, contact and any website/support-service practices before publishing a real policy URL. The current app's no-data-collection declaration does not describe an as-yet-unselected website host or support provider.

### OffsideGolf privacy

Operator: **[Owner legal name — unresolved]**  
Effective date: **[Owner to set before publication]**  
Contact: **[Owner-controlled privacy/support contact — unresolved]**

OffsideGolf is an offline golf game. The current app does not require an account and does not send gameplay, profile or device information to servers operated by us. It contains no advertising, analytics or tracking SDKs.

The app saves your round, scores, golfer appearance, settings and a local profile identifier in its application storage on your device. It keeps a previous valid save to help recover progress if the current save cannot be read. The profile identifier is used locally; it is not an advertising identifier.

OffsideGolf does not currently offer an app-operated cloud-sync service. Your device's backup and restore features may include app data according to your Apple settings and Apple's policies. Deleting the app can remove its local saves; restoring a device backup may restore earlier app data. Offloading an app is different from deleting its data.

The app does not request access to your microphone, camera, contacts or location. Sound effects use bundled audio, and haptic feedback can be turned off.

If you choose to contact support outside the app, you may provide information such as your email address, a description of a problem or a screenshot. **[Owner to document the actual support provider, use, access, retention and deletion process before publication.]** Avoid sending sensitive information that is unrelated to your request.

If the app's data practices change, we will update this policy and the App Store privacy information as appropriate. **[Owner to specify where the current policy is published and how material changes are communicated.]**

**Publication check:** the final binary must still match this wording. App Store Connect needs a real privacy policy URL even for an app declaring no collected data. Website and voluntary support practices require their own accurate explanation. [Apple app privacy requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

## TestFlight drafts

### Beta description

```text
OffsideGolf is an offline golf game for iPhone and iPad. Play nine holes along Whispering Coast, choose from six clubs, practice individual holes and resume a saved round. This beta focuses on shot behavior, scoring, saved progress, comfortable controls and clear feedback.
```

### What to test

```text
Please try a short practice session and a full nine-hole round.

1. Swing and aim: try the pull-and-release pad, cancel a charge, change clubs, and use the untimed power controls. Check that each completed swing counts once.
2. Course behavior: try fairway, rough, sand, slopes, trees and water. Report shots that become stuck, disappear or produce unexpected penalties.
3. Putting and scores: check cup entry, hole results, scorecards and personal bests. Practice results should not replace your saved full round.
4. Resume: leave the app after a shot and reopen it. Background during a charge or ball flight. Check that progress returns without an extra stroke or lost completed shot.
5. Layout and controls: rotate iPhone and iPad, increase device text size, and try left-handed, reduced-motion, high-contrast and untimed controls. Report clipped or unreachable actions.
6. Sound and touch: adjust all four sound levels, turn haptics off, test silent mode and interrupt/resume audio. Report harsh peaks, looping clicks or unwanted sound.
7. Comfort: play for several holes and report repeated stutter, unusual heat or unexpectedly high battery use. These reports supplement measured device profiling.

Use TestFlight feedback to describe the hole, club, approximate power, device model, OS version and steps to reproduce. A screenshot or short recording is helpful. Do not include personal or sensitive information.
```

### Review notes

```text
No login or demo account is required. The app plays offline. From the main menu, Play Meadow Start opens practice; Play all nine holes starts a full round. Settings offers Replay the short tutorial and an untimed power control option. Continue appears when there is a saved round. There are no in-app purchases or ads.
```

Before using these notes, confirm their menu labels and paths against the final candidate. Tester email, review contact and distribution group are unresolved. No invitations or notifications have been sent. First external beta distribution still requires Apple's review process. [External TestFlight guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

## Owner fields and remaining gates

| Item | Status |
|---|---|
| Developer Program team / Team ID | Unresolved; no team/signing identity currently available for this build |
| Registered bundle ID | `ai.offside.OffsideGolf` in source; account ownership/registration unresolved |
| App Store record, SKU and Apple ID | Unresolved; no record created by this work |
| Seller/developer legal name and copyright holder | Unresolved |
| Price, currency, storefronts and release date | Unresolved |
| Paid agreement, tax/banking and applicable storefront declarations | Owner/account setup pending |
| Support URL and feedback email | Unresolved; no sample URL provided |
| Privacy policy URL and privacy contact | Unresolved; draft above is not a hosted policy |
| Review contact name/email/phone | Unresolved |
| Primary English locale and additional localization plans | Unresolved; current in-app catalog is English base only |
| Age rating / Made for Kids / content rights | Complete actual questionnaire and rights review; no rating guessed |
| Icon and screenshots | Final artwork/manual inspection and current gameplay captures pending |
| Physical-device acceptance and performance | Still pending; a paired iPhone alone does not establish signed installation or baseline results |
| Final archive and validation | An unsigned archive exists; final rebuild/inspection, signed validation and TestFlight processing remain pending |

Keep the art review, full-round playtest, accessibility walkthrough, save interruption checks and baseline performance measurements as explicit release gates. Store copy must be adjusted if the final tested feature set changes.
