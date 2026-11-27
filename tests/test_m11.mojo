"""M11 AutoLLM substrate tests: artifacts, suites, honest backend status."""

from std.math import abs
from std.os import mkdir, remove
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.autollm.registry import discover_models, model_format
from hyperforge.autollm.prompt_suite import load_suite, load_responses, evaluate
from hyperforge.autollm.backend import probe_backend, STATUS_UNAVAILABLE, STATUS_BLOCKED
from hyperforge.cli.args import parse_tokens

comptime SUITE = "/home/jack/Projects/HyperForge/examples/autollm/prompts.txt"
comptime RESPONSES = "/home/jack/Projects/HyperForge/examples/autollm/responses.txt"


def test_artifact_discovery() raises:
    var path = "/tmp/opencode/autollm_artifacts"
    if not Path(path).exists():
        mkdir(path)
    if Path(path + "/tiny.model.json").exists():
        remove(path + "/tiny.model.json")
    if Path(path + "/LICENSE.txt").exists():
        remove(path + "/LICENSE.txt")
    var file = open(path + "/tiny.model.json", "w")
    file.write("synthetic fixture\n")
    file.close()
    var license_file = open(path + "/LICENSE.txt", "w")
    license_file.write("Synthetic\n")
    license_file.close()
    var artifacts = discover_models(path)
    assert_equal(len(artifacts), 1)
    assert_equal(artifacts[0].format, ".json")
    assert_equal(artifacts[0].license_status, "DECLARED")
    assert_true(artifacts[0].checksum.byte_length() > 0)
    var again = discover_models(path)
    assert_equal(again[0].checksum, artifacts[0].checksum)
    remove(path + "/tiny.model.json")
    remove(path + "/LICENSE.txt")


def test_prompt_suite_evaluation() raises:
    var suite = load_suite(SUITE)
    assert_equal(len(suite.cases), 3)
    var responses = load_responses(RESPONSES)
    assert_equal(len(responses), 2)
    var result = evaluate(suite, responses)
    assert_equal(result.total, 3)
    assert_equal(result.matched, 2)
    assert_equal(result.missing, 1)
    assert_true(abs(result.accuracy - 2.0 / 3.0) < 1e-6)
    assert_equal(suite.cases[0].metric, "exact")
    assert_equal(suite.cases[1].metric, "contains")


def test_backend_status_is_honest() raises:
    var empty = probe_backend(0)
    assert_equal(empty.status, STATUS_UNAVAILABLE)
    var with_artifact = probe_backend(1)
    assert_equal(with_artifact.status, STATUS_BLOCKED)
    assert_true(with_artifact.detail.byte_length() > 0)


def test_autollm_parser() raises:
    var tokens: List[String] = ["hyperforge", "autollm", "discover", "/tmp/models"]
    var parsed = parse_tokens(tokens)
    assert_equal(parsed.command, "autollm")
    assert_equal(parsed.args[0], "discover")
    assert_equal(parsed.args[1], "/tmp/models")
    assert_equal(parsed.error, "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
