<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<script setup>
import { computed, ref } from "vue";
import { useMapStore } from "../../store/mapStore";
import { useDialogStore } from "../../store/dialogStore";

import DialogContainer from "./DialogContainer.vue";

const mapStore = useMapStore();
const dialogStore = useDialogStore();

const radiusKm = ref(mapStore.searchCircleRadiusKm || 1.2);

const estimatedWalkMinutes = computed(() => Math.round((Number(radiusKm.value) / 4.8) * 60));

const visiblePointLayerCount = computed(
	() => mapStore.getSearchCircleLayerIds(mapStore.currentVisibleLayers).length,
);

function handleClose() {
	dialogStore.hideAllDialogs();
}

function handleStart() {
	const parsedRadiusKm = Number(radiusKm.value);
	if (!Number.isFinite(parsedRadiusKm) || parsedRadiusKm <= 0) {
		dialogStore.showNotification("fail", "請輸入大於 0 的搜尋半徑");
		return;
	}
	if (visiblePointLayerCount.value === 0) {
		dialogStore.showNotification("fail", "請先開啟至少一個點位圖層");
		return;
	}

	mapStore.enableSearchCircleClickMode({
		radiusKm: parsedRadiusKm,
	});
	dialogStore.hideAllDialogs();
}
</script>

<template>
  <DialogContainer
    dialog="searchCircleSettings"
    @on-close="handleClose"
  >
    <div class="searchcirclesettings">
      <h2>搜尋圈設定</h2>
      <div class="searchcirclesettings-input">
        <div class="searchcirclesettings-radiusheader">
          <label for="search-circle-radius">搜尋半徑</label>
          <strong>{{ Number(radiusKm).toFixed(1) }} km</strong>
        </div>
        <div class="searchcirclesettings-slider">
          <span>0.1</span>
          <input
            id="search-circle-radius"
            v-model="radiusKm"
            type="range"
            min="0.1"
            max="5"
            step="0.1"
          >
          <span>5 km</span>
        </div>
        <p class="searchcirclesettings-walktime">
          約 {{ estimatedWalkMinutes }} 分鐘步行路程
        </p>
        <p class="searchcirclesettings-note">
          設定後點擊地圖，系統會統計目前已開啟的
          {{ visiblePointLayerCount }} 個點位圖層。
        </p>
      </div>
      <div class="searchcirclesettings-control">
        <button @click="handleClose">
          取消
        </button>
        <button @click="handleStart">
          開始圈選
        </button>
      </div>
    </div>
  </DialogContainer>
</template>

<style scoped lang="scss">
.searchcirclesettings {
	width: 320px;

	&-input {
		display: flex;
		flex-direction: column;

		label {
			margin: 8px 0;
			font-size: var(--font-s);
			color: var(--color-complement-text);
		}

	}

	&-radiusheader {
		display: flex;
		align-items: center;
		justify-content: space-between;

		strong {
			color: var(--color-highlight);
			font-size: var(--font-ms);
		}
	}

	&-slider {
		display: grid;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		gap: 8px;
		margin: 2px 0 4px;
		color: var(--color-complement-text);
		font-size: var(--font-s);

		input[type="range"] {
			width: 100%;
			accent-color: var(--color-highlight);
			cursor: pointer;
		}
	}

	&-walktime {
		margin: 2px 0 8px;
		color: white;
		font-size: var(--font-ms);
	}

	&-note {
		margin: 4px 0 8px;
		color: var(--color-complement-text);
		font-size: var(--font-s);
		line-height: 1.4;
	}

	&-control {
		height: var(--font-xl);
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		margin-top: 12px;

		button {
			padding: 2px 8px;
			border-radius: 5px;
			background-color: var(--color-highlight);
			transition: opacity 0.2s;

			&:first-child {
				background-color: var(--color-border);
			}

			&:hover {
				opacity: 0.8;
			}
		}
	}
}
</style>
