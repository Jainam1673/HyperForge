"""Local append-only experiment journal with versioning and tail recovery.

This is a project-owned file format. It requires no database or service.
Recovery policy: an invalid **last** record (truncated line, bad checksum,
unknown version, bad sequence, or duplicate ID) is dropped and the validated
prefix is rewritten. An invalid record in the middle is a hard error and the
file is left untouched. Atomic rename is unavailable in installed Mojo 1.2.0,
so the rewrite is a plain full-file write; this limitation is documented.
"""

from std.pathlib import Path
from hyperforge.evidence.record import (
    Field,
    JournalRecord,
    JOURNAL_MAGIC,
    RECORD_EXPERIMENT,
    RECORD_EVENT,
    RECORD_TRIAL,
    RECORD_OPTIMIZER,
    RECORD_SCIENTIFIC,
    RECORD_SCIT,
    RECORD_DISCOVERY,
    parse_record,
    serialize_record,
)


struct JournalReadResult:
    var records: List[JournalRecord]
    var status: String
    var reason: String
    var good_content: String

    def __init__(
        out self,
        var records: List[JournalRecord],
        status: String,
        reason: String,
        good_content: String,
    ):
        self.records = records^
        self.status = status
        self.reason = reason
        self.good_content = good_content


def journal_path(workspace: String) raises -> String:
    return workspace + "/experiments/hf-journal.hfj"


def required_fields_present(record: JournalRecord) raises -> Bool:
    var required = List[String]()
    if record.kind == RECORD_EXPERIMENT:
        required.append("id")
        required.append("name")
        required.append("seed")
        required.append("state")
        required.append("config_artifact")
        required.append("config_checksum")
        required.append("trial_seeds")
    elif record.kind == RECORD_EVENT:
        required.append("exp_id")
        required.append("kind")
        required.append("detail")
        required.append("state")
    elif record.kind == RECORD_TRIAL:
        required.append("exp_id")
        required.append("candidate_id")
        required.append("model_kind")
        required.append("index")
        required.append("split")
        required.append("mae")
        required.append("rmse")
        required.append("r2")
        required.append("state")
        required.append("detail")
    elif record.kind == RECORD_OPTIMIZER:
        required.append("exp_id")
        required.append("observed")
        required.append("succeeded")
        required.append("failed")
        required.append("invalid")
        required.append("best_rmse")
        required.append("best_candidate")
        required.append("policy")
        required.append("search_seconds")
    elif record.kind == RECORD_SCIENTIFIC:
        required.append("exp_id")
        required.append("problem")
        required.append("seed")
        required.append("iters")
        required.append("initial_loss")
        required.append("final_loss")
        required.append("residual")
        required.append("boundary")
        required.append("exact_l2")
        required.append("fd_l2")
        required.append("state")
        required.append("detail")
        required.append("runtime")
    elif record.kind == RECORD_SCIT:
        required.append("exp_id")
        required.append("task")
        required.append("seed")
        required.append("epochs")
        required.append("initial_loss")
        required.append("final_loss")
        required.append("model_mse")
        required.append("persistence_mse")
        required.append("mean_mse")
        required.append("linear_mse")
        required.append("drift")
        required.append("state")
        required.append("detail")
        required.append("runtime")
    elif record.kind == RECORD_DISCOVERY:
        required.append("seed")
        required.append("budget")
        required.append("policy")
        required.append("best_rmse")
        required.append("best_latency")
        required.append("wall_seconds")
        required.append("evaluations")
        required.append("discoveries")
        required.append("pareto_count")
        required.append("detail")
    else:
        return False
    for key in required:
        if String(key) not in record.fields:
            return False
    return True


def read_journal(path: String) raises -> JournalReadResult:
    var records = List[JournalRecord]()
    if not Path(path).exists():
        return JournalReadResult(records^, "OK", "", "")

    var content = open(path, "r").read()
    var ends_with_newline = content.endswith("\n")
    var raw_lines = List[String]()
    for span in content.split("\n"):
        var line = String(span)
        if line != "":
            raw_lines.append(line^)

    var good_content = String("")
    var expected: UInt64 = 1
    var seen_ids = List[String]()
    var line_count = len(raw_lines)

    for i in range(line_count):
        var line = raw_lines[i]
        var is_last = i == line_count - 1
        var failure = String("")
        var record = JournalRecord(UInt64(0), "", Dict[String, String]())
        var parsed_ok = False
        try:
            record = parse_record(line)
            parsed_ok = True
        except e:
            failure = String(e)

        if is_last and not ends_with_newline:
            failure = "truncated last record"

        if failure == "" and parsed_ok:
            if record.seq != expected:
                failure = "sequence is not monotonic"
            elif not required_fields_present(record):
                failure = "missing required fields"
            elif record.kind == RECORD_EXPERIMENT:
                var duplicate = False
                for seen in seen_ids:
                    if seen == record.fields["id"]:
                        duplicate = True
                        break
                if duplicate:
                    failure = "duplicate experiment id"
                else:
                    seen_ids.append(record.fields["id"])

        if failure != "":
            if is_last:
                return JournalReadResult(records^, "RECOVERED", failure, good_content)
            return JournalReadResult(records^, "ERROR", failure, good_content)

        records.append(record^)
        good_content += line + "\n"
        expected += 1

    return JournalReadResult(records^, "OK", "", good_content)


def next_sequence(records: List[JournalRecord]) raises -> UInt64:
    if len(records) == 0:
        return 1
    return records[len(records) - 1].seq + 1


def append_record(
    path: String, seq: UInt64, kind: String, fields: List[Field]
) raises -> None:
    var handle = open(path, "a")
    handle.write(serialize_record(seq, kind, fields))
    handle.close()


def rewrite_journal(path: String, content: String) raises -> None:
    """Used only for documented tail recovery."""
    var handle = open(path, "w")
    handle.write(content)
    handle.close()
