#!/usr/bin/env python3
"""
Multi-Calendar Google iCal Fetcher & Parser with Offline Caching.
Designed for Quickshell ClockPanel.
"""

import os
import sys
import json
import re
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone, date

CONFIG_DIR = os.path.expanduser("~/.config/quickshell")
CACHE_DIR = os.path.expanduser("~/.cache/quickshell/calendars")
COMBINED_CACHE_FILE = os.path.join(CACHE_DIR, "events.json")

DEFAULT_PALETTE = [
    "#47c8ff",  # Cyan / Blue
    "#a78bfa",  # Purple
    "#34d399",  # Emerald Green
    "#f472b6",  # Pink
    "#fbbf24",  # Amber / Gold
    "#38bdf8",  # Sky Blue
    "#f87171",  # Light Red
    "#818cf8",  # Indigo
]


def ensure_dirs():
    os.makedirs(CACHE_DIR, exist_ok=True)


def load_config():
    """Find and parse calendars configuration."""
    config_paths = [
        os.path.join(CONFIG_DIR, "calendars.conf"),
        os.path.join(CONFIG_DIR, "calendar.conf"),
        os.path.join(CONFIG_DIR, "calendar_url"),
    ]

    for path in config_paths:
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    lines = [line.strip() for line in f if line.strip() and not line.strip().startswith("#")]
                
                calendars = []
                for idx, line in enumerate(lines):
                    parts = [p.strip() for p in line.split("|")]
                    if len(parts) >= 3:
                        name = parts[0]
                        color = parts[1]
                        url = parts[2]
                    elif len(parts) == 2:
                        name = parts[0]
                        color = DEFAULT_PALETTE[idx % len(DEFAULT_PALETTE)]
                        url = parts[1]
                    else:
                        name = f"Calendar {idx + 1}"
                        color = DEFAULT_PALETTE[idx % len(DEFAULT_PALETTE)]
                        url = parts[0]
                    
                    if url.startswith("http://") or url.startswith("https://") or url.startswith("webcal://"):
                        if url.startswith("webcal://"):
                            url = "https://" + url[9:]
                        calendars.append({
                            "name": name,
                            "color": color,
                            "url": url,
                            "slug": re.sub(r'[^a-zA-Z0-9_-]', '_', name.lower())
                        })
                if calendars:
                    return calendars
            except Exception:
                pass

    return []


def fetch_or_load_ics(cal):
    """Fetch iCal content from web with timeout, caching locally, or load from cache."""
    cache_path = os.path.join(CACHE_DIR, f"{cal['slug']}.ics")
    content = None

    # Try fetching over network
    try:
        req = urllib.request.Request(
            cal["url"],
            headers={"User-Agent": "Quickshell-Calendar-Sync/1.0"}
        )
        with urllib.request.urlopen(req, timeout=4) as response:
            raw_bytes = response.read()
            content = raw_bytes.decode("utf-8", errors="replace")
            # Write to cache
            try:
                with open(cache_path, "w", encoding="utf-8") as f:
                    f.write(content)
            except Exception:
                pass
    except Exception:
        # Fallback to local cache
        if os.path.isfile(cache_path):
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                content = None

    return content


def unfold_ics(text):
    """Unfold lines that are wrapped across multiple lines according to RFC 5545."""
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    unfolded = []
    for line in lines:
        if line.startswith(" ") or line.startswith("\t"):
            if unfolded:
                unfolded[-1] += line[1:]
        else:
            unfolded.append(line)
    return unfolded


def unescape_ics(val):
    """Unescape text fields in ics."""
    if not val:
        return ""
    val = val.replace("\\n", " ").replace("\\N", " ")
    val = val.replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")
    return val.strip()


