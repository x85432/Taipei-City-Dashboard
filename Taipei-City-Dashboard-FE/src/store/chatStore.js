import { ref, watch } from 'vue'
import { defineStore } from 'pinia'
import http from "../router/axios";

export const useChatStore = defineStore('chat', () => {
  	// 預設訊息
  	const defaultChatData = [
    	{
      		id: 1,
      		role: 'bot',
	  		isDefault: true,
      		content:
        	'TEST您好，我是【臺北城市儀表板】小幫手，很高興為您服務！\n 您可以： \n\n • 點擊左側既有的儀表板主題，快速查看各主題內容 \n • 輸入您感興趣的主題描述，我會自動為您組建最適合的儀表板 \n\n 如果有想了解的內容，歡迎直接告訴我，我會盡力協助！\n\n 📩 聯絡信箱：tuic@gov.taipei \n 🏢 臺北大數據中心 \n\n',
    	},
  	];

	const recommendComponents = ref(null)

  	// 從 sessionStorage 讀取
  	const savedChatData = JSON.parse(sessionStorage.getItem('chatData')) || [];

  	// 拼接預設訊息 + sessionStorage 的聊天紀錄
  	const chatData = ref([...defaultChatData, ...savedChatData]);

  	// 監聽 chatData 的變化，自動同步到 sessionStorage
  	watch(
    	chatData,
    	(newVal) => {
      	// 只存使用者與機器人的聊天訊息，不存重複的預設訊息
      	const userBotMessages = newVal.filter((item) => !item.isDefault)
      	sessionStorage.setItem('chatData', JSON.stringify(userBotMessages))
    	},
    	{ deep: true }
  	);

  	const addChatData = (newChatData) => {
    	chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });
  	};

	const addQueryData = async (newChatData) => {

    	chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });

		recommendComponents.value = [];
		let topK = null;

		try {
			const response = await http.post(
  				"/vector/component",
  				new URLSearchParams({
    				query: newChatData.content,
    				limit: 10,
    				score: 0.8,
  				}),
  				{
    				headers: {
      					"Content-Type": "application/x-www-form-urlencoded",
    				},
  				}
			);
			if (response.data?.data?.length > 0) {
				recommendComponents.value = response.data.data;
			}

			// 去除重複項目存到 result
			const result = Array.from(
  				recommendComponents.value.reduce((map, item) => {
    				const key = item.index
    				const exist = map.get(key)

    				// 如果還沒放過，直接放
    				if (!exist) {
      					map.set(key, item)
      					return map
    				}

    				// 如果已存在，但現在的是 metrotaipei，就覆蓋
    				if (item.city === 'metrotaipei') {
      					map.set(key, item)
    				}

    				return map
  				}, new Map()).values()
			)
			// 把 result 蓋回去 recommendComponents
			recommendComponents.value = result

		} catch (error) { 
			console.error("VectorAnalysisError :", error);
		}

		if (recommendComponents.value && recommendComponents.value?.length > 0) {
			topK = [...recommendComponents.value].sort((a, b) => b.score - a.score);
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, button: [{ id:1, text:'建立儀表板' }], content: `您好 😊 \n 以下是根據您的問題，自動為您推薦的「組件清單」。您可以將這些組件整批加入「個人儀表板」，方便日後快速查看與使用。\n`, relations: topK });
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, content: `若您有任何新的查詢或想深入探索的內容，都可以隨時在對話框告訴我～\n 我很樂意再協助您 💬✨` });
		} else {
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, content: `很抱歉，您提供的描述沒有相似組件，請繼續提問 ! ` });
		}

		// 分析結束後紀錄問答log
		saveChatLog(newChatData.content, recommendComponents.value);
  	};

	const aiTools = () => [
		{
			type: "function",
			function: {
				name: "search_dashboard_components",
				description: "當使用者詢問任何與城市、生活品質、交通、政策相關的探索性問題時，使用此工具來搜尋系統內有哪些可用的儀表板組件資料。傳入的關鍵字請盡量精簡為名詞，例如將『想了解台北市的交通狀況』轉換為『台北 交通』進行搜尋。",
				parameters: {
					type: "object",
					properties: {
						query: {
							type: "string",
							description: "要搜尋的關鍵字，例如 '商圈活化' 或 '智慧交通'"
						}
					},
					required: ["query"]
				}
			}
		},
		{
			type: "function",
			function: {
				name: "get_selected_components_context",
				description: "當使用者已經選取數個儀表板組件，並要求解釋它們的關聯、脈絡或洞察時使用。此工具會根據 component_ids 與 city 回傳組件描述、用途、來源、限制與少量樣本資料。",
				parameters: {
					type: "object",
					properties: {
						component_ids: {
							type: "array",
							items: { type: "integer" },
							description: "使用者選取的 components.id，最多 4 個"
						},
						city: {
							type: "string",
							description: "城市範圍，例如 taipei 或 metrotaipei"
						},
						sample_limit: {
							type: "integer",
							description: "每個組件最多取幾筆樣本資料"
						}
					},
					required: ["component_ids", "city"]
				}
			}
		}
	];

	const chatWithAI = async (newChatData) => {
		// 1. 先把使用者的話加到畫面
		chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });

		try {
			// 2. 準備對話歷史 (過濾掉預設訊息、錯誤訊息、以及組件搜尋的提示語)
			const messages = chatData.value
				.filter(m => {
					// 過濾掉：1. 預設訊息 2. 沒有內容 3. 系統報錯訊息 4. 組件搜尋的推薦語
					if (m.isDefault || !m.content) return false;
					if (m.content.includes("抱歉，我現在無法與 AI 取得聯繫")) return false;
					if (m.content.includes("自動為您推薦的「組件清單」")) return false;
					if (m.content.includes("提供的描述沒有相似組件")) return false;
					return true;
				})
				.map(m => ({
					role: m.role === 'bot' ? 'assistant' : 'user',
					content: m.content
				}));

			// 3. 呼叫後端 AI 接口，並附帶 Tools 定義
			const response = await http.post("/ai/chat/twai", {
				messages: messages,
				stream: false, // 目前先使用非串流模式
				tools: aiTools(),
				tool_choice: "auto"
			});

			// 4. 將 AI 回覆加入畫面
			if (response.data?.status === "success" && response.data.data?.content) {
				const aiResponseContent = response.data.data.content;
				
				addChatData({ 
					role: 'bot', 
					content: aiResponseContent 
				});

				// 5. 紀錄問答 log，如果 AI 有呼叫 Tool 也一併記錄
				let logAnswer = aiResponseContent;
				if (response.data.data.tool_used) {
					logAnswer += `\n[System Log] 呼叫了工具: ${response.data.data.tools_executed}`;
				}
				saveChatLog(newChatData.content, logAnswer);

			} else {
				throw new Error("AI response format error");
			}

		} catch (error) {
			console.error("AI Chat Error:", error);
			addChatData({ 
				role: 'bot', 
				content: "抱歉，我現在無法與 AI 取得聯繫，請稍後再試或檢查後端設定。" 
			});
		}
	};

	const insightSelectedComponents = async (components, city = 'taipei') => {
		const componentIds = components.map((item) => item.id);
		const componentNames = components.map((item) => item.name).join('、');
		const prompt = `請解讀我選取的永續環境組件之間的關聯。component_ids=${JSON.stringify(componentIds)}, city=${city}。請用繁體中文回答，並固定分成「各自代表什麼」、「可能的關聯」、「不能直接推論」、「下一步可以看什麼」四段。`;

		chatData.value.push({
			id: chatData.value.length + 1,
			role: 'user',
			isDefault: false,
			content: `解讀所選組件：${componentNames}`,
		});

		try {
			const response = await http.post("/ai/chat/twai", {
				messages: [
					{
						role: "system",
						content: "你是臺北城市儀表板的永續環境資料解讀助理。使用者提供 component_ids 時，你必須先呼叫 get_selected_components_context 取得組件脈絡，再根據工具結果回答。回答要具體、保守，避免硬推因果。"
					},
					{
						role: "user",
						content: prompt
					}
				],
				stream: false,
				tools: aiTools(),
				tool_choice: "auto"
			});

			if (response.data?.status === "success" && response.data.data?.content) {
				const aiResponseContent = response.data.data.content;
				addChatData({
					role: 'bot',
					content: aiResponseContent,
				});
				saveChatLog(prompt, aiResponseContent);
			} else {
				throw new Error("AI response format error");
			}
		} catch (error) {
			console.error("AI Insight Error:", error);
			addChatData({
				role: 'bot',
				content: "抱歉，目前無法產生組件解讀，請稍後再試或檢查後端 AI 設定。",
			});
		}
	};

	const saveChatLog = async(question, answer) => {
		try {
        	const formData = new FormData();
        	const d = new Date();
        	const todayId =
          		d.getFullYear() +
          		String(d.getMonth() + 1).padStart(2, "0") +
          		String(d.getDate()).padStart(2, "0");

        	formData.append("session", "session_" + todayId);
        	formData.append("question", question);
        	formData.append("answer", JSON.stringify(answer));

        	await http.post("/chatlog/", formData, {
          		headers: {
            		"Content-Type": "multipart/form-data",
          		},
        	});
      	} catch (error) {
        	console.error("saveChatLog error:", error);
      	}
	};

	return { chatData, addChatData, addQueryData, chatWithAI, insightSelectedComponents, saveChatLog }
})
