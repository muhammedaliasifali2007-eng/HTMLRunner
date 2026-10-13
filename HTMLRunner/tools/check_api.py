#!/usr/bin/env python3
"""
Catches the second bug class that reached CI:
"value of type 'X' has no member 'y'" — a call to a method that doesn't exist.

Scope: the project's own singletons/types that the UI calls a lot —
LibraryStore, SharedStore, HTMLTools and SharedHTMLItem — where a rename on one
side and not the other is silent until Xcode runs.

Collects `func` declarations per owner, collects call sites (`store.foo(`,
`SharedStore.foo(`, `HTMLTools.foo(`, `item.foo(`) and reports mismatches.

Exit code 1 if a call has no matching declaration.
"""

import glob
import os
import re
import sys

ROOT = "/home/user/HTMLRunner"

OWNERS = {
    "store":       [f"{ROOT}/HTMLRunner/LibraryStore.swift"],
    "SharedStore": [f"{ROOT}/Shared/SharedStore.swift"],
    "HTMLTools":   [f"{ROOT}/Shared/SharedHTMLItem.swift"],
    "item":        [f"{ROOT}/Shared/SharedHTMLItem.swift"],
    "SharedHTMLItem": [f"{ROOT}/Shared/SharedHTMLItem.swift"],
}

FUNC = re.compile(r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
VAR = re.compile(r"\b(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*[:=]")
# computed properties look like:  var previewText: String { ... }
COMPUTED = re.compile(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:[^=\n]*\{")

CALL = re.compile(r"(?<![A-Za-z0-9_.])(store|SharedStore|HTMLTools|item|SharedHTMLItem)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def calls_and_decls():
    declared = {}
    for owner, paths in OWNERS.items():
        names = set()
        for path in paths:
            if not os.path.exists(path):
                continue
            text = open(path).read()
            names |= set(FUNC.findall(text))
            names |= set(VAR.findall(text))
            names |= set(COMPUTED.findall(text))
        declared[owner] = names

    used = {}
    for path in (glob.glob(f"{ROOT}/HTMLRunner/*.swift")
                 + glob.glob(f"{ROOT}/ShareExtension/*.swift")
                 + glob.glob(f"{ROOT}/Shared/*.swift")):
        text = open(path).read()
        text = re.sub(r"//[^\n]*", "", text)
        text = re.sub(r'"""(?:.|\n)*?"""', '""', text)
        text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
        for owner, member in CALL.findall(text):
            used.setdefault(owner, {}).setdefault(member, set()).add(os.path.basename(path))
    return declared, used


def main():
    declared, used = calls_and_decls()
    print("declared members:")
    for owner, names in declared.items():
        print(f"  {owner:14s} {len(names):2d}  {', '.join(sorted(names)) if names else '-'}")

    problems = []
    for owner, members in used.items():
        for member, where in sorted(members.items()):
            if member not in declared.get(owner, set()):
                problems.append((owner, member, sorted(where)))
    # Swift's own `init`/`self` members on item/structs are fine
    problems = [p for p in problems if p[1] not in {"init", "self"}]

    print()
    if problems:
        print("x calls with no matching declaration:")
        for owner, member, where in problems:
            print(f"  {owner}.{member}()  <- {', '.join(where)}")
        return 1
    print("ok every store/SharedStore/HTMLTools/item call has a matching declaration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
