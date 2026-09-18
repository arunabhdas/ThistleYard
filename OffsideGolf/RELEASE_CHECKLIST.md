# OffsideGolf release readiness

Reviewed 2026-09-17 against the current source and Apple's official documentation. This is release preparation; no signed archive, App Store Connect upload, TestFlight processing, external beta approval or physical-device sign-off has been verified.

## Blocking inputs and evidence

- [ ] Select the owner's Apple Developer Program team and provide its Team ID. No `DEVELOPMENT_TEAM` is configured, and no usable signing identity is currently available for this build. A physical iPhone is paired, but signing and device installation remain blocked by team/identity setup. Do not substitute an arbitrary team or expose signing credentials. Developer Program membership, App Store Connect access and provisioning remain unverified.
- [ ] Register/confirm ownership of `ai.offside.OffsideGolf` and create the matching App Store Connect app record. Name availability is unverified.
- [ ] Supply a working public support URL, privacy policy URL, support/feedback email and review contact. These must be real owner-controlled destinations, not sample values.
- [ ] Choose the paid download price, storefront availability and seller identity; complete the appropriate paid-app agreement, tax and banking setup in App Store Connect. No ads or in-app purchases are part of this version.
- [ ] Obtain physical iPhone 12 and iPad 9th-generation baseline results: performance traces, memory/thermal behavior, audio mix/silent switch/interruption and haptic feedback. Simulator tests cannot establish these results.
- [ ] Verify final original icon/art, all nine holes, score/recovery flows, accessibility, localization coverage and final regression results before archiving. Treat remaining art placeholders or unresolved gameplay failures as release blockers.

Apple requires a Developer Program team for TestFlight/App Store distribution and an app record before upload. Use the account's permitted roles and signing assets. See [preparing distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution), [distribution workflow](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), and [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow).

## Toolchain and build configuration

- [x] Local toolchain observed: Xcode **26.5 (17F42)**, iPhoneOS SDK **26.5**. This meets the currently published minimum: Xcode 26 or later with iOS/iPadOS 26 SDK or later, in force since April 28, 2026. It does not prove an individual archive will be accepted. Recheck immediately before upload. [Apple SDK requirement](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)
- [x] App minimum deployment target is iOS/iPadOS 17.0; device families are iPhone and iPad (`1,2`). The build SDK minimum is distinct from the supported device OS minimum.
- [ ] Set/verify the following in the generated **Release** configuration and archive scheme. These are project recommendations, not a claim that each is an Apple submission mandate:

| Setting | Required project value or check |
|---|---|
| `DEVELOPMENT_TEAM` | Owner's verified Team ID, supplied locally/CI; currently unset |
| `CODE_SIGN_STYLE` | `Automatic` with an authorized account, or deliberate manually managed distribution signing |
| `PRODUCT_BUNDLE_IDENTIFIER` | `ai.offside.OffsideGolf`, after confirming its registration |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | Owner-approved release version; unique increasing build number for uploads |
| `SDKROOT` | `iphoneos` for device archive; installed supported SDK >=26 |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` |
| `TARGETED_DEVICE_FAMILY` | `1,2` |
| `SWIFT_VERSION` | `6.0` |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | No `DEBUG` in Release; empty unless there is a justified production flag |
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` |
| `SWIFT_COMPILATION_MODE` | `wholemodule` |
| `ENABLE_TESTABILITY` | `NO` in Release |
| `DEBUG_INFORMATION_FORMAT` | `dwarf-with-dsym`; retain/upload matching symbols |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon`, backed by a complete actual icon asset |
| `GENERATE_INFOPLIST_FILE` | `NO`, using `_OffsideGolf-frontend-iOS/App/Info.plist` |
| `SUPPORTS_MACCATALYST` / `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD` | `NO` for this release |

- [x] An unsigned Release device archive exists at `/tmp/OffsideGolf-directional-candidate.xcarchive`; its app bundle and DEBUG-string exclusion were inspected. This establishes a local archive artifact only. It is not a distributable or TestFlight-validated build.
- [ ] After team setup, Archive a device Release build, validate it in Organizer and inspect the exported product before any authorized upload. Retain the archive, dSYM and build log. A simulator build is insufficient.

## Privacy and export audit

The source audit covers `App/` and `Packages/OffsideGolfCore/Sources/`. Dependencies are Apple frameworks and the in-repository `OffsideGolfCore` package. No external package/analytics/advertising/tracking SDK was found. Local saves use `Data(contentsOf:)`, atomic `Data.write`, and application-support-directory creation. The app does not currently implement network transport, an account system, cloud sync, Game Center, microphone recording or custom cryptography.

No direct use was found of UserDefaults/AppStorage, file timestamps, disk free-space APIs, system boot-time APIs or active keyboard lists. `ProcessInfo.environment` only appears in a `#if DEBUG` UI-test save override; it is not `systemUptime`. SpriteKit supplies frame timing. Ordinary save-file reading/writing is not being mislabeled as a file-timestamp API. Do not invent required-reason codes for unobserved APIs. Apple's [required-reason category/API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and [declaration rules](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) define what to declare.

