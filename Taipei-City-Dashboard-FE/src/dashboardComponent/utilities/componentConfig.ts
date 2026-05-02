export type ComponentConfig = {
	id: number;
	index: string;
	chart_config: ChartConfig;
	chart_data: any;
	query_data: string;
	map_config: MapConfig[] | null;
	map_filter: MapFilter | null;
	history_config: HistoryConfig | null;
	name: string;
	source: string;
	time_from: string;
	time_to: string;
	update_freq: number | null;
	update_freq_unit: string | null;
	short_desc: string;
};

export type ChartConfig = {
	color: string[];
	types: string[];
	unit: string | null;
	categories: string[] | null;
	timeline_config: TimelineConfig | null;
};

export type MapConfig = {
	index: string;
	paint: any;
	property: any[];
	title: string;
	type: string;
	size: string | null;
	icon: string | null;
	source: string;
};

export type MapFilter = {
	mode: string;
	byParam: {
		xParam: string;
		yParam: string;
	} | null;
};

export type HistoryConfig = {
	color: string[] | null;
	range: string[];
};

export type TimelineConfig = {
	enabled: boolean;
	granularity?: "year" | "month" | "auto";
	field?: string;
	timeField?: string;
	nameDelimiter?: string | string[];
	sort?: "asc" | "desc" | null;
} | boolean;
