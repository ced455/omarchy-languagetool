#!/usr/bin/env python3
"""Small static safety/style checks for plugin QML files."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []


def blocks(source, opener):
    pattern = re.compile(r"(?m)^[ \t]*" + re.escape(opener) + r"\s*\{")
    for match in pattern.finditer(source):
        start = match.end() - 1
        depth = 0
        for index in range(start, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    yield source.count("\n", 0, match.start()) + 1, source[start:index]
                    break


for path in sorted(ROOT.glob("*.qml")):
    source = path.read_text(encoding="utf-8")
    for line, block in blocks(source, "Text"):
        if "font.family" not in block:
            FAILURES.append(f"{path.name}:{line} Text missing font.family")
        if "textFormat: Text.PlainText" not in block:
            FAILURES.append(f"{path.name}:{line} Text missing PlainText format")
    for line, block in blocks(source, "QQC.TextArea"):
        if "textFormat: TextEdit.PlainText" not in block:
            FAILURES.append(f"{path.name}:{line} TextArea missing PlainText format")

if FAILURES:
    for failure in FAILURES:
        print("  FAIL", failure)
    sys.exit(1)

print("QML safety/style checks passed")
