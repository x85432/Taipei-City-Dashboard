--
-- Green store district source data
--

DROP TABLE IF EXISTS public.green_store_district_stats;

CREATE TABLE public.green_store_district_stats (
    city VARCHAR(20),
    district VARCHAR(20),
    store_count INTEGER
);

COPY public.green_store_district_stats (
    city,
    district,
    store_count
) FROM stdin WITH (FORMAT csv);
臺北市,北投區,377
臺北市,士林區,521
臺北市,內湖區,524
臺北市,南港區,253
臺北市,松山區,433
臺北市,信義區,267
臺北市,中山區,571
臺北市,大同區,314
臺北市,中正區,425
臺北市,萬華區,347
臺北市,大安區,586
臺北市,文山區,466
新北市,板橋區,1254
新北市,三重區,959
新北市,中和區,955
新北市,永和區,644
新北市,新莊區,850
新北市,新店區,422
新北市,土城區,444
新北市,蘆洲區,359
新北市,樹林區,319
新北市,汐止區,358
新北市,三峽區,203
新北市,淡水區,308
新北市,鶯歌區,126
新北市,林口區,158
新北市,五股區,234
新北市,泰山區,160
新北市,瑞芳區,20
新北市,八里區,58
新北市,深坑區,26
新北市,三芝區,17
新北市,萬里區,6
新北市,金山區,9
新北市,貢寮區,5
新北市,石門區,7
新北市,雙溪區,16
新北市,石碇區,9
新北市,坪林區,6
新北市,平溪區,0
新北市,烏來區,14
\.
