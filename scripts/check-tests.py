#!/usr/bin/env python3
"""Flag tautological XCTest assertions in BilouNookTests.

A tautology is an assertion whose first two arguments are textually identical,
or a constant boolean assertion such as XCTAssertTrue(true).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "BilouNook" / "BilouNookTests"
CALL = re.compile(r"XCTAssert\w*\s*\(")
CONSTANT = re.compile(r"XCTAssert(True|False)\s*\(\s*(true|false)\s*\)")


def split_arguments(body: str) -> list[str]:
    arguments: list[str] = []
    current: list[str] = []
    depth = 0
    quote: str | None = None
    escaped = False
    for character in body:
        if quote is not None:
            current.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character in "\"'":
            quote = character
            current.append(character)
        elif character in "([{":
            depth += 1
            current.append(character)
        elif character in ")]}":
            depth -= 1
            current.append(character)
        elif character == "," and depth == 0:
            arguments.append("".join(current).strip())
            current = []
        else:
            current.append(character)
    arguments.append("".join(current).strip())
    return arguments


def matching_paren(text: str, opening: int) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(opening, len(text)):
        character = text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character in "\"'":
            quote = character
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def main() -> int:
    failures: list[str] = []
    for path in sorted(TESTS.glob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in CALL.finditer(text):
            opening = text.index("(", match.start())
            closing = matching_paren(text, opening)
            if closing is None:
                continue
            body = text[opening + 1:closing]
            line = text[: match.start()].count("\n") + 1
            if CONSTANT.fullmatch(match.group(0) + body + ")"):
                failures.append(f"{path.relative_to(ROOT)}:{line}: constant assertion")
                continue
            arguments = split_arguments(body)
            if len(arguments) >= 2 and arguments[0] == arguments[1]:
                failures.append(
                    f"{path.relative_to(ROOT)}:{line}: identical assertion arguments"
                )

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print(f"check-tests: {len(failures)} tautological assertion(s)")
        return 1
    print("check-tests: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
