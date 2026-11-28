"""M23 AutoLLM full lifecycle tests: tiny first-party model and stages."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.autollm.language_model import (
    Vocabulary,
    TinyLM,
    build_vocab,
    tokenize,
    init_params,
    train_tiny_lm,
    save_checkpoint,
    load_checkpoint,
    sample_tiny_lm,
    logits_plain,
)
from hyperforge.autollm.lifecycle import (
    STAGE_NONE, STAGE_PRETRAIN, STAGE_MIDTRAIN, STAGE_POSTTRAIN, STAGE_INFER,
    stage_rank, can_run, latest_stage, lineage_of,
)
from hyperforge.evidence.record import Field, JournalRecord, decode_fields
from hyperforge.evidence.record import encode_fields

comptime CORPUS = "/home/jack/Projects/HyperForge/examples/autollm/corpus_pre.txt"


def test_vocab_and_tokenization() raises:
    var content = open(CORPUS, "r").read()
    var vocab = build_vocab(content)
    assert_true(vocab.size() > 2)
    var same = build_vocab(content)
    assert_equal(len(vocab.bytes), len(same.bytes))
    for i in range(len(vocab.bytes)):
        assert_equal(vocab.bytes[i], same.bytes[i])
    var tokens = tokenize(vocab, content)
    assert_true(len(tokens) > 3)
    var first_params = init_params(vocab, UInt64(42))
    var second_params = init_params(vocab, UInt64(42))
    assert_equal(len(first_params), len(second_params))
    assert_true(first_params[0] == second_params[0])


def test_training_reduces_loss() raises:
    var content = open(CORPUS, "r").read()
    var vocab = build_vocab(content)
    var tokens = tokenize(vocab, content)
    var short = TinyLM(vocab, init_params(vocab, UInt64(42)), String(""))
    var short_loss = train_tiny_lm(short, tokens, 1, 0.1)
    var long = TinyLM(vocab, init_params(vocab, UInt64(42)), String(""))
    var long_loss = train_tiny_lm(long, tokens, 6, 0.1)
    assert_true(long_loss < short_loss)
    var logits = logits_plain(long, [1, 2, 3])
    assert_true(len(logits) == vocab.size() + 1)


def test_checkpoint_roundtrip_and_corruption() raises:
    var content = open(CORPUS, "r").read()
    var vocab = build_vocab(content)
    var model = TinyLM(vocab, init_params(vocab, UInt64(7)), String(""))
    var checksum = save_checkpoint(model, "/tmp/opencode/hf-lm-test.ckpt")
    var loaded = load_checkpoint("/tmp/opencode/hf-lm-test.ckpt")
    assert_equal(loaded.checkpoint, checksum)
    assert_equal(len(loaded.params), len(model.params))

    var path = "/tmp/opencode/hf-lm-corrupt.ckpt"
    var handle = open(path, "w")
    handle.write("HFLLM1|schema=bad|checksum=deadbeef\n")
    handle.close()
    var rejected = False
    try:
        _ = load_checkpoint(path)
    except e:
        _ = e
        rejected = True
    assert_true(rejected)


def test_sampling_is_bounded_and_deterministic() raises:
    var content = open(CORPUS, "r").read()
    var vocab = build_vocab(content)
    var model = TinyLM(vocab, init_params(vocab, UInt64(42)), String(""))
    var first = sample_tiny_lm(model, "the ", 4, 1.0, 0, UInt64(42))
    var again = sample_tiny_lm(model, "the ", 4, 1.0, 0, UInt64(42))
    assert_equal(first, again)
    assert_true(first.byte_length() <= 4)
    var rejected = False
    try:
        _ = sample_tiny_lm(model, "the ", 0, 1.0, 0, UInt64(42))
    except e:
        _ = e
        rejected = True
    assert_true(rejected)


def test_lifecycle_transitions() raises:
    assert_true(can_run(STAGE_PRETRAIN, STAGE_NONE))
    assert_false(can_run(STAGE_MIDTRAIN, STAGE_NONE))
    assert_true(can_run(STAGE_MIDTRAIN, STAGE_PRETRAIN))
    assert_false(can_run(STAGE_POSTTRAIN, STAGE_PRETRAIN))
    assert_true(can_run(STAGE_POSTTRAIN, STAGE_MIDTRAIN))
    assert_true(can_run(STAGE_INFER, STAGE_POSTTRAIN))
    assert_false(can_run(STAGE_INFER, STAGE_MIDTRAIN))
    assert_true(stage_rank(STAGE_POSTTRAIN) > stage_rank(STAGE_MIDTRAIN))

    var records = List[JournalRecord]()
    for stage in [STAGE_PRETRAIN, STAGE_MIDTRAIN, STAGE_POSTTRAIN]:
        var fields = List[Field]()
        fields.append(Field("stage", stage))
        fields.append(Field("checksum", hex64(fnv1a64(stage))))
        fields.append(Field("schema", "x"))
        fields.append(Field("epochs", "1"))
        fields.append(Field("lineage", "x"))
        fields.append(Field("detail", "x"))
        fields.append(Field("loss", "0.0"))
        records.append(JournalRecord(UInt64(len(records) + 1), "autollm_stage", decode_fields(encode_fields(fields))))
    assert_equal(latest_stage(records), STAGE_POSTTRAIN)
    assert_equal(len(lineage_of(records).split("->")), 3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
