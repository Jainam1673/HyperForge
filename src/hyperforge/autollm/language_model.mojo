"""Tiny first-party next-token model trained with the autodiff tape.

This is a maximum-entropy context model over byte tokens: a *real* trainable
language model with genuine reverse-mode gradients, not MAX inference and not
a frontier transformer. Every stage records that boundary explicitly.
"""

from std.math import exp, log
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodiff.tape import Tape

comptime LM_SCHEMA = "hyperforge-autollm-tiny-lm-v1"
comptime LM_CONTEXT = 3
comptime LM_MAGIC = "HFLLM1"


struct Vocabulary(Copyable, Movable):
    var bytes: List[Int]

    def __init__(out self):
        self.bytes = List[Int]()

    def size(self) raises -> Int:
        return len(self.bytes) + 1

    def id_of(self, byte_value: Int) raises -> Int:
        for i in range(len(self.bytes)):
            if self.bytes[i] == byte_value:
                return i + 1
        return -1

    def byte_of(self, id: Int) raises -> Int:
        if id < 1 or id > len(self.bytes):
            raise Error("token id out of range")
        return self.bytes[id - 1]

    def contains_byte(self, byte_value: Int) raises -> Bool:
        return self.id_of(byte_value) > 0


struct TinyLM(Copyable, Movable):
    var vocab: Vocabulary
    var params: List[Float64]
    var checkpoint: String

    def __init__(out self, vocab: Vocabulary, params: List[Float64], checksum: String):
        self.vocab = vocab.copy()
        self.params = params.copy()
        self.checkpoint = checksum


def build_vocab(content: String) raises -> Vocabulary:
    var vocabulary = Vocabulary()
    for i in range(content.byte_length()):
        var byte_value = ord(String(content[byte=i]))
        if not vocabulary.contains_byte(byte_value):
            vocabulary.bytes.append(byte_value)
    for i in range(1, len(vocabulary.bytes)):
        var value = vocabulary.bytes[i]
        var j = i - 1
        while j >= 0 and vocabulary.bytes[j] > value:
            vocabulary.bytes[j + 1] = vocabulary.bytes[j]
            j -= 1
        vocabulary.bytes[j + 1] = value
    return vocabulary^


def tokenize(vocabulary: Vocabulary, content: String) raises -> List[Int]:
    var tokens = List[Int]()
    for i in range(content.byte_length()):
        var id = vocabulary.id_of(ord(String(content[byte=i])))
        if id < 1:
            raise Error("input contains a byte outside the model vocabulary")
        tokens.append(id)
    return tokens^


def derive_seed_local(seed: UInt64, tag: String, index: UInt64) raises -> UInt64:
    return derive_seed(seed, tag, index)


def init_params(vocabulary: Vocabulary, seed: UInt64) raises -> List[Float64]:
    var input_dim = vocabulary.size() * LM_CONTEXT
    var output_dim = vocabulary.size() + 1
    var rng = SplitMix64(derive_seed_local(seed, "tiny-lm-init", UInt64(0)))
    var params = List[Float64]()
    for _ in range(output_dim * input_dim):
        params.append(
            (Float64(Int(rng.next_below(UInt64(2001)))) - 1000.0) / 100000.0
        )
    return params^


def input_dim_of(vocabulary: Vocabulary) raises -> Int:
    return vocabulary.size() * LM_CONTEXT


def logits_plain(model: TinyLM, context: List[Int]) raises -> List[Float64]:
    var vocabulary_size = model.vocab.size()
    var dim = input_dim_of(model.vocab)
    var out = List[Float64]()
    for target in range(vocabulary_size + 1):
        var value = 0.0
        for p in range(LM_CONTEXT):
            var index = target * dim + p * vocabulary_size + context[p]
            value += model.params[index]
        out.append(value)
    return out^


def train_tiny_lm(
    mut model: TinyLM,
    tokens: List[Int],
    epochs: Int,
    learning_rate: Float64,
) raises -> Float64:
    """Real reverse-mode training of softmax cross-entropy on the tape."""
    if len(tokens) <= LM_CONTEXT:
        raise Error("training corpus is shorter than the context window")
    if epochs < 1:
        raise Error("epochs must be positive")
    var vocabulary_size = model.vocab.size()
    var dim = input_dim_of(model.vocab)
    var final_loss = 0.0

    for _ in range(epochs):
        for t in range(LM_CONTEXT, len(tokens)):
            var tape = Tape()
            var logits = List[Int]()
            for out_id in range(vocabulary_size + 1):
                var acc = tape.constant(0.0)
                for p in range(LM_CONTEXT):
                    var flat = out_id * dim + p * vocabulary_size + tokens[t - LM_CONTEXT + p]
                    var node = tape.parameter(model.params[flat], flat)
                    acc = tape.add(acc, node)
                logits.append(acc)

            var max_logit = -1e300
            for i in range(len(logits)):
                var value = tape.value(logits[i])
                if value > max_logit:
                    max_logit = value
            var max_node = tape.constant(max_logit)
            var sum_exp = tape.constant(0.0)
            for i in range(len(logits)):
                sum_exp = tape.add(sum_exp, tape.exp(tape.sub(logits[i], max_node)))
            var log_sum = tape.log(sum_exp)
            var shifted_target = tape.sub(logits[tokens[t]], max_node)
            var loss = tape.sub(log_sum, shifted_target)
            final_loss = tape.value(loss)
            tape.backward(loss)
            for i in range(len(model.params)):
                model.params[i] -= learning_rate * tape.accumulated(i)
    return final_loss


