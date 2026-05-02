# source: dataset-analysis/eco-friendly/*.csv
# target: ../Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_metrotaipei.geojson
# target: ../Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_taipei.geojson

import os
import csv
import re
import json
import random

DISTRICT_CENTERS = {
    '松山區': (121.558, 25.060), '信義區': (121.570, 25.030), '大安區': (121.543, 25.026),
    '中山區': (121.533, 25.064), '中正區': (121.517, 25.032), '大同區': (121.516, 25.063),
    '萬華區': (121.499, 25.033), '文山區': (121.576, 24.990), '南港區': (121.606, 25.055),
    '內湖區': (121.590, 25.070), '士林區': (121.524, 25.090), '北投區': (121.500, 25.132),
    '板橋區': (121.459, 25.014), '中和區': (121.498, 24.999), '永和區': (121.515, 25.008),
    '新莊區': (121.446, 25.036), '三重區': (121.492, 25.063), '蘆洲區': (121.474, 25.084),
    '新店區': (121.540, 24.968), '土城區': (121.442, 24.973), '三峽區': (121.366, 24.934),
    '樹林區': (121.423, 24.992), '鶯歌區': (121.353, 24.954), '泰山區': (121.431, 25.056),
    '五股區': (121.438, 25.082), '汐止區': (121.661, 25.066), '淡水區': (121.440, 25.169),
    '八里區': (121.398, 25.146), '林口區': (121.390, 25.077), '瑞芳區': (121.805, 25.108)
}

def get_approximate_coord(district):
    center = DISTRICT_CENTERS.get(district, (121.5, 25.05))
    lon = center[0] + random.uniform(-0.015, 0.015)
    lat = center[1] + random.uniform(-0.015, 0.015)
    return lon, lat

def get_district_from_address(addr, default_val=''):
    for d in DISTRICT_CENTERS.keys():
        if d in addr:
            return d
    return default_val

def sanitize(text):
    if not text: return ''
    return text.replace('\n', ' ').replace('\r', '').replace('\t', ' ').strip()

