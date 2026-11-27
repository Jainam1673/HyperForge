"""Shared input validation and resource ceilings (M21 hardening).

These checks are deliberately simple and first-party: no external parser, no
network, no shell. They reject inputs before parsing rather than after.
"""

from std.os import stat
from std.pathlib import Path

comptime HARDENING_SCHEMA = "hyperforge-hardening-v1"
comptime MAX_PATH_BYTES = 4096
comptime MAX_CSV_BYTES = 16 * 1024 * 1024
comptime MAX_CSV_ROWS = 100000
comptime MAX_CSV_COLS = 256


def validate_path(path: String) raises -> Bool:
    """Reject empty, over-long, NUL-bearing, and `..`-traversing paths."""
    if path == "":
        return False
    if path.byte_length() > MAX_PATH_BYTES:
        return False
    for i in range(path.byte_length()):
        if String(path[byte=i]) == "\0":
            return False
    for segment in path.split("/"):
        if String(segment) == "..":
            return False
    return True


def enforce_csv_limits(
    path: String, max_bytes: Int, max_rows: Int, max_cols: Int
) raises -> Bool:
    """Bound file size, column count, and row count before full parsing."""
    if not validate_path(path):
        return False
    if not Path(path).exists():
        return False
    var size = stat(path).st_size
    if size < 0 or size > max_bytes:
        return False
    var content = open(path, "r").read()
    var rows = 0
    var cols = 0
    var first = True
    for span in content.split("\n"):
        var line = String(span)
        if line == "":
            continue
        if first:
            cols = 1
            for i in range(line.byte_length()):
                if String(line[byte=i]) == ",":
                    cols += 1
            first = False
        rows += 1
    if rows > max_rows or cols > max_cols:
        return False
    return rows > 0 and cols > 0


def hardening_summary() raises -> String:
    return (
        "paths<=" + String(MAX_PATH_BYTES) + "B; '..' and NUL rejected; "
        + "CSV<=" + String(MAX_CSV_BYTES) + "B/" + String(MAX_CSV_ROWS)
        + " rows/" + String(MAX_CSV_COLS) + " cols"
    )
