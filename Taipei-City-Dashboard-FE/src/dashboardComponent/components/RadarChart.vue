<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<script setup>
import { computed } from "vue";
import VueApexCharts from "vue3-apexcharts";

const props = defineProps(["chart_config", "activeChart", "series"]);

// const emits = defineEmits([
// 	"filterByParam",
// 	"filterByLayer",
// 	"clearByParamFilter",
// 	"clearByLayerFilter",
// 	"fly"
// ]);

function getPointCategory(point, index) {
	if (point && typeof point === "object") {
		return point.x ?? point.name ?? props.chart_config.categories?.[index];
	}
	return props.chart_config.categories?.[index];
}

function getPointValue(point) {
	if (point && typeof point === "object") {
		const value = point.y ?? point.data ?? point.value;
		const number = Number(value);
		return Number.isFinite(number) ? number : null;
	}
	const number = Number(point);
	return Number.isFinite(number) ? number : null;
}

const radarCategories = computed(() => {
	const firstSeries = props.series?.find((item) => Array.isArray(item?.data));
	const pointCategories = firstSeries?.data
		?.map(getPointCategory)
		.filter((category) => category !== undefined && category !== null);

	return pointCategories?.length
		? pointCategories
		: props.chart_config.categories || [];
});

const radarSeries = computed(() =>
	(props.series || []).map((item) => ({
		...item,
		data: Array.isArray(item?.data) ? item.data.map(getPointValue) : [],
	})),
);

const chartOptions = computed(() => ({
	chart: {
		stacked: true,
		toolbar: {
			show: false,
		},
	},
	colors: [...props.chart_config.color],
	grid: {
		show: false,
	},
	legend: {
		show: radarCategories.value.length > 0,
	},
	markers: {
		size: 3,
		strokeWidth: 0,
	},
	plotOptions: {
		radar: {
			polygons: {
				connectorColors: "#444",
				strokeColors: "#555",
			},
		},
	},
	stroke: {
		show: true,
		width: 2,
	},
	tooltip: {
		custom: function ({
			series,
			seriesIndex,
			dataPointIndex,
			w,
		}) {
			// The class "chart-tooltip" could be edited in /assets/styles/chartStyles.css
			return (
				'<div class="chart-tooltip">' +
				"<h6>" +
				w.globals.labels[dataPointIndex] +
				`${
					radarCategories.value.length > 0
						? "-" + w.globals.seriesNames[seriesIndex]
						: ""
				}` +
				"</h6>" +
				"<span>" +
				series[seriesIndex][dataPointIndex] +
				` ${props.chart_config.unit}` +
				"</span>" +
				"</div>"
			);
		},
	},
	xaxis: {
		categories: radarCategories.value,
		labels: {
			offsetY: 5,
			formatter: function (value) {
				const label = String(value ?? "");
				return label.length > 7 ? label.slice(0, 6) + "..." : label;
			},
		},
		type: "category",
	},
	yaxis: {
		axisBorder: {
			color: "#000",
		},
		labels: {
			formatter: (_value) => {
				return "";
			},
		},
		// To fix a bug when there is more than 1 series.
		// Original behavior: max defaults to the max sum of each series.
		max: function (max) {
			if (!radarCategories.value.length) {
				return max;
			}
			let adjustedMax = 0;
			radarSeries.value.forEach((element) => {
				const values = element.data.filter((value) => Number.isFinite(value));
				const maxOfSeries = Math.max(0, ...values);
				if (maxOfSeries > adjustedMax) {
					adjustedMax = maxOfSeries;
				}
			});
			return adjustedMax * 1.1;
		},
	},
}));
</script>

<template>
  <div v-if="activeChart === 'RadarChart'">
    <VueApexCharts
      width="100%"
      height="270px"
      type="radar"
      :options="chartOptions"
      :series="radarSeries"
    />
  </div>
</template>
