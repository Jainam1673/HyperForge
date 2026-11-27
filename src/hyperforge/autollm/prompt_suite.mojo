"""Versioned prompt/evaluation suite and recorded-response scoring.

The suite is a local, explicitly versioned text format. Responses are read from
a separate recorded file; no model is invoked by this module. Missing responses
count as failures rather than being fabricated.
"""

from std.pathlib import Path
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.evidence.record import (
    decode_value,
    split_unescaped,
)

comptime SUITE_SCHEMA = "hyperforge-autollm-suite-v1"
comptime SUITE_MAGIC = "HFPS1"
comptime RESPONSE_MAGIC = "HFRSP1"


struct PromptCase(Copyable, Movable):
    var id: String
    var prompt: String
    var expected: String
    var metric: String

    def __init__(out self, id: String, prompt: String, expected: String, metric: String):
        self.id = id
        self.prompt = prompt
        self.expected = expected
        self.metric = metric


struct PromptSuite(Copyable, Movable):
    var cases: List[PromptCase]
    var checksum: String

    def __init__(out self, var cases: List[PromptCase], checksum: String):
        self.cases = cases^
        self.checksum = checksum


struct ResponseRecord(Copyable, Movable):
    var id: String
    var response: String

    def __init__(out self, id: String, response: String):
        self.id = id
        self.response = response


struct EvalResult(Copyable, Movable):
    var total: Int
    var matched: Int
    var missing: Int
    var accuracy: Float64
    var state: String

    def __init__(out self, total: Int, matched: Int, missing: Int, accuracy: Float64, state: String):
        self.total = total
        self.matched = matched
        self.missing = missing
        self.accuracy = accuracy
        self.state = state


def parse_encoded_fields(line: String, expected_magic: String) raises -> List[String]:
    var parts = split_unescaped(line)
    if len(parts) < 2 or parts[0] != expected_magic:
        raise Error("invalid prompt-suite record")
    var out = List[String]()
    for i in range(1, len(parts)):
        out.append(decode_value(String(parts[i])))
    return out^


def load_suite(path: String) raises -> PromptSuite:
    var content = open(path, "r").read()
    var cases = List[PromptCase]()
    for raw_line in content.split("\n"):
        var line = String(raw_line)
        if line == "":
            continue
        var fields = parse_encoded_fields(line, SUITE_MAGIC)
        if len(fields) != 4:
            raise Error("prompt case must have id, prompt, expected, metric")
        if fields[3] != "exact" and fields[3] != "contains":
            raise Error("unsupported prompt metric: " + fields[3])
        cases.append(PromptCase(fields[0], fields[1], fields[2], fields[3]))
    if len(cases) == 0:
        raise Error("prompt suite is empty")
    return PromptSuite(cases^, hex64(fnv1a64(content)))


def load_responses(path: String) raises -> List[ResponseRecord]:
    var content = open(path, "r").read()
    var records = List[ResponseRecord]()
    for raw_line in content.split("\n"):
        var line = String(raw_line)
        if line == "":
            continue
        var fields = parse_encoded_fields(line, RESPONSE_MAGIC)
        if len(fields) != 2:
            raise Error("response record must have id and response")
        records.append(ResponseRecord(fields[0], fields[1]))
    return records^


def evaluate(suite: PromptSuite, responses: List[ResponseRecord]) raises -> EvalResult:
    var matched = 0
    var missing = 0
    for prompt_case in suite.cases:
        var found = False
        for record in responses:
            if record.id != prompt_case.id:
                continue
            found = True
            var success: Bool
            if prompt_case.metric == "exact":
                success = record.response == prompt_case.expected
            else:
                success = prompt_case.expected in record.response
            if success:
                matched += 1
            break
        if not found:
            missing += 1
    var total = len(suite.cases)
    var state = String("EVALUATED")
    if missing == total:
        state = "NO_RESPONSES"
    return EvalResult(
        total, matched, missing, Float64(matched) / Float64(total), state
    )
