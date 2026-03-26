#!/usr/bin/env python3
"""
更新 store_locations.json 中的四大便利商店資料。

目前支援：
- 7-ELEVEN：從官方 emap.pcsc.com.tw API 爬取
- 全家 FamilyMart：保留現有資料（官方 API 需瀏覽器端 JS SDK，無法腳本爬取）
- 萊爾富 Hi-Life：保留現有 OSM 資料
- OK 超商：保留現有 OSM 資料
"""

import json
import re
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import requests

STORE_FILE = Path(__file__).resolve().parent.parent / "lib" / "data" / "store_locations.json"
STATS_FILE = Path("/tmp/store-update-stats.md")

SEVEN_CITIES = {
    "01": "台北市", "02": "基隆市", "03": "新北市", "04": "桃園市",
    "05": "新竹市", "06": "新竹縣", "07": "苗栗縣", "08": "台中市",
    "10": "彰化縣", "11": "南投縣", "12": "雲林縣", "13": "嘉義市",
    "14": "嘉義縣", "15": "台南市", "17": "高雄市", "19": "屏東縣",
    "20": "宜蘭縣", "21": "花蓮縣", "22": "台東縣", "23": "澎湖縣",
    "25": "金門縣", "24": "連江縣",
}

DELAY = 0.3
SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
})


# ---------------------------------------------------------------------------
# 7-ELEVEN
# ---------------------------------------------------------------------------

def seven_get_towns(city_id: str) -> list[str]:
    """取得某城市的所有區/鄉/鎮名稱。"""
    r = SESSION.post(
        "https://emap.pcsc.com.tw/EMapSDK.aspx",
        data={"commandid": "GetTown", "cityid": city_id},
        timeout=15,
    )
    r.raise_for_status()
    root = ET.fromstring(r.text)
    return [el.text for el in root.iter("TownName") if el.text]


def seven_search_stores(city: str, town: str) -> list[dict]:
    """搜尋某城市某區的全部門市。"""
    r = SESSION.post(
        "https://emap.pcsc.com.tw/EMapSDK.aspx",
        data={"commandid": "SearchStore", "city": city, "town": town},
        timeout=15,
    )
    r.raise_for_status()
    root = ET.fromstring(r.text)
    stores = []
    for pos in root.iter("GeoPosition"):
        name_el = pos.find("POIName")
        x_el = pos.find("X")
        y_el = pos.find("Y")
        if name_el is None or x_el is None or y_el is None:
            continue
        name = (name_el.text or "").strip()
        try:
            x = float(x_el.text)
            y = float(y_el.text)
        except (TypeError, ValueError):
            continue
        if not name or x == 0 or y == 0:
            continue
        # 座標格式：整數 > 1000 表示需要除以某個因子
        lng = x / 1_000_000 if x > 1000 else x
        lat = y / 1_000_000 if y > 1000 else y
        # 基本合理範圍檢查（台灣本島+離島，金門~118.3, 馬祖~119.9）
        if not (21 < lat < 27 and 117 < lng < 123):
            continue
        stores.append({"name": name, "lat": round(lat, 6), "lng": round(lng, 6), "radius": 100})
    return stores


def fetch_seven_eleven() -> list[dict]:
    """爬取全台 7-ELEVEN 門市。"""
    all_stores = []
    seen_names = set()
    total_cities = len(SEVEN_CITIES)

    for idx, (city_id, city_name) in enumerate(SEVEN_CITIES.items(), 1):
        print(f"  7-ELEVEN: [{idx}/{total_cities}] {city_name} ...", end="", flush=True)
        try:
            towns = seven_get_towns(city_id)
        except Exception as e:
            print(f" ⚠ GetTown 失敗: {e}")
            continue
        time.sleep(DELAY)

        city_count = 0
        for town in towns:
            try:
                stores = seven_search_stores(city_name, town)
                for s in stores:
                    if s["name"] not in seen_names:
                        seen_names.add(s["name"])
                        all_stores.append(s)
                        city_count += 1
            except Exception as e:
                print(f" ⚠ {town} 失敗: {e}", end="")
            time.sleep(DELAY)

        print(f" {city_count} 家")

    return all_stores


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print(f"讀取 {STORE_FILE} ...")
    with open(STORE_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    old_version = data["version"]
    old_counts = {brand: len(info["locations"]) for brand, info in data["stores"].items()}

    # --- 7-ELEVEN ---
    print("\n=== 爬取 7-ELEVEN ===")
    seven_stores = fetch_seven_eleven()
    print(f"  合計: {len(seven_stores)} 家（去重後）")

    if seven_stores:
        data["stores"]["7-ELEVEN"]["locations"] = seven_stores
    else:
        print("  ⚠ 7-ELEVEN 爬取結果為空，保留原有資料")

    # --- 全家 ---
    print("\n=== 全家 FamilyMart ===")
    print("  保留現有資料（官方 API 需瀏覽器端 JS SDK）")

    # --- 萊爾富 / OK ---
    print("\n=== 萊爾富 Hi-Life / OK 超商 ===")
    print("  保留現有 OSM 資料")

    # --- 更新版本 ---
    data["version"] = old_version + 1

    # --- 寫回檔案 ---
    print(f"\n寫回 {STORE_FILE} ...")
    with open(STORE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # --- 統計 ---
    new_counts = {brand: len(info["locations"]) for brand, info in data["stores"].items()}
    total_old = sum(old_counts.values())
    total_new = sum(new_counts.values())

    stats_lines = [
        "# 門市資料更新統計",
        "",
        f"- 版本: {old_version} → {data['version']}",
        f"- 總筆數: {total_old:,} → {total_new:,} (差異: {total_new - total_old:+,})",
        "",
        "## 品牌明細",
        "",
        "| 品牌 | 更新前 | 更新後 | 差異 |",
        "|------|--------|--------|------|",
    ]

    for brand in data["stores"]:
        old = old_counts.get(brand, 0)
        new = new_counts.get(brand, 0)
        diff = new - old
        marker = " ✱" if diff != 0 else ""
        stats_lines.append(f"| {brand} | {old:,} | {new:,} | {diff:+,}{marker} |")

    stats_text = "\n".join(stats_lines) + "\n"
    print(stats_text)

    STATS_FILE.write_text(stats_text, encoding="utf-8")
    print(f"統計已寫入 {STATS_FILE}")


if __name__ == "__main__":
    main()
