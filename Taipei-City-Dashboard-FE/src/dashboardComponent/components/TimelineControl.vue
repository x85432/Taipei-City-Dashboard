<script setup>
import { computed, ref, watch } from "vue";

const props = defineProps({
	times: { type: Array, default: () => [] },
	modelValue: { type: String, default: "" },
	granularity: { type: String, default: "month" },
});

const emit = defineEmits(["update:modelValue"]);

const total = computed(() => props.times.length);
const periodLabel = computed(() => props.granularity === "year" ? "年度" : "月份");

// ── Local slider state ─────────────────────────────────────────────────────────
// Slider pos: 0 = leftmost (oldest), total-1 = rightmost (newest).
// times[0] is the most recent, so pos = total - 1 - timesIndex.
const isDragging = ref(false);
const localPos = ref(0);

function posFromModelValue(mv) {
	const idx = props.times.indexOf(mv);
	const safeIdx = idx >= 0 ? idx : 0;
	return Math.max(0, total.value - 1 - safeIdx);
}

// Sync from parent only when the user is NOT actively dragging.
watch(
	[() => props.modelValue, total],
	() => {
		if (!isDragging.value) {
			localPos.value = posFromModelValue(props.modelValue);
		}
	},
	{ immediate: true },
);

// Label shown while dragging reflects local position immediately.
const currentLabel = computed(() => {
	const idx = Math.max(0, Math.min(total.value - 1, total.value - 1 - localPos.value));
	return props.times[idx] || props.modelValue || "";
});

const progressPercent = computed(() => {
	if (total.value <= 1) return "100%";
	return `${(localPos.value / (total.value - 1)) * 100}%`;
});

// ── Event handlers ─────────────────────────────────────────────────────────────
function emitFromPos(pos) {
	const idx = Math.max(0, Math.min(total.value - 1, total.value - 1 - pos));
	emit("update:modelValue", props.times[idx]);
}

function onDragStart() {
	isDragging.value = true;
}

function onInput(event) {
	const pos = Number(event.target.value);
	localPos.value = pos;
	emitFromPos(pos);
}

function onDragEnd(event) {
	const pos = Number(event.target.value);
	localPos.value = pos;
	emitFromPos(pos);
	// Release lock after a tick so the parent update doesn't clobber localPos.
	setTimeout(() => { isDragging.value = false; }, 0);
}

function prev() {
	// Move left → older period
	if (localPos.value > 0) {
		localPos.value--;
		emitFromPos(localPos.value);
	}
}
function next() {
	// Move right → newer period
	if (localPos.value < total.value - 1) {
		localPos.value++;
		emitFromPos(localPos.value);
	}
}
</script>

<template>
  <div class="timeline-control">
    <button
      class="timeline-control-btn"
      :disabled="localPos <= 0"
      title="上一期"
      @click="prev"
    >
      <span>chevron_left</span>
    </button>

    <label class="timeline-control-main">
      <span class="timeline-label">
        <span>{{ periodLabel }}</span>
        <strong>{{ currentLabel }}</strong>
      </span>

      <input
        :value="localPos"
        type="range"
        min="0"
        :max="total - 1"
        class="timeline-slider"
        :style="{ '--timeline-progress': progressPercent }"
        :title="currentLabel"
        :disabled="total <= 1"
        aria-label="選擇時間"
        @mousedown="onDragStart"
        @touchstart="onDragStart"
        @input="onInput"
        @mouseup="onDragEnd"
        @touchend="onDragEnd"
      >
    </label>

    <button
      class="timeline-control-btn"
      :disabled="localPos >= total - 1"
      title="下一期"
      @click="next"
    >
      <span>chevron_right</span>
    </button>
  </div>
</template>

<style scoped lang="scss">
.timeline-control {
	display: grid;
	grid-template-columns: 15px minmax(0, 1fr) 15px;
	align-items: center;
	gap: 3px;
	width: 100%;
	min-width: 0;
	box-sizing: border-box;
	min-height: 25px;
	padding: 2px 4px;
	border-radius: 5px;
	background: rgba(77, 77, 77, 0.58);
	box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.07);

	&-btn {
		background: transparent;
		border: none;
		cursor: pointer;
		width: 15px;
		height: 19px;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--color-complement-text);
		opacity: 0.78;
		transition: color 0.18s, background-color 0.18s, opacity 0.18s;

		&:hover:not(:disabled) {
			background: rgba(255, 255, 255, 0.1);
			color: white;
			opacity: 1;
		}

		&:disabled {
			opacity: 0.25;
			cursor: not-allowed;
		}

		span {
			font-family: var(--font-icon);
			font-size: 0.9rem;
			line-height: 1;
			user-select: none;
		}
	}

	&-main {
		display: grid;
		grid-template-columns: auto minmax(34px, 1fr);
		align-items: center;
		gap: 7px;
		min-width: 0;
		height: 19px;
		padding: 0 3px;
		cursor: pointer;
	}
}

.timeline-label {
	display: flex;
	align-items: center;
	gap: 0;
	min-width: 0;
	height: 18px;
	padding: 0 2px;
	border-radius: 3px;

	span {
		display: none;
		color: var(--color-complement-text);
		font-size: 0.66rem;
		line-height: 1;
		white-space: nowrap;
	}

	strong {
		color: var(--color-highlight);
		font-size: 0.72rem;
		font-weight: 700;
		line-height: 1;
		white-space: nowrap;
	}
}

.timeline-slider {
	width: 100%;
	min-width: 0;
	height: 10px;
	padding: 0 4px;
	box-sizing: border-box;
	-webkit-appearance: none;
	appearance: none;
	background: linear-gradient(
		90deg,
		var(--color-highlight) 0%,
		var(--color-highlight) var(--timeline-progress),
		rgba(255, 255, 255, 0.16) var(--timeline-progress),
		rgba(255, 255, 255, 0.16) 100%
	);
	background-size: calc(100% - 8px) 2px;
	background-position: 4px center;
	background-repeat: no-repeat;
	border-radius: 999px;
	outline: none;
	cursor: pointer;

	&:focus-visible {
		box-shadow: 0 0 0 2px rgba(78, 185, 235, 0.34);
	}

	&::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--color-highlight);
		border: 1px solid rgb(77, 77, 77);
		box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.22);
		cursor: pointer;
		transition: transform 0.15s, box-shadow 0.15s;

		&:hover {
			transform: scale(1.25);
			box-shadow: 0 0 0 3px rgba(76, 180, 149, 0.18);
		}
	}

	&::-moz-range-track {
		height: 2px;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.12);
	}

	&::-moz-range-progress {
		height: 2px;
		border-radius: 999px;
		background: rgba(76, 180, 149, 0.82);
	}

	&::-moz-range-thumb {
		width: 8px;
		height: 8px;
		border: 1px solid rgb(77, 77, 77);
		border-radius: 50%;
		background: var(--color-highlight);
		cursor: pointer;
	}
}

@media (max-width: 520px) {
	.timeline-control {
		&-main {
			grid-template-columns: auto minmax(48px, 1fr);
			gap: 5px;
		}
	}
}
</style>
