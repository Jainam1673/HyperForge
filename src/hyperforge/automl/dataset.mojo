"""Strict local CSV loader for numeric tabular regression.

Supported scope (deliberately narrow): header row, comma separator, numeric
cells, empty cell means missing. No quoting, escaped separators, categorical
features, or whitespace trimming are supported; unsupported input is rejected
rather than silently reinterpreted. Target cells must be present and finite.
"""

from std.pathlib import Path
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.numeric import is_finite

comptime DATASET_SCHEMA = "hyperforge-dataset-v1"
comptime MIN_ROWS = 8


struct Dataset(Copyable, Movable):
    var values: List[Float64]
    var missing: List[Bool]
    var rows: Int
    var cols: Int
    var feature_names: List[String]
    var target_name: String
    var target_index: Int
    var fingerprint: String

    def __init__(
        out self,
        var values: List[Float64],
        var missing: List[Bool],
        rows: Int,
        cols: Int,
        var feature_names: List[String],
        target_name: String,
        target_index: Int,
        fingerprint: String,
    ):
        self.values = values^
        self.missing = missing^
        self.rows = rows
        self.cols = cols
        self.feature_names = feature_names^
        self.target_name = target_name
        self.target_index = target_index
        self.fingerprint = fingerprint


def strip_cr(line: String) raises -> String:
    if not line.endswith("\r"):
        return line
    var out = String("")
    for i in range(line.byte_length() - 1):
        out += String(line[byte=i])
    return out


def split_csv_row(line: String) raises -> List[String]:
    var clean = strip_cr(line)
    var out = List[String]()
    for cell in clean.split(","):
        out.append(String(cell))
    return out^


def value_at(dataset: Dataset, row: Int, col: Int) raises -> Float64:
    return dataset.values[row * dataset.cols + col]


def is_missing_at(dataset: Dataset, row: Int, col: Int) raises -> Bool:
    return dataset.missing[row * dataset.cols + col]


def target_at(dataset: Dataset, row: Int) raises -> Float64:
    return value_at(dataset, row, dataset.target_index)


def load_csv(path: String, target_name: String) raises -> Dataset:
    if not Path(path).exists():
        raise Error("dataset not found: " + path)
    var content = open(path, "r").read()
    var lines = List[String]()
    for span in content.split("\n"):
        var line = String(span)
        if line != "":
            lines.append(line^)
    if len(lines) < 2:
        raise Error("dataset needs a header and at least one data row")

    var names = split_csv_row(lines[0])
    if len(names) < 2:
        raise Error("dataset needs at least one feature and one target column")
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            if names[i] == names[j]:
                raise Error("duplicate column name: " + names[i])

    var target_index = -1
    for i in range(len(names)):
        if names[i] == target_name:
            target_index = i
            break
    if target_index < 0:
        raise Error("target column not found: " + target_name)

    var feature_names = List[String]()
    for i in range(len(names)):
        if i != target_index:
            feature_names.append(names[i])

    var values = List[Float64]()
    var missing = List[Bool]()
    for row in range(1, len(lines)):
        var cells = split_csv_row(lines[row])
        if len(cells) != len(names):
            raise Error("row length does not match header")
        for i in range(len(cells)):
            if cells[i] == "":
                if i == target_index:
                    raise Error("target missing at data row " + String(row))
                values.append(Float64(0.0))
                missing.append(True)
            else:
                var parsed = Float64(cells[i])
                if not is_finite(parsed):
                    raise Error("non-finite value at row " + String(row))
                values.append(parsed)
                missing.append(False)

    if len(lines) - 1 < MIN_ROWS:
        raise Error("dataset has fewer than " + String(MIN_ROWS) + " rows")

    var fingerprint = hex64(fnv1a64(content))
    return Dataset(
        values^,
        missing^,
        len(lines) - 1,
        len(names),
        feature_names^,
        target_name,
        target_index,
        fingerprint,
    )
