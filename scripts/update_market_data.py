#!/usr/bin/env python3
"""Build the bundled 70-city housing index dataset from NBS release pages."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen


BASE_URL = "https://www.stats.gov.cn/sj/zxfb/"
ARTICLE_PATTERN = re.compile(
    r"""href=["']([^"']+)["'][^>]*title=["'](\d{4})年(\d{1,2})月份"""
    r"""70个大中城市商品住宅销售价格变动情况["']"""
)
MANUAL_ARTICLES = {
    (2024, 1): "https://www.stats.gov.cn/sj/zxfb/202402/t20240223_1947806.html",
    (2025, 1): "https://www.stats.gov.cn/sj/zxfb/202502/t20250219_1958761.html",
    (2026, 1): "https://www.stats.gov.cn/sj/zxfb/202602/t20260213_1962617.html",
}


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tables: list[list[list[str]]] = []
        self._table: list[list[str]] | None = None
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table":
            self._table = []
            self.tables.append(self._table)
        elif tag == "tr" and self._table is not None:
            self._row = []
            self._table.append(self._row)
        elif tag in ("td", "th") and self._row is not None:
            self._cell = []
            self._row.append("")

    def handle_data(self, data: str) -> None:
        if self._cell is not None and self._row is not None:
            self._row[-1] += data

    def handle_endtag(self, tag: str) -> None:
        if tag in ("td", "th"):
            self._cell = None
        elif tag == "tr":
            self._row = None
        elif tag == "table":
            self._table = None


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "Mozilla/5.0 HuJuDataSync/1.0"})
    for attempt in range(3):
        try:
            with urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8")
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    raise RuntimeError("unreachable")


def clean(value: str) -> str:
    return re.sub(r"\s+", "", html.unescape(value)).replace("\u3000", "")


def number(value: str) -> float | None:
    try:
        return float(clean(value))
    except ValueError:
        return None


def discover_articles(start_year: int, end_year: int) -> dict[tuple[int, int], str]:
    articles = dict(MANUAL_ARTICLES)
    for page in range(0, 70):
        url = BASE_URL if page == 0 else urljoin(BASE_URL, f"index_{page}.html")
        source = fetch(url)
        found_in_range = False
        for path, year_text, month_text in ARTICLE_PATTERN.findall(source):
            year, month = int(year_text), int(month_text)
            if start_year <= year <= end_year:
                articles[(year, month)] = urljoin(url, path)
                found_in_range = True
        if page > 5 and not found_in_range and articles:
            oldest_year = min(year for year, _ in articles)
            if oldest_year <= start_year and page > 40:
                break
    return {
        key: value
        for key, value in articles.items()
        if start_year <= key[0] <= end_year
    }


def parse_overall(table: list[list[str]]) -> dict[str, tuple[float, float]]:
    result: dict[str, tuple[float, float]] = {}
    for row in table:
        cells = [clean(cell) for cell in row]
        if len(cells) < 6:
            continue
        half = len(cells) // 2
        for start in (0, half):
            if start + 2 >= len(cells):
                continue
            city = cells[start]
            month_value = number(cells[start + 1])
            year_value = number(cells[start + 2])
            if city and month_value is not None and year_value is not None:
                result[city] = (month_value, year_value)
    return result


def parse_bands(tables: list[list[list[str]]]) -> dict[str, list[dict[str, float | str]]]:
    result: dict[str, list[dict[str, float | str]]] = {}
    for table in tables:
        for row in table:
            cells = [clean(cell) for cell in row]
            if len(cells) < 7:
                continue
            city = cells[0]
            values = [number(value) for value in cells[1:]]
            if not city or len(values) < 6 or any(value is None for value in values[:6]):
                continue
            stride = 3 if len(values) >= 9 else 2
            result[city] = [
                {
                    "title": "90 平方米以下",
                    "monthOverMonthIndex": values[0],
                    "yearOverYearIndex": values[1],
                },
                {
                    "title": "90 至 144 平方米",
                    "monthOverMonthIndex": values[stride],
                    "yearOverYearIndex": values[stride + 1],
                },
                {
                    "title": "144 平方米以上",
                    "monthOverMonthIndex": values[stride * 2],
                    "yearOverYearIndex": values[stride * 2 + 1],
                },
            ]
    return result


def parse_article(url: str, year: int, month: int) -> tuple[dict[str, dict], str]:
    source = fetch(url)
    parser = TableParser()
    parser.feed(source)
    if len(parser.tables) < 6:
        raise ValueError(f"Expected at least six data tables at {url}")

    new_home = parse_overall(parser.tables[0])
    resale = parse_overall(parser.tables[1])
    new_bands = parse_bands(parser.tables[2:4])
    resale_bands = parse_bands(parser.tables[4:6])
    cities = set(new_home) & set(resale)
    if len(cities) != 70:
        raise ValueError(f"Expected 70 cities at {url}, found {len(cities)}")

    records: dict[str, dict] = {}
    for city in cities:
        records[city] = {
            "year": year,
            "month": month,
            "newMonthOverMonthIndex": new_home[city][0],
            "newYearOverYearIndex": new_home[city][1],
            "resaleMonthOverMonthIndex": resale[city][0],
            "resaleYearOverYearIndex": resale[city][1],
            "newHomeAreaBands": new_bands.get(city, []),
            "resaleAreaBands": resale_bands.get(city, []),
        }

    published = re.search(r'<meta name="PubDate" content="([^"]+)"', source)
    return records, published.group(1) if published else ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-year", type=int, default=2024)
    parser.add_argument("--end-year", type=int, default=2026)
    parser.add_argument(
        "--city",
        action="append",
        dest="cities",
        help="City to include in the app bundle. Repeat to filter; defaults to all 70 cities.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "HuJu" / "MarketData.json",
    )
    args = parser.parse_args()
    selected_cities = set(args.cities) if args.cities else None

    articles = discover_articles(args.start_year, args.end_year)
    expected = {
        (year, month)
        for year in range(args.start_year, args.end_year + 1)
        for month in range(1, 13)
        if (year, month) <= (2026, 7)
    }
    missing = sorted(expected - set(articles))
    if missing:
        print(f"Missing article URLs: {missing}", file=sys.stderr)
        return 1

    cities: dict[str, list[dict]] = {}
    sources: list[dict] = []
    for (year, month), url in sorted(articles.items()):
        records, published = parse_article(url, year, month)
        for city, record in records.items():
            cities.setdefault(city, []).append(record)
        sources.append(
            {
                "year": year,
                "month": month,
                "publishedAt": published,
                "url": url,
            }
        )
        print(f"Fetched {year}-{month:02d}: {len(records)} cities")

    payload = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "sourceName": "国家统计局 · 70 个大中城市住宅销售价格指数",
        "cities": [
            {"name": city, "records": records}
            for city, records in sorted(cities.items())
            if selected_cities is None or city in selected_cities
        ],
        "sources": sources,
    }
    missing_cities = (selected_cities or set()) - set(cities)
    if missing_cities:
        print(f"Missing selected cities: {sorted(missing_cities)}", file=sys.stderr)
        return 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {args.output} with {len(payload['cities'])} cities")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
