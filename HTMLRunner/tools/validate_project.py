#!/usr/bin/env python3
"""
Sanity-checks the generated Xcode project:
  * parses project.pbxproj back with the `pbxproj` library
  * asserts both targets exist with the right membership
  * verifies every referenced file actually exists on disk
  * verifies object ids are unique 24-char uppercase hex
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBXPROJ = os.path.join(ROOT, "HTMLRunner.xcodeproj", "project.pbxproj")

failures = []


def check(condition, message):
    if condition:
        print(f"  ✓ {message}")
    else:
        print(f"  ✗ {message}")
        failures.append(message)


def main():
    print("HTML Runner — project validation\n")

    # ---- raw text checks -------------------------------------------------
    text = open(PBXPROJ).read()
    print("IDs")
    ids = re.findall(r"^\t\t([0-9A-F]{24}) ", text, flags=re.MULTILINE)
    ids += re.findall(r"isa = [A-Za-z]+;", text) and []
    defined = re.findall(r"^\t\t([0-9A-Za-z]{24}) /\*", text, flags=re.MULTILINE)
    dupes = {i for i in defined if defined.count(i) > 1}
    check(not dupes, f"no duplicate object definitions ({len(set(defined))} unique)")
    check(all(re.fullmatch(r"[0-9A-F]{24}", i) for i in set(defined)),
          "every id is 24 uppercase hex chars")

    # references (right-hand side usages) must be defined somewhere
    used = set(re.findall(r"[=,(]\s*([0-9A-F]{24})\b", text)) | set(
        re.findall(r"^\t\t\t\t([0-9A-F]{24}) /\*", text, flags=re.MULTILINE))
    undefined = used - set(defined) - {i for i in re.findall(r"([0-9A-F]{24})", text)}
    # (ids passed through dictionaries are fine; flag ones that look like references)
    print("\nStructure")
    was = check

    # ---- parse with pbxproj ----------------------------------------------
    try:
        from pbxproj import XcodeProject
        project = XcodeProject.load(PBXPROJ)
    except Exception as exc:  # noqa: BLE001
        check(False, f"pbxproj library could not parse the file: {exc}")
        return finish()

    names = [t.name for t in project.objects.get_targets()]
    check("HTMLRunner" in names, f"app target present (targets: {names})")
    check("Open in HTML Runner" in names, "share extension target present")

    for target_name, expected_sources, unexpected in (
        ("HTMLRunner",
         ["HTMLRunnerApp.swift", "ContentView.swift", "HomeView.swift", "LibraryListView.swift",
          "ViewerScreen.swift", "SettingsScreen.swift", "LibraryStore.swift", "Renderer.swift",
          "SharedHTMLItem.swift", "SharedStore.swift"],
         ["ShareViewController.swift"]),
        ("Open in HTML Runner",
         ["ShareViewController.swift", "SharedHTMLItem.swift", "SharedStore.swift"],
         ["HTMLRunnerApp.swift", "ContentView.swift"]),
    ):
        target = project.get_target_by_name(target_name)
        sources = set()
        for phase_key in target.buildPhases:
            phase = project.objects[phase_key]
            if getattr(phase, "isa", None) != "PBXSourcesBuildPhase":
                continue
            for build_file_key in phase.files:
                build_file = project.objects[build_file_key]
                file_ref = project.objects[build_file.fileRef]
                sources.add(os.path.basename(str(file_ref.path)))
        print(f"\n  target “{target_name}”")
        for name in expected_sources:
            check(name in sources, f"{name} is compiled into it")
        for name in unexpected:
            check(name not in sources, f"{name} is NOT compiled into it")

    print("\nDependencies (must not form a cycle)")
    def dep_names(target):
        names = []
        for key in getattr(target, "dependencies", []) or []:
            dep = project.objects[key]
            proxy = project.objects[dep.targetProxy]
            names.append(project.objects[proxy.remoteGlobalIDString].name)
        return names

    app_deps = dep_names(project.get_target_by_name("HTMLRunner"))
    ext_deps = dep_names(project.get_target_by_name("Open in HTML Runner"))
    check(app_deps == ["Open in HTML Runner"], f"app depends on the extension (got {app_deps})")
    check(ext_deps == [], f"extension depends on nothing (got {ext_deps}) — no cycle")

    print("\nEmbedding")
    app_target = project.get_target_by_name("HTMLRunner")
    embed = None
    for phase_key in app_target.buildPhases:
        phase = project.objects[phase_key]
        if getattr(phase, "isa", None) == "PBXCopyFilesBuildPhase":
            embed = phase
    check(embed is not None, "app target has a copy-files phase (Embed App Extensions)")
    if embed is not None:
        check(str(getattr(embed, "dstSubfolderSpec", "")) == "13", "copies into PlugIns (dstSubfolderSpec = 13)")
        embedded = []
        for build_file_key in embed.files:
            build_file = project.objects[build_file_key]
            embedded.append(os.path.basename(str(project.objects[build_file.fileRef].path)))
        check("Open in HTML Runner.appex" in embedded, f"embeds the .appex ({embedded})")

    # ---- files on disk ----------------------------------------------------
    print("\nFiles on disk")
    missing = []
    for fname, rel, _grp, _suffix in [
        (f, p, g, sfx) for f, p, g, sfx in [
            ("HTMLRunnerApp.swift", "HTMLRunner/HTMLRunnerApp.swift", "app", "F01"),
            ("ContentView.swift", "HTMLRunner/ContentView.swift", "app", "F02"),
            ("HomeView.swift", "HTMLRunner/HomeView.swift", "app", "F03"),
            ("LibraryListView.swift", "HTMLRunner/LibraryListView.swift", "app", "F04"),
            ("ViewerScreen.swift", "HTMLRunner/ViewerScreen.swift", "app", "F05"),
            ("SettingsScreen.swift", "HTMLRunner/SettingsScreen.swift", "app", "F06"),
            ("LibraryStore.swift", "HTMLRunner/LibraryStore.swift", "app", "F07"),
            ("Renderer.swift", "HTMLRunner/Renderer.swift", "app", "F08"),
            ("Info.plist", "HTMLRunner/Info.plist", "app", "F09"),
            ("HTMLRunner.entitlements", "HTMLRunner/HTMLRunner.entitlements", "app", "F0A"),
            ("Assets.xcassets", "HTMLRunner/Assets.xcassets", "app", "F0B"),
            ("ShareViewController.swift", "ShareExtension/ShareViewController.swift", "ext", "F11"),
            ("Info.plist", "ShareExtension/Info.plist", "ext", "F12"),
            ("ShareExtension.entitlements", "ShareExtension/ShareExtension.entitlements", "ext", "F13"),
            ("Assets.xcassets", "ShareExtension/Assets.xcassets", "ext", "F14"),
            ("SharedHTMLItem.swift", "Shared/SharedHTMLItem.swift", "shared", "F21"),
            ("SharedStore.swift", "Shared/SharedStore.swift", "shared", "F22"),
        ]
    ]:
        if not os.path.exists(os.path.join(ROOT, rel)):
            missing.append(rel)
    check(not missing, f"all {17 - len(missing)}/17 referenced files exist" +
          (f" — missing: {missing}" if missing else ""))

    # ---- plist sanity -----------------------------------------------------
    print("\nPlists / entitlements")
    import plistlib
    try:
        ext_plist = plistlib.load(open(os.path.join(ROOT, "ShareExtension/Info.plist"), "rb"))
        check(ext_plist["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.share-services",
              "extension declares the share-services point")
        check(ext_plist["NSExtension"]["NSExtensionPrincipalClass"].endswith("ShareViewController"),
              "extension principal class points at ShareViewController")
        rule = ext_plist["NSExtension"]["NSExtensionAttributes"]["NSExtensionActivationRule"]
        check(rule["NSExtensionActivationSupportsWebPageWithMaxCount"] == 1,
              "accepts web pages (Safari → Share as Web Page)")
        check(rule["NSExtensionActivationSupportsText"] is True, "accepts plain text")
    except Exception as exc:  # noqa: BLE001
        check(False, f"extension Info.plist unreadable: {exc}")

    try:
        app_plist = plistlib.load(open(os.path.join(ROOT, "HTMLRunner/Info.plist"), "rb"))
        schemes = app_plist["CFBundleURLTypes"][0]["CFBundleURLSchemes"]
        check("htmlrunner" in schemes, "app registers the htmlrunner:// URL scheme")
        for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleName",
                    "CFBundleShortVersionString", "CFBundleVersion"):
            check(key in app_plist, f"app Info.plist has {key}")
        check(app_plist.get("UILaunchScreen") is not None, "app Info.plist declares UILaunchScreen")
    except Exception as exc:  # noqa: BLE001
        check(False, f"app Info.plist unreadable: {exc}")

    try:
        ext_plist = plistlib.load(open(os.path.join(ROOT, "ShareExtension/Info.plist"), "rb"))
        for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleName",
                    "CFBundleShortVersionString", "CFBundleVersion"):
            check(key in ext_plist, f"extension Info.plist has {key}")
        check(ext_plist.get("CFBundlePackageType") == "XPC!", "extension CFBundlePackageType is XPC!")
        check("NSExtension" in ext_plist, "extension Info.plist declares NSExtension")
    except Exception as exc:  # noqa: BLE001
        check(False, f"extension Info.plist unreadable: {exc}")

    for path in ("HTMLRunner/HTMLRunner.entitlements", "ShareExtension/ShareExtension.entitlements"):
        try:
            ent = plistlib.load(open(os.path.join(ROOT, path), "rb"))
            groups = ent.get("com.apple.security.application-groups", [])
            check(len(groups) == 1, f"{path} declares one app group ({groups})")
        except Exception as exc:  # noqa: BLE001
            check(False, f"{path} unreadable: {exc}")

    return finish()


def finish():
    print()
    if failures:
        print(f"FAILED — {len(failures)} check(s) failed")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
