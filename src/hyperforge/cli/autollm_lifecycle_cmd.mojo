"""CLI for the complete AutoLLM PreTrain/MidTrain/PostTrain/Infer lifecycle."""

from std import os
from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.autollm.language_model import (
    LM_SCHEMA,
    TinyLM,
    build_vocab,
    init_params,
    load_checkpoint,
    sample_tiny_lm,
    save_checkpoint,
    tokenize,
    train_tiny_lm,
)
from hyperforge.autollm.lifecycle import (
    LIFECYCLE_SCHEMA,
    STAGE_PRETRAIN,
    STAGE_MIDTRAIN,
    STAGE_POSTTRAIN,
    STAGE_INFER,
    STAGE_NONE,
    can_run,
    checkpoint_path,
    lineage_of,
    latest_stage,
)

comptime DEFAULT_SEED = 42
comptime DEFAULT_EPOCHS = 6
comptime BOUNDARY_NOTE = "tiny first-party byte model with real gradients; MAX model inference is a separate BLOCKED_BY_MAX_INTERFACE boundary"


struct LifecycleContext(Copyable, Movable):
    var workspace: String
    var sequence: UInt64
    var stage: String
    var lineage: String

    def __init__(
        out self, workspace: String, sequence: UInt64,
        stage: String, lineage: String,
    ):
        self.workspace = workspace
        self.sequence = sequence
        self.stage = stage
        self.lineage = lineage


def prepare(workspace: String, stage: String) raises -> LifecycleContext:
    var journal = read_journal(journal_path(workspace))
    var latest = latest_stage(journal.records)
    if not can_run(stage, latest):
        raise Error(
            "invalid lifecycle transition: " + latest + " -> " + stage
        )
    var directory = workspace + "/artifacts/autollm"
    if not Path(directory).exists():
        os.mkdir(directory)
    return LifecycleContext(
        workspace, next_sequence(journal.records), latest,
        lineage_of(journal.records),
    )


def fingerprint(path: String) raises -> String:
    return hex64(fnv1a64(open(path, "r").read()))


def record_stage(
    context: LifecycleContext,
    stage: String,
    epochs: Int,
    checksum: String,
    lineage: String,
    detail: String,
    loss: Float64,
) raises -> None:
    var fields = List[Field]()
    fields.append(Field("schema", LIFECYCLE_SCHEMA))
    fields.append(Field("stage", stage))
    fields.append(Field("epochs", String(epochs)))
    fields.append(Field("checksum", checksum))
    fields.append(Field("lineage", lineage))
    fields.append(Field("detail", detail))
    fields.append(Field("loss", String(loss)))
    append_record(
        journal_path(context.workspace), context.sequence,
        "autollm_stage", fields,
    )


def print_stage_header(stage: String, context: LifecycleContext) raises -> None:
    print("schema:          " + LIFECYCLE_SCHEMA)
    print("stage:           " + stage)
    print("previous_stage:  " + context.stage)
    print("lineage:         " + context.lineage)
    print("model_schema:    " + LM_SCHEMA)
    print("note:            " + BOUNDARY_NOTE)


def pretrain_command(
    workspace: String, corpus_path: String, epochs: Int
) raises -> Int:
    var err = stderr
    if epochs < 1 or epochs > 100:
        err.write("hyperforge: epochs must be between 1 and 100\n")
        return EXIT_USAGE
    try:
        var context = prepare(workspace, STAGE_PRETRAIN)
        var content = open(corpus_path, "r").read()
        var vocabulary = build_vocab(content)
        var model = TinyLM(vocabulary, init_params(vocabulary, UInt64(DEFAULT_SEED)), String(""))
        var tokens = tokenize(vocabulary, content)
        var loss = train_tiny_lm(model, tokens, epochs, 0.1)
        var checksum = save_checkpoint(model, checkpoint_path(workspace, STAGE_PRETRAIN))
        var lineage = context.lineage if context.lineage == "" else context.lineage
        if lineage == "":
            lineage = checksum
        else:
            lineage += "->" + checksum
        record_stage(
            context, STAGE_PRETRAIN, epochs, checksum, lineage,
            fingerprint(corpus_path), loss,
        )
        print_stage_header(STAGE_PRETRAIN, context)
        print("vocab_size:      " + String(vocabulary.size()))
        print("training_tokens: " + String(len(tokens)))
        print("final_loss:      " + String(loss))
        print("checksum:        " + checksum)
        print("lineage_after:   " + lineage)
        return EXIT_OK
    except e:
        err.write("hyperforge: pretrain failed: " + String(e) + "\n")
        return EXIT_FAILURE


