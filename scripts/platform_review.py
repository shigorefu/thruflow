#!/usr/bin/env python3
"""Report review scope; never infer behavioral parity from file changes."""

import argparse
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = Path(__file__).with_name("platform_review_map.json")


def load_map(path=MAP_PATH):
    return json.loads(path.read_text(encoding="utf-8"))


def validate_map(mapping, root=ROOT):
    errors = []
    groups = mapping.get("groups", [])
    identifiers = set()
    for group in groups:
        identifier = group["id"]
        if identifier in identifiers:
            errors.append(f"Duplicate group: {identifier}")
        identifiers.add(identifier)
        for field in ("triggers", "review", "tests"):
            for path in group[field]:
                if PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
                    errors.append(f"Invalid repository path: {path}")
                elif not (root / path).exists():
                    errors.append(f"Missing {field} path: {path}")
    if not groups:
        errors.append("No feature groups configured")
    return errors


def git_paths(root, arguments):
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], check=True, stdout=subprocess.PIPE,
    )
    return [path.decode("utf-8", errors="surrogateescape")
            for path in result.stdout.split(b"\0") if path]


def changed_paths(root=ROOT, base="HEAD", head=None):
    # Disable rename detection: both old/deleted and new/added paths matter.
    paths = git_paths(root, ["diff", "--name-only", "-z", "--no-renames", base,
                             *([head] if head else []), "--"])
    if head is None:
        paths += git_paths(root, ["ls-files", "--others", "--exclude-standard", "-z"])
    return sorted(set(paths))


def matches(path, prefix):
    return path == prefix or path.startswith(prefix.rstrip("/") + "/")


def classify(paths, mapping):
    selected = set()
    fallback = []
    for path in sorted(set(paths)):
        # Documentation alone does not establish an affected runtime surface.
        if path.lower().endswith(".md"):
            continue
        if any(matches(path, prefix) for prefix in mapping["always_review_all"]):
            fallback.append(path)
            selected.update(group["id"] for group in mapping["groups"])
            continue
        matched = [group["id"] for group in mapping["groups"]
                   if any(matches(path, prefix)
                          for prefix in group["triggers"] + group["tests"])]
        selected.update(matched)
        if not matched and any(matches(path, prefix)
                               for prefix in mapping["unknown_review_all"]):
            fallback.append(path)
            selected.update(group["id"] for group in mapping["groups"])
    return [group for group in mapping["groups"] if group["id"] in selected], fallback


def code(value):
    # Paths may contain whitespace, Markdown characters, or non-ASCII text.
    return "<code>" + (value.replace("&", "&amp;").replace("<", "&lt;")
                       .replace(">", "&gt;").replace("\n", "&#10;")) + "</code>"


def render(paths, mapping):
    groups, fallback = classify(paths, mapping)
    lines = ["## Cross-platform review scope", "",
             "This is an impact report, not proof of behavioral or UI parity. "
             "It does not run tests, start agents, or require edits in every client.", "",
             "### Changed paths", ""]
    lines.extend(f"- {code(path)}" for path in sorted(set(paths)))
    if not paths:
        lines.append("No changed paths.")
    if fallback:
        lines += ["", "Conservative fallback: shared/configuration or unmapped app/test "
                  "changes require review of all feature groups. Also inspect Watch and "
                  "widget/Live Activity consumers and target exclusions.", ""]
        lines.extend(f"- {code(path)}" for path in fallback)
    if not groups:
        lines += ["", "No mapped application feature was selected. Documentation/tooling-only "
                  "changes need their own relevant checks; this is not a parity approval."]
    for group in groups:
        lines += ["", f"### {group['name']}", "", "Review counterparts and shared owners:", ""]
        lines.extend(f"- {code(path)}" for path in group["review"])
        lines += ["", "Suggested existing tests (not executed):", ""]
        lines.extend(f"- {code(path)}" for path in group["tests"])
    if groups:
        lines += ["", "Reviewer: inspect the final diff and counterpart wiring; record intentional "
                  "platform differences, missing changes, and checks run/skipped. "
                  "Build macOS and iOS when shared behavior is affected. Compilation does "
                  "not verify UI interaction or signed integrations."]
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="Explicit repository-relative paths for preview")
    parser.add_argument("--base", default="HEAD", help="Compare from this Git ref (default: HEAD)")
    parser.add_argument("--head", help="Compare to this ref; omit to include local and untracked changes")
    parser.add_argument("--validate-map", action="store_true", help="Validate map paths and exit")
    args = parser.parse_args(argv)
    mapping = load_map()
    if args.validate_map:
        errors = validate_map(mapping)
        print("\n".join(errors) if errors else "Platform review map paths are valid.")
        return bool(errors)
    if any(ref and ref.startswith("-") for ref in (args.base, args.head)):
        parser.error("Git references must not start with '-'")
    try:
        paths = args.paths or changed_paths(base=args.base, head=args.head)
    except subprocess.CalledProcessError as error:
        print(f"Cannot determine changed files: git exited {error.returncode}", file=sys.stderr)
        return 1
    print(render(paths, mapping), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
