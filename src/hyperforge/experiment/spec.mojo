"""Typed experiment definition and its versioned config artifact contract."""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import derive_seed
from hyperforge.core.state_machine import EXP_DRAFT
from hyperforge.evidence.record import Field

comptime EXPERIMENT_SCHEMA = "hyperforge-experiment-v1"
comptime DEFAULT_SEED: UInt64 = 42
comptime TRIAL_SEED_COUNT = 3


struct Experiment(Copyable, Movable):
    var id: String
    var name: String
    var seed: UInt64
    var state: String
    var config_artifact: String
    var config_checksum: String
    var trial_seeds: String

    def __init__(
        out self,
        id: String,
        name: String,
        seed: UInt64,
        state: String,
        config_artifact: String,
        config_checksum: String,
        trial_seeds: String,
    ):
        self.id = id
        self.name = name
        self.seed = seed
        self.state = state
        self.config_artifact = config_artifact
        self.config_checksum = config_checksum
        self.trial_seeds = trial_seeds


def make_experiment_id(name: String, seed: UInt64) raises -> String:
    return "exp-" + hex64(fnv1a64("experiment|" + name + "|" + String(seed)))


def config_artifact_path(id: String) raises -> String:
    return "artifacts/" + id + ".config.txt"


def config_artifact_content(name: String, seed: UInt64) raises -> String:
    return (
        "HFEXP1|schema=" + EXPERIMENT_SCHEMA + "|name=" + name
        + "|seed=" + String(seed) + "\n"
    )


def derived_trial_seeds(seed: UInt64) raises -> String:
    var out = String("")
    for i in range(TRIAL_SEED_COUNT):
        if i > 0:
            out += ","
        out += String(derive_seed(seed, "trial", UInt64(i)))
    return out


def experiment_from_fields(fields: Dict[String, String]) raises -> Experiment:
    var seed = UInt64(Int(fields["seed"]))
    return Experiment(
        fields["id"],
        fields["name"],
        seed,
        fields["state"],
        fields["config_artifact"],
        fields["config_checksum"],
        fields["trial_seeds"],
    )


def experiment_to_fields(experiment: Experiment) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("id", experiment.id))
    fields.append(Field("name", experiment.name))
    fields.append(Field("seed", String(experiment.seed)))
    fields.append(Field("state", experiment.state))
    fields.append(Field("config_artifact", experiment.config_artifact))
    fields.append(Field("config_checksum", experiment.config_checksum))
    fields.append(Field("trial_seeds", experiment.trial_seeds))
    return fields^
