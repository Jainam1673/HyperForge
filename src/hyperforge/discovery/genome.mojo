"""First typed DiscoveryGenome: one AI choice and one compute choice.

Only genes with a real execution path are represented: a regression model kind
(M02) and a GPU kernel launch block size (M06). Unsupported combinations are
rejected. The genome is canonicalized and hashed so evidence can reference it
by a stable ID.
"""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.automl.models import MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN

comptime GENOME_SCHEMA = "hyperforge-discovery-genome-v1"
comptime DEFAULT_BLOCK = 256
comptime BLOCK_CHOICES = [Int(64), 128, 256, 512]


struct DiscoveryGenome(Copyable, Movable):
    var model_kind: String
    var block_size: Int

    def __init__(out self, model_kind: String, block_size: Int):
        self.model_kind = model_kind
        self.block_size = block_size


def is_valid_genome(genome: DiscoveryGenome) raises -> Bool:
    if genome.model_kind != MODEL_LINEAR and genome.model_kind != MODEL_RIDGE and genome.model_kind != MODEL_KNN:
        return False
    var choices: List[Int] = [64, 128, 256, 512]
    for choice in choices:
        if genome.block_size == choice:
            return True
    return False


def genome_id(genome: DiscoveryGenome) raises -> String:
    return "genome-" + hex64(
        fnv1a64(genome.model_kind + "|block=" + String(genome.block_size))
    )


def canonical_genome(genome: DiscoveryGenome) raises -> String:
    return genome.model_kind + "|block=" + String(genome.block_size)


def mutate(genome: DiscoveryGenome, side: String, offset: Int) raises -> DiscoveryGenome:
    """Return a mutated genome; only the named side changes."""
    var kinds = List[String]()
    kinds.append(MODEL_LINEAR)
    kinds.append(MODEL_RIDGE)
    kinds.append(MODEL_KNN)
    var model_kind = genome.model_kind
    var block = genome.block_size
    if side == "ai":
        var index = 0
        for i in range(len(kinds)):
            if kinds[i] == model_kind:
                index = i
                break
        var new_index = (index + offset) % len(kinds)
        if new_index < 0:
            new_index += len(kinds)
        model_kind = kinds[new_index]
    elif side == "compute":
        var index = 0
        var choices: List[Int] = [64, 128, 256, 512]
        for i in range(len(choices)):
            if choices[i] == block:
                index = i
                break
        var new_index = (index + offset) % len(choices)
        if new_index < 0:
            new_index += len(choices)
        block = choices[new_index]
    else:
        raise Error("unknown mutation side: " + side)
    var child = DiscoveryGenome(model_kind, block)
    if not is_valid_genome(child):
        raise Error("mutation produced an invalid genome")
    return child^
