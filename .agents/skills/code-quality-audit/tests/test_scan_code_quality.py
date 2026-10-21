from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "scan_code_quality.py"


class ScannerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write(self, relative: str, source: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(source).strip() + "\n", encoding="utf-8")
        return path

    def run_scan(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(self.root), *arguments],
            check=check,
            capture_output=True,
            text=True,
        )

    def json_findings(self, *arguments: str) -> list[dict[str, object]]:
        result = self.run_scan(*arguments, "--format", "json")
        return json.loads(result.stdout)

    def test_java_profile_distinguishes_throw_from_fallback(self) -> None:
        self.write(
            "src/main/java/example/Selection.java",
            """
            class Selection {
                Object required() {
                    return values.stream().findFirst().orElseThrow();
                }

                Object guessed() {
                    return values.stream().findFirst().orElse(defaultValue);
                }

                void swallowed() {
                    try {
                        call();
                    } catch (Exception ignored) {
                    }
                }

                Object masked() {
                    try {
                        return call();
                    } catch (RuntimeException error) {
                        return null;
                    }
                }
            }
            """,
        )

        findings = self.json_findings("--profile", "backend-java")
        rule_ids = [finding["rule_id"] for finding in findings]

        self.assertEqual(1, rule_ids.count("find-first-fallback-selection"))
        self.assertEqual(1, rule_ids.count("silent-catch"))
        self.assertEqual(1, rule_ids.count("catch-empty-result"))
        self.assertEqual(2, rule_ids.count("broad-catch-java"))

    def test_one_line_catch_uses_catch_body(self) -> None:
        self.write(
            "src/main/java/example/OneLine.java",
            "class OneLine { void run() { try { call(); } catch (Exception ignored) {} } }",
        )

        findings = self.json_findings("--profile", "backend-java")

        self.assertIn("silent-catch", [finding["rule_id"] for finding in findings])

    def test_documented_catch_and_logged_empty_result_are_medium(self) -> None:
        self.write(
            "src/main/java/example/Compatibility.java",
            """
            class Compatibility {
                void cleanup() {
                    try {
                        remove();
                    } catch (MissingValueException ignored) {
                        // Deletion is idempotent by contract.
                    }
                }

                Optional<Value> parse(String raw) {
                    try {
                        return Optional.of(parseValue(raw));
                    } catch (IllegalArgumentException error) {
                        logger.debug("Invalid compatibility value", error);
                        return Optional.empty();
                    }
                }
            }
            """,
        )

        findings = self.json_findings("--profile", "backend-java")
        target = [
            finding
            for finding in findings
            if finding["rule_id"] in {"silent-catch", "catch-empty-result"}
        ]

        self.assertEqual(["MEDIUM", "MEDIUM"], [finding["severity"] for finding in target])

    def test_react_effect_requires_local_state_setter(self) -> None:
        self.write(
            "src/Panel.tsx",
            """
            export function Panel({ remote }: Props) {
                useEffect(() => {
                    setValue(remote)
                }, [remote])

                useEffect(() => subscribe(remote), [remote])
                return <Suspense fallback={<Spinner />}><Content /></Suspense>
            }
            """,
        )

        findings = self.json_findings("--profile", "frontend-react")
        rule_ids = [finding["rule_id"] for finding in findings]

        self.assertEqual(1, rule_ids.count("react-effect-state-copy"))
        self.assertNotIn("fallback-contract-name", rule_ids)

    def test_test_support_rule_uses_generic_resource_terms(self) -> None:
        self.write(
            "tests/test_fixture.py",
            """
            def create_test_bucket():
                return None
            """,
        )

        findings = self.json_findings(
            "--profile", "test-support", "--min-severity", "low"
        )

        self.assertEqual(
            ["test-helper-runtime-resource"],
            [finding["rule_id"] for finding in findings],
        )

    def test_tool_directories_are_excluded(self) -> None:
        self.write(
            ".agents/skills/example/bad.py",
            """
            try:
                call()
            except Exception:
                pass
            """,
        )
        self.write(
            ".codex/tools/bad.py",
            """
            try:
                call()
            except Exception:
                pass
            """,
        )
        self.write(
            ".claude/skills/example/bad.py",
            """
            try:
                call()
            except Exception:
                pass
            """,
        )

        findings = self.json_findings("--profile", "backend-python")

        self.assertEqual([], findings)

    def test_baseline_and_summary_are_not_truncated(self) -> None:
        self.write(
            "src/main/java/example/Catches.java",
            """
            class Catches {
                void one() { try { call(); } catch (Exception error) { throw error; } }
                void two() { try { call(); } catch (Exception error) { throw error; } }
                void three() { try { call(); } catch (Exception error) { throw error; } }
            }
            """,
        )
        baseline = self.root / "baseline.json"

        emitted = self.run_scan(
            "--profile",
            "backend-java",
            "--max-findings",
            "1",
            "--write-baseline",
            str(baseline),
            "--format",
            "json",
        )
        summary = self.run_scan(
            "--profile", "backend-java", "--max-findings", "1", "--summary-only"
        )

        self.assertEqual(1, len(json.loads(emitted.stdout)))
        self.assertEqual(
            3, len(json.loads(baseline.read_text(encoding="utf-8"))["findings"])
        )
        self.assertIn("MEDIUM=3", summary.stdout)

    def test_incompatible_baseline_configuration_fails(self) -> None:
        self.write(
            "src/main/java/example/Catch.java",
            "class Catch { void run() { try { call(); } catch (Exception error) { throw error; } } }",
        )
        baseline = self.root / "baseline.json"
        self.run_scan(
            "--profile", "backend-java", "--write-baseline", str(baseline)
        )

        result = self.run_scan(
            "--profile",
            "all",
            "--baseline",
            str(baseline),
            "--only-new",
            check=False,
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("configuration does not match", result.stderr)

    def test_changed_since_scans_modified_and_untracked_files_only(self) -> None:
        self.write("Changed.java", "class Changed { void run() {} }")
        self.write(
            "Unchanged.java",
            "class Unchanged { void run() { try { call(); } catch (Exception error) { throw error; } } }",
        )
        subprocess.run(["git", "init"], cwd=self.root, check=True, capture_output=True)
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(
            [
                "git",
                "-c",
                "user.name=Scanner Test",
                "-c",
                "user.email=scanner@example.test",
                "commit",
                "-m",
                "fixture",
            ],
            cwd=self.root,
            check=True,
            capture_output=True,
        )
        self.write(
            "Changed.java",
            "class Changed { void run() { try { call(); } catch (Exception error) { throw error; } } }",
        )
        self.write(
            "Untracked.java",
            "class Untracked { void run() { try { call(); } catch (Exception error) { throw error; } } }",
        )

        findings = self.json_findings(
            "--profile", "backend-java", "--changed-since", "HEAD"
        )

        self.assertEqual(
            {"Changed.java", "Untracked.java"},
            {finding["path"] for finding in findings},
        )

    def test_cli_validation_and_list_rules(self) -> None:
        unknown = self.run_scan("--rule", "not-a-rule", check=False)
        zero = self.run_scan("--max-findings", "0", check=False)
        incompatible = self.run_scan(
            "--profile",
            "sdk-go",
            "--rule",
            "typescript-any",
            check=False,
        )
        listed = self.run_scan("--list-rules")

        self.assertEqual(2, unknown.returncode)
        self.assertEqual(2, zero.returncode)
        self.assertEqual(2, incompatible.returncode)
        self.assertIn("silent-catch", listed.stdout)


if __name__ == "__main__":
    unittest.main()
