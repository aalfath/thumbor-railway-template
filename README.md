[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/thumbor-2?utm_medium=integration&utm_source=button&utm_campaign=thumbor)

# Thumbor on Railway

One-click [Thumbor](https://github.com/thumbor/thumbor) on Railway, built from this repo. Thumbor is an image service: you ask for a URL such as `/300x200/smart/example.com/photo.jpg` and it fetches the original, crops it (around detected faces and features when you ask for `smart`), resizes it, applies filters and returns the result.

## What the template deploys

| Service | Source | What it does |
|---|---|---|
| **thumbor** | this repo (`Dockerfile`) | Thumbor 7.8.0 from the official `ghcr.io/thumbor/thumbor:7.8.0-py-3.13` image, pinned by digest, on `PORT` 8080 with a public Railway domain. Volume at `/data` caches downloaded originals, smart-crop focal points and rendered images. Health check `/healthcheck` (no key needed). |

Thumbor needs no database. Redis is only an optional alternative storage backend upstream, so it isn't included: the volume cache does the same job for a single instance.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `THUMBOR_SECURITY_KEY` | `${{secret(40,…)}}` | Generated at deploy. Signs every image URL. Copy it from the service's Variables tab to build URLs. |
| `PORT` | `8080` | Port Thumbor listens on; the Railway domain points here. |

Optional settings (add them to the service to change the defaults baked into `thumbor.conf`):

| Variable | Default | What it does |
|---|---|---|
| `THUMBOR_ALLOWED_SOURCES` | empty (any host) | Comma-separated list of hostnames Thumbor may fetch from. |
| `THUMBOR_MAX_WIDTH` / `THUMBOR_MAX_HEIGHT` | `2560` | Larger sources are scaled down to this before cropping; also caps output size. Raise to `3840` or `0` (no limit) with 1 GB+ RAM. |
| `THUMBOR_MAX_PIXELS` | `50000000` | Sources above this many pixels are rejected. |
| `THUMBOR_ENGINE_THREADS` | `1` | Images processed in parallel. Raise with more RAM and vCPUs. |
| `THUMBOR_QUALITY` | `80` | JPEG quality. |
| `THUMBOR_AUTO_WEBP` | `true` | Serve WebP to browsers that accept it. |
| `THUMBOR_RESULT_STORAGE_EXPIRATION_SECONDS` | `604800` (7 days) | How long rendered images stay cached. |
| `THUMBOR_STORAGE_EXPIRATION_SECONDS` | `2592000` (30 days) | How long downloaded originals stay cached. |
| `THUMBOR_CACHE_MAX_MB` | 80% of the volume | The cache is pruned (oldest first) above this size, every 10 minutes. |
| `THUMBOR_ALLOW_UNSAFE_URL` | `false` | `true` enables unsigned `/unsafe/` URLs. This makes the service an open image proxy: don't. |

## After deploy

1. Open `https://YOUR-DOMAIN/healthcheck`: it answers `WORKING`.
2. Copy `THUMBOR_SECURITY_KEY` from the service's Variables tab.
3. Build signed URLs with a Thumbor client library (for example [libthumbor](https://github.com/thumbor/libthumbor) for Python, `thumbor` on npm, `ruby-thumbor`), or by hand: the signature is the URL-safe base64 HMAC-SHA1 of the path after the signature, keyed with the security key.

   ```python
   from libthumbor import CryptoURL
   url = CryptoURL(key="YOUR-KEY").generate(width=300, height=200, smart=True, image_url="example.com/photo.jpg")
   # -> /<signature>/300x200/smart/example.com/photo.jpg ; prefix it with https://YOUR-DOMAIN
   ```

4. Put a CDN in front of the domain if you serve a lot of traffic: Thumbor sends `Cache-Control: max-age=86400`.

## Resources

Tested on a Railway service limited to 0.5 GB RAM and 1 vCPU (the Free plan): one request peaks at about 400 MB with the default 2560 px source limit, and a burst of 16 parallel smart crops of 7–8 MB photos all succeeded. Thumbor uses about 70 MB at rest.

## Updates

Deployers get Railway's "update available" notice when `main` of this repo changes. Each change is listed in [CHANGELOG.md](CHANGELOG.md), breaking changes first. The cache on the volume is disposable, so updates never need a data migration.

## How it works

- `Dockerfile`: the pinned official image plus `thumbor.conf` and `start.sh`.
- `thumbor.conf`: Thumbor executes it as Python, so every setting reads an environment variable with a safe default. Signed URLs only, file storage and result storage on `/data`, local OpenCV face and feature detection for `smart` crops, one engine thread and two parallel downloads.
- `start.sh`: refuses to start without a security key of at least 16 characters, fixes volume ownership, drops to the image's unprivileged `thumbor` user, prunes the cache every 10 minutes, and exits non-zero if Thumbor stops unexpectedly so Railway's restart policy brings it back.

## Licence

Thumbor is MIT-licensed. This wrapper is MIT-licensed too.
