<!-- Developed By Taipei Urban Intelligence Center 2023-2024 -->
<!-- 
Lead Developer:  Igor Ho (Full Stack Engineer)
Data Pipelines:  Iima Yu (Data Scientist)
Design and UX: Roy Lin (Fmr. Consultant), Chu Chen (Researcher)
Systems: Ann Shih (Systems Engineer)
Testing: Jack Huang (Data Scientist), Ian Huang (Data Analysis Intern) 
-->
<!-- Department of Information Technology, Taipei City Government -->

<script setup>
/* global gtag */
import { computed, ref } from "vue";
import DashboardComponent from "../dashboardComponent/DashboardComponent.vue";
import router from "../router";
import { useContentStore } from "../store/contentStore";
import { useDialogStore } from "../store/dialogStore";
import { useAuthStore } from "../store/authStore";
import { useChatStore } from "../store/chatStore";

import MoreInfo from "../components/dialogs/MoreInfo.vue";
import ReportIssue from "../components/dialogs/ReportIssue.vue";

const contentStore = useContentStore();
const dialogStore = useDialogStore();
const authStore = useAuthStore();
const chatStore = useChatStore();
const aiInsightComponents = ref([]);

const aiInsightComponentKeys = computed(() =>
	new Set(aiInsightComponents.value.map((item) => `${item.id}-${item.city}`))
);

function toggleAiInsight(item) {
	const key = `${item.id}-${item.city}`;
	const existingIndex = aiInsightComponents.value.findIndex(
		(component) => `${component.id}-${component.city}` === key
	);
	if (existingIndex >= 0) {
		aiInsightComponents.value.splice(existingIndex, 1);
		return;
	}
	if (aiInsightComponents.value.length >= 4) {
		dialogStore.showNotification("fail", "AI 解讀最多選取 4 個組件");
		return;
	}
	aiInsightComponents.value.push({
		id: item.id,
		name: item.name,
		index: item.index,
		city: item.city,
	});
}

function clearAiInsightSelection() {
	aiInsightComponents.value = [];
}

async function runAiInsight() {
	if (aiInsightComponents.value.length < 2) {
		dialogStore.showNotification("fail", "請至少選取 2 個組件");
		return;
	}
	const city = contentStore.currentDashboard?.city || aiInsightComponents.value[0]?.city || "taipei";
	await chatStore.insightSelectedComponents(aiInsightComponents.value, city);
	dialogStore.showNotification("success", "AI 解讀已送出，請打開小幫手查看結果");
}

function handleOpenSettings() {
	contentStore.editDashboard = JSON.parse(
		JSON.stringify(contentStore.currentDashboard)
	);
	dialogStore.addEdit = "edit";
	dialogStore.showDialog("addEditDashboards");
}

function toggleFavorite(id,name,city) {
	if (contentStore.favorites.components.includes(id)) {
		contentStore.unfavoriteComponent(id);
	} else {
		contentStore.favoriteComponent(id);
		// 成功收藏組件時觸發GA自訂事件
		if (city && name) {
			gtag('event','popular_component', {
				dashboard_city:city,
				component_name:name,
				city_component:`${city}-${name}`,
				time: Date.now(),
  			})
		}
	}
}
function handleMoreInfo(item) {
	// 檢視更多資訊時觸發GA自訂事件
	if (item.city && item.name){
		gtag('event','popular_component', {
			dashboard_city:item.city,
			component_name:item.name,
			city_component:`${item.city}-${item.name}`,
			time: Date.now(),
  		})
	}

	if (authStore.isMobileDevice && authStore.isNarrowDevice) {
		router.push({
			name: "component-info",
			params: { index: item.index },
		});
	} else {
		dialogStore.showMoreInfo(item);
	}
}
</script>

