"""Typed trial record for AutoML experiments."""

from hyperforge.evidence.record import Field

comptime TRIAL_STATE_CREATED = "CREATED"
comptime TRIAL_STATE_SUCCEEDED = "SUCCEEDED"
comptime TRIAL_STATE_FAILED = "FAILED"
comptime TRIAL_SPLIT_VALIDATION = "validation"
comptime TRIAL_SPLIT_TEST = "test"


struct Trial(Copyable, Movable):
    var experiment_id: String
    var candidate_id: String
    var model_kind: String
    var index: Int
    var split: String
    var mae: Float64
    var rmse: Float64
    var r2: Float64
    var state: String
    var detail: String

    def __init__(
        out self,
        experiment_id: String,
        candidate_id: String,
        model_kind: String,
        index: Int,
        split: String,
        mae: Float64,
        rmse: Float64,
        r2: Float64,
        state: String,
        detail: String,
    ):
        self.experiment_id = experiment_id
        self.candidate_id = candidate_id
        self.model_kind = model_kind
        self.index = index
        self.split = split
        self.mae = mae
        self.rmse = rmse
        self.r2 = r2
        self.state = state
        self.detail = detail


def trial_to_fields(trial: Trial) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("exp_id", trial.experiment_id))
    fields.append(Field("candidate_id", trial.candidate_id))
    fields.append(Field("model_kind", trial.model_kind))
    fields.append(Field("index", String(trial.index)))
    fields.append(Field("split", trial.split))
    fields.append(Field("mae", String(trial.mae)))
    fields.append(Field("rmse", String(trial.rmse)))
    fields.append(Field("r2", String(trial.r2)))
    fields.append(Field("state", trial.state))
    fields.append(Field("detail", trial.detail))
    return fields^


def trial_from_fields(fields: Dict[String, String]) raises -> Trial:
    return Trial(
        fields["exp_id"],
        fields["candidate_id"],
        fields["model_kind"],
        Int(fields["index"]),
        fields["split"],
        Float64(fields["mae"]),
        Float64(fields["rmse"]),
        Float64(fields["r2"]),
        fields["state"],
        fields["detail"],
    )
