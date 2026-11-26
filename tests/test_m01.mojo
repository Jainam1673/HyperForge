"""M01 core, journal, and recovery tests.

Run with: pixi run mojo run -I src tests/test_m01.mojo
"""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.os import remove
from std.pathlib import Path
from hyperforge.core.hash import fnv1a64, hex64, FNV_OFFSET
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.core.state_machine import (
    can_transition_trial,
    can_transition_experiment,
    is_terminal_trial_state,
)
from hyperforge.evidence.record import (
    Field,
    encode_value,
    decode_value,
    serialize_record,
    parse_record,
)
from hyperforge.evidence.journal import read_journal
from hyperforge.experiment.spec import (
    experiment_from_fields,
    experiment_to_fields,
    Experiment,
)
from hyperforge.cli.args import parse_tokens


def write_temp(path: String, content: String) raises -> None:
    var handle = open(path, "w")
    handle.write(content)
    handle.close()


def make_experiment_fields(id: String) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("id", id))
    fields.append(Field("name", "demo"))
    fields.append(Field("seed", "42"))
    fields.append(Field("state", "DRAFT"))
    fields.append(Field("config_artifact", "artifacts/x.config.txt"))
    fields.append(Field("config_checksum", "abc123"))
    fields.append(Field("trial_seeds", "1,2,3"))
    return fields^


def test_fnv_known_values() raises:
    assert_equal(fnv1a64(""), FNV_OFFSET)
    assert_equal(fnv1a64("a"), UInt64(12638187200555641996))


def test_hex64_format() raises:
    assert_equal(hex64(UInt64(0)), "0000000000000000")
    assert_equal(hex64(UInt64(255)), "00000000000000ff")


def test_splitmix_is_deterministic() raises:
    var a = SplitMix64(12345)
    var b = SplitMix64(12345)
    var c = SplitMix64(12346)
    assert_equal(a.next_u64(), b.next_u64())
    assert_equal(a.next_u64(), b.next_u64())
    assert_true(a.next_u64() != c.next_u64())
    var bounded = SplitMix64(7)
    assert_equal(bounded.next_below(UInt64(0)), UInt64(0))


def test_seed_derivation() raises:
    assert_equal(derive_seed(42, "trial", 0), derive_seed(42, "trial", 0))
    assert_true(derive_seed(42, "trial", 0) != derive_seed(42, "valid", 0))
    assert_true(derive_seed(42, "trial", 0) != derive_seed(42, "trial", 1))


def test_state_transitions() raises:
    assert_true(can_transition_trial("CREATED", "QUEUED"))
    assert_true(can_transition_trial("RUNNING", "SUCCEEDED"))
    assert_false(can_transition_trial("SUCCEEDED", "RUNNING"))
    assert_false(can_transition_trial("CREATED", "SUCCEEDED"))
    assert_true(is_terminal_trial_state("FAILED"))
    assert_false(is_terminal_trial_state("RUNNING"))
    assert_true(can_transition_experiment("DRAFT", "RUNNING"))
    assert_false(can_transition_experiment("COMPLETED", "DRAFT"))


def test_field_codec_roundtrip() raises:
    var original = String("a|b=c\\d\ne")
    assert_equal(decode_value(encode_value(original)), original)


def test_record_roundtrip_and_tamper() raises:
    var fields = make_experiment_fields("exp-test")
    var line = serialize_record(UInt64(1), "experiment", fields)
    var record = parse_record(line)
    assert_equal(record.seq, UInt64(1))
    assert_equal(record.kind, "experiment")
    assert_equal(record.fields["id"], "exp-test")
    assert_equal(record.fields["name"], "demo")

    var tampered = line.replace("HFJ1", "HFX1")
    with assert_raises():
        _ = parse_record(tampered)


def test_experiment_fields_roundtrip() raises:
    var original = Experiment("exp-a", "demo", UInt64(42), "DRAFT", "artifacts/a", "cc", "1,2,3")
    var encoded = serialize_record(UInt64(1), "experiment", experiment_to_fields(original))
    var restored = experiment_from_fields(parse_record(encoded).fields)
    assert_equal(restored.id, "exp-a")
    assert_equal(restored.seed, UInt64(42))
    assert_equal(restored.trial_seeds, "1,2,3")


def test_journal_recovers_corrupt_tail() raises:
    var path = "/tmp/opencode/m01_test_tail.hfj"
    if Path(path).exists():
        remove(path)
    var good = serialize_record(UInt64(1), "experiment", make_experiment_fields("exp-a"))
    write_temp(path, good + "HFJ1|2|event|deadbeef|exp_id=x|kind=Y|detail=z|state=DRAFT\n")
    var result = read_journal(path)
    assert_equal(result.status, "RECOVERED")
    assert_equal(len(result.records), 1)
    remove(path)


def test_journal_recovers_truncated_tail() raises:
    var path = "/tmp/opencode/m01_test_trunc.hfj"
    if Path(path).exists():
        remove(path)
    var good = serialize_record(UInt64(1), "experiment", make_experiment_fields("exp-a"))
    write_temp(path, good + "HFJ1|2|event|bad")
    var result = read_journal(path)
    assert_equal(result.status, "RECOVERED")
    assert_equal(result.reason, "truncated last record")
    remove(path)


def test_journal_rejects_middle_corruption() raises:
    var path = "/tmp/opencode/m01_test_middle.hfj"
    if Path(path).exists():
        remove(path)
    var bad = serialize_record(UInt64(1), "experiment", make_experiment_fields("exp-a"))
    bad = bad.replace("HFJ1", "HFJ9")
    var good = serialize_record(UInt64(2), "experiment", make_experiment_fields("exp-b"))
    write_temp(path, bad + good)
    var result = read_journal(path)
    assert_equal(result.status, "ERROR")
    assert_equal(result.reason, "unknown journal version")
    remove(path)


def test_journal_rejects_duplicate_id() raises:
    var path = "/tmp/opencode/m01_test_dup.hfj"
    if Path(path).exists():
        remove(path)
    var first = serialize_record(UInt64(1), "experiment", make_experiment_fields("exp-a"))
    var second = serialize_record(UInt64(2), "experiment", make_experiment_fields("exp-a"))
    write_temp(path, first + second)
    var result = read_journal(path)
    assert_equal(result.status, "RECOVERED")
    assert_equal(result.reason, "duplicate experiment id")
    remove(path)


def test_parser_experiment_commands() raises:
    var list_tokens: List[String] = ["hyperforge", "experiment", "list", "--json"]
    var list_args = parse_tokens(list_tokens)
    assert_equal(list_args.command, "experiment")
    assert_equal(list_args.subcommand, "list")
    assert_true(list_args.json)
    assert_equal(list_args.error, "")

    var create_tokens: List[String] = ["hyperforge", "experiment", "create", "demo", "7"]
    var create_args = parse_tokens(create_tokens)
    assert_equal(create_args.subcommand, "create")
    assert_equal(create_args.target, "demo")
    assert_equal(create_args.extra, "7")

    var bad_tokens: List[String] = ["hyperforge", "experiment"]
    var bad_args = parse_tokens(bad_tokens)
    assert_true(bad_args.error.byte_length() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
