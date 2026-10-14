# Third-party software and data

Alcove is AGPL-3.0-only. It ships or downloads the following, under their own licenses.

| Component | Where | License |
|---|---|---|
| [PocketBase](https://pocketbase.io) | server | MIT |
| [Leaflet](https://leafletjs.com) © Volodymyr Agafonkin, CloudMade | web (map page) | BSD-2-Clause |
| [Natural Earth](https://www.naturalearthdata.com) country shapes and populated places | `web/static/basemap/world.json` | Public domain |
| [world-atlas](https://github.com/topojson/world-atlas) (Natural Earth as TopoJSON) | build of the basemap | ISC |
| [Lucide](https://lucide.dev) icons | web | ISC |
| [Inter](https://rsms.me/inter/) © The Inter Project Authors | web (Fontsource), mobile (`assets/fonts`) | SIL OFL 1.1 |
| [Fraunces](https://github.com/undercasetype/Fraunces) © The Fraunces Project Authors | web (Fontsource), mobile (`assets/fonts`) | SIL OFL 1.1 |
| [Tesseract](https://github.com/tesseract-ocr/tesseract) and its models, [poppler](https://poppler.freedesktop.org) from Alpine Linux packages | Docker image, Linux OCR bundles (ADR 0025) | Apache-2.0 / GPL-2.0-or-later; see the bundle's README.txt |
| [FFmpeg](https://ffmpeg.org) from Alpine Linux packages | Docker image, Linux ffmpeg bundles (ADR 0016, 0017) | GPL-2.0-or-later / LGPL; see the bundle's README.txt |
| OpenStreetMap tiles, when enabled by an administrator | loaded by browsers from tile.openstreetmap.org | © OpenStreetMap contributors, ODbL; [tile usage policy](https://operations.osmfoundation.org/policies/tiles/) |

The full dependency lists are in `server/go.mod` and the `package.json` files.
