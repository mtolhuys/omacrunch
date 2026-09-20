"""Deterministic subprocess fixture: no network and no user state."""
import json
import sys
import time
from pathlib import Path

city = sys.argv[2]
time.sleep(0.25)
if city == "process-failure":
    sys.exit(2)
if city == "recover-on-retry":
    marker = Path(__file__).with_name("retry-marker")
    first = not marker.exists()
    marker.touch()
    if first:
        print(json.dumps({"error": "Temporary network failure"}))
        sys.exit(0)
if city == "network-failure":
    print(json.dumps({"error": "Network unavailable; will retry."}))
elif not city:
    print(json.dumps({"error": "Choose a location", "needsLocation": True}))
else:
    print(json.dumps({"city": city, "current": {"temperature_2m": 17}}))
