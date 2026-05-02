--
-- Food carbon footprint category source data
-- Values keep source label units and include a normalized gCO2e per gram value.
-- Normalization assumptions:
--   每公克: unchanged
--   每毫升: 1 ml ~= 1 g
--   每顆: 1 egg ~= 60 g
--

DROP TABLE IF EXISTS public.food_carbon_categories;

CREATE TABLE public.food_carbon_categories (
    category VARCHAR(50),
    product_count INTEGER,
    unit_avg_carbon_gco2e double precision,
    unit_basis VARCHAR(20),
    carbon_gco2e_per_gram double precision,
    normalization_note VARCHAR(80),
    min_carbon_gco2e double precision,
    max_carbon_gco2e double precision
);

COPY public.food_carbon_categories (
    category,
    product_count,
    unit_avg_carbon_gco2e,
    unit_basis,
    carbon_gco2e_per_gram,
    normalization_note,
    min_carbon_gco2e,
    max_carbon_gco2e
) FROM stdin WITH (FORMAT csv);
蛋,15,110.06,每顆,1.83,以每顆蛋約60公克換算,93.33,149.20
奶油,4,18.90,每公克,18.90,來源已為每公克,17.78,20.00
蔬菜,12,12.00,每公克,12.00,來源已為每公克,0.83,66.67
魚肉,6,10.01,每公克,10.01,來源已為每公克,7.41,12.22
豬肉,46,7.04,每公克,7.04,來源已為每公克,6.50,9.96
雞肉,24,6.11,每公克,6.11,來源已為每公克,4.00,9.00
米粉及調和米粉(絲),2,5.00,每公克,5.00,來源已為每公克,5.00,5.00
酒,15,4.67,每毫升,4.67,以1毫升約1公克換算,3.67,6.00
燕麥,2,3.82,每公克,3.82,來源已為每公克,3.64,4.00
咖啡,5,3.16,每公克,3.16,來源已為每公克,0.69,7.33
魚製品,5,3.06,每公克,3.06,來源已為每公克,2.08,4.13
米,11,2.44,每公克,2.44,來源已為每公克,0.99,3.95
水果,2,2.16,每公克,2.16,來源已為每公克,1.57,2.75
油,21,1.88,每毫升,1.88,以1毫升約1公克換算,1.00,9.30
果汁,7,1.35,每毫升,1.35,以1毫升約1公克換算,0.64,4.00
豆穀類飲品,4,0.92,每毫升,0.92,以1毫升約1公克換算,0.82,1.03
碳酸飲料,9,0.65,每毫升,0.65,以1毫升約1公克換算,0.44,0.86
茶飲料,25,0.49,每毫升,0.49,以1毫升約1公克換算,0.33,0.86
運動飲料,7,0.48,每毫升,0.48,以1毫升約1公克換算,0.29,0.82
水,10,0.37,每毫升,0.37,以1毫升約1公克換算,0.10,0.63
\.
