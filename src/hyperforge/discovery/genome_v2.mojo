"""DiscoveryGenome v2: only genes with real execution paths.

AI gene (`model_kind`) is carried for future coupling but is not executed by
the systems-only search; this is stated explicitly in reports. Compute and
runtime genes are executed by the GPU catalogue benchmark.
"""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.models import MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN

comptime GENOME_V2_SCHEMA = "hyperforge-discovery-genome-v2"
comptime BLOCK_CHOICES = "64, 128, 256, 512"
comptime SUPPORTED_KERNELS = "vector_add, vector_axpy"


struct GenomeV2(Copyable, Movable):
    var model_kind: String
    var compute_kernel: String
    var block_size: Int
    var vector_size: Int
    var seed: UInt64

    def __init__(
        out self,
        model_kind: String,
        compute_kernel: String,
        block_size: Int,
        vector_size: Int,
        seed: UInt64,
    ):
        self.model_kind = model_kind
        self.compute_kernel = compute_kernel
        self.block_size = block_size
        self.vector_size = vector_size
        self.seed = seed


def valid_genome(genome: GenomeV2) raises -> Bool:
    if genome.model_kind != MODEL_LINEAR and genome.model_kind != MODEL_RIDGE and genome.model_kind != MODEL_KNN:
        return False
    if genome.compute_kernel != "vector_add" and genome.compute_kernel != "vector_axpy":
        return False
    if genome.block_size != 64 and genome.block_size != 128 and genome.block_size != 256 and genome.block_size != 512:
        return False
    return genome.vector_size == 1024


def genome_id(genome: GenomeV2) raises -> String:
    return "gv2-" + hex64(fnv1a64(
        genome.model_kind + "|" + genome.compute_kernel + "|"
        + String(genome.block_size) + "|" + String(genome.vector_size)
        + "|" + String(genome.seed)
    ))


def canonical(genome: GenomeV2) raises -> String:
    return (
        genome.model_kind + "|" + genome.compute_kernel + "|block="
        + String(genome.block_size) + "|n=" + String(genome.vector_size)
    )


def prior_genome(seed: UInt64, index: Int) raises -> GenomeV2:
    var rng = SplitMix64(derive_seed(seed, "genome-v2", UInt64(index)))
    var kinds: List[String] = [MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN]
    var kernels: List[String] = ["vector_add", "vector_axpy"]
    var blocks: List[Int] = [64, 128, 256, 512]
    var genome = GenomeV2(
        kinds[Int(rng.next_below(UInt64(3)))],
        kernels[Int(rng.next_below(UInt64(2)))],
        blocks[Int(rng.next_below(UInt64(4)))],
        1024,
        seed,
    )
    if not valid_genome(genome):
        raise Error("prior produced an invalid genome")
    return genome^


def mutate_genome(
    parent: GenomeV2, side: String, seed: UInt64, index: Int
) raises -> GenomeV2:
    var rng = SplitMix64(derive_seed(seed, "genome-v2-mutate", UInt64(index)))
    var genome = parent.copy()
    if side == "compute":
        genome.compute_kernel = (
            "vector_axpy" if genome.compute_kernel == "vector_add" else "vector_add"
        )
    elif side == "runtime":
        var blocks: List[Int] = [64, 128, 256, 512]
        genome.block_size = blocks[Int(rng.next_below(UInt64(4)))]
    elif side == "ai":
        var kinds: List[String] = [MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN]
        genome.model_kind = kinds[Int(rng.next_below(UInt64(3)))]
    elif side == "experiment":
        genome.seed = seed
    else:
        raise Error("unknown mutation side: " + side)
    if not valid_genome(genome):
        raise Error("mutation produced an invalid genome")
    return genome^
