"""Typed causal evidence graph with explicit relation labels.

Relations are `observed`, `experimentally_supported`, or `hypothesized`.
A single correlated change is never promoted to a causal claim; only a
controlled intervention with a measured outcome can be labeled observed.
"""

comptime CAUSAL_SCHEMA = "hyperforge-causal-graph-v1"
comptime RELATION_OBSERVED = "observed"
comptime RELATION_SUPPORTED = "experimentally_supported"
comptime RELATION_HYPOTHESIZED = "hypothesized"


struct CausalNode(Copyable, Movable):
    var id: String
    var kind: String
    var content: String
    var intervention: Bool

    def __init__(out self, id: String, kind: String, content: String, intervention: Bool):
        self.id = id
        self.kind = kind
        self.content = content
        self.intervention = intervention


struct CausalEdge(Copyable, Movable):
    var source: String
    var target: String
    var relation: String
    var evidence: String
    var detail: String

    def __init__(out self, source: String, target: String, relation: String, evidence: String, detail: String):
        self.source = source
        self.target = target
        self.relation = relation
        self.evidence = evidence
        self.detail = detail


def edge_for_measurement(
    hypothesis: CausalNode, run: CausalNode, measured: Bool, evidence: String
) raises -> CausalEdge:
    var relation = String(RELATION_HYPOTHESIZED)
    if measured:
        relation = RELATION_SUPPORTED
    return CausalEdge(
        hypothesis.id, run.id, relation, evidence,
        "controlled intervention with recorded outcome",
    )


def coupling_edge(ai_node: CausalNode, compute_node: CausalNode) raises -> CausalEdge:
    """Cross-loop coupling is a hypothesis until an ablation isolates it."""
    return CausalEdge(
        ai_node.id, compute_node.id, RELATION_HYPOTHESIZED, "ablation_pending",
        "shared evidence does not by itself establish causation",
    )
