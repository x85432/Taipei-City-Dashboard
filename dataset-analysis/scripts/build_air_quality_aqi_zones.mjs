#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "../..");
const feRoot = path.join(projectRoot, "Taipei-City-Dashboard-FE");
const requireFromFe = createRequire(path.join(feRoot, "package.json"));
const turf = requireFromFe("@turf/turf");

const defaultStationCsv = path.join(
	projectRoot,
	"dataset-analysis/eco-friendly/environment_air_quality_stations.csv"
);
const defaultBoundaryGeojson = path.join(
	feRoot,
	"public/mapData/metrotaipei_town.geojson"
);
const defaultOutputGeojson = path.join(
	feRoot,
	"public/mapData/environment_air_quality_aqi_zones.geojson"
);

const AQI_LEVELS = [
	{ label: "良好", min: 0, max: 50, startColor: "#A7E3A0", endColor: "#21884B" },
	{ label: "普通", min: 51, max: 100, startColor: "#FFF2A0", endColor: "#D29300" },
	{ label: "對敏感族群不健康", min: 101, max: 150, startColor: "#FFD59A", endColor: "#E77800" },
	{ label: "對所有族群不健康", min: 151, max: 200, startColor: "#FF9A9A", endColor: "#CB3333" },
	{ label: "非常不健康", min: 201, max: 300, startColor: "#C7A4FF", endColor: "#7444B8" },
	{ label: "危害", min: 301, max: 500, startColor: "#B89163", endColor: "#684221" },
];

function parseArgs(argv) {
	const options = {
		stations: defaultStationCsv,
		boundary: defaultBoundaryGeojson,
		output: defaultOutputGeojson,
		width: 180,
		simplifyTolerance: 0.00025,
		bandStep: 5,
	};
	for (let index = 0; index < argv.length; index += 1) {
		const arg = argv[index];
		const next = argv[index + 1];
		if (arg === "--stations") {
			options.stations = path.resolve(next);
			index += 1;
		} else if (arg === "--boundary") {
			options.boundary = path.resolve(next);
			index += 1;
		} else if (arg === "--output") {
			options.output = path.resolve(next);
			index += 1;
		} else if (arg === "--width") {
			options.width = Number(next);
			index += 1;
		} else if (arg === "--simplify-tolerance") {
			options.simplifyTolerance = Number(next);
			index += 1;
		} else if (arg === "--band-step") {
			options.bandStep = Number(next);
			index += 1;
		}
	}
	return options;
}

function parseCsv(text) {
	const rows = [];
	let field = "";
	let row = [];
	let quoted = false;
	for (let index = 0; index < text.length; index += 1) {
		const char = text[index];
		const next = text[index + 1];
		if (quoted) {
			if (char === "\"" && next === "\"") {
				field += "\"";
				index += 1;
			} else if (char === "\"") {
				quoted = false;
			} else {
				field += char;
			}
			continue;
		}
		if (char === "\"") {
			quoted = true;
		} else if (char === ",") {
			row.push(field);
			field = "";
		} else if (char === "\n") {
			row.push(field);
			rows.push(row);
			row = [];
			field = "";
		} else if (char !== "\r") {
			field += char;
		}
	}
	if (field || row.length) {
		row.push(field);
		rows.push(row);
	}
	const headers = rows.shift() || [];
	return rows
		.filter((item) => item.length && item.some((value) => value !== ""))
		.map((item) =>
			Object.fromEntries(headers.map((header, index) => [header, item[index] || ""]))
		);
}

