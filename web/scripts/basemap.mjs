// Builds the offline basemap (ADR 0020) from Natural Earth data (public domain):
// country shapes from world-atlas (50m) and major cities. Run: node scripts/basemap.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { feature } from 'topojson-client';

const CITIES =
	'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_populated_places_simple.geojson';
const round = (n) => Math.round(n * 100) / 100; // ~1 km: plenty for an overview map

const topo = JSON.parse(
	readFileSync(new URL('../node_modules/world-atlas/countries-50m.json', import.meta.url))
);
const countries = feature(topo, topo.objects.countries);
const strip = (coords) =>
	Array.isArray(coords[0]) ? coords.map(strip) : [round(coords[0]), round(coords[1])];
for (const f of countries.features) {
	f.geometry.coordinates = strip(f.geometry.coordinates);
	f.properties = { name: f.properties.name };
	delete f.id;
}

const places = await (await fetch(CITIES)).json();
const cities = places.features
	.map((f) => f.properties)
	.filter((p) => p.pop_max >= 750_000 || p.adm0cap === 1)
	.sort((a, b) => b.pop_max - a.pop_max)
	.map((p) => [p.name, round(p.latitude), round(p.longitude), p.adm0cap === 1 ? 1 : 0]);

const out = { source: 'Natural Earth (public domain)', countries, cities };
writeFileSync(new URL('../static/basemap/world.json', import.meta.url), JSON.stringify(out));
console.log(`${countries.features.length} countries, ${cities.length} cities`);
