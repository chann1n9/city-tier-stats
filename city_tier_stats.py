#!/usr/bin/env python3
"""City tier statistics helpers."""

from __future__ import annotations

import argparse
import sys
import warnings
from collections import Counter
from pathlib import Path
from typing import TYPE_CHECKING, Any, Final

import yaml

if TYPE_CHECKING:
    import pandas as pd


DEFAULT_CITY_TIERS_FILE: Final = "city_tiers.yaml"
LOCATION_COLUMN: Final = "归属地"


TIER_ORDER: Final = (
    "new_first",
    "first",
    "second",
    "third",
    "fourth",
    "other",
)


TIER_LABELS: Final = {
    "new_first": "新一线",
    "first": "一线",
    "second": "二线",
    "third": "三线",
    "fourth": "四线",
    "other": "其他",
}


def bundled_base_dir() -> Path | None:
    """Return PyInstaller's unpacked bundle directory when available."""
    bundle_dir = getattr(sys, "_MEIPASS", None)
    if bundle_dir:
        return Path(bundle_dir)
    return None


def default_config_candidates() -> list[Path]:
    """Build default config lookup paths."""
    candidates = [Path.cwd() / DEFAULT_CITY_TIERS_FILE]

    executable_dir = Path(sys.executable).resolve().parent
    script_dir = Path(__file__).resolve().parent
    for base_dir in (executable_dir, script_dir, bundled_base_dir()):
        if base_dir is None:
            continue
        candidate = base_dir / DEFAULT_CITY_TIERS_FILE
        if candidate not in candidates:
            candidates.append(candidate)

    return candidates


def resolve_config_path(config_path: str | Path | None = None) -> Path:
    """Resolve user config or the bundled/default city tiers config."""
    if config_path:
        path = Path(config_path)
        if not path.exists():
            raise FileNotFoundError(f"找不到城市分层配置文件：{path}")
        return path

    for path in default_config_candidates():
        if path.exists():
            return path

    searched = "\n".join(f"- {path}" for path in default_config_candidates())
    raise FileNotFoundError(f"找不到默认城市分层配置文件，已查找：\n{searched}")


def is_empty_value(value: Any) -> bool:
    """Return whether a raw spreadsheet value should be treated as empty."""
    if value is None:
        return True
    try:
        return bool(value != value)
    except TypeError:
        return False


def read_location_column(file_path: str | Path, column_name: str = LOCATION_COLUMN) -> "pd.Series":
    """Read the location column from an Excel or CSV file."""
    import pandas as pd

    path = Path(file_path)
    suffix = path.suffix.lower()

    if suffix == ".xlsx":
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="Workbook contains no default style, apply openpyxl's default",
                category=UserWarning,
            )
            data = pd.read_excel(path, engine="openpyxl")
    elif suffix == ".csv":
        data = pd.read_csv(path)
    else:
        raise ValueError(f"不支持的文件类型：{suffix or '无扩展名'}")

    if column_name not in data.columns:
        raise ValueError(f"文件中没有找到列：{column_name}")

    return data[column_name]


def extract_city_name(raw_location: Any) -> str:
    """Extract city from values like '重庆-重庆-九龙坡'."""
    if is_empty_value(raw_location):
        return ""

    location = str(raw_location).strip()
    if not location:
        return ""

    for separator in ("－", "—", "–"):
        location = location.replace(separator, "-")

    parts = [part.strip() for part in location.split("-") if part.strip()]
    if len(parts) >= 2:
        return parts[1]
    return location


def normalize_city_name(city_name: Any) -> str:
    """Normalize city names before matching."""
    if is_empty_value(city_name):
        return ""

    city = str(city_name).strip()
    if city.endswith("市"):
        city = city[:-1]
    return city


def city_match_keys(city_name: Any) -> set[str]:
    """Build practical match keys for city names in config and input."""
    city = normalize_city_name(city_name)
    if not city:
        return set()

    keys = {city}
    for suffix in ("地区", "盟"):
        if city.endswith(suffix):
            keys.add(city[: -len(suffix)])

    if city.endswith("自治州"):
        keys.add(city[: -len("自治州")])

    return keys


