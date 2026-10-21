#!/usr/bin/env python3
"""Find defensive-fallback and unnecessary-complexity review candidates.

This is a context-aware heuristic scanner, not a parser or defect classifier. It supports common
Java, Kotlin, TypeScript, JavaScript, Go, and Python project layouts using only the standard library.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


SCANNER_VERSION = 3
BASELINE_SCHEMA_VERSION = 1

SKIP_DIRS = {
    ".agents",
    ".claude",
    ".codex",
    ".git",
    ".gradle",
    ".idea",
    ".mvn",
    ".next",
    ".turbo",
    ".venv",
    ".vscode",
    "__pycache__",
    "build",
    "coverage",
    "dist",
    "generated",
    "node_modules",
    "out",
    "target",
    "vendor",
}

TEXT_EXTENSIONS = {".java", ".kt", ".ts", ".tsx", ".js", ".jsx", ".go", ".py"}
SEVERITY_RANK = {"HIGH": 3, "MEDIUM": 2, "LOW": 1}


@dataclass(frozen=True)
class Rule:
    rule_id: str
    severity: str
    languages: tuple[str, ...]
    pattern: re.Pattern[str]
    message: str


@dataclass(frozen=True)
class Finding:
    severity: str
    rule_id: str
    path: str
    line: int
    message: str
    evidence: str
    fingerprint: str


RULES = [
    Rule(
        "broad-catch-java",
        "MEDIUM",
        (".java", ".kt"),
        re.compile(r"\bcatch\s*\(\s*(Exception|RuntimeException|Throwable)\b"),
        "Broad Java/Kotlin catch needs explicit translation, diagnostics, or rethrow.",
    ),
    Rule(
        "broad-except-python",
        "MEDIUM",
        (".py",),
        re.compile(r"^\s*except\s+(Exception|BaseException)\b|^\s*except\s*:"),
        "Broad Python except needs explicit translation, diagnostics, or re-raise.",
    ),
    Rule(
        "silent-catch",
        "HIGH",
        (".java", ".kt", ".ts", ".tsx", ".js", ".jsx", ".py"),
        re.compile(r"\bcatch\s*\([^)]*\)\s*\{|^\s*except(?:\s+[^:]+)?\s*:"),
        "Empty or pass-only exception handling silently discards a failure.",
    ),
    Rule(
        "catch-empty-result",
        "HIGH",
        (".java", ".kt", ".ts", ".tsx", ".js", ".jsx", ".py"),
        re.compile(r"\bcatch\s*\([^)]*\)\s*\{|^\s*except(?:\s+[^:]+)?\s*:"),
        "Exception handling returns an empty success-like value; verify the public contract.",
    ),
    Rule(
        "find-first-fallback-selection",
        "HIGH",
        (".java", ".kt", ".ts", ".tsx", ".js", ".jsx"),
        re.compile(r"\.findFirst\s*\(|\bfirstOrNull\s*\("),
        "First-match selection is paired with a fallback value; verify that context is not guessed.",
    ),
    Rule(
        "fallback-contract-name",
        "LOW",
        (".java", ".kt", ".ts", ".tsx", ".js", ".jsx", ".go", ".py"),
        re.compile(r"\b(fallback|degraded|compat|legacy)\w*\b", re.IGNORECASE),
        "Named fallback/compat behavior should map to a documented and tested contract.",
    ),
    Rule(
        "java-empty-result",
        "LOW",
        (".java", ".kt"),
        re.compile(
            r"\breturn\s+(null|Optional\.empty\s*\(\)|List\.of\s*\(\)|"
            r"Map\.of\s*\(\)|Set\.of\s*\(\)|\"\"\s*;)"
        ),
        "Empty Java/Kotlin result may mask a contract violation; inspect caller semantics.",
    ),
    Rule(
        "ts-empty-result",
        "LOW",
        (".ts", ".tsx", ".js", ".jsx"),
        re.compile(r"\breturn\s+(null|undefined|\{\}|\[\]|''|\"\")\s*;"),
        "Empty JS/TS result may mask a contract violation; inspect caller semantics.",
    ),
    Rule(
        "python-empty-result",
        "LOW",
        (".py",),
        re.compile(r"\breturn\s+(None|\{\}|\[\]|''|\"\")\s*(#.*)?$"),
        "Empty Python result may mask a contract violation; inspect caller semantics.",
    ),
    Rule(
        "go-empty-success",
        "LOW",
        (".go",),
        re.compile(r"\breturn\s+(nil,\s*nil|\"\",\s*nil|0,\s*nil)\b"),
        "Go zero-value success may mask a contract violation; inspect API semantics.",
    ),
    Rule(
        "typescript-any",
        "MEDIUM",
        (".ts", ".tsx"),
        re.compile(r"(:\s*any\b|\bas\s+any\b|<any>)"),
        "TypeScript any can hide absent/error states; prefer narrowing or typed results.",
    ),
    Rule(
        "default-object-masking",
        "LOW",
        (".ts", ".tsx", ".js", ".jsx"),
        re.compile(r"(\?\?\s*\{\}|\|\|\s*\{\}|\?\?\s*\[\]|\|\|\s*\[\])"),
        "Default object/array masking can hide missing API state; verify the UX contract.",
    ),
    Rule(
        "browser-token-storage",
        "HIGH",
        (".ts", ".tsx", ".js", ".jsx"),
        re.compile(
            r"\b(localStorage|sessionStorage)\s*\.\s*(setItem|getItem)\s*"
            r"\([^)]*(token|tokens|refresh|permission|session)",
            re.IGNORECASE,
        ),
        "Browser token/session/permission persistence must be explicit opt-in and reviewed.",
    ),
    Rule(
        "react-effect-state-copy",
        "MEDIUM",
        (".tsx", ".jsx"),
        re.compile(r"\b(?:React\.)?useEffect\s*\("),
        "Effect writes component state; inspect whether the value can be derived during render.",
    ),
    Rule(
        "test-helper-runtime-resource",
        "LOW",
        (".java", ".kt", ".ts", ".tsx", ".js", ".jsx", ".go", ".py"),
        re.compile(
            r"\b(create|insert|seed|upsert)\w*"
            r"(user|account|client|application|tenant|organization|workspace|permission|role|"
            r"token|project|repository|database|schema|queue|bucket|topic|resource)\b",
            re.IGNORECASE,
        ),
        "Test resource helpers need production-parity review before supporting runtime claims.",
    ),
]

RULE_BY_ID = {rule.rule_id: rule for rule in RULES}

PROFILE_RULES: dict[str, set[str] | None] = {
    "all": None,
    "backend-java": {
        "broad-catch-java",
        "silent-catch",
        "catch-empty-result",
        "find-first-fallback-selection",
        "java-empty-result",
    },
    "backend-go": {"go-empty-success"},
    "backend-python": {
        "broad-except-python",
        "silent-catch",
        "catch-empty-result",
        "python-empty-result",
    },
    "frontend-typescript": {
        "silent-catch",
        "catch-empty-result",
        "ts-empty-result",
        "typescript-any",
        "default-object-masking",
        "browser-token-storage",
    },
    "frontend-react": {
        "silent-catch",
        "catch-empty-result",
        "ts-empty-result",
        "typescript-any",
        "default-object-masking",
        "browser-token-storage",
        "react-effect-state-copy",
    },
    "sdk-js": {
        "silent-catch",
        "catch-empty-result",
        "ts-empty-result",
        "typescript-any",
        "default-object-masking",
        "browser-token-storage",
        "react-effect-state-copy",
    },
    "sdk-server": {
        "broad-catch-java",
        "broad-except-python",
        "silent-catch",
        "catch-empty-result",
        "find-first-fallback-selection",
        "java-empty-result",
        "python-empty-result",
        "go-empty-success",
    },
    "sdk-java": {
        "broad-catch-java",
        "silent-catch",
        "catch-empty-result",
        "find-first-fallback-selection",
        "java-empty-result",
    },
    "sdk-go": {"go-empty-success"},
    "sdk-python": {
        "broad-except-python",
        "silent-catch",
        "catch-empty-result",
        "python-empty-result",
    },
    "test-support": {"test-helper-runtime-resource"},
    "fallback-review": {
        "fallback-contract-name",
        "java-empty-result",
        "ts-empty-result",
        "python-empty-result",
        "go-empty-success",
    },
}

EMPTY_RESULT_PATTERN = re.compile(
    r"\breturn\s+(?:null|undefined|None|Optional\.empty\s*\(\)|\{\}|\[\]|"
    r"List\.of\s*\(\)|Map\.of\s*\(\)|Set\.of\s*\(\)|''|\"\")\s*;?"
)
STATE_SETTER_PATTERN = re.compile(r"\bset[A-Z][A-Za-z0-9_]*\s*\(")


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Directory to scan")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--profile", choices=tuple(PROFILE_RULES), default="all")
    parser.add_argument(
        "--rule",
        action="append",
        choices=tuple(sorted(RULE_BY_ID)),
        default=[],
        help="Only include this rule id; repeatable",
    )
    parser.add_argument(
        "--min-severity",
        choices=("low", "medium", "high"),
        default="medium",
        help="Only include findings at or above this severity",
    )
    parser.add_argument("--summary-only", action="store_true")
    parser.add_argument("--include-tests", action="store_true")
    parser.add_argument("--changed-since", help="Scan files changed from this Git revision")
    parser.add_argument("--baseline", help="Existing JSON baseline")
    parser.add_argument("--only-new", action="store_true")
    parser.add_argument("--write-baseline", help="Write all filtered findings as a JSON baseline")
    parser.add_argument("--fail-on", choices=("none", "high", "medium", "low"), default="none")
    parser.add_argument("--list-rules", action="store_true")
    parser.add_argument(
        "--max-findings",
        type=positive_int,
        default=500,
        help="Maximum details to print; does not limit summary, baseline, or exit status",
    )
    args = parser.parse_args()
    if args.only_new and not args.baseline:
        parser.error("--only-new requires --baseline")
    if args.write_baseline and args.changed_since:
        parser.error("--write-baseline cannot be combined with --changed-since")
    profile_rules = PROFILE_RULES[args.profile]
    if args.rule and profile_rules is not None:
        incompatible = sorted(set(args.rule) - profile_rules)
        if incompatible:
            parser.error(
                f"rules not available in profile {args.profile}: {', '.join(incompatible)}"
            )
    return args


def is_test_path(path: Path) -> bool:
    lowered = path.as_posix().lower()
    name = path.name.lower()
    return (
        "/test/" in lowered
        or "/tests/" in lowered
        or "__tests__" in lowered
        or "test-utils" in lowered
        or "/testing/" in lowered
        or name.startswith("test_")
        or name.endswith(
            (
                "test.java",
                "test.kt",
                ".test.ts",
                ".test.tsx",
                ".spec.ts",
                ".spec.tsx",
                "_test.go",
                "_test.py",
            )
        )
    )


def iter_files(root: Path, selected_files: set[Path] | None = None) -> Iterable[Path]:
    candidates = selected_files if selected_files is not None else root.rglob("*")
    for path in candidates:
        if not path.is_file():
            continue
        try:
            relative_parts = path.relative_to(root).parts
        except ValueError:
            continue
        if any(part in SKIP_DIRS for part in relative_parts):
            continue
        if path.suffix.lower() in TEXT_EXTENSIONS:
            yield path


def should_scan_rule(rule: Rule, path: Path, include_tests: bool) -> bool:
    test_path = is_test_path(path)
    if rule.rule_id == "test-helper-runtime-resource":
        return test_path
    return include_tests or not test_path


def braced_body(
    lines: list[str],
    index: int,
    anchor: re.Pattern[str] | None = None,
    max_lines: int = 40,
) -> str:
    source = "\n".join(lines[index : index + max_lines])
    start = 0
    if anchor is not None:
        match = anchor.search(source)
        if match is None:
            return ""
        start = match.end()
    opening = source.find("{", start)
    if opening < 0:
        return ""
    depth = 0
    for position in range(opening, len(source)):
        character = source[position]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : position]
    return source[opening + 1 :]


def python_block(lines: list[str], index: int, max_lines: int = 40) -> str:
    base_indent = len(lines[index]) - len(lines[index].lstrip())
    body: list[str] = []
    for line in lines[index + 1 : index + max_lines]:
        if not line.strip():
            body.append(line)
            continue
        indent = len(line) - len(line.lstrip())
        if indent <= base_indent:
            break
        body.append(line)
    return "\n".join(body)


def exception_body(lines: list[str], index: int, suffix: str) -> str:
    if suffix == ".py":
        return python_block(lines, index)
    return braced_body(lines, index, re.compile(r"\bcatch\s*\([^)]*\)"))


def executable_body(body: str) -> str:
    without_block_comments = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    code_lines = []
    for line in without_block_comments.splitlines():
        line = re.sub(r"//.*$|#.*$", "", line).strip()
        if line:
            code_lines.append(line)
    return " ".join(code_lines).strip(" ;")


def context(lines: list[str], index: int, size: int = 12) -> str:
    return "\n".join(lines[index : index + size])


def is_framework_fallback(line: str) -> bool:
    return bool(
        re.search(
            r"<Suspense\s+fallback=|AvatarPrimitive\.Fallback|data-slot=[\"']avatar-fallback|"
            r"fallbackLng\s*:|fallback\??:\s*ReactNode",
            line,
        )
    )


def rule_matches(rule: Rule, lines: list[str], index: int, suffix: str) -> bool:
    line = lines[index]
    if not rule.pattern.search(line):
        return False
    if rule.rule_id == "silent-catch":
        return executable_body(exception_body(lines, index, suffix)) in {"", "pass"}
    if rule.rule_id == "catch-empty-result":
        return bool(EMPTY_RESULT_PATTERN.search(exception_body(lines, index, suffix)))
    if rule.rule_id == "find-first-fallback-selection":
        nearby = context(lines, index, 8)
        if ".orElseThrow" in nearby:
            return False
        return bool(re.search(r"\.orElse(?:Get)?\s*\(|\?:|\bgetOrElse\s*\(", nearby))
    if rule.rule_id == "react-effect-state-copy":
        nearby = context(lines, index, 4)
        if not re.search(r"(?:React\.)?useEffect\s*\(\s*\(\)\s*=>\s*\{", nearby):
            return False
        body = braced_body(lines, index, re.compile(r"(?:React\.)?useEffect\s*\("))
        return bool(STATE_SETTER_PATTERN.search(body))
    if rule.rule_id == "fallback-contract-name":
        return not is_framework_fallback(line)
    return True


def fingerprint(rule_id: str, path: str, evidence: str) -> str:
    return f"{rule_id}|{path}|{' '.join(evidence.split())}"


def finding_severity(rule: Rule, lines: list[str], index: int, suffix: str) -> str:
    if rule.rule_id == "silent-catch":
        body = exception_body(lines, index, suffix)
        return "MEDIUM" if re.search(r"//|/\*|#", body) else "HIGH"
    if rule.rule_id == "catch-empty-result":
        body = exception_body(lines, index, suffix)
        if re.search(r"\b(?:log|logger|audit|metric|counter)\w*\s*\.", body, re.IGNORECASE):
            return "MEDIUM"
    return rule.severity


def scan_file(root: Path, path: Path, include_tests: bool) -> list[Finding]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()

    findings: list[Finding] = []
    relative = path.relative_to(root).as_posix()
    suffix = path.suffix.lower()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith(("//", "*", "#")):
            continue
        for rule in RULES:
            if suffix not in rule.languages or not should_scan_rule(rule, path, include_tests):
                continue
            if not rule_matches(rule, lines, index, suffix):
                continue
            evidence = stripped[:220]
            findings.append(
                Finding(
                    severity=finding_severity(rule, lines, index, suffix),
                    rule_id=rule.rule_id,
                    path=relative,
                    line=index + 1,
                    message=rule.message,
                    evidence=evidence,
                    fingerprint=fingerprint(rule.rule_id, relative, evidence),
                )
            )
    return findings


def git_changed_files(root: Path, revision: str) -> set[Path]:
    try:
        top_level = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except subprocess.CalledProcessError as error:
        raise SystemExit("--changed-since requires a Git repository root") from error

    if Path(top_level).resolve() != root:
        raise SystemExit("--changed-since requires --root to be the real Git repository root")

    try:
        changed = subprocess.run(
            ["git", "-C", str(root), "diff", "--name-only", "--diff-filter=ACMR", revision, "--"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"cannot diff Git revision: {revision}") from error

    untracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return {root / relative for relative in changed + untracked}


def selected_rule_ids(args: argparse.Namespace) -> set[str]:
    profile_rules = PROFILE_RULES[args.profile]
    explicit_rules = set(args.rule)
    if profile_rules is None:
        return explicit_rules or set(RULE_BY_ID)
    return profile_rules & explicit_rules if explicit_rules else set(profile_rules)


def scan_config(root: Path, args: argparse.Namespace) -> dict[str, object]:
    return {
        "scanner_version": SCANNER_VERSION,
        "scope": root.name,
        "profile": args.profile,
        "rules": sorted(selected_rule_ids(args)),
        "min_severity": args.min_severity,
        "include_tests": args.include_tests,
    }


def load_baseline(path: Path, expected_config: dict[str, object]) -> set[str]:
    if not path.exists():
        raise SystemExit(f"baseline does not exist: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"baseline is not valid JSON: {path}") from error

    if isinstance(data, list):
        entries = data
    elif isinstance(data, dict):
        if data.get("schema_version") != BASELINE_SCHEMA_VERSION:
            raise SystemExit(f"unsupported baseline schema: {data.get('schema_version')}")
        if data.get("scan_config") != expected_config:
            raise SystemExit("baseline scan configuration does not match the current scan")
        entries = data.get("findings")
        if not isinstance(entries, list):
            raise SystemExit(f"baseline findings must be a JSON array: {path}")
    else:
        raise SystemExit(f"baseline must be a JSON object or legacy array: {path}")

    fingerprints: set[str] = set()
    for item in entries:
        if not isinstance(item, dict):
            continue
        explicit = item.get("fingerprint")
        if isinstance(explicit, str):
            fingerprints.add(explicit)
            continue
        rule_id = item.get("rule_id")
        file_path = item.get("path")
        evidence = item.get("evidence")
        if isinstance(rule_id, str) and isinstance(file_path, str) and isinstance(evidence, str):
            fingerprints.add(fingerprint(rule_id, file_path, evidence))
    return fingerprints


def write_baseline(path: Path, config: dict[str, object], findings: list[Finding]) -> None:
    payload = {
        "schema_version": BASELINE_SCHEMA_VERSION,
        "scan_config": config,
        "findings": [asdict(finding) for finding in findings],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def severity_rank(severity: str) -> int:
    return SEVERITY_RANK[severity]


def apply_filters(
    findings: list[Finding], root: Path, args: argparse.Namespace
) -> list[Finding]:
    enabled_rules = selected_rule_ids(args)
    threshold = {"high": 3, "medium": 2, "low": 1}[args.min_severity]
    filtered = [
        finding
        for finding in findings
        if finding.rule_id in enabled_rules and severity_rank(finding.severity) >= threshold
    ]
    if args.only_new:
        baseline = load_baseline(Path(args.baseline), scan_config(root, args))
        filtered = [finding for finding in filtered if finding.fingerprint not in baseline]
    return filtered


def counts_by(items: Iterable[Finding], attr: str) -> list[tuple[str, int]]:
    counts: dict[str, int] = {}
    for item in items:
        key = getattr(item, attr)
        counts[key] = counts.get(key, 0) + 1
    return sorted(counts.items(), key=lambda entry: (-entry[1], entry[0]))


def print_summary(findings: list[Finding]) -> None:
    print(
        "Defensive fallback/code-quality candidates: "
        f"HIGH={sum(item.severity == 'HIGH' for item in findings)} "
        f"MEDIUM={sum(item.severity == 'MEDIUM' for item in findings)} "
        f"LOW={sum(item.severity == 'LOW' for item in findings)}"
    )
    print("\nBy rule:")
    for rule_id, count in counts_by(findings, "rule_id"):
        print(f"  {rule_id}: {count}")
    print("\nTop paths:")
    path_counts: dict[str, int] = {}
    for finding in findings:
        top_path = finding.path.split("/", 1)[0]
        path_counts[top_path] = path_counts.get(top_path, 0) + 1
    for path, count in sorted(path_counts.items(), key=lambda entry: (-entry[1], entry[0]))[:20]:
        print(f"  {path}: {count}")


def print_text(findings: list[Finding], displayed: list[Finding]) -> None:
    print_summary(findings)
    if len(displayed) < len(findings):
        print(f"\nShowing {len(displayed)} of {len(findings)} finding details.")
    print("\nThese are candidates, not confirmed bugs. Inspect context before fixing.\n")
    for finding in displayed:
        print(f"{finding.severity} {finding.rule_id} {finding.path}:{finding.line}")
        print(f"  {finding.message}")
        print(f"  {finding.evidence}")


def list_rules() -> None:
    for rule in RULES:
        languages = ",".join(language.removeprefix(".") for language in rule.languages)
        print(f"{rule.rule_id}\t{rule.severity}\t{languages}\t{rule.message}")


def main() -> int:
    args = parse_args()
    if args.list_rules:
        list_rules()
        return 0

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"scan root is not a directory: {root}", file=sys.stderr)
        return 2

    selected_files = git_changed_files(root, args.changed_since) if args.changed_since else None
    findings: list[Finding] = []
    for path in iter_files(root, selected_files):
        findings.extend(scan_file(root, path, args.include_tests))

    findings = apply_filters(findings, root, args)
    findings.sort(key=lambda item: (-severity_rank(item.severity), item.path, item.line, item.rule_id))

    if args.write_baseline:
        write_baseline(Path(args.write_baseline), scan_config(root, args), findings)

    displayed = findings[: args.max_findings]
    if args.format == "json":
        print(json.dumps([asdict(finding) for finding in displayed], indent=2, ensure_ascii=False))
    elif args.summary_only:
        print_summary(findings)
    else:
        print_text(findings, displayed)

    fail_threshold = {"none": 99, "high": 3, "medium": 2, "low": 1}[args.fail_on]
    return int(any(severity_rank(finding.severity) >= fail_threshold for finding in findings))


if __name__ == "__main__":
    raise SystemExit(main())
