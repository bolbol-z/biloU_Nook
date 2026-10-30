#!/usr/bin/env python3
"""Validate BilouNook.xcodeproj structural integrity.

Checks:
  1. duplicate object IDs in the raw pbxproj text
  2. every PBXFileReference path exists on disk (group paths resolved)
  3. every Swift file in a Sources phase belongs to a PBXGroup
  4. every PBXGroup child points at an existing object
  5. no file path is referenced by two different PBXFileReference IDs
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = ROOT / "BilouNook"
PROJECT = PROJECT_DIR / "BilouNook.xcodeproj" / "project.pbxproj"

OBJECT_DEF = re.compile(
    r"^[ \t]*([A-Fa-f0-9]{6,})[^\n]*?=\s*\{", re.MULTILINE
)
FILE_REF = re.compile(
    r"^[ \t]*([A-Fa-f0-9]{6,})[^\n]*?\{isa = PBXFileReference;([^\n]*)\}[ \t]*;[ \t]*$",
    re.MULTILINE,
)
PATH_VALUE = re.compile(r'\bpath = ("(?:[^"\\]|\\.)*"|[^;]+);')
SOURCE_TREE = re.compile(r'\bsourceTree = ("(?:[^"\\]|\\.)*"|[^;]+);')
CHILD = re.compile(r"^\s*([A-Fa-f0-9]{6,})\s*(?:/\*.*?\*/)?\s*,?\s*$", re.MULTILINE)


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1].replace('\\"', '"')
    return value


def load_json() -> dict:
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(PROJECT)],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def duplicate_ids(text: str) -> list[str]:
    seen: dict[str, int] = defaultdict(int)
    for match in OBJECT_DEF.finditer(text):
        seen[match.group(1)] += 1
    return sorted(obj_id for obj_id, count in seen.items() if count > 1)


def file_references(text: str) -> dict[str, dict[str, str]]:
    refs: dict[str, dict[str, str]] = {}
    for match in FILE_REF.finditer(text):
        body = match.group(2)
        path_match = PATH_VALUE.search(body)
        tree_match = SOURCE_TREE.search(body)
        refs[match.group(1)] = {
            "path": unquote(path_match.group(1)) if path_match else None,
            "sourceTree": unquote(tree_match.group(1)) if tree_match else "<group>",
        }
    return refs


def group_children(block: dict) -> list[str]:
    children = block.get("children", [])
    return list(children)


def main() -> int:
    if not PROJECT.is_file():
        print(f"FAIL missing project file: {PROJECT}")
        return 1

    text = PROJECT.read_text(encoding="utf-8")
    data = load_json()
    objects: dict[str, dict] = data["objects"]
    root = objects[data["rootObject"]]
    main_group = root["mainGroup"]

    failures: list[str] = []
    warnings: list[str] = []

    dupes = duplicate_ids(text)
    for obj_id in dupes:
        failures.append(f"duplicate object ID {obj_id}")

    parent_of: dict[str, str] = {}
    for group_id, block in objects.items():
        if block.get("isa") != "PBXGroup":
            continue
        for child in group_children(block):
            parent_of.setdefault(child, group_id)

    group_paths: dict[str, Path] = {}

    def resolve_group(group_id: str, stack: tuple[str, ...] = ()) -> Path | None:
        if group_id in group_paths:
            return group_paths[group_id]
        if group_id in stack:
            failures.append(f"group cycle at {group_id}")
            return None
        block = objects[group_id]
        tree = block.get("sourceTree", "<group>")
        if tree != "<group>":
            return None
        base = PROJECT_DIR
        parent = parent_of.get(group_id)
        if parent:
            parent_path = resolve_group(parent, stack + (group_id,))
            if parent_path is None:
                return None
            base = parent_path
        component = block.get("path")
        resolved = base / component if component else base
        group_paths[group_id] = resolved
        return resolved

    refs = file_references(text)

    def resolve_ref(ref_id: str) -> Path | None:
        info = refs.get(ref_id)
        if info is None:
            block = objects.get(ref_id)
            if block is None or block.get("isa") != "PBXFileReference":
                return None
            info = {
                "path": block.get("path"),
                "sourceTree": block.get("sourceTree", "<group>"),
            }
        if info["sourceTree"] != "<group>":
            return None
        parent = parent_of.get(ref_id)
        if parent is None:
            base = PROJECT_DIR
        else:
            base = resolve_group(parent)
            if base is None:
                return None
        path = info["path"]
        return base / path if path else base

    path_owners: dict[Path, set[str]] = defaultdict(set)
    for ref_id, info in refs.items():
        resolved = resolve_ref(ref_id)
        if resolved is None:
            continue
        path_owners[resolved].add(ref_id)
        if not resolved.exists():
            failures.append(
                f"missing file for {ref_id} ({info['path']}): "
                f"{resolved.relative_to(ROOT)}"
            )

    for path, owners in sorted(path_owners.items()):
        if len(owners) > 1:
            failures.append(
                f"path referenced by multiple IDs {sorted(owners)}: "
                f"{path.relative_to(ROOT)}"
            )

    for group_id, block in objects.items():
        if block.get("isa") != "PBXGroup":
            continue
        for child in group_children(block):
            if child not in objects:
                failures.append(f"group {group_id} child {child} does not exist")

    in_group = set(parent_of)
    for obj_id, block in objects.items():
        if block.get("isa") != "PBXSourcesBuildPhase":
            continue
        for build_file_id in block.get("files", []):
            build_file = objects.get(build_file_id)
            if build_file is None:
                failures.append(
                    f"sources phase {obj_id} references missing build file {build_file_id}"
                )
                continue
            ref_id = build_file.get("fileRef")
            if ref_id is None:
                failures.append(f"build file {build_file_id} has no fileRef")
                continue
            ref = objects.get(ref_id)
            if ref is None:
                failures.append(
                    f"build file {build_file_id} references missing fileRef {ref_id}"
                )
                continue
            if not str(ref.get("path", "")).endswith(".swift"):
                continue
            if ref_id not in in_group:
                failures.append(
                    f"Swift source {ref_id} ({ref.get('path')}) is not in any group"
                )

    if warnings:
        for warning in warnings:
            print(f"WARN {warning}")
    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print(f"check-project: {len(failures)} failure(s)")
        return 1
    print(
        "check-project: PASS "
        f"({len(objects)} objects, {len(refs)} file references)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