def join_ints(values: List[Int]) raises -> String:
    var out = String("")
    for i in range(len(values)):
        if i > 0:
            out += ","
        out += String(values[i])
    return out


def join_floats(values: List[Float64]) raises -> String:
    var out = String("")
    for i in range(len(values)):
        if i > 0:
            out += ","
        out += String(values[i])
    return out


def split_csv_ints(text: String) raises -> List[Int]:
    var out = List[Int]()
    for part in text.split(","):
        if String(part) != "":
            out.append(Int(String(part)))
    return out^


def split_csv_floats(text: String) raises -> List[Float64]:
    var out = List[Float64]()
    for part in text.split(","):
        if String(part) != "":
            out.append(Float64(String(part)))
    return out^


def field_value(line: String, key: String) raises -> String:
    for part in line.split("|"):
        var piece = String(part)
        var prefix = key + "="
        if piece.startswith(prefix):
            return String(piece[byte=prefix.byte_length():])
    return String("")


def checkpoint_content(model: TinyLM) raises -> String:
    return (
        LM_MAGIC + "|schema=" + LM_SCHEMA
        + "|context=" + String(LM_CONTEXT)
        + "|vocab=" + join_ints(model.vocab.bytes)
        + "|params=" + join_floats(model.params)
    )


def save_checkpoint(model: TinyLM, path: String) raises -> String:
    var content = checkpoint_content(model)
    var checksum = hex64(fnv1a64(content))
    var handle = open(path, "w")
    handle.write(content + "|checksum=" + checksum + "\n")
    handle.close()
    return checksum


def strip_trailing_newline(value: String) raises -> String:
    if not value.endswith("\n"):
        return value
    var out = String("")
    for i in range(value.byte_length() - 1):
        out += String(value[byte=i])
    return out


def load_checkpoint(path: String) raises -> TinyLM:
    var raw = open(path, "r").read()
    var content = strip_trailing_newline(raw)
    var checksum = field_value(content, "checksum")
    var body = String("")
    for part in content.split("|"):
        var piece = String(part)
        if not piece.startswith("checksum=") and piece != "":
            if body != "":
                body += "|"
            body += piece
    if hex64(fnv1a64(body)) != checksum:
        raise Error("checkpoint checksum mismatch")
    if field_value(body, "schema") != LM_SCHEMA:
        raise Error("unsupported checkpoint schema")
    var vocabulary = Vocabulary()
    vocabulary.bytes = split_csv_ints(field_value(body, "vocab"))
    var params = split_csv_floats(field_value(body, "params"))
    if len(params) != (vocabulary.size() + 1) * vocabulary.size() * LM_CONTEXT:
        raise Error("checkpoint parameter count mismatch")
    return TinyLM(vocabulary, params, checksum)


def context_at(tokens: List[Int], position: Int) raises -> List[Int]:
    var context = List[Int]()
    for p in range(LM_CONTEXT):
        var index = position - LM_CONTEXT + p
        if index < 0:
            context.append(0)
        else:
            context.append(tokens[index])
    return context^


def sample_tiny_lm(
    model: TinyLM,
    prompt: String,
    max_tokens: Int,
    temperature: Float64,
    top_k: Int,
    seed: UInt64,
) raises -> String:
    if max_tokens < 1 or max_tokens > 256:
        raise Error("max_tokens must be between 1 and 256")
    if temperature <= 0.0:
        raise Error("temperature must be positive")
    var rng = SplitMix64(derive_seed_local(seed, "tiny-lm-sample", UInt64(0)))
    var tokens = tokenize(model.vocab, prompt)
    var out = String("")
    for _ in range(max_tokens):
        var context = context_at(tokens, len(tokens))
        var logits = logits_plain(model, context)
        if top_k > 0 and top_k < len(logits):
            for i in range(len(logits)):
                var keep = False
                for j in range(len(logits)):
                    if logits[j] > logits[i]:
                        var better = 0
                        for k in range(len(logits)):
                            if logits[k] > logits[j]:
                                better += 1
                        if better < top_k:
                            keep = True
                            break
                if not keep:
                    logits[i] = -1e300
        var maximum = -1e300
        for i in range(len(logits)):
            if logits[i] > maximum:
                maximum = logits[i]
        var total = 0.0
        var probabilities = List[Float64]()
        for i in range(len(logits)):
            var probability = exp((logits[i] - maximum) / temperature)
            probabilities.append(probability)
            total += probability
        var threshold = Float64(rng.next_below(UInt64(1000000))) / 1000000.0 * total
        var cumulative = 0.0
        var selected = 0
        for i in range(len(probabilities)):
            cumulative += probabilities[i]
            if cumulative >= threshold:
                selected = i
                break
        if selected == 0 or selected >= model.vocab.size():
            break
        out += chr(model.vocab.byte_of(selected))
        tokens.append(selected)
    return out^
