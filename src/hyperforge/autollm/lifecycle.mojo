"""AutoLLM lifecycle state machine with checkpoint lineage."""

from hyperforge.evidence.record import JournalRecord

comptime LIFECYCLE_SCHEMA = "hyperforge-autollm-lifecycle-v1"
comptime STAGE_PRETRAIN = "pretrain"
comptime STAGE_MIDTRAIN = "midtrain"
comptime STAGE_POSTTRAIN = "posttrain"
comptime STAGE_INFER = "infer"
comptime STAGE_NONE = "none"


def stage_rank(stage: String) raises -> Int:
    if stage == STAGE_NONE:
        return 0
    if stage == STAGE_PRETRAIN:
        return 1
    if stage == STAGE_MIDTRAIN:
        return 2
    if stage == STAGE_POSTTRAIN:
        return 3
    if stage == STAGE_INFER:
        return 4
    return -1


def latest_stage(records: List[JournalRecord]) raises -> String:
    var latest = String(STAGE_NONE)
    for i in range(len(records)):
        ref record = records[i]
        if record.kind == "autollm_stage":
            if "stage" in record.fields:
                latest = record.fields["stage"]
    return latest^


def lineage_of(records: List[JournalRecord]) raises -> String:
    var parts = List[String]()
    for i in range(len(records)):
        ref record = records[i]
        if record.kind == "autollm_stage":
            if "checksum" in record.fields:
                parts.append(record.fields["checksum"])
    var out = String("")
    for i in range(len(parts)):
        if i > 0:
            out += "->"
        out += parts[i]
    return out^


def can_run(stage: String, latest: String) raises -> Bool:
    if stage_rank(stage) < 1:
        return False
    if stage == STAGE_PRETRAIN:
        return True
    if stage == STAGE_INFER:
        return stage_rank(latest) >= 3
    return stage_rank(latest) >= stage_rank(stage) - 1


def checkpoint_path(workspace: String, stage: String) raises -> String:
    return workspace + "/artifacts/autollm/" + stage + ".ckpt"