<template>
  <!-- 1. If the dashboard is map-layers -->
  <div
    v-if="contentStore.currentDashboard.index?.includes('map-layers')"
    class="dashboard"
  >
    <DashboardComponent
      v-for="item in contentStore.currentDashboard.components"
      :key="`${item.index}-${item.city}`"
      :config="item"
      mode="half"
      :info-btn="true"
      :active-city="item.city"
      :select-btn="true"
      :select-btn-disabled="contentStore.cityManager.getSelectList(contentStore.currentDashboard?.city).length === 1"
      :select-btn-list="contentStore.cityManager.getSelectList(contentStore.currentDashboard?.city)"
      :city-tag="contentStore.cityManager.getTagList(contentStore.currentDashboard?.city)"
      :favorite-btn="authStore.token ? true : false"
      :is-favorite="contentStore.favorites?.components.includes(item.id)"
      :ai-insight-btn="contentStore.currentDashboard?.index?.includes('sustainable')"
      :is-ai-insight-selected="aiInsightComponentKeys.has(`${item.id}-${item.city}`)"
      @favorite="
        (id) => {
          toggleFavorite(id,item.name,item.city);
        }
      "
      @toggle-ai-insight="toggleAiInsight"
      @info="
        (item) => {
          handleMoreInfo(item);
        }
      "
      @change-city="(city)=> {
        const selectedData = contentStore.cityDashboard.components.find((data) => {
          if (data.index === item.index && data.city === city) {
            return data
          }
        });

        const componentIndex = contentStore.currentDashboard.components.findIndex(
          (item) => item.id === selectedData.id
        );

        if (selectedData) {
          contentStore.setComponentData(componentIndex, selectedData);
        }
      }"
    />
    <div
      v-if="aiInsightComponents.length > 0"
      class="dashboard-ai-insight"
    >
      <p>已選取 {{ aiInsightComponents.length }} 個組件</p>
      <button @click="runAiInsight">
        <span>auto_awesome</span>
        解讀所選組件
      </button>
      <button
        class="dashboard-ai-insight-clear"
        @click="clearAiInsightSelection"
      >
        清除
      </button>
    </div>
    <MoreInfo />
    <ReportIssue />
  </div>
  <!-- 2. Dashboards that have components -->
  <div
    v-else-if="contentStore.currentDashboard.components?.length !== 0 || contentStore.cityDashboard.components?.length !== 0"
    class="dashboard"
  >
    <DashboardComponent
      v-for="item in contentStore.currentDashboard.components"
      :key="`${item.index}-${item.city}`"
      :config="item"
      :info-btn="true"
      :active-city="item.city"
      :select-btn="true"
      :select-btn-disabled="contentStore.cityManager.getSelectList(contentStore.currentDashboard?.city).length === 1 || contentStore.currentDashboardExcluded.components.filter((data) => data.index === item.index).length === 0"
      :select-btn-list="contentStore.currentDashboard?.city
        ? contentStore.cityManager.getSelectList(contentStore.currentDashboard?.city)
        : contentStore.cityManager.getCities(contentStore.cityManager.activeCities)
      "
      :city-tag="contentStore.currentDashboard?.city
        ? contentStore.cityManager.getTagList(contentStore.currentDashboard?.city)
        : contentStore.cityManager.getTagList(item.city)
      "
      :delete-btn="
        contentStore.personalDashboards
          .map((item) => item.index)
          .includes(contentStore.currentDashboard.index)
      "
      :favorite-btn="
        authStore.token &&
          contentStore.currentDashboard.icon !== 'favorite'
      "
      :is-favorite="contentStore.favorites?.components.includes(item.id)"
      :ai-insight-btn="contentStore.currentDashboard?.index?.includes('sustainable')"
      :is-ai-insight-selected="aiInsightComponentKeys.has(`${item.id}-${item.city}`)"
      @favorite="
        (id) => {
          toggleFavorite(id,item.name,item.city);
        }
      "
      @toggle-ai-insight="toggleAiInsight"
      @info="
        (item) => {
          handleMoreInfo(item);
        }
      "
      @delete="
        (id) => {
          contentStore.deleteComponent(id);
        }
      "
      @change-city="(city)=> {
        const selectedData = contentStore.cityDashboard.components.find((data) => {
          if (data.index === item.index && data.city === city) {
            return data
          }
        });

        const componentIndex = contentStore.currentDashboard.components.findIndex(
          (item) => item.id === selectedData.id
        );

        if (selectedData) {
          contentStore.setComponentData(componentIndex, selectedData);
        }
      }
      "
    />
    <div
      v-if="aiInsightComponents.length > 0"
      class="dashboard-ai-insight"
    >
      <p>已選取 {{ aiInsightComponents.length }} 個組件</p>
      <button @click="runAiInsight">
        <span>auto_awesome</span>
        解讀所選組件
      </button>
      <button
        class="dashboard-ai-insight-clear"
        @click="clearAiInsightSelection"
      >
        清除
      </button>
    </div>
    <MoreInfo />
    <ReportIssue />
  </div>
  <!-- 3. If dashboard is still loading -->
  <div
    v-else-if="contentStore.loading"
    class="dashboard dashboard-nodashboard"
  >
    <div class="dashboard-nodashboard-content">
      <div />
    </div>
  </div>
  <!-- 4. If dashboard failed to load -->
  <div
    v-else-if="contentStore.error"
    class="dashboard dashboard-nodashboard"
  >
    <div class="dashboard-nodashboard-content">
      <span>sentiment_very_dissatisfied</span>
      <h2>發生錯誤，無法載入儀表板</h2>
    </div>
  </div>
  <!-- 5. Dashboards that don't have components -->
  <div
    v-else
    class="dashboard dashboard-nodashboard"
  >
    <div class="dashboard-nodashboard-content">
      <span>addchart</span>
      <h2>尚未加入組件</h2>
      <button
        v-if="contentStore.currentDashboard.icon !== 'favorite'"
        class="hide-if-mobile"
        @click="handleOpenSettings"
      >
        加入您的第一個組件
      </button>
      <p v-else>
        點擊其他儀表板組件之愛心以新增至收藏組件
      </p>
    </div>
  </div>