def parse_ics_datetime(dt_str):
    """Parse date or datetime string from iCal."""
    dt_str = dt_str.strip()
    # Check date only: YYYYMMDD
    if len(dt_str) == 8 and dt_str.isdigit():
        try:
            d = datetime.strptime(dt_str, "%Y%m%d").date()
            return d, None, True
        except ValueError:
            return None, None, False

    # Check ISO format like 20260830T150000Z or 20260830T150000
    is_utc = dt_str.endswith("Z")
    clean_dt = dt_str.rstrip("Z")

    formats = [
        "%Y%m%dT%H%M%S",
        "%Y%m%dT%H%M",
    ]
    for fmt in formats:
        try:
            dt = datetime.strptime(clean_dt, fmt)
            if is_utc:
                # Convert UTC to local system time
                dt = dt.replace(tzinfo=timezone.utc).astimezone().replace(tzinfo=None)
            return dt.date(), dt.time(), False
        except ValueError:
            continue

    return None, None, False


def expand_event_days(base_event, start_d, end_d, is_all_day, start_t, end_t, window_start, window_end):
    """Generate event instances across all days an event spans."""
    instances = []
    if not start_d:
        return instances

    # Calculate last included date
    if is_all_day:
        # In RFC 5545, all-day DTEND is exclusive
        if end_d and end_d > start_d:
            last_d = end_d - timedelta(days=1)
        else:
            last_d = start_d
    else:
        # Timed events
        if end_d and end_d > start_d:
            if end_t and end_t.hour == 0 and end_t.minute == 0:
                last_d = end_d - timedelta(days=1)
            else:
                last_d = end_d
        else:
            last_d = start_d

    if last_d < start_d:
        last_d = start_d

    curr_d = start_d
    start_str = start_t.strftime("%H:%M") if (start_t and not is_all_day) else ""
    end_str = end_t.strftime("%H:%M") if (end_t and not is_all_day) else ""

    while curr_d <= last_d:
        if window_start <= curr_d <= window_end:
            inst = dict(base_event)
            inst["date"] = curr_d.isoformat()

            # Format time string appropriately for each day
            if is_all_day:
                inst["timeStr"] = "All Day"
            else:
                if start_d == last_d:
                    inst["timeStr"] = f"{start_str} - {end_str}" if end_str else start_str
                elif curr_d == start_d:
                    inst["timeStr"] = f"{start_str} →"
                elif curr_d == last_d:
                    inst["timeStr"] = f"→ {end_str}" if end_str else "Ends"
                else:
                    inst["timeStr"] = "All Day (Ongoing)"

            instances.append(inst)

        curr_d += timedelta(days=1)

    return instances


def expand_recurring_events(event_base, rrule_str, start_date, end_date, is_all_day, start_t, end_t, window_start, window_end):
    """Generate event instances for simple recurrence rules within a time window."""
    instances = []
    
    rules = {}
    for part in rrule_str.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            rules[k.upper()] = v.upper()

    freq = rules.get("FREQ")
    interval = int(rules.get("INTERVAL", "1"))
    count = int(rules.get("COUNT", "999"))
    until_date = None
    if "UNTIL" in rules:
        u_d, _, _ = parse_ics_datetime(rules["UNTIL"])
        until_date = u_d

    curr_date = start_date
    duration = (end_date - start_date) if end_date else timedelta(days=0)
    iterations = 0

    while iterations < count and curr_date <= window_end:
        if until_date and curr_date > until_date:
            break

        inst_end = curr_date + duration
        day_instances = expand_event_days(event_base, curr_date, inst_end, is_all_day, start_t, end_t, window_start, window_end)
        instances.extend(day_instances)

        # Advance curr_date
        if freq == "DAILY":
            curr_date += timedelta(days=interval)
        elif freq == "WEEKLY":
            curr_date += timedelta(weeks=interval)
        elif freq == "MONTHLY":
            # Advance 1 month
            month = curr_date.month - 1 + interval
            year = curr_date.year + month // 12
            month = month % 12 + 1
            day = min(curr_date.day, 28)
            curr_date = curr_date.replace(year=year, month=month, day=day)
        elif freq == "YEARLY":
            try:
                curr_date = curr_date.replace(year=curr_date.year + interval)
            except ValueError:
                curr_date = curr_date.replace(year=curr_date.year + interval, day=28)
        else:
            break

        iterations += 1

    return instances