function readJson(filePath) {
	return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function getBoundaryFeature(boundaryGeojson) {
	const polygons = [];
	for (const feature of boundaryGeojson.features || []) {
		const geometry = feature.geometry || {};
		if (geometry.type === "Polygon") {
			polygons.push(geometry.coordinates);
		} else if (geometry.type === "MultiPolygon") {
			polygons.push(...geometry.coordinates);
		}
	}
	return turf.multiPolygon(polygons);
}

function getBounds(feature) {
	const [minLng, minLat, maxLng, maxLat] = turf.bbox(feature);
	return { minLng, minLat, maxLng, maxLat };
}

function collectStations(rows) {
	return rows
		.map((row) => ({
			lng: Number(row.longitude),
			lat: Number(row.latitude),
			aqi: Number(row.aqi),
		}))
		.filter(
			(row) =>
				Number.isFinite(row.lng) &&
				Number.isFinite(row.lat) &&
				Number.isFinite(row.aqi)
		);
}

function interpolateIdw(lng, lat, stations) {
	let weightedValue = 0;
	let weightSum = 0;
	for (const station of stations) {
		const distanceSq = (station.lng - lng) ** 2 + (station.lat - lat) ** 2;
		if (distanceSq < 0.00000001) return station.aqi;
		const weight = 1 / distanceSq;
		weightedValue += station.aqi * weight;
		weightSum += weight;
	}
	return weightSum ? weightedValue / weightSum : 0;
}

function buildScalarField(stations, boundaryFeature, bounds, width) {
	const aspect = (bounds.maxLat - bounds.minLat) / (bounds.maxLng - bounds.minLng);
	const height = Math.max(1, Math.round(width * aspect));
	const values = new Array(width * height);
	let minValue = Infinity;
	let maxValue = -Infinity;
	for (let y = 0; y < height; y += 1) {
		const lat =
			bounds.maxLat - (y / Math.max(1, height - 1)) * (bounds.maxLat - bounds.minLat);
		for (let x = 0; x < width; x += 1) {
			const lng =
				bounds.minLng + (x / Math.max(1, width - 1)) * (bounds.maxLng - bounds.minLng);
			const value = interpolateIdw(lng, lat, stations);
			values[y * width + x] = value;
			minValue = Math.min(minValue, value);
			maxValue = Math.max(maxValue, value);
		}
	}
	return { values, width, height, minValue, maxValue };
}

function roundCoord(value) {
	return Number(value.toFixed(6));
}

function asFeature(geometry) {
	if (!geometry || !geometry.coordinates?.length) return null;
	return turf.feature(geometry);
}

function clipFeature(feature, boundaryFeature) {
	if (!feature) return null;
	try {
		return turf.intersect(feature, boundaryFeature);
	} catch {
		return null;
	}
}

function buildBands(bandStep) {
	const bands = [];
	for (let levelIndex = 0; levelIndex < AQI_LEVELS.length; levelIndex += 1) {
		const level = AQI_LEVELS[levelIndex];
		const lowerBoundary = level.min === 0 ? 0 : level.min - 0.5;
		const upperBoundary = level.max + 0.5;
		for (let lower = lowerBoundary; lower < upperBoundary; lower += bandStep) {
			const upper = Math.min(upperBoundary, lower + bandStep);
			const mid = (lower + upper) / 2;
			bands.push({
				levelIndex,
				level,
				lower,
				upper,
				displayMin: Math.ceil(Math.max(level.min, lower)),
				displayMax: Math.floor(Math.min(level.max, upper - 0.000001)),
				color: interpolateColor(level.startColor, level.endColor, normalizedLevelRatio(level, mid)),
			});
		}
	}
	return bands;
}

function normalizedLevelRatio(level, value) {
	if (level.max === level.min) return 1;
	return Math.min(1, Math.max(0, (value - level.min) / (level.max - level.min)));
}

function interpolateColor(startHex, endHex, ratio) {
	const start = hexToRgb(startHex);
	const end = hexToRgb(endHex);
	const channels = start.map((value, index) =>
		Math.round(value + (end[index] - value) * ratio)
	);
	return rgbToHex(channels);
}

function hexToRgb(hex) {
	const normalized = hex.replace("#", "");
	return [0, 2, 4].map((start) => parseInt(normalized.slice(start, start + 2), 16));
}

function rgbToHex(channels) {
	return `#${channels.map((value) => value.toString(16).padStart(2, "0")).join("")}`;
}

function buildPointGrid(scalarField, bounds) {
	const features = [];
	for (let y = 0; y < scalarField.height; y += 1) {
		const lat =
			bounds.maxLat -
			(y / Math.max(1, scalarField.height - 1)) * (bounds.maxLat - bounds.minLat);
		for (let x = 0; x < scalarField.width; x += 1) {
			const lng =
				bounds.minLng +
				(x / Math.max(1, scalarField.width - 1)) * (bounds.maxLng - bounds.minLng);
			features.push(
				turf.point([roundCoord(lng), roundCoord(lat)], {
					aqi: scalarField.values[y * scalarField.width + x],
				})
			);
		}
	}
	return turf.featureCollection(features);
}

function buildAqiZones(stations, boundaryFeature, bounds, width, simplifyTolerance, bandStep) {
	const scalarField = buildScalarField(
		stations,
		boundaryFeature,
		bounds,
		width
	);
	const bands = buildBands(bandStep).filter(
		(band) => band.upper > scalarField.minValue && band.lower <= scalarField.maxValue
	);
	const thresholds = [
		...new Set(
			bands
				.flatMap((band) => [band.lower, band.upper])
		),
	].sort((a, b) => a - b);
	const bandByRange = new Map(
		bands.map((band) => [`${band.lower}-${band.upper}`, band])
	);
	const breakProperties = thresholds.slice(0, -1).map((lower, index) => {
		const upper = thresholds[index + 1];
		const band = bandByRange.get(`${lower}-${upper}`);
		return band
			? {
					level: band.levelIndex + 1,
					label: band.level.label,
					min: band.displayMin,
					max: band.displayMax,
					level_min: band.level.min,
					level_max: band.level.max,
					color: band.color,
					metric: "AQI",
					source: "IDW interpolation from MOENV AQX_P_432 stations",
				}
			: {};
	});
	const isobands = turf.isobands(buildPointGrid(scalarField, bounds), thresholds, {
		zProperty: "aqi",
		breaksProperties: breakProperties,
	});

	const features = [];
	for (const isobandFeature of isobands.features) {
		if (!isobandFeature.properties?.label) continue;
		const bandFeature = clipFeature(asFeature(isobandFeature.geometry), boundaryFeature);
		if (!bandFeature?.geometry) continue;
		let feature = {
			type: "Feature",
			geometry: bandFeature.geometry,
			properties: { ...isobandFeature.properties },
		};
		if (simplifyTolerance > 0) {
			feature = turf.simplify(feature, {
				tolerance: simplifyTolerance,
				highQuality: false,
				mutate: false,
			});
		}
		features.push(feature);
	}
	return {
		type: "FeatureCollection",
		features,
	};
}

function main() {
	const options = parseArgs(process.argv.slice(2));
	const stationRows = parseCsv(fs.readFileSync(options.stations, "utf8"));
	const stations = collectStations(stationRows);
	if (!stations.length) {
		throw new Error("No station AQI records found.");
	}
	const boundaryFeature = getBoundaryFeature(readJson(options.boundary));
	const bounds = getBounds(boundaryFeature);
	const zones = buildAqiZones(
		stations,
		boundaryFeature,
		bounds,
		options.width,
		options.simplifyTolerance,
		options.bandStep
	);
	fs.mkdirSync(path.dirname(options.output), { recursive: true });
	fs.writeFileSync(options.output, JSON.stringify(zones), "utf8");
	console.log(`aqi_zones=${options.output} features=${zones.features.length}`);
}

main();
