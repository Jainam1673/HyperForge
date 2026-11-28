"""M24 MAX adapter and portability contract tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.runtime.max_adapter import (
    probe_adapter,
    serve_decision,
    verification_checklist,
    SERVE_DISABLED,
)
from hyperforge.runtime.portability import (
    target_matrix,
    source_rules,
    current_target,
    portability_summary,
    VERIFIED_TARGET,
)


def test_adapter_refuses_unverified_interface() raises:
    var status = probe_adapter(0)
    assert_true(status.status == "BLOCKED_BY_MAX_INTERFACE")
    assert_false(status.serve_enabled)
    assert_equal(serve_decision(status), SERVE_DISABLED)
    assert_false(status.reason == "")
    var with_artifacts = probe_adapter(5)
    assert_false(with_artifacts.serve_enabled)
    assert_equal(serve_decision(with_artifacts), SERVE_DISABLED)


def test_checklist_and_portability() raises:
    assert_true(len(verification_checklist()) == 6)
    assert_true(len(source_rules()) == 5)
    var targets = target_matrix()
    assert_true(len(targets) == 5)
    var verified = 0
    var untested = 0
    for i in range(len(targets)):
        if targets[i].status == "VERIFIED":
            verified += 1
        if targets[i].status == "NOT_TESTED":
            untested += 1
    assert_true(verified >= 2)
    assert_true(untested >= 3)
    assert_true(find_in_string(portability_summary(), VERIFIED_TARGET))
    var target = current_target()
    assert_true(target == "cpu" or target == "UNKNOWN_VENDOR")


def find_in_string(haystack: String, needle: String) raises -> Bool:
    for i in range(haystack.byte_length() - needle.byte_length() + 1):
        var matched = True
        for j in range(needle.byte_length()):
            if String(haystack[byte=i + j]) != String(needle[byte=j]):
                matched = False
                break
        if matched:
            return True
    return False


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
