"""M00 CLI unit tests.

Run with: pixi run mojo run -I src tests/test_cli.mojo
`mojo test` does not exist in the installed Mojo 1.2.0 toolchain.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.cli.args import parse_tokens
from hyperforge.doctor import Probe, json_escape, render_json
from hyperforge.workspace import has_parent_segment
from hyperforge.core.exit_codes import (
    EXIT_OK,
    EXIT_FAILURE,
    EXIT_USAGE,
    EXIT_UNAVAILABLE,
    EXIT_INTERNAL,
    EXIT_INTERRUPTED,
)


def test_no_arguments_shows_help() raises:
    var tokens: List[String] = ["hyperforge"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.help)
    assert_equal(parsed.command, "")
    assert_equal(parsed.error, "")


def test_version_flag() raises:
    var tokens: List[String] = ["hyperforge", "--version"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.version)
    assert_equal(parsed.error, "")


def test_doctor_json_flag() raises:
    var tokens: List[String] = ["hyperforge", "doctor", "--json"]
    var parsed = parse_tokens(tokens)
    assert_equal(parsed.command, "doctor")
    assert_true(parsed.json)
    assert_equal(parsed.error, "")


def test_unknown_command_is_usage_error() raises:
    var tokens: List[String] = ["hyperforge", "nonsense"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.error.byte_length() > 0)
    assert_false(parsed.help)


def test_unknown_option_is_usage_error() raises:
    var tokens: List[String] = ["hyperforge", "--bogus"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.error.byte_length() > 0)


def test_init_requires_target() raises:
    var tokens: List[String] = ["hyperforge", "init"]
    var parsed = parse_tokens(tokens)
    assert_equal(parsed.command, "init")
    assert_true(parsed.error.byte_length() > 0)


def test_init_accepts_target() raises:
    var tokens: List[String] = ["hyperforge", "init", "./workspace"]
    var parsed = parse_tokens(tokens)
    assert_equal(parsed.command, "init")
    assert_equal(parsed.target, "./workspace")
    assert_equal(parsed.error, "")


def test_json_only_valid_with_doctor() raises:
    var tokens: List[String] = ["hyperforge", "--json"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.error.byte_length() > 0)


def test_extra_argument_is_usage_error() raises:
    var tokens: List[String] = ["hyperforge", "doctor", "extra"]
    var parsed = parse_tokens(tokens)
    assert_true(parsed.error.byte_length() > 0)


def test_parent_segment_rejected() raises:
    assert_true(has_parent_segment("../escape"))
    assert_true(has_parent_segment("a/../b"))
    assert_false(has_parent_segment("./workspace"))
    assert_false(has_parent_segment("workspace-v1"))


def test_json_escape() raises:
    assert_equal(json_escape('a"b'), 'a\\"b')
    assert_equal(json_escape("a\\b"), "a\\\\b")
    assert_equal(json_escape("line\nnext"), "line\\nnext")


def test_render_json_schema() raises:
    var probes = List[Probe]()
    probes.append(Probe("executable", "OK", "test detail"))
    var rendered = render_json(probes)
    assert_true(rendered.startswith('{"schema":"hyperforge-doctor-v1"'))
    assert_true(rendered.endswith(']}'))


def test_exit_code_contract() raises:
    assert_equal(EXIT_OK, 0)
    assert_equal(EXIT_FAILURE, 1)
    assert_equal(EXIT_USAGE, 2)
    assert_equal(EXIT_UNAVAILABLE, 3)
    assert_equal(EXIT_INTERNAL, 70)
    assert_equal(EXIT_INTERRUPTED, 130)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
