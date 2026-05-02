package tools

import (
	"TaipeiCityDashboardBE/app/models"
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type SelectedComponentsArgs struct {
	ComponentIDs []int  `json:"component_ids"`
	City         string `json:"city"`
	SampleLimit  int    `json:"sample_limit"`
}

type ComponentInsightContext struct {
	ID          int64           `json:"id"`
	Index       string          `json:"index"`
	Name        string          `json:"name"`
	City        string          `json:"city"`
	QueryType   string          `json:"query_type"`
	Source      string          `json:"source"`
	ShortDesc   string          `json:"short_desc"`
	LongDesc    string          `json:"long_desc"`
	UseCase     string          `json:"use_case"`
	Links       []string        `json:"links"`
	SampleData  []map[string]any `json:"sample_data,omitempty"`
	SampleNote  string          `json:"sample_note,omitempty"`
	ReadLimits  []string        `json:"read_limits"`
}

func GetSelectedComponentsContext(ctx context.Context, args string) (string, error) {
	var params SelectedComponentsArgs
	if err := parseArgs(args, &params); err != nil {
		return "", fmt.Errorf("invalid arguments: %v", err)
	}
	if len(params.ComponentIDs) == 0 {
		return "", fmt.Errorf("component_ids is required")
	}
	if len(params.ComponentIDs) > 4 {
		return "", fmt.Errorf("please select at most 4 components")
	}
	if params.City == "" {
		params.City = "taipei"
	}
	if params.SampleLimit <= 0 || params.SampleLimit > 20 {
		params.SampleLimit = 12
	}

	contexts := make([]ComponentInsightContext, 0, len(params.ComponentIDs))
	for _, id := range params.ComponentIDs {
		component, err := models.GetComponentByID(id, params.City)
		if err != nil && params.City != "" {
			all, allErr := models.GetComponentByIDAll(id)
			if allErr == nil && len(all) > 0 {
				component = all[0]
				err = nil
			}
		}
		if err != nil {
			return "", fmt.Errorf("component %d not found: %v", id, err)
		}

		item := ComponentInsightContext{
			ID:         component.ID,
			Index:      component.Index,
			Name:       component.Name,
			City:       component.City,
			QueryType:  component.QueryType,
			Source:     component.Source,
			ShortDesc:  component.ShortDesc,
			LongDesc:   component.LongDesc,
			UseCase:    component.UseCase,
			Links:      []string(component.Links),
			ReadLimits: defaultReadLimits(component.QueryType),
		}

		sample, note := sampleComponentData(component.QueryChart, params.SampleLimit)
		item.SampleData = sample
		item.SampleNote = note
		contexts = append(contexts, item)
	}

	payload := map[string]any{
		"instruction": "Use this trusted dashboard context to explain relationships. Do not claim causality unless explicitly supported. Mention data limits.",
		"city":        params.City,
		"components":  contexts,
	}
	out, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func sampleComponentData(query string, limit int) ([]map[string]any, string) {
	query = strings.TrimSpace(strings.TrimSuffix(query, ";"))
	if query == "" {
		return nil, "No chart query is configured for this component."
	}
	if strings.Contains(query, "%s") {
		return nil, "This component needs a time range, so the tool returned metadata only."
	}

	rows := []map[string]any{}
	wrapped := fmt.Sprintf("SELECT * FROM (%s) AS ai_component_sample LIMIT %d", query, limit)
	if err := models.DBDashboard.Raw(wrapped).Scan(&rows).Error; err != nil {
		return nil, fmt.Sprintf("Sample query failed: %v", err)
	}
	for _, row := range rows {
		for key, val := range row {
			if b, ok := val.([]byte); ok {
				row[key] = string(b)
			}
		}
	}
	return rows, ""
}

func defaultReadLimits(queryType string) []string {
	limits := []string{
		"這些資料可用於描述現況與比較差異，但不能單獨證明因果關係。",
		"解讀時應同時注意資料來源、統計口徑與更新時間。",
	}
	if queryType == "three_d" || queryType == "percent" {
		limits = append(limits, "多維圖表常用於比較分類與行政區，數值高低不一定代表政策效果好壞。")
	}
	if queryType == "time" {
		limits = append(limits, "時間序列可觀察趨勢，但短期波動可能受季節、資料更新或事件影響。")
	}
	return limits
}