def continue_command(
    workspace: String, stage: String, corpus_path: String, epochs: Int
) raises -> Int:
    var err = stderr
    if epochs < 1 or epochs > 100:
        err.write("hyperforge: epochs must be between 1 and 100\n")
        return EXIT_USAGE
    try:
        var context = prepare(workspace, stage)
        var previous = STAGE_PRETRAIN if stage == STAGE_MIDTRAIN else STAGE_MIDTRAIN
        var model = load_checkpoint(checkpoint_path(workspace, previous))
        var text = open(corpus_path, "r").read()
        if stage == STAGE_POSTTRAIN:
            # Instruction pairs: prompt<TAB>response per line, trained on the
            # concatenation with a separator. No response is self-validating.
            var combined = String("")
            for line in text.split("\n"):
                var row = String(line)
                if row == "":
                    continue
                if combined != "":
                    combined += "\n"
                combined += row.replace("\t", "\n")
            text = combined^
        var tokens = tokenize(model.vocab, text)
        var loss = train_tiny_lm(model, tokens, epochs, 0.05)
        var checksum = save_checkpoint(model, checkpoint_path(workspace, stage))
        var lineage = context.lineage + "->" + checksum
        record_stage(
            context, stage, epochs, checksum, lineage,
            fingerprint(corpus_path), loss,
        )
        print_stage_header(stage, context)
        print("training_tokens: " + String(len(tokens)))
        print("final_loss:      " + String(loss))
        print("checksum:        " + checksum)
        print("lineage_after:   " + lineage)
        return EXIT_OK
    except e:
        err.write("hyperforge: " + stage + " failed: " + String(e) + "\n")
        return EXIT_FAILURE


def infer_command(
    workspace: String, prompt: String, max_tokens: Int, temperature: Float64
) raises -> Int:
    var err = stderr
    try:
        var context = prepare(workspace, STAGE_INFER)
        var model = load_checkpoint(checkpoint_path(workspace, STAGE_POSTTRAIN))
        var response = sample_tiny_lm(
            model, prompt, max_tokens, temperature, 0, UInt64(DEFAULT_SEED)
        )
        var fields = List[Field]()
        fields.append(Field("schema", LIFECYCLE_SCHEMA))
        fields.append(Field("prompt", prompt))
        fields.append(Field("response", response))
        fields.append(Field("lineage", context.lineage))
        fields.append(Field("model_checksum", model.checkpoint))
        fields.append(Field("seed", String(DEFAULT_SEED)))
        fields.append(Field("max_tokens", String(max_tokens)))
        fields.append(Field("temperature", String(temperature)))
        append_record(
            journal_path(workspace), context.sequence,
            "autollm_response", fields,
        )
        print("schema:          " + LIFECYCLE_SCHEMA)
        print("stage:           " + STAGE_INFER)
        print("prompt:          " + prompt)
        print("response:        " + response)
        print("model_checksum:  " + model.checkpoint)
        print("lineage:         " + context.lineage)
        print("note:            " + BOUNDARY_NOTE)
        return EXIT_OK
    except e:
        err.write("hyperforge: infer failed: " + String(e) + "\n")
        return EXIT_FAILURE


def lifecycle_status(workspace: String) raises -> None:
    var journal = read_journal(journal_path(workspace))
    var stage = latest_stage(journal.records)
    var lineage = lineage_of(journal.records)
    print("lifecycle_schema:" + " " + LIFECYCLE_SCHEMA)
    print("lifecycle_stage: " + stage)
    print("checkpoint_chain:" + " " + (lineage if lineage != "" else "NONE"))
    print("first_party_lm:  " + LM_SCHEMA)
    print("model_scope:     tiny byte-level max-entropy context model; not a frontier LLM")
    print("max_inference:   " + "BLOCKED_BY_MAX_INTERFACE (separate boundary)")
    if stage == STAGE_NONE:
        print("next_action:     hyperforge autollm pretrain <corpus>")
    elif stage == STAGE_PRETRAIN:
        print("next_action:     hyperforge autollm midtrain <corpus>")
    elif stage == STAGE_MIDTRAIN:
        print("next_action:     hyperforge autollm posttrain <pairs.tsv>")
    else:
        print("next_action:     hyperforge autollm infer <prompt>")
