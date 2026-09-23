#!/usr/bin/env python3
"""Analyze local profiling-only unified logs against the unchanged CPU recorder."""
import argparse
import collections
import datetime
import json
import math
from pathlib import Path


def analyze(log_path, measurement, app_pid, helper_pid):
    duration = measurement['durationSeconds']
    if not math.isfinite(duration) or duration < 599.5:
        raise ValueError('A full 600-second installed measurement is required')
    start = datetime.datetime.fromisoformat(measurement['startedAt'].replace('Z', '+00:00')).timestamp()
    start = measurement.get('startedAtUnixSeconds', start)
    end = start + duration
    if 'endedAtUnixSeconds' in measurement and abs(measurement['endedAtUnixSeconds'] - end) > 0.25:
        raise ValueError('Wall clock changed during the measurement; log window is uncertain')
    events = []
    for line in Path(log_path).read_text().splitlines():
        if not line.strip():
            continue
        envelope = json.loads(line)
        if envelope.get('subsystem') != 'com.lidpilot.profile':
            continue
        event = json.loads(envelope['eventMessage'])
        if event.get('schema') != 1:
            raise ValueError('Unsupported trace schema')
        if event['pid'] in (app_pid, helper_pid):
            events.append(event)
    if not events:
        raise ValueError('No target profiling events; cannot infer zero activity')
    gaps = []
    for pid in (app_pid, helper_pid):
        seq = sorted(e['seq'] for e in events if e['pid'] == pid)
        if not seq:
            raise ValueError(f'No events for PID {pid}')
        gaps.extend({'pid': pid, 'previous': a, 'next': b} for a, b in zip(seq, seq[1:]) if b != a + 1)
    window = [e for e in events if start <= e['wall_time'] <= end]
    counts = collections.Counter(e['event'] for e in window)
    origins = collections.Counter('/'.join(str(e.get(k, '-')) for k in ('event', 'source', 'stage', 'direction', 'op')) for e in window)
    paths = collections.defaultdict(lambda: {'calls': 0, 'duration_ns': 0, 'child_user_us': 0, 'child_system_us': 0})
    for e in window:
        if e['event'] != 'pmset_span_end':
            continue
        key = f"{e.get('operation', 'unknown')}/{e.get('callsite', 'unknown')}"
        row = paths[key]
        row['calls'] += 1
        if e.get('result') == 'error' or e.get('reaped_child_cpu_complete') is False:
            raise ValueError('Failed or incompletely accounted command span; cannot produce complete attribution')
        row['duration_ns'] += e['duration_ns']
        row['child_user_us'] += e['reaped_child_user_us']
        row['child_system_us'] += e['reaped_child_system_us']
    for row in paths.values():
        row['calls_per_minute'] = row['calls'] * 60 / duration
        row['child_cpu_percent_of_one_core'] = (row['child_user_us'] + row['child_system_us']) / 1e6 / duration * 100
    factor = measurement['machTimebaseNumerator'] / measurement['machTimebaseDenominator'] / 1e9 / duration * 100
    split = {}
    for target in measurement['cpuByTarget']:
        pid = target['pid']
        if pid not in (app_pid, helper_pid):
            raise ValueError('Unexpected CPU measurement PID')
        role = 'app' if pid == app_pid else 'helper'
        split[role] = (target['ownUserTicks'] + target['ownSystemTicks']) * factor
        split[role + '_reaped_children'] = (target['reapedChildUserTicks'] + target['reapedChildSystemTicks']) * factor
    if len(split) != 4:
        raise ValueError('Both app and helper CPU measurements are required')
    if not math.isclose(sum(split.values()), measurement['cpuPercentOfOneCoreIncludingReapedChildren'], rel_tol=1e-9, abs_tol=1e-12):
        raise ValueError('CPU breakdown does not match aggregate measurement')
    return {'duration_seconds': duration, 'cpu_percent_of_one_core': split,
            'total_cpu_percent': measurement['cpuPercentOfOneCoreIncludingReapedChildren'],
            'event_origins': dict(origins), 'event_counts': dict(counts), 'events_per_minute': {k: v * 60 / duration for k, v in counts.items()},
            'pmset_by_path': dict(paths), 'sequence_gaps': gaps,
            'counts_complete': not gaps,
            'limitations': ['Profiling instrumentation overhead is included.',
                           'Commands crossing the window boundary need manual reconciliation.',
                           'No events before/after the measurement window must be checked against capture start/end.',
                           'Child command CPU is a separate getrusage measurement; compare it with recorder child counters.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log'); parser.add_argument('measurement')
    parser.add_argument('--app-pid', type=int, required=True)
    parser.add_argument('--helper-pid', type=int, required=True)
    args = parser.parse_args()
    try:
        report = analyze(args.log, json.loads(Path(args.measurement).read_text()), args.app_pid, args.helper_pid)
        print(json.dumps(report, indent=2, sort_keys=True))
    except (ValueError, KeyError, OSError, TypeError) as error:
        parser.exit(1, f'Profile analysis failed: {error}\n')
