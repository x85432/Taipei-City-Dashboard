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

const emits = defineEmits([
	"filterByParam",
	"clearByParamFilter",
]);

const selectedKey = ref(null);

const categories = computed(() => props.chart_config.categories || []);

const palette = computed(() => {
	const colors = props.chart_config.color || [];
	return props.series.reduce((output, serie, index) => {
		output[serie.name] = colors[index] || "#94A3B8";
		return output;
	}, {});
});

const groupTotals = computed(() => {
	return props.series.map((serie, index) => {
		const value = serie.data.reduce((sum, item) => sum + Number(item || 0), 0);
		return {
			name: serie.name,
			value,
			color: props.chart_config.color?.[index] || "#94A3B8",
		};
	});
});

const total = computed(() => {
	return groupTotals.value.reduce((sum, item) => sum + item.value, 0);
});

const districtTotals = computed(() => {
	return categories.value
		.map((district, districtIndex) => {
			const groups = props.series.map((serie) => ({
				name: serie.name,
				value: Number(serie.data[districtIndex] || 0),
			}));
			const value = groups.reduce((sum, item) => sum + item.value, 0);
			return { district, value, groups };
		})
		.filter((item) => item.value > 0)
		.sort((a, b) => b.value - a.value);
});

const topDistricts = computed(() => districtTotals.value.slice(0, 10));

const maxDistrictTotal = computed(() => {
	return Math.max(...districtTotals.value.map((item) => item.value), 1);
});

const leadingGroup = computed(() => {
	return [...groupTotals.value].sort((a, b) => b.value - a.value)[0] || {
		name: "無資料",
		value: 0,
		color: "#94A3B8",
	};
});

const monitoredDistricts = computed(() => districtTotals.value.length);

const leadingDistrict = computed(() => {
	return districtTotals.value[0] || { district: "無資料", value: 0 };
});

function percentage(value, denominator = total.value) {
	if (!denominator) return 0;
	return Math.round((value / denominator) * 100);
}

function cellIntensity(value, districtValue) {
	if (!districtValue) return 0;
	return Math.max(0.16, value / districtValue);
}

function isSelected(district, group) {
	return selectedKey.value === `${district || ""}-${group || ""}`;
}

function handleDataSelection(district, group) {
	const nextKey = `${district || ""}-${group || ""}`;
	if (selectedKey.value === nextKey) {
		if (props.map_filter && props.map_filter_on) {
			emits("clearByParamFilter", props.map_config);
		}
		selectedKey.value = null;
		return;
	}

	selectedKey.value = nextKey;
	if (!props.map_filter || !props.map_filter_on) {
		return;
	}

	emits(
		"filterByParam",
		props.map_filter,
		props.map_config,
		district,
		group
	);
}

function clearSelection() {
	selectedKey.value = null;
	if (props.map_filter && props.map_filter_on) {
		emits("clearByParamFilter", props.map_config);
	}
}
</script>

