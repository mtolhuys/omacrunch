import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("collector", Path(__file__).parents[1] / "widget-data.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class Collectors(unittest.TestCase):
    def test_disks(self):
        for row in collector.disks()["rows"]:
            self.assertGreater(row["total"], 0)
            self.assertTrue(0 <= row["percent"] <= 100)

    def test_agents_missing_corrupt_and_fractional_limits(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict("os.environ", {"XDG_STATE_HOME": directory}):
            self.assertEqual(collector.agents(), {"rows": []})
            usage = Path(directory) / "omarchy/agents/usage"
            usage.mkdir(parents=True)
            (usage / "bad.json").write_text("{invalid")
            (usage / "codex.json").write_text(json.dumps({"name": "Codex", "todayTotalTokens": 123,
                "limits": [{"label": "Session", "percent": 0.32}], "authToken": "must-not-leak"}))
            record = collector.agents()["rows"][0]
            self.assertEqual(record["limits"][0]["percent"], 32)
            self.assertNotIn("authToken", record)

    def test_weather_requires_location(self):
        with patch.object(collector, "read_json", side_effect=FileNotFoundError), patch.object(collector, "fetch") as fetch:
            self.assertTrue(collector.weather("")["needsLocation"])
            fetch.assert_not_called()

    def test_weather_lookup_and_current_conditions(self):
        with patch.object(collector, "fetch", side_effect=[
            {"results": [{"name": "Utrecht", "country_code": "NL", "latitude": 52.1, "longitude": 5.1}]},
            {"current": {"temperature_2m": 12}, "daily": {}}
        ]) as fetch:
            result = collector.weather("Utrecht")
            self.assertEqual(result["city"], "Utrecht, NL")
            self.assertEqual(result["current"]["temperature_2m"], 12)
            self.assertEqual(fetch.call_args.args[2]["forecast_days"], 3)

    def test_missing_temperature_is_not_zero(self):
        with patch.object(collector, "read_json", return_value={"latitude": 52, "longitude": 5}), patch.object(collector, "fetch", return_value={}):
            with self.assertRaises(ValueError):
                collector.weather("")


if __name__ == "__main__":
    unittest.main()