</template>

<style scoped lang="scss">
.dashboard {
	max-height: calc(100vh - 127px);
	max-height: calc(var(--vh) * 100 - 127px);
	display: grid;
	row-gap: var(--font-s);
	column-gap: var(--font-s);
	margin: var(--font-m) var(--font-m);
	overflow-y: scroll;

	@media (min-width: 720px) {
		grid-template-columns: 1fr 1fr;
	}

	@media (min-width: 1296px) {
		grid-template-columns: 1fr 1fr 1fr;
	}

	@media (min-width: 1800px) {
		grid-template-columns: 1fr 1fr 1fr 1fr;
	}

	@media (min-width: 2200px) {
		grid-template-columns: 1fr 1fr 1fr 1fr 1fr;
	}

	&-nodashboard {
		grid-template-columns: 1fr;

		&-content {
			width: 100%;
			height: calc(100vh - 127px);
			height: calc(var(--vh) * 100 - 127px);
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;

			span {
				margin-bottom: var(--font-ms);
				font-family: var(--font-icon);
				font-size: 2rem;
			}

			button {
				color: var(--color-highlight);
			}

			div {
				width: 2rem;
				height: 2rem;
				border-radius: 50%;
				border: solid 4px var(--color-border);
				border-top: solid 4px var(--color-highlight);
				animation: spin 0.7s ease-in-out infinite;
			}
		}
	}

	&-ai-insight {
		position: sticky;
		bottom: var(--font-s);
		z-index: 5;
		grid-column: 1 / -1;
		display: flex;
		align-items: center;
		gap: var(--font-s);
		width: fit-content;
		max-width: 100%;
		margin: 0 auto;
		padding: 8px 12px;
		border: solid 1px var(--color-border);
		border-radius: 8px;
		background-color: var(--color-component-background);
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);

		p {
			color: var(--color-normal-text);
			font-size: var(--font-s);
			white-space: nowrap;
		}

		button {
			display: flex;
			align-items: center;
			gap: 4px;
			color: var(--color-highlight);
			font-size: var(--font-s);
			white-space: nowrap;

			span {
				font-family: var(--font-icon);
			}
		}

		&-clear {
			color: var(--color-complement-text) !important;
		}
	}
}

@keyframes spin {
	to {
		transform: rotate(360deg);
	}
}
</style>