<template>
  <div
    v-if="activeChart === 'CameraMonitorChart'"
    class="cameramonitorchart"
  >
    <div class="cameramonitorchart-scroll">
      <section class="cameramonitorchart-summary">
        <button
          class="cameramonitorchart-total"
          :class="{ selected: selectedKey === null }"
          @click="clearSelection"
        >
          <span class="material-icons-round">photo_camera</span>
          <div>
            <p>固定式照相設備</p>
            <strong>{{ total }}</strong>
            <small>{{ chart_config.unit }}</small>
          </div>
        </button>
        <div class="cameramonitorchart-stats">
          <div>
            <p>主要取締</p>
            <strong :style="{ color: leadingGroup.color }">
              {{ leadingGroup.name }}
            </strong>
            <small>{{ percentage(leadingGroup.value) }}%</small>
          </div>
          <div>
            <p>熱點行政區</p>
            <strong>{{ leadingDistrict.district }}</strong>
            <small>{{ leadingDistrict.value }} {{ chart_config.unit }}</small>
          </div>
          <div>
            <p>涵蓋行政區</p>
            <strong>{{ monitoredDistricts }}</strong>
            <small>區</small>
          </div>
        </div>
      </section>

      <section class="cameramonitorchart-body">
        <div class="cameramonitorchart-distribution">
          <header>
            <p>違規類型比例</p>
            <span>點擊可篩選地圖</span>
          </header>
          <button
            v-for="group in groupTotals"
            :key="group.name"
            class="cameramonitorchart-group"
            :class="{ selected: isSelected(null, group.name) }"
            @click="handleDataSelection(null, group.name)"
          >
            <span
              class="cameramonitorchart-group-dot"
              :style="{ backgroundColor: group.color }"
            />
            <span>{{ group.name }}</span>
            <div>
              <i :style="{ width: `${percentage(group.value)}%`, backgroundColor: group.color }" />
            </div>
            <strong>{{ group.value }}</strong>
            <small>{{ percentage(group.value) }}%</small>
          </button>
        </div>

        <div class="cameramonitorchart-ranking">
          <header>
            <p>行政區熱點</p>
            <span>前 {{ topDistricts.length }} 名</span>
          </header>
          <button
            v-for="district in topDistricts"
            :key="district.district"
            class="cameramonitorchart-district"
            :class="{ selected: isSelected(district.district, null) }"
            @click="handleDataSelection(district.district, null)"
          >
            <span>{{ district.district }}</span>
            <div>
              <i :style="{ width: `${percentage(district.value, maxDistrictTotal)}%` }" />
            </div>
            <strong>{{ district.value }}</strong>
          </button>
        </div>
      </section>

      <section class="cameramonitorchart-matrix">
        <header>
          <p>熱點 × 取締型態</p>
          <span>點擊格子可篩選單一組合</span>
        </header>
        <div class="cameramonitorchart-matrix-grid">
          <div />
          <div
            v-for="group in groupTotals"
            :key="`matrix-heading-${group.name}`"
            class="cameramonitorchart-matrix-heading"
            :style="{ color: group.color }"
          >
            {{ group.name }}
          </div>
          <template
            v-for="district in topDistricts"
            :key="district.district"
          >
            <div class="cameramonitorchart-matrix-label">
              {{ district.district }}
            </div>
            <button
              v-for="group in district.groups"
              :key="`${district.district}-${group.name}`"
              :title="`${district.district} ${group.name}: ${group.value}`"
              :class="{ selected: isSelected(district.district, group.name) }"
              :style="{
                backgroundColor: palette[group.name],
                opacity: cellIntensity(group.value, district.value),
              }"
              @click="handleDataSelection(district.district, group.name)"
            >
              {{ group.value || "" }}
            </button>
          </template>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.cameramonitorchart {
	position: relative;
	width: 100%;
	min-height: 100%;
	overflow: visible;
	color: var(--color-normal-text);

	&-scroll {
		display: grid;
		grid-template-rows: auto auto auto;
		gap: 0.65rem;
		width: 100%;
		box-sizing: border-box;
		padding-right: 0.35rem;
		overflow: visible;
	}

	button {
		border: 1px solid transparent;
		color: inherit;
		text-align: left;
		transition: border-color 0.2s, background-color 0.2s, opacity 0.2s;
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

		p {
			margin: 0;
			font-size: var(--font-s);
			font-weight: 700;
		}

		span {
			color: var(--color-complement-text);
			font-size: var(--font-s);
		}
	}

	&-summary {
		display: grid;
		grid-template-columns: minmax(140px, 0.9fr) 2fr;
		gap: 0.5rem;
	}

	&-total,
	&-stats > div,
	&-distribution,
	&-ranking,
	&-matrix {
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.045);
	}

	&-total {
		display: flex;
		align-items: center;
		gap: 0.55rem;
		padding: 0.5rem 0.6rem;

		span {
			color: var(--color-highlight);
			font-size: 1.8rem;
		}

		p,
		small {
			margin: 0;
			color: var(--color-complement-text);
			font-size: var(--font-s);
		}

		strong {
			display: inline-block;
			margin-right: 0.25rem;
			font-size: 1.5rem;
			line-height: 1;
		}
	}

	&-stats {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 0.5rem;

		div {
			padding: 0.45rem 0.55rem;
		}

		p,
		small {
			margin: 0;
			color: var(--color-complement-text);
			font-size: var(--font-s);
		}

		strong {
			display: block;
			margin: 0.2rem 0;
			overflow: hidden;
			font-size: var(--font-ms);
			text-overflow: ellipsis;
			white-space: nowrap;
		}
	}

	&-body {
		display: grid;
		grid-template-columns: 1.08fr 1fr;
		gap: 0.6rem;
		min-height: 0;
	}

	&-distribution,
	&-ranking,
	&-matrix {
		padding: 0.55rem 0.6rem;
	}

	&-group,
	&-district {
		display: grid;
		align-items: center;
		width: 100%;
		min-height: 26px;
		margin-top: 0.25rem;
		border-radius: 5px;
		background: rgba(255, 255, 255, 0.04);
		font-size: var(--font-s);
	}

	&-group {
		grid-template-columns: 10px minmax(54px, 0.7fr) 1fr 34px 32px;
		gap: 0.45rem;

		&-dot {
			width: 8px;
			height: 8px;
			border-radius: 50%;
		}

		div {
			height: 5px;
			overflow: hidden;
			border-radius: 999px;
			background: rgba(255, 255, 255, 0.08);
		}

		i {
			display: block;
			height: 100%;
			border-radius: inherit;
		}

		strong,
		small {
			text-align: right;
		}

		small {
			color: var(--color-complement-text);
		}
	}

	&-district {
		grid-template-columns: minmax(48px, 0.7fr) 1fr 34px;
		gap: 0.5rem;

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
			background: var(--color-highlight);
		}

		strong {
			text-align: right;
		}
	}

	&-matrix {
		min-height: 0;

		&-grid {
			display: grid;
			grid-template-columns: minmax(48px, 0.8fr) repeat(5, minmax(32px, 1fr));
			gap: 4px;
		}

		&-heading {
			overflow: hidden;
			font-size: var(--font-s);
			font-weight: 700;
			text-align: center;
			text-overflow: ellipsis;
			white-space: nowrap;
		}

		&-label,
		&-grid button {
			min-height: 22px;
			border-radius: 4px;
			font-size: var(--font-s);
		}

		&-label {
			display: flex;
			align-items: center;
			color: var(--color-complement-text);
		}

		&-grid button {
			display: flex;
			align-items: center;
			justify-content: center;
			color: white;
			font-weight: 700;
			text-align: center;
		}
	}
}

@media (max-width: 600px) {
	.cameramonitorchart {
		&-summary,
		&-body {
			grid-template-columns: 1fr;
		}

		&-stats {
			grid-template-columns: 1fr;
		}
	}
}
</style>
