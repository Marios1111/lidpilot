#!/usr/bin/env python3
"""Synthetic parser checks, not installed performance evidence."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
spec = importlib.util.spec_from_file_location('profile_analysis', Path(__file__).with_name('analyze-performance-profile.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ProfileTests(unittest.TestCase):
    def test_attribution_and_missing_events(self):
        record = {'durationSeconds': 600, 'startedAt': '1970-01-01T00:00:00Z',
                  'machTimebaseNumerator': 1, 'machTimebaseDenominator': 1,
                  'cpuPercentOfOneCoreIncludingReapedChildren': 2000 / 1e9 / 600 * 100,
                  'cpuByTarget': [dict(pid=p, ownUserTicks=100, ownSystemTicks=200,
                                     reapedChildUserTicks=300, reapedChildSystemTicks=400) for p in (10, 20)]}
        events = [dict(schema=1, event='heartbeat', seq=1, pid=10, wall_time=1),
                  dict(schema=1, event='pmset_span_end', seq=1, pid=20, wall_time=2,
                       span_id='s1', operation='read', callsite='reply', duration_ns=1000,
                       reaped_child_user_us=100, reaped_child_system_us=200)]
        events.insert(1, dict(schema=1, event='pmset_span_begin', seq=1, pid=20, wall_time=1.5, span_id='s1'))
        events[2]['seq'] = 2
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'trace.ndjson'
            def write():
                p.write_text('Filtering the log data using test predicate\n' + '\n'.join(json.dumps(dict(subsystem='com.lidpilot.profile', eventMessage=json.dumps(e))) for e in events))
            write()
            report = module.analyze(p, record, 10, 20)
            self.assertTrue(report['counts_complete'])
            self.assertEqual(report['pmset_by_path']['read/unknown/reply']['calls_per_minute'], 0.1)
            events[1]['wall_time'] = -0.1
            write()
            self.assertEqual(module.analyze(p, record, 10, 20)['boundary_spans'], ['s1'])
            events[1]['wall_time'] = 1.5
            events[1]['span_id'] = 'missing-end'
            write()
            self.assertFalse(module.analyze(p, record, 10, 20)['counts_complete'])
            events[1]['span_id'] = 's1'
            events.append(dict(schema=1, event='heartbeat', seq=3, pid=10, wall_time=3))
            write()
            self.assertFalse(module.analyze(p, record, 10, 20)['counts_complete'])
            p.write_text('')
            with self.assertRaises(ValueError): module.analyze(p, record, 10, 20)
            record['durationSeconds'] = 60
            with self.assertRaises(ValueError): module.analyze(p, record, 10, 20)

unittest.main()
