"""Versioned journal record encoding and decoding.

Format (one record per line):

    HFJ1|<seq>|<type>|<checksum>|<payload>\n

`payload` is `key=value|key=value|...`. Values escape `\\`, `|`, `=`, and
newline. The checksum is FNV-1a 64 over `seq|type|payload`. HFJ1 is the only
supported version; unknown versions are rejected, not silently skipped.
"""

from hyperforge.core.hash import fnv1a64, hex64

comptime JOURNAL_MAGIC = "HFJ1"
comptime RECORD_EXPERIMENT = "experiment"
comptime RECORD_EVENT = "event"
comptime RECORD_TRIAL = "trial"
comptime RECORD_OPTIMIZER = "optimizer"
comptime RECORD_SCIENTIFIC = "scientific"
comptime RECORD_SCIT = "scit"
comptime RECORD_DISCOVERY = "discovery"
comptime RECORD_AUTOML_DL = "autodl"
comptime RECORD_AUTORL = "autorl"
comptime RECORD_AUTOTRANS = "autotrans"
comptime RECORD_AUTOLLM = "autollm"
comptime RECORD_SCIML = "sciml"
comptime RECORD_SCIDL = "scidl"
comptime RECORD_SCIRL = "scirl"
comptime RECORD_LOOPER = "looper"
comptime RECORD_GPU_BENCH = "gpu_bench"
comptime RECORD_SYSTEMS_TRIAL = "systems_trial"
comptime RECORD_META_ECONOMY = "meta_economy"
comptime RECORD_CAUSAL_EDGE = "causal_edge"
comptime RECORD_JOINT_OUTCOME = "joint_outcome"
comptime RECORD_RSI_BASELINE = "rsi_baseline"
comptime RECORD_RSI_PROTOCOL = "rsi_protocol"
comptime RECORD_RSI_DECISION = "rsi_decision"
comptime RECORD_FULL_TRIAL = "full_trial"
comptime RECORD_FULL_SUMMARY = "full_summary"
comptime RECORD_AUTOLLM_STAGE = "autollm_stage"
comptime RECORD_AUTOLLM_RESPONSE = "autollm_response"
comptime RECORD_SERVE_STATUS = "serve_status"
comptime RECORD_AUTODL_FULL = "autodl_full"
comptime RECORD_AUTORL_FULL = "autorl_full"
comptime RECORD_SCIAI_OUTCOME = "sciai_outcome"


struct Field:
    var key: String
    var value: String

    def __init__(out self, key: String, value: String):
        self.key = key
        self.value = value


def encode_value(value: String) raises -> String:
    var out = String("")
    for i in range(value.byte_length()):
        var ch = value[byte=i]
        if ch == "\\":
            out += "\\\\"
        elif ch == "|":
            out += "\\|"
        elif ch == "=":
            out += "\\q"
        elif ch == "\n":
            out += "\\n"
        else:
            out += String(ch)
    return out


def decode_value(value: String) raises -> String:
    var out = String("")
    var escaped = False
    for i in range(value.byte_length()):
        var ch = value[byte=i]
        if escaped:
            if ch == "n":
                out += "\n"
            elif ch == "q":
                out += "="
            else:
                out += String(ch)
            escaped = False
        elif ch == "\\":
            escaped = True
        else:
            out += String(ch)
    if escaped:
        raise Error("dangling escape in encoded value")
    return out


def encode_fields(fields: List[Field]) raises -> String:
    var out = String("")
    for i in range(len(fields)):
        if i > 0:
            out += "|"
        out += fields[i].key + "=" + encode_value(fields[i].value)
    return out


def split_unescaped(line: String) raises -> List[String]:
    """Split on unescaped `|` characters."""
    var out = List[String]()
    var current = String("")
    var escaped = False
    for i in range(line.byte_length()):
        var ch = line[byte=i]
        if escaped:
            current += String(ch)
            escaped = False
        elif ch == "\\":
            current += String(ch)
            escaped = True
        elif ch == "|":
            out.append(current^)
            current = String("")
        else:
            current += String(ch)
    if escaped:
        raise Error("dangling escape in record line")
    out.append(current^)
    return out^


def decode_fields(payload: String) raises -> Dict[String, String]:
    var out = Dict[String, String]()
    var parts = split_unescaped(payload)
    for part in parts:
        var text = String(part)
        var equals_at = -1
        for i in range(text.byte_length()):
            if text[byte=i] == "=":
                equals_at = i
                break
        if equals_at <= 0:
            raise Error("malformed payload field")
        var prefix = String("")
        for i in range(equals_at):
            prefix += String(text[byte=i])
        var suffix = String("")
        for i in range(equals_at + 1, text.byte_length()):
            suffix += String(text[byte=i])
        if prefix in out:
            raise Error("duplicate field: " + prefix)
        out[prefix] = decode_value(suffix)
    return out^


def record_checksum(seq: UInt64, kind: String, payload: String) raises -> String:
    return hex64(fnv1a64(String(seq) + "|" + kind + "|" + payload))


struct JournalRecord:
    var seq: UInt64
    var kind: String
    var fields: Dict[String, String]

    def __init__(
        out self, seq: UInt64, kind: String, var fields: Dict[String, String]
    ):
        self.seq = seq
        self.kind = kind
        self.fields = fields^


def serialize_record(seq: UInt64, kind: String, fields: List[Field]) raises -> String:
    var payload = encode_fields(fields)
    return (
        JOURNAL_MAGIC + "|" + String(seq) + "|" + kind + "|"
        + record_checksum(seq, kind, payload) + "|" + payload + "\n"
    )


def split_record_line(line: String) raises -> List[String]:
    """Split only the four structural `|` separators; the rest is payload.

    Payload fields are themselves separated by `|`, so a plain split cannot be
    used here. Escape handling applies only before the payload begins.
    """
    var out = List[String]()
    var current = String("")
    var escaped = False
    var separators = 0
    for i in range(line.byte_length()):
        var ch = line[byte=i]
        if separators < 4:
            if escaped:
                current += String(ch)
                escaped = False
            elif ch == "\\":
                current += String(ch)
                escaped = True
            elif ch == "|":
                out.append(current^)
                current = String("")
                separators += 1
            else:
                current += String(ch)
        else:
            current += String(ch)
    out.append(current^)
    return out^


def strip_trailing_newline(line: String) raises -> String:
    if not line.endswith("\n"):
        return line
    var out = String("")
    for i in range(line.byte_length() - 1):
        out += String(line[byte=i])
    return out


def parse_record(raw_line: String) raises -> JournalRecord:
    var line = strip_trailing_newline(raw_line)
    var parts = split_record_line(line)
    if len(parts) != 5:
        raise Error("record field count is not 5")
    if parts[0] != JOURNAL_MAGIC:
        raise Error("unknown journal version")
    var seq = UInt64(Int(parts[1]))
    var kind = String(parts[2])
    var checksum = String(parts[3])
    var payload = String(parts[4])
    if record_checksum(seq, kind, payload) != checksum:
        raise Error("journal checksum mismatch")
    var fields = decode_fields(payload)
    return JournalRecord(seq, kind, fields^)
