# Backend contract

The iOS client deliberately calls only an operator-owned HTTPS service. Implement and security-review this contract on your server after SoundCloud approves the app/use case. Do not forward arbitrary URLs or proxy arbitrary SoundCloud resources.

`GET /v1/search/tracks?q={query}&limit=30`

Returns `{ "tracks": [Track] }`. Only include official API results and preserve attribution/permalink. Set `playable` only when official API access is `playable` and a valid official stream/transcoding is available. Do not expose client secret or refresh token.

`POST /v1/playback/{urn}` returns `{ "streamURL": "https://...", "expiresAt": "..." }` only after verifying official API access and current user/app authorization. Stream URL must come from the official API; no website scraping, URL guessing, or unapproved caching.

Optional `POST /v1/oauth/start` and callback handling should use official authorization-code + PKCE. Keep state, verifier, client secret, and tokens server-side. If implementing native authorization instead, obtain SoundCloud's written confirmation that the precise public-client flow is supported before putting it in production.

Errors use `{ "code": "unauthorized|rate_limited|offline|unavailable|restricted|invalid_response", "message": "..." }` with suitable HTTP status and `Retry-After` for rate limiting.