def parse_ics(ics_content, cal_info):
    """Parse events from iCal string."""
    if not ics_content:
        return []

    lines = unfold_ics(ics_content)
    events = []
    in_vevent = False
    cur_props = {}

    today = date.today()
    window_start = today - timedelta(days=730)  # 2 years in the past
    window_end = today + timedelta(days=730)    # 2 years in the future

    for line in lines:
        line_clean = line.strip()
        if line_clean == "BEGIN:VEVENT":
            in_vevent = True
            cur_props = {}
            continue
        elif line_clean == "END:VEVENT":
            in_vevent = False
            
            # Process current event
            summary = unescape_ics(cur_props.get("SUMMARY", "Event"))
            location = unescape_ics(cur_props.get("LOCATION", ""))
            uid = cur_props.get("UID", f"{summary}_{len(events)}")
            dtstart_raw = cur_props.get("DTSTART", "")
            dtend_raw = cur_props.get("DTEND", "")
            rrule = cur_props.get("RRULE", "")

            # Value could be DTSTART;VALUE=DATE:...
            dtstart_val = dtstart_raw.split(":")[-1] if ":" in dtstart_raw else dtstart_raw
            dtend_val = dtend_raw.split(":")[-1] if ":" in dtend_raw else dtend_raw

            start_d, start_t, is_allday_start = parse_ics_datetime(dtstart_val)
            if not start_d:
                continue

            end_d, end_t, is_allday_end = parse_ics_datetime(dtend_val) if dtend_val else (start_d, None, is_allday_start)

            is_all_day = is_allday_start or (start_t is None)

            time_str = "All Day"
            start_str = ""
            end_str = ""
            if not is_all_day and start_t:
                start_str = start_t.strftime("%H:%M")
                if end_t:
                    end_str = end_t.strftime("%H:%M")
                    time_str = f"{start_str} - {end_str}"
                else:
                    time_str = start_str

            base_event = {
                "id": uid,
                "calendar": cal_info["name"],
                "color": cal_info["color"],
                "title": summary,
                "date": start_d.isoformat(),
                "start": start_str,
                "end": end_str,
                "timeStr": time_str,
                "isAllDay": is_all_day,
                "location": location,
            }

            if rrule:
                instances = expand_recurring_events(base_event, rrule, start_d, end_d, is_all_day, start_t, end_t, window_start, window_end)
                events.extend(instances)
            else:
                instances = expand_event_days(base_event, start_d, end_d, is_all_day, start_t, end_t, window_start, window_end)
                events.extend(instances)

            continue

        if in_vevent and ":" in line:
            key_part, val_part = line.split(":", 1)
            key = key_part.split(";")[0].upper()
            cur_props[key] = val_part.strip()
            cur_props[key + "_FULL"] = line

    return events


def main():
    ensure_dirs()
    calendars = load_config()

    if not calendars:
        # Check if combined cache exists
        if os.path.isfile(COMBINED_CACHE_FILE):
            try:
                with open(COMBINED_CACHE_FILE, "r", encoding="utf-8") as f:
                    print(f.read())
                    return
            except Exception:
                pass
        print(json.dumps([]))
        return

    all_events = []
    seen_ids = set()

    for cal in calendars:
        ics_text = fetch_or_load_ics(cal)
        cal_events = parse_ics(ics_text, cal)
        for ev in cal_events:
            unique_key = (ev["calendar"], ev["date"], ev["title"], ev["start"])
            if unique_key not in seen_ids:
                seen_ids.add(unique_key)
                all_events.append(ev)

    # Sort events chronologically by date and start time
    all_events.sort(key=lambda x: (x["date"], 0 if x["isAllDay"] else 1, x["start"] or "00:00"))

    output_json = json.dumps(all_events, indent=2)

    # Save combined cache
    try:
        with open(COMBINED_CACHE_FILE, "w", encoding="utf-8") as f:
            f.write(output_json)
    except Exception:
        pass

    print(output_json)


if __name__ == "__main__":
    main()