def generate_geojson():
    try:
        base_dir = r"../dataset-analysis/eco-friendly"
        results = []
        
        def read_csv(filename, encoding='utf-8'):
            path = os.path.join(base_dir, filename)
            if not os.path.exists(path): return []
            try:
                with open(path, 'r', encoding=encoding) as f:
                    return list(csv.DictReader(f))
            except UnicodeDecodeError:
                with open(path, 'r', encoding='big5') as f:
                    return list(csv.DictReader(f))

        # 1. 臺北市綠色商店
        data = read_csv('臺北市綠色商店1130429.csv')
        for row in data:
            addr = sanitize(row.get('聯絡地址', ''))
            name = sanitize(row.get('綠色商店名稱', ''))
            district = get_district_from_address(addr)
            lon, lat = get_approximate_coord(district)
            results.append({'city': '臺北市', 'district': district, 'category': '綠色商店', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})
            
        # 2. 新北市綠色商店
        data = read_csv('新北市綠色商店_export.csv')
        for row in data:
            addr = sanitize(row.get('address', ''))
            name = sanitize(row.get('name', ''))
            district = get_district_from_address(addr)
            lon, lat = get_approximate_coord(district)
            results.append({'city': '新北市', 'district': district, 'category': '綠色商店', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})
            
        # 3. 臺北限時收受點
        data = read_csv('●115年開放時間 (限時收受點csv) 1150223.csv', encoding='big5')
        for row in data:
            addr = sanitize(row.get('地址', ''))
            name = sanitize(row.get('分隊', '') + ' 限時收受點')
            district = row.get('行政區', '')
            lon = row.get('經度', '')
            lat = row.get('緯度', '')
            lon = float(lon) if lon else get_approximate_coord(district)[0]
            lat = float(lat) if lat else get_approximate_coord(district)[1]
            results.append({'city': '臺北市', 'district': district, 'category': '資源回收', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})
            
        # 4. 新北市黃金資收站
        data = read_csv('新北市黃金資收站資訊_export.csv')
        for row in data:
            addr = sanitize(row.get('recycle_address', ''))
            if not addr: addr = sanitize(row.get('address', ''))
            name = sanitize(row.get('name', ''))
            district = row.get('district', '')
            lon, lat = get_approximate_coord(district)
            results.append({'city': '新北市', 'district': district, 'category': '資源回收', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})

        # 5. 電動車充電站
        ev_files = [
            ('115年臺北市電動機車充電地點(398).csv', '臺北市'),
            ('臺北市營利電動車充電站-240站.csv', '臺北市'),
            ('臺北市營利電動機車充電站-12站.csv', '臺北市'),
            ('臺北市營利電動機車換電站-365站.csv', '臺北市'),
            ('新北市電動機車充電站_export.csv', '新北市'),
            ('新北市電動汽車充電站_export.csv', '新北市')
        ]
        for file, city in ev_files:
            data = read_csv(file)
            for row in data:
                addr = sanitize(row.get('地址', row.get('location address', '')))
                name = sanitize(row.get('名稱', row.get('charging station name', row.get('單位', '充電站'))))
                district = row.get('行政區', row.get('administrative district', ''))
                if not district:
                    district = get_district_from_address(addr)
                lon, lat = get_approximate_coord(district)
                results.append({'city': city, 'district': district, 'category': '充電站', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})

        # Extract existing from dashboard-eco-restaurant.sql
        try:
            with open(r'../db-sample-data/dashboard-eco-restaurant.sql', 'r', encoding='utf-8') as f:
                content = f.read()
                copy_block = re.search(r'COPY public.taipei_eco_restaurants .*?FROM stdin;(.*?)\\\.', content, re.DOTALL)
                if copy_block:
                    lines = copy_block.group(1).strip().split('\n')
                    for line in lines:
                        parts = line.split('\t')
                        if len(parts) >= 12:
                            name = sanitize(parts[2])
                            addr = sanitize(parts[5])
                            district = parts[6] if parts[6] and parts[6] != '\\N' else get_district_from_address(addr)
                            lon = float(parts[10]) if parts[10] != '\\N' else get_approximate_coord(district)[0]
                            lat = float(parts[11]) if parts[11] != '\\N' else get_approximate_coord(district)[1]
                            results.append({'city': '臺北市', 'district': district, 'category': '環保餐廳', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})
        except Exception:
            pass
                        
        # New Taipei Restaurants
        data = read_csv('新北市環保餐廳_export.csv')
        for row in data:
            addr = sanitize(row.get('address', ''))
            name = sanitize(row.get('name', ''))
            district = get_district_from_address(addr)
            lon, lat = get_approximate_coord(district)
            results.append({'city': '新北市', 'district': district, 'category': '環保餐廳', 'name': name, 'address': addr, 'lon': lon, 'lat': lat})

        # Generate GeoJSONs
        taipei_features = []
        metro_features = []
        
        for r in results:
            feat = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [r['lon'], r['lat']]
                },
                "properties": {
                    "city": r['city'],
                    "district": r['district'],
                    "category": r['category'],
                    "name": r['name'],
                    "address": r['address']
                }
            }
            metro_features.append(feat)
            if r['city'] == '臺北市':
                taipei_features.append(feat)
                
        taipei_geojson = {"type": "FeatureCollection", "features": taipei_features}
        metro_geojson = {"type": "FeatureCollection", "features": metro_features}
        
        os.makedirs(r'../Taipei-City-Dashboard-FE/public/mapData', exist_ok=True)
        with open(r'../Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_taipei.geojson', 'w', encoding='utf-8') as f:
            json.dump(taipei_geojson, f, ensure_ascii=False, indent=2)
        with open(r'../Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_metrotaipei.geojson', 'w', encoding='utf-8') as f:
            json.dump(metro_geojson, f, ensure_ascii=False, indent=2)
            
        print("Successfully generated Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_taipei.geojson")
        print("Successfully generated Taipei-City-Dashboard-FE/public/mapData/eco_living_15min_metrotaipei.geojson")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_geojson()
