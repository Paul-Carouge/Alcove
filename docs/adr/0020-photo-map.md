# 0020. Photo map: offline basemap, optional OpenStreetMap tiles

- Status: Accepted (2026-10-12).

## Context

The photo map must work on a home server without internet access and must not tell a third party which
places a user looks at, yet a map without streets is of limited use. The user chose an offline map by
default, with detailed OpenStreetMap tiles that an administrator can enable.

## Decision

- **Leaflet** (BSD-2, ~40 KB gzipped) renders the map in the web app. It is loaded only on the map page.
- **Offline basemap**: country shapes, coastlines and major cities from Natural Earth (public domain),
  simplified and bundled as a static file (`web/static/basemap/world.json`, built by
  `web/scripts/basemap.mjs`). No request leaves the server.
- **OpenStreetMap tiles** (`tile.openstreetmap.org`) are off by default. An administrator enables them on the
  System page (stored in the `app_settings` collection). Only then does the Content Security Policy allow that
  origin in `img-src`; the browser then sends the viewed area to OSM, which the System page says. Attribution
  is shown on the map, as the OSM tile usage policy requires.
- Locations come from `GET /api/v1/photos/locations` (the caller's own photos only); markers are clustered
  in the browser.

## Consequences

- ✅ Works offline and privately out of the box; one switch for detail.
- ⚠️ Heavy use of OSM's public tiles is against their policy; a large instance should point to its own tile
  server (a later setting).
- ⚠️ The CSP is no longer constant: it depends on that setting, read from memory on each request.
