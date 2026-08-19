#!/usr/bin/env python3
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE / "sidecar"))
import pzgrok  # noqa: E402


class Forbidden(unittest.TestCase):
    def test_rejects_health(self):
        with self.assertRaises(ValueError):
            pzgrok.walk_forbidden({"said": "hi", "health": 80})

    def test_rejects_nested_position(self):
        with self.assertRaises(ValueError):
            pzgrok.walk_forbidden({"roster": {"x": 10, "y": 4}})

    def test_allows_clean_talk(self):
        pzgrok.walk_forbidden({
            "said": "has anyone come across the bridge?",
            "day": 6,
            "hour": 21,
            "frequency_khz": 145350,
            "events": [{"type": "no_answer"}],
        })


class Sentinel(unittest.TestCase):
    def test_torn_read_discarded(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "talk_request.json"
            p.write_text('{"seq": 1, "said": "hi"}\n', encoding="utf-8")
            self.assertIsNone(pzgrok.read_request(p))

    def test_stale_seq_discarded(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "talk_request.json"
            p.write_text('{"seq": 1, "said": "hi"}\n--END 2\n', encoding="utf-8")
            self.assertIsNone(pzgrok.read_request(p))

    def test_matching_sentinel(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "talk_request.json"
            p.write_text('{"seq": 7, "said": "hi"}\n--END 7\n', encoding="utf-8")
            data = pzgrok.read_request(p)
            self.assertEqual(data["seq"], 7)
            self.assertEqual(data["said"], "hi")


class Parse(unittest.TestCase):
    def test_json_lines(self):
        raw = json.dumps({"lines": [{"speaker": "Verna", "text": "Nobody's come across since Tuesday."}]})
        parsed = pzgrok.parse_lines(raw)
        self.assertEqual(parsed["lines"][0]["speaker"], "Verna")


class SurvivorsPrompt(unittest.TestCase):
    def setUp(self):
        self.text = pzgrok.load_prompt("survivors.md")

    def test_present(self):
        self.assertGreater(len(self.text), 4000)

    def test_never_say_zombie(self):
        self.assertIn('Never say "zombie."', self.text)

    def test_exclusion_zone(self):
        self.assertIn("Exclusion Zone stops at the Ohio River", self.text)

    def test_know_only_what_crossed_the_radio(self):
        self.assertIn("You know only what has crossed the radio.", self.text)

    def test_kentucky_places_forbidden(self):
        for place in ("Muldraugh", "West Point", "Rosewood", "Louisville"):
            self.assertIn(place, self.text)

    def test_mcgrew_not_deceased(self):
        self.assertIn("Sufferers are NOT deceased.", self.text)

    def test_second_wave_day_7(self):
        self.assertIn("The second wave.", self.text)

    def test_output_is_json_not_identity(self):
        self.assertIn("revealed_names", self.text)
        self.assertIn("needIdentity", self.text)
        self.assertIn("invite_frequency_khz", self.text)

    def test_eras(self):
        self.assertIn("Era 1, days 0–4", self.text)
        self.assertIn("Era 4, day 18+", self.text)

    def test_call_district_9(self):
        self.assertIn("call district 9", self.text)


if __name__ == "__main__":
    unittest.main()