def load_city_tier_mapping(config_path: str | Path | None = None) -> dict[str, str]:
    """Load city-to-tier mapping from YAML."""
    path = resolve_config_path(config_path)
    with path.open("r", encoding="utf-8") as file:
        config = yaml.safe_load(file) or {}

    tiers = config.get("tiers")
    if not isinstance(tiers, dict):
        raise ValueError("YAML 配置缺少 tiers 字段")

    city_to_tier: dict[str, str] = {}
    valid_tiers = set(TIER_ORDER) - {"other"}

    for tier, cities in tiers.items():
        if tier not in valid_tiers:
            raise ValueError(f"YAML 配置中存在未知城市分层：{tier}")
        if cities is None:
            continue
        if not isinstance(cities, list):
            raise ValueError(f"YAML 配置中 {tier} 必须是城市列表")

        for city in cities:
            for key in city_match_keys(city):
                existing_tier = city_to_tier.get(key)
                if existing_tier and existing_tier != tier:
                    raise ValueError(f"城市重复出现在多个分层：{city}")
                city_to_tier[key] = tier

    return city_to_tier


def match_city_tier(city_name: Any, city_to_tier: dict[str, str]) -> str:
    """Match a city name to its tier, defaulting to other."""
    for key in city_match_keys(city_name):
        tier = city_to_tier.get(key)
        if tier:
            return tier
    return "other"


def match_location_tier(raw_location: Any, city_to_tier: dict[str, str]) -> str:
    """Extract city from a raw location value and match it to a tier."""
    city_name = extract_city_name(raw_location)
    return match_city_tier(city_name, city_to_tier)


def calculate_tier_stats(
    locations: "pd.Series",
    city_to_tier: dict[str, str],
) -> list[dict[str, int | float | str]]:
    """Count city tiers and percentages from a location series."""
    tiers = locations.map(lambda value: match_location_tier(value, city_to_tier))
    counts = Counter(tiers)
    total = len(locations)

    results: list[dict[str, int | float | str]] = []
    for tier in TIER_ORDER:
        count = counts.get(tier, 0)
        percentage = count / total if total else 0
        results.append(
            {
                "tier": tier,
                "label": TIER_LABELS[tier],
                "count": count,
                "percentage": percentage,
            }
        )
    return results


def build_location_details(
    locations: "pd.Series",
    city_to_tier: dict[str, str],
) -> "pd.DataFrame":
    """Build row-level location matching details."""
    import pandas as pd

    details = pd.DataFrame({"归属地": locations})
    details["城市"] = details["归属地"].map(extract_city_name)
    details["城市归一化"] = details["城市"].map(normalize_city_name)
    details["分层代码"] = details["城市"].map(lambda value: match_city_tier(value, city_to_tier))
    details["分层"] = details["分层代码"].map(TIER_LABELS)
    return details


def write_location_details(details: "pd.DataFrame", output_path: str | Path) -> None:
    """Write row-level location matching details to a CSV or XLSX file."""
    path = Path(output_path)
    suffix = path.suffix.lower()

    if suffix == ".xlsx":
        details.to_excel(path, index=False)
    elif suffix == ".csv":
        details.to_csv(path, index=False, encoding="utf-8-sig")
    else:
        raise ValueError(f"明细文件只支持 .xlsx、.csv：{suffix or '无扩展名'}")


def output_tier_stats(stats: list[dict[str, int | float | str]]) -> None:
    """Print city tier statistics."""
    total = sum(int(row["count"]) for row in stats)

    print(f"总数: {total}")

    for row in stats:
        label = str(row["label"])
        count = int(row["count"])
        percentage = float(row["percentage"])
        print(f"{label}: {count}, {percentage:.2%}")


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="统计归属地城市分层数量和占比")
    parser.add_argument("file", help="输入文件，支持 .xlsx、.csv")
    parser.add_argument(
        "-c",
        "--config",
        help=f"自定义城市分层 YAML 配置文件；不传则自动查找 {DEFAULT_CITY_TIERS_FILE}",
    )
    parser.add_argument(
        "--column",
        default=LOCATION_COLUMN,
        help=f"归属地列名，默认：{LOCATION_COLUMN}",
    )
    parser.add_argument(
        "--detail-output",
        help="导出逐行匹配明细，支持 .xlsx、.csv；默认不导出",
    )
    return parser.parse_args()


def main() -> None:
    """Run command line entrypoint."""
    args = parse_args()
    city_to_tier = load_city_tier_mapping(args.config)
    locations = read_location_column(args.file, args.column)
    stats = calculate_tier_stats(locations, city_to_tier)
    output_tier_stats(stats)

    if args.detail_output:
        details = build_location_details(locations, city_to_tier)
        write_location_details(details, args.detail_output)
        print(f"明细已导出: {args.detail_output}")


if __name__ == "__main__":
    main()
