#!/usr/bin/env python3
"""
Generates HTMLRunner.xcodeproj/project.pbxproj for the HTML Runner iOS app
(main app target + "Open in HTML Runner" share extension).

Run:  python3 tools/make_pbxproj.py
Then: python3 tools/validate_project.py   (parses the result back)
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_DIR = os.path.join(ROOT, "HTMLRunner.xcodeproj")

# ----------------------------------------------------------------------------
# Object IDs — 24 uppercase hex chars, as Xcode expects
# ----------------------------------------------------------------------------
def oid(suffix, prefix="AA"):
    """Build a 24-char hex object id from a short unique suffix."""
    body = prefix + suffix.upper().rjust(24 - len(prefix), "0")
    assert len(body) == 24, len(body)
    return body


ID = {
    "project":            oid("0001"),
    "main_group":         oid("0002"),
    "products_group":     oid("0003"),
    "group_app":          oid("0004"),
    "group_ext":          oid("0005"),
    "group_shared":       oid("0006"),
    "product_app":        oid("0010"),
    "product_ext":        oid("0011"),
    "target_app":         oid("0020"),
    "target_ext":         oid("0021"),
    "cfglist_project":    oid("0030"),
    "cfglist_app":        oid("0031"),
    "cfglist_ext":        oid("0032"),
    "cfg_project_debug":  oid("0040"),
    "cfg_project_release":oid("0041"),
    "cfg_app_debug":      oid("0042"),
    "cfg_app_release":    oid("0043"),
    "cfg_ext_debug":      oid("0044"),
    "cfg_ext_release":    oid("0045"),
    "dependency_ext":     oid("0050"),
    "proxy_ext":          oid("0051"),
    "ph_sources_app":     oid("0060"),
    "ph_sources_ext":     oid("0061"),
    "ph_resources_app":   oid("0062"),
    "ph_resources_ext":   oid("0063"),
    "ph_frameworks_app":  oid("0064"),
    "ph_frameworks_ext":  oid("0065"),
    "ph_embed_ext":       oid("0066"),
    "bf_appex_embed":     oid("E001", prefix="DD"),
}

# (filename, path relative to project root, group, id suffix)
FILES = [
    # --- app target -------------------------------------------------------
    ("HTMLRunnerApp.swift",    "HTMLRunner/HTMLRunnerApp.swift",    "app", "F01"),
    ("ContentView.swift",      "HTMLRunner/ContentView.swift",      "app", "F02"),
    ("HomeView.swift",         "HTMLRunner/HomeView.swift",         "app", "F03"),
    ("LibraryListView.swift",  "HTMLRunner/LibraryListView.swift",  "app", "F04"),
    ("ViewerScreen.swift",     "HTMLRunner/ViewerScreen.swift",     "app", "F05"),
    ("SettingsScreen.swift",   "HTMLRunner/SettingsScreen.swift",   "app", "F06"),
    ("LibraryStore.swift",     "HTMLRunner/LibraryStore.swift",     "app", "F07"),
    ("Renderer.swift",         "HTMLRunner/Renderer.swift",         "app", "F08"),
    ("Info.plist",             "HTMLRunner/Info.plist",             "app", "F09"),
    ("HTMLRunner.entitlements","HTMLRunner/HTMLRunner.entitlements","app", "F0A"),
    ("Assets.xcassets",        "HTMLRunner/Assets.xcassets",        "app", "F0B"),
    # --- share extension --------------------------------------------------
    ("ShareViewController.swift",   "ShareExtension/ShareViewController.swift",   "ext", "F11"),
    ("Info.plist",                  "ShareExtension/Info.plist",                  "ext", "F12"),
    ("ShareExtension.entitlements", "ShareExtension/ShareExtension.entitlements", "ext", "F13"),
    ("Assets.xcassets",             "ShareExtension/Assets.xcassets",             "ext", "F14"),
    # --- shared (compiled into both targets) -------------------------------
    ("SharedHTMLItem.swift",   "Shared/SharedHTMLItem.swift",       "shared", "F21"),
    ("SharedStore.swift",      "Shared/SharedStore.swift",          "shared", "F22"),
]

APP_SOURCES = ["HTMLRunnerApp.swift", "ContentView.swift", "HomeView.swift",
               "LibraryListView.swift", "ViewerScreen.swift", "SettingsScreen.swift",
               "LibraryStore.swift", "Renderer.swift",
               "SharedHTMLItem.swift", "SharedStore.swift"]
EXT_SOURCES = ["ShareViewController.swift", "SharedHTMLItem.swift", "SharedStore.swift"]


def _fid_entry(name, group):
    _grp, suffix = _entry(name, group)
    return oid("F" + suffix[-2:])


def _entry(name, group=None):
    """Find the FILES entry for `name`, optionally restricted to a group."""
    for fname, _path, grp, suffix in FILES:
        if fname == name and (group is None or grp == group):
            return grp, suffix
    raise KeyError(f"{name} ({group})")


def file_id(name, group=None):
    """File reference id (AA… namespace)."""
    _grp, suffix = _entry(name, group)
    return oid("F" + suffix[-2:])


def build_file_id(name, target):
    """PBXBuildFile id. `target` is "app" or "ext" so a file compiled into
    both targets gets two distinct build-file objects, as Xcode requires."""
    _grp, suffix = _entry(name)
    prefix = "BB" if target == "app" else "CC"
    return oid("F" + suffix[-2:], prefix=prefix)


def render():
    L = []
    add = L.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")
    add("")

    # ---- PBXBuildFile ------------------------------------------------------
    add("/* Begin PBXBuildFile section */")
    for name in APP_SOURCES:
        add(f'\t\t{build_file_id(name, "app")} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id(name)} /* {name} */; }};')
    for name in EXT_SOURCES:
        add(f'\t\t{build_file_id(name, "ext")} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id(name)} /* {name} */; }};')
    add(f'\t\t{build_file_id("Assets.xcassets", "app")} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id("Assets.xcassets", "app")} /* Assets.xcassets */; }};')
    add(f'\t\t{build_file_id("Assets.xcassets", "ext")} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id("Assets.xcassets", "ext")} /* Assets.xcassets */; }};')
    add(f'\t\t{ID["bf_appex_embed"]} /* Open in HTML Runner.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {ID["product_ext"]} /* Open in HTML Runner.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};')
    add("/* End PBXBuildFile section */")
    add("")

    # ---- PBXContainerItemProxy --------------------------------------------
    add("/* Begin PBXContainerItemProxy section */")
    add(f'\t\t{ID["proxy_ext"]} /* PBXContainerItemProxy */ = {{')
    add("\t\t\tisa = PBXContainerItemProxy;")
    add(f'\t\t\tcontainerPortal = {ID["project"]} /* Project object */;')
    add("\t\t\tproxyType = 1;")
    add(f'\t\t\tremoteGlobalIDString = {ID["target_ext"]};')
    add('\t\t\tremoteInfo = "Open in HTML Runner";')
    add("\t\t};")
    add("/* End PBXContainerItemProxy section */")
    add("")

    # ---- PBXCopyFilesBuildPhase (embed the extension into the app) --------
    add("/* Begin PBXCopyFilesBuildPhase section */")
    add(f'\t\t{ID["ph_embed_ext"]} /* Embed App Extensions */ = {{')
    add("\t\t\tisa = PBXCopyFilesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tdstPath = \"\";")
    add("\t\t\tdstSubfolderSpec = 13;")
    add("\t\t\tfiles = (")
    add(f'\t\t\t\t{ID["bf_appex_embed"]} /* Open in HTML Runner.appex in Embed App Extensions */,')
    add("\t\t\t);")
    add('\t\t\tname = "Embed App Extensions";')
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXCopyFilesBuildPhase section */")
    add("")

    # ---- PBXFileReference --------------------------------------------------
    add("/* Begin PBXFileReference section */")
    add(f'\t\t{ID["product_app"]} /* HTMLRunner.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = HTMLRunner.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    add(f'\t\t{ID["product_ext"]} /* Open in HTML Runner.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = "Open in HTML Runner.appex"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    for fname, path, grp, suffix in FILES:
        fid = _fid_entry(fname, grp)
        if fname == "Assets.xcassets":
            add(f'\t\t{fid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
        elif fname.endswith(".plist"):
            add(f'\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {fname}; sourceTree = "<group>"; }};')
        elif fname.endswith(".entitlements"):
            add(f'\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = {fname}; sourceTree = "<group>"; }};')
        else:
            add(f'\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};')
    add("/* End PBXFileReference section */")
    add("")

    # ---- PBXFrameworksBuildPhase ------------------------------------------
    add("/* Begin PBXFrameworksBuildPhase section */")
    for key, name in (("ph_frameworks_app", "HTMLRunner"), ("ph_frameworks_ext", "Open in HTML Runner")):
        add(f'\t\t{ID[key]} /* Frameworks */ = {{')
        add("\t\t\tisa = PBXFrameworksBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")
    add("")

    # ---- PBXGroup ----------------------------------------------------------
    add("/* Begin PBXGroup section */")
    add(f'\t\t{ID["main_group"]} = {{')
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f'\t\t\t\t{ID["group_app"]} /* HTMLRunner */,')
    add(f'\t\t\t\t{ID["group_ext"]} /* ShareExtension */,')
    add(f'\t\t\t\t{ID["group_shared"]} /* Shared */,')
    add(f'\t\t\t\t{ID["products_group"]} /* Products */,')
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

    for key, name, grp in (("group_app", "HTMLRunner", "app"),
                           ("group_ext", "ShareExtension", "ext"),
                           ("group_shared", "Shared", "shared")):
        add(f'\t\t{ID[key]} /* {name} */ = {{')
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        for fname, _path, g, suffix in FILES:
            if g == grp:
                add(f'\t\t\t\t{_fid_entry(fname, g)} /* {fname} */,')
        add("\t\t\t);")
        add(f'\t\t\tpath = {name};')
        add("\t\t\tsourceTree = \"<group>\";")
        add("\t\t};")

    add(f'\t\t{ID["products_group"]} /* Products */ = {{')
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f'\t\t\t\t{ID["product_app"]} /* HTMLRunner.app */,')
    add(f'\t\t\t\t{ID["product_ext"]} /* Open in HTML Runner.appex */,')
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    add("/* End PBXGroup section */")
    add("")

    # ---- PBXNativeTarget ---------------------------------------------------
    add("/* Begin PBXNativeTarget section */")
    add(f'\t\t{ID["target_app"]} /* HTMLRunner */ = {{')
    add("\t\t\tisa = PBXNativeTarget;")
    add(f'\t\t\tbuildConfigurationList = {ID["cfglist_app"]} /* Build configuration list for PBXNativeTarget "HTMLRunner" */;')
    add("\t\t\tbuildPhases = (")
    add(f'\t\t\t\t{ID["ph_sources_app"]} /* Sources */,')
    add(f'\t\t\t\t{ID["ph_frameworks_app"]} /* Frameworks */,')
    add(f'\t\t\t\t{ID["ph_resources_app"]} /* Resources */,')
    add(f'\t\t\t\t{ID["ph_embed_ext"]} /* Embed App Extensions */,')
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add(f'\t\t\t\t{ID["dependency_ext"]} /* PBXTargetDependency */,')
    add("\t\t\t);")
    add("\t\t\tname = HTMLRunner;")
    add("\t\t\tproductName = HTMLRunner;")
    add(f'\t\t\tproductReference = {ID["product_app"]} /* HTMLRunner.app */;')
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add(f'\t\t{ID["target_ext"]} /* Open in HTML Runner */ = {{')
    add("\t\t\tisa = PBXNativeTarget;")
    add(f'\t\t\tbuildConfigurationList = {ID["cfglist_ext"]} /* Build configuration list for PBXNativeTarget "Open in HTML Runner" */;')
    add("\t\t\tbuildPhases = (")
    add(f'\t\t\t\t{ID["ph_sources_ext"]} /* Sources */,')
    add(f'\t\t\t\t{ID["ph_frameworks_ext"]} /* Frameworks */,')
    add(f'\t\t\t\t{ID["ph_resources_ext"]} /* Resources */,')
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add("\t\t\tname = \"Open in HTML Runner\";")
    add("\t\t\tproductName = \"Open in HTML Runner\";")
    add(f'\t\t\tproductReference = {ID["product_ext"]} /* Open in HTML Runner.appex */;')
    add("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")
    add("")

    # ---- PBXProject --------------------------------------------------------
    add("/* Begin PBXProject section */")
    add(f'\t\t{ID["project"]} /* Project object */ = {{')
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    add("\t\t\t\tLastUpgradeCheck = 1500;")
    add("\t\t\t\tTargetAttributes = {")
    add(f'\t\t\t\t\t{ID["target_app"]} = {{')
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add("\t\t\t\t\t};")
    add(f'\t\t\t\t\t{ID["target_ext"]} = {{')
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f'\t\t\tbuildConfigurationList = {ID["cfglist_project"]} /* Build configuration list for PBXProject "HTMLRunner" */;')
    add("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    add("\t\t\tdevelopmentRegion = en;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f'\t\t\tmainGroup = {ID["main_group"]};')
    add(f'\t\t\tproductRefGroup = {ID["products_group"]} /* Products */;')
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add("\t\t\ttargets = (")
    add(f'\t\t\t\t{ID["target_app"]} /* HTMLRunner */,')
    add(f'\t\t\t\t{ID["target_ext"]} /* Open in HTML Runner */,')
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")
    add("")

    # ---- PBXResourcesBuildPhase -------------------------------------------
    add("/* Begin PBXResourcesBuildPhase section */")
    add(f'\t\t{ID["ph_resources_app"]} /* Resources */ = {{')
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add(f'\t\t\t\t{build_file_id("Assets.xcassets", "app")} /* Assets.xcassets in Resources */,')
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add(f'\t\t{ID["ph_resources_ext"]} /* Resources */ = {{')
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add(f'\t\t\t\t{build_file_id("Assets.xcassets", "ext")} /* Assets.xcassets in Resources */,')
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")
    add("")

    # ---- PBXSourcesBuildPhase ---------------------------------------------
    add("/* Begin PBXSourcesBuildPhase section */")
    add(f'\t\t{ID["ph_sources_app"]} /* Sources */ = {{')
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for name in APP_SOURCES:
        add(f'\t\t\t\t{build_file_id(name, "app")} /* {name} in Sources */,')
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add(f'\t\t{ID["ph_sources_ext"]} /* Sources */ = {{')
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add(f'\t\t\t\t{build_file_id("ShareViewController.swift", "ext")} /* ShareViewController.swift in Sources */,')
    the_shared_ext = ["SharedHTMLItem.swift", "SharedStore.swift"]
    for name in the_shared_ext:
        add(f'\t\t\t\t{build_file_id(name, "ext")} /* {name} in Sources */,')
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")
    add("")

    # ---- PBXTargetDependency ----------------------------------------------
    add("/* Begin PBXTargetDependency section */")
    add(f'\t\t{ID["dependency_ext"]} /* PBXTargetDependency */ = {{')
    add("\t\t\tisa = PBXTargetDependency;")
    add(f'\t\t\ttarget = {ID["target_app"]} /* HTMLRunner */;')
    add(f'\t\t\ttargetProxy = {ID["proxy_ext"]} /* PBXContainerItemProxy */;')
    add("\t\t};")
    add("/* End PBXTargetDependency section */")
    add("")

    # ---- XCBuildConfiguration ---------------------------------------------
    common_project = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;"""

    project_debug = common_project + """
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

    project_release = common_project + """
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;"""

    target_app = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = HTMLRunner/HTMLRunner.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = HTMLRunner/Info.plist;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.htmlrunner;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

    target_ext = """\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ShareExtension/ShareExtension.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = ShareExtension/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.htmlrunner.share;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) APP_EXTENSION";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

    add("/* Begin XCBuildConfiguration section */")
    for key, name, settings in (
        ("cfg_project_debug", "Debug", project_debug),
        ("cfg_project_release", "Release", project_release),
        ("cfg_app_debug", "Debug", target_app),
        ("cfg_app_release", "Release", target_app),
        ("cfg_ext_debug", "Debug", target_ext),
        ("cfg_ext_release", "Release", target_ext),
    ):
        add(f'\t\t{ID[key]} /* {name} */ = {{')
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add(settings)
        add("\t\t\t};")
        add(f'\t\t\tname = {name};')
        add("\t\t};")
    add("/* End XCBuildConfiguration section */")
    add("")

    # ---- XCConfigurationList ----------------------------------------------
    add("/* Begin XCConfigurationList section */")
    for key, label, dbg, rel in (
        ("cfglist_project", 'Build configuration list for PBXProject "HTMLRunner"', "cfg_project_debug", "cfg_project_release"),
        ("cfglist_app", 'Build configuration list for PBXNativeTarget "HTMLRunner"', "cfg_app_debug", "cfg_app_release"),
        ("cfglist_ext", 'Build configuration list for PBXNativeTarget "Open in HTML Runner"', "cfg_ext_debug", "cfg_ext_release"),
    ):
        add(f'\t\t{ID[key]} /* {label} */ = {{')
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        add(f'\t\t\t\t{ID[dbg]} /* Debug */,')
        add(f'\t\t\t\t{ID[rel]} /* Release */,')
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")
    add("/* End XCConfigurationList section */")
    add("\t};")
    add(f'\trootObject = {ID["project"]} /* Project object */;')
    add("}")
    return "\n".join(L) + "\n"


def main():
    os.makedirs(PROJECT_DIR, exist_ok=True)
    target = os.path.join(PROJECT_DIR, "project.pbxproj")
    with open(target, "w") as handle:
        handle.write(render())
    print(f"wrote {target}")


if __name__ == "__main__":
    main()
