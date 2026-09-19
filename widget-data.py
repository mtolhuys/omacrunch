"""Small read-only widget collectors. No credentials or conversation logs are read."""
import datetime as dt
import json
import math
import os
from pathlib import Path
import sys
import urllib.parse
import urllib.request

LIMIT = 1_048_576


def read_json(path):
    with open(path, "rb") as stream:
        content = stream.read(LIMIT + 1)
    if len(content) > LIMIT:
        raise ValueError("Record too large")
    return json.loads(content)


def fetch(host, route, params):
    # Hosts are constants at the call sites. No redirects to arbitrary hosts.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    url = "https://" + host + route + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": "Omacrunch/0.5"})
    with urllib.request.build_opener(NoRedirect).open(request, timeout=7) as response:
        content = response.read(LIMIT + 1)
    if len(content) > LIMIT:
        raise ValueError("Response too large")
    return json.loads(content)


def disks():
    result = []
    for name, path in [("System /", Path("/")), ("Home", Path.home())]:
        stat = os.statvfs(path)
        total = stat.f_blocks * stat.f_frsize
        available = stat.f_bavail * stat.f_frsize
        used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        result.append({"name": name, "total": total, "available": available,
                       "used": used, "percent": 100 * used / max(1, used + available)})
    return {"rows": result}


def agents():
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    directory = base / "omarchy/agents/usage"
    rows = []
    if not directory.is_dir():
        return {"rows": rows}
    for path in sorted(directory.glob("*.json"))[:16]:
        try:
            record = read_json(path)
            if not isinstance(record, dict):
                continue
            limits = []
            for limit in record.get("limits", [])[:3]:
                percent = limit.get("percent")
                if isinstance(percent, (int, float)) and math.isfinite(percent):
                    limits.append({"label": str(limit.get("label", "Usage"))[:60],
                                   "percent": min(100, max(0, percent * 100)),
                                   "resetsAt": str(limit.get("resetsAt", ""))[:40]})
            rows.append({"name": str(record.get("name", path.stem))[:60],
                         "updatedAt": str(record.get("updatedAt", ""))[:40],
                         "tokens": record.get("todayTotalTokens"), "limits": limits,
                         "status": str(record.get("usageStatusText", ""))[:140]})
        except (OSError, ValueError, TypeError, AttributeError):
            continue
    return {"rows": rows}


def weather(city):
    location = {}
    if not city:
        try:
            location = read_json(Path.home() / ".local/state/omarchy/settings/weather.json")
            city = str(location.get("name", ""))
        except (OSError, ValueError, AttributeError):
            pass
    lat, lon = location.get("latitude"), location.get("longitude")
    if lat is None or lon is None:
        if not city.strip():
            return {"error": "Set a city in Widgets → Weather location.", "needsLocation": True}
        results = fetch("geocoding-api.open-meteo.com", "/v1/search", {"name": city[:120], "count": 1}).get("results", [])
        if not results:
            return {"error": "City not found. Try city and region."}
        location = results[0]
        lat, lon = location["latitude"], location["longitude"]
        city = ", ".join(filter(None, [location.get("name"), location.get("country_code")]))
    lat, lon = float(lat), float(lon)
    if not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError("Invalid location coordinates")
    report = fetch("api.open-meteo.com", "/v1/forecast", {
        "latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 3,
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m",
        "daily": "temperature_2m_max,temperature_2m_min,weather_code"})
    current = report.get("current", {})
    if not isinstance(current.get("temperature_2m"), (int, float)):
        raise ValueError("No current conditions")
    return {"city": city or f"{lat:.2f}, {lon:.2f}", "current": current, "daily": report.get("daily", {}),
            "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat()}


def main():
    try:
        mode = sys.argv[1]
        if mode == "disk":
            result = disks()
        elif mode == "agents":
            result = agents()
        elif mode == "weather":
            result = weather(sys.argv[2] if len(sys.argv) > 2 else "")
        else:
            raise ValueError("Unknown collector")
    except Exception:
        result = {"error": "Data unavailable. Will retry automatically."}
    print(json.dumps(result, ensure_ascii=True, allow_nan=False))


if __name__ == "__main__":
    main()