- [x] Added `App/Resources/PrivacyInfo.xcprivacy` with tracking false and empty tracking-domain, collected-data and accessed-API arrays. This explicitly records the audited app behavior; an empty manifest is not presented as an Apple mandate for this app. [Manifest format](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [x] Regenerated the Xcode project and verified the manifest is copied to the built app's root in `/tmp/OffsideGolf-directional-candidate.xcarchive`. Organizer's privacy report and App Store validation still require an owner-signed archive. Reaudit whenever dependencies or API use change.
- [ ] App Store privacy questionnaire: the current source supports **Data Not Collected** for app/developer collection. Confirm the final binary and any operational additions before publishing this answer. A privacy policy URL remains required even when no data is collected. Local profiles/save data and system-managed backups should be explained accurately; do not promise that OS backups never occur. [App privacy declarations](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [x] `App/Info.plist` now declares `ITSAppUsesNonExemptEncryption = false`. The current source audit found no encryption implementation or networking SDK. Final candidate verification and the owner's App Store Connect export determination remain pending. Apple permits false when an app uses no encryption or only exempt forms; answer the actual determination and retain any applicable documentation. This checklist is not a legal export classification. [Encryption declaration](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) and [export workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).
- [ ] Do not add tracking, microphone, camera, location or Game Center entitlements/usage descriptions without an implemented feature that needs them. Playing bundled sound does not imply microphone access.

## Bundle contents, language and screenshots

- [x] Current XcodeGen app source root is `_OffsideGolf-frontend-iOS/App`; tests are separate targets under `_OffsideGolf-frontend-iOS/Tests`. `ArtSource`, `Tools`, `mocks`, `specification`, `verification` and Markdown specs lie outside the app source root. Audio master WAV loops and the Python generator are under `ArtSource/Audio`, while runtime audio lives in `_OffsideGolf-frontend-iOS/App/Resources/Audio`.
- [x] Current debug geometry flag and UI-test save override are guarded with `#if DEBUG`.
- [x] Confirmed the Release product contains no `Tests`, `.xctest`, fixtures, Python scripts, mocks, questionnaire screenshots, source masters or debug injection tools. The inspected archive retains runtime textures, nine hole JSON files, course manifest, short WAV effects, four M4A loops, asset provenance, icon, localized resources and privacy manifest.
- [x] Inspected the Release binary for `OFFSIDE_UI_TEST_SAVE`, debug tool names and trajectory markers; none were present in `/tmp/OffsideGolf-directional-candidate.xcarchive`. This is an archive inspection, not an Apple Organizer validation.
- [x] Added a narrow English `Localizable.xcstrings` catalog for stable menu/settings labels without changing UI code. English remains the initial language. Dynamic course content, error strings, plural forms and runtime String labels are not claimed fully localized.
- [ ] Verify the icon on home screen, Settings and App Store representation; eliminate transparency where the chosen icon format forbids it and ensure the asset compiler emits a valid app icon.
- [ ] Capture truthful current gameplay screenshots for iPhone and iPad; the older M0 screenshots are verification artifacts, not final marketing media. Supply accepted 6.9-inch iPhone screenshots (or the required 6.5-inch alternative) and 13-inch iPad screenshots. Follow the current table and remove alpha/transparency. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [ ] Supply title/subtitle/description/keywords/category/copyright/support information and answer the current age-rating questionnaire, including social features. Do not assign a rating by guesswork. There are no authored chat, social-media, gambling or loot-box features in the current app. Apple determines ratings from the questionnaire. [Age-rating setup](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating); [July 2026 questionnaire update](https://developer.apple.com/help/app-store-connect/release-notes/).

## Candidate acceptance and TestFlight

English metadata, an offline/local-save privacy draft and beta testing notes are prepared in `APP_STORE_DRAFT.md`. They are unpublished; owner fields and final feature/visual acceptance remain unresolved.

- [ ] Complete core/platform/UI regression tests and retain results against the exact candidate revision.
- [ ] On devices, test full nine-hole play, practice isolation, resumed shots, forced termination after impact/settlement, save backup recovery, rotations, backgrounding, accessibility text sizes, VoiceOver controls, reduced motion, contrast cues, left-handed/untimed controls and audio opt-outs.
- [ ] Provide beta description, what-to-test notes, feedback email and review contact; no demo login is needed for the current offline game.
- [ ] After a separately authorized upload, wait for App Store Connect processing, resolve all validation/export/privacy issues and confirm the internal TestFlight install launches and resumes correctly.
- [ ] External testing requires an external group and TestFlight review of the first submitted build. Do not call an internal-only build publicly distributable. No tester invitations or notifications have been sent. [External TestFlight process](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [ ] Record Apple processing/review status and physical installation results before marking M13 complete. Keep the current status **prepared, not TestFlight verified** until those gates pass.
