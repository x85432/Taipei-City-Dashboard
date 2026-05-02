<script setup>
import { computed, ref } from "vue";

const props = defineProps([
	"chart_config",
	"activeChart",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);

const emits = defineEmits(["filterByParam", "clearByParamFilter"]);

const selectedItem = ref(null);

const categories = computed(() => props.chart_config.categories || []);

const primarySeries = computed(() => (props.series || [])[0] || { data: [] });

const metricName = computed(() => primarySeries.value.name || "指標");
const metricUnit = computed(() => props.chart_config.unit || "");
const fallbackColor = computed(() => props.chart_config.color?.[0] || "#5CA8D8");
const rankingConfig = computed(() => props.chart_config.ranking_config || {});
const rankingLabels = computed(() => rankingConfig.value.labels || {});
const valuePrecision = computed(() => {
	const precision = Number(rankingConfig.value.value_precision);
	return Number.isInteger(precision) && precision >= 0 ? precision : 0;
});
const valueDivisor = computed(() => {
	const divisor = Number(rankingConfig.value.value_divisor);
	return Number.isFinite(divisor) && divisor > 0 ? divisor : 1;
});
const sortOrder = computed(() =>
	rankingConfig.value.order === "asc" ? "asc" : "desc"
);
const primaryMetric = computed(() =>
	["average", "sum", "leading"].includes(rankingConfig.value.primary_metric)
		? rankingConfig.value.primary_metric
		: "average"
);
const levels = computed(() => {
	return (props.chart_config.levels || [])
		.map((level, index) => ({
			label: level.label,
			fullLabel: level.fullLabel || level.full_label || level.label,
			min: Number(level.min),
			max: Number(level.max),
			color: level.color || props.chart_config.color?.[index] || fallbackColor.value,
		}))
		.filter((level) =>
			level.label && Number.isFinite(level.min) && Number.isFinite(level.max)
		)
		.sort((a, b) => a.min - b.min);
});

const rankedItems = computed(() => {
	return categories.value
		.map((label, index) => {
			const value = Number(primarySeries.value.data?.[index]);
			return {
				label,
				value: Number.isFinite(value)
					? normalizeValue(value / valueDivisor.value)
					: null,
			};
		})
		.filter((item) => item.value !== null)
		.sort((a, b) =>
			sortOrder.value === "asc" ? a.value - b.value : b.value - a.value
		);
});

const averageValue = computed(() => {
	if (!rankedItems.value.length) return null;
	return normalizeValue(
		rankedItems.value.reduce((sum, item) => sum + item.value, 0) /
			rankedItems.value.length
	);
});

const sumValue = computed(() => {
	if (!rankedItems.value.length) return null;
	return normalizeValue(
		rankedItems.value.reduce((sum, item) => sum + item.value, 0)
	);
});

const leadingItem = computed(() => rankedItems.value[0] || {
	label: "待接資料",
	value: null,
});

const selectedItemData = computed(() => {
	if (!selectedItem.value) return null;
	const index = rankedItems.value.findIndex(
		(item) => item.label === selectedItem.value
	);
	if (index === -1) return null;
	return {
		...rankedItems.value[index],
		rank: index + 1,
	};
});

const selectedValueDiff = computed(() => {
	if (!selectedItemData.value || averageValue.value === null) return null;
	return selectedItemData.value.value - averageValue.value;
});

const primaryValue = computed(() => {
	if (primaryMetric.value === "sum") return sumValue.value;
	if (primaryMetric.value === "leading") return leadingItem.value.value;
	return averageValue.value;
});

const primaryTitle = computed(() => {
	if (primaryMetric.value === "sum") {
		return labelText("primary", `總計 ${metricName.value}`);
	}
	if (primaryMetric.value === "leading") {
		return labelText("primary", leadingItem.value.label);
	}
	return labelText("primary", `平均 ${metricName.value}`);
});

const leadingLabel = computed(() =>
	labelText("leading", sortOrder.value === "asc" ? "最低" : "最高")
);

const displayedValue = computed(() => selectedItemData.value?.value ?? primaryValue.value);

const displayedLevel = computed(() => getScoreLevel(displayedValue.value));

const diffLabel = computed(() => {
	if (selectedValueDiff.value === null) return "--";
	if (selectedValueDiff.value === 0) return "持平";
	return selectedValueDiff.value > 0
		? `+${formatValue(selectedValueDiff.value)}`
		: formatValue(selectedValueDiff.value);
});

function barWidth(value) {
	if (value === null) return "0%";
	const maxValue = Math.max(...rankedItems.value.map((item) => item.value), 1);
	const scaleMax = Math.max(1, maxValue);
	return `${Math.min(100, Math.max(8, (value / scaleMax) * 100))}%`;
}

function getScoreLevel(value) {
	if (value === null || value === undefined) return null;
	return levels.value.find((level) => value >= level.min && value <= level.max) ||
		null;
}

function levelColor(value) {
	const level = getScoreLevel(value);
	return level?.color || fallbackColor.value;
}

function normalizeValue(value) {
	return Number(value.toFixed(valuePrecision.value));
}

function formatValue(value) {
	if (value === null || value === undefined) return "--";
	return value.toLocaleString("zh-TW", {
		maximumFractionDigits: valuePrecision.value,
		minimumFractionDigits: 0,
	});
}

function labelText(key, fallback) {
	return rankingLabels.value[key] || fallback;
}

function handleSelection(label) {
	if (selectedItem.value === label) {
		clearSelection();
		return;
	}

	selectedItem.value = label;
	if (!props.map_filter || !props.map_filter_on) return;
	emits("filterByParam", props.map_filter, props.map_config, label, null);
}

function clearSelection() {
	selectedItem.value = null;
	if (props.map_filter && props.map_filter_on) {
		emits("clearByParamFilter", props.map_config);
	}
}
</script>

<template>
  <div
    v-if="activeChart === 'RankingOverviewChart'"
    class="rankingoverviewchart"
  >
    <div class="rankingoverviewchart-scroll">
      <section class="rankingoverviewchart-summary">
        <button
          class="rankingoverviewchart-score"
          :class="{ selected: selectedItem === null }"
          @click="clearSelection"
        >
          <div>
            <p>{{ selectedItemData ? selectedItemData.label : primaryTitle }}</p>
            <strong :style="{ color: levelColor(displayedValue) }">
              {{ formatValue(displayedValue) }}
            </strong>
            <small>{{ metricUnit }}</small>
            <em v-if="displayedLevel">
              {{ displayedLevel.label }}
            </em>
          </div>
        </button>

        <div class="rankingoverviewchart-kpis">
          <div v-if="selectedItemData">
            <p>{{ labelText("rank", "排名") }}</p>
            <strong>{{ selectedItemData.rank }}</strong>
            <small>/ {{ rankedItems.length }} {{ labelText("countUnit", "項") }}</small>
          </div>
          <div v-else>
            <p>{{ leadingLabel }}</p>
            <strong>{{ leadingItem.label }}</strong>
            <small>{{ formatValue(leadingItem.value) }} {{ metricUnit }}</small>
          </div>
          <div v-if="selectedItemData">
            <p>{{ labelText("diff", "平均差") }}</p>
            <strong>{{ diffLabel }}</strong>
            <small>{{ metricUnit }}</small>
          </div>
          <div v-else>
            <p>{{ labelText("average", "平均") }}</p>
            <strong>{{ formatValue(averageValue) }}</strong>
            <small>{{ metricUnit }}</small>
          </div>
          <div>
            <p>{{ labelText("count", "筆數") }}</p>
            <strong>{{ rankedItems.length }}</strong>
            <small>{{ labelText("countUnit", "項") }}</small>
          </div>
        </div>
      </section>

      <section class="rankingoverviewchart-panel">
        <header>
          <p>{{ labelText("listTitle", `${metricName} 排名`) }}</p>
          <span>{{ rankedItems.length }} {{ labelText("countUnit", "項") }}</span>
        </header>
        <div
          v-if="levels.length"
          class="rankingoverviewchart-levels"
        >
          <span
            v-for="level in levels"
            :key="level.label"
            :title="`${level.fullLabel} ${level.min}-${level.max}`"
          >
            <i :style="{ backgroundColor: level.color }" />
            {{ level.label }} {{ level.min }}-{{ level.max }}
          </span>
        </div>
        <button
          v-for="item in rankedItems"
          :key="item.label"
          class="rankingoverviewchart-row"
          :class="{ selected: selectedItem === item.label }"
          @click="handleSelection(item.label)"
        >
          <span>{{ item.label }}</span>
          <div>
            <i
              :style="{
                width: barWidth(item.value),
                backgroundColor: levelColor(item.value),
              }"
            />
          </div>
          <strong>{{ formatValue(item.value) }}</strong>
          <small>{{ getScoreLevel(item.value)?.label }}</small>
        </button>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.rankingoverviewchart {
	width: 100%;
	min-height: 100%;
	color: var(--color-normal-text);

	&-scroll {
		display: grid;
		gap: 0.6rem;
		width: 100%;
		box-sizing: border-box;
		padding-right: 0.35rem;
	}

	button {
		border: 1px solid transparent;
		color: inherit;
		text-align: left;
		transition: border-color 0.2s, background-color 0.2s;
	}

	button:hover,
	button.selected {
		border-color: var(--color-highlight);
	}

	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.5rem;
		margin-bottom: 0.45rem;

		p,
		span {
			margin: 0;
			white-space: nowrap;
		}

		p {
			font-size: var(--font-s);
			font-weight: 700;
		}

		span {
			color: var(--color-complement-text);
			font-size: 0.78rem;
		}
	}

	&-summary {
		display: grid;
		grid-template-columns: minmax(124px, 1fr) 1.45fr;
		gap: 0.55rem;
	}

	&-score,
	&-kpis > div,
	&-panel {
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.045);
	}

	&-score {
		min-width: 0;
		padding: 0.5rem 0.55rem;

		p,
		small,
		em {
			margin: 0;
			color: var(--color-complement-text);
			font-size: 0.78rem;
			line-height: 1.15;
			white-space: nowrap;
		}

		em {
			display: inline-block;
			margin-left: 0.28rem;
			font-style: normal;
		}

		strong {
			display: inline-block;
			margin-right: 0.25rem;
			font-size: 1.5rem;
			line-height: 1;
		}
	}

	&-kpis {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 0.45rem;

		div {
			min-width: 0;
			padding: 0.5rem 0.48rem;
		}

		p,
		small {
			margin: 0;
			color: var(--color-complement-text);
			font-size: 0.76rem;
			line-height: 1.15;
			white-space: nowrap;
		}

		strong {
			display: block;
			margin: 0.16rem 0;
			font-size: 1rem;
			line-height: 1.12;
			white-space: nowrap;
		}
	}

	&-panel {
		padding: 0.55rem 0.6rem;
	}

	&-levels {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 0.28rem 0.4rem;
		margin-bottom: 0.45rem;

		span {
			display: flex;
			align-items: center;
			min-width: 0;
			gap: 0.25rem;
			color: var(--color-complement-text);
			font-size: 0.64rem;
			line-height: 1.05;
			white-space: nowrap;
		}

		i {
			display: block;
			width: 0.46rem;
			height: 0.46rem;
			flex: 0 0 auto;
			border-radius: 50%;
		}
	}

	&-row {
		display: grid;
		grid-template-columns: 3.2rem minmax(2.5rem, 1fr) 2rem 4.2rem;
		gap: 0.38rem;
		align-items: center;
		width: 100%;
		min-height: 26px;
		margin-top: 0.25rem;
		border-radius: 5px;
		background: rgba(255, 255, 255, 0.04);
		font-size: 0.82rem;

		> span,
		small {
			white-space: nowrap;
		}

		div {
			height: 6px;
			overflow: hidden;
			border-radius: 999px;
			background: rgba(255, 255, 255, 0.08);
		}

		i {
			display: block;
			height: 100%;
			border-radius: inherit;
		}

		strong {
			font-size: 0.86rem;
			text-align: right;
			white-space: nowrap;
		}

		small {
			color: var(--color-complement-text);
			font-size: 0.78rem;
			text-align: right;
		}
	}
}

@media (max-width: 600px) {
	.rankingoverviewchart {
		&-summary {
			grid-template-columns: 1fr;
		}

		&-kpis {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}
}
</style>
