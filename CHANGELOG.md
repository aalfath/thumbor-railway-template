# Changelog

Every release of this template. Breaking changes are listed first in each entry.
Railway shows deployers an "update available" notice when `main` changes; read the entry
before you apply it.

## 7.8.0-railway.1 (2026-11-21)

First release.

- Thumbor 7.8.0 (`ghcr.io/thumbor/thumbor:7.8.0-py-3.13`, pinned by digest).
- Signed URLs only (`ALLOW_UNSAFE_URL = False`); the key comes from the generated `THUMBOR_SECURITY_KEY`.
- Originals, focal points and rendered images cached on the `/data` volume, with age-based expiry and a size cap.
- Smart cropping with OpenCV face and feature detection, sized for 0.5 GB RAM (sources scaled to 2560 px first,
  one engine thread, two parallel downloads).
- Health check `/healthcheck`. The container exits non-zero if Thumbor stops, so Railway restarts it.
