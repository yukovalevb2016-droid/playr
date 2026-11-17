# SoundCloud Player

Native SwiftUI iPhone client shell for a SoundCloud integration. This repository does not contain a SoundCloud API key, client secret, backend, or claims of playback authorization. Do not ship a custom player until SoundCloud has approved the app and the integration is confirmed compliant with the current API Terms.

## Current API constraints

- SoundCloud's official API supports search, OAuth 2.1 with PKCE, likes, and track playback where the API marks a track playable. Access may be `playable`, `preview`, or `blocked`; do not infer streamability from metadata.
- API app credentials currently require an Artist Pro account. SoundCloud treats clients as confidential and requires a client secret to obtain tokens. A production mobile app must not embed that secret; use an operator-controlled HTTPS backend for token exchange/refresh and API mediation, or obtain written SoundCloud guidance for an approved public-client pattern.
- Public tracks may be streamed using the official API's stream/transcoding resources. Restricted, paywalled, geo-blocked, or otherwise blocked tracks must not be played through a workaround. Never extract website player URLs, download, or cache audio.
- Custom playback requires uploader attribution, SoundCloud branding, and a link to the SoundCloud work. Metadata/content storage, commercial use, and product naming are governed by SoundCloud API Terms. The proposed name here is only a development placeholder; do not market as an official SoundCloud app or imply endorsement.
- SoundCloud's API documentation indicates API access is subject to app registration and terms. Confirm that the exact standalone consumer-player use case and App Store distribution are accepted by SoundCloud before connecting a real backend.

## Architecture

- SwiftUI app shell with Search, Queue, Favorites, and Now Playing.
- `SoundCloudService` is the API boundary. It expects an operator-owned HTTPS backend that returns normalized SoundCloud data; it intentionally has no guessed SoundCloud endpoint or fake data.
- `PlaybackCoordinator` only accepts an official stream URL explicitly returned by that backend. There is no playback simulation.
- Favorites/queue persist track identifiers and display metadata only. No audio bytes are cached.
- Unit tests cover duration formatting, playable gating, and API error mapping.

## OAuth and backend setup

1. A SoundCloud Artist Pro app owner registers an application through the official SoundCloud Developers app registration workflow/CLI and reviews the current API Terms.
2. Configure a registered redirect URI, for example `tokenplan-soundcloud://oauth/callback`, in SoundCloud app settings and in the backend OAuth client. The exact redirect must match byte-for-byte.
3. Use OAuth 2.1 authorization-code + PKCE for user-scoped endpoints. Keep Client Secret on the backend, not in this app, and securely store/rotate tokens there. SoundCloud says access tokens expire after about an hour and refresh tokens are single-use.
4. Deploy an HTTPS backend and expose the normalized contract documented in `BackendContract.md`; set `SOUNDCLOUD_BACKEND_URL` in the Xcode scheme environment. This is a service URL, not a secret.
5. Only enable likes if the user grants the required scope and the backend implements the official endpoint. Local saved items in this shell are device-local metadata, not SoundCloud likes.

## Open/build

Open `SoundCloudPlayer.xcodeproj` in Xcode 26 or later. Select an iPhone simulator or connected iPhone, set a unique bundle identifier and a development team under Signing & Capabilities, then run. A real device requires an Apple Developer signing identity (free Personal Team is suitable for personal device testing with limitations; paid Apple Developer Program membership is generally required for TestFlight/App Store distribution).

To archive, select Any iOS Device (arm64) and Product > Archive. In Organizer choose Distribute App and follow the signing/export workflow. IPA export/signing has not been performed by this project.
