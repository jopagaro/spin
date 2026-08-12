#!/usr/bin/env python3
"""
gen_xcodeproj.py — generate ios/RoyalSpin/RoyalSpin.xcodeproj from the source tree.

    python3 tools/gen_xcodeproj.py

Rather than committing a hand-edited pbxproj that rots the moment a file is added,
this walks the source directory and emits the project fresh. Re-run it whenever you
add or remove a file.

Object IDs are derived from a hash of each object's role and path, so regenerating
produces a byte-identical project — no spurious diffs.
"""

import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(ROOT, "ios", "RoyalSpin")
SRC = os.path.join(IOS, "RoyalSpin")
PROJ = os.path.join(IOS, "RoyalSpin.xcodeproj")

BUNDLE_ID = "com.royalspin.game"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"


def oid(*parts):
    """Deterministic 24-hex-char object id."""
    h = hashlib.sha256("::".join(parts).encode()).hexdigest().upper()
    return h[:24]


def find_sources():
    """Swift files, grouped by their directory relative to SRC."""
    groups = {}
    for dirpath, dirnames, filenames in os.walk(SRC):
        dirnames[:] = [d for d in dirnames if not d.endswith(".xcassets")]
        rel = os.path.relpath(dirpath, SRC)
        rel = "" if rel == "." else rel
        swift = sorted(f for f in filenames if f.endswith(".swift"))
        if swift:
            groups.setdefault(rel, []).extend(swift)
    return groups


def find_audio():
    d = os.path.join(SRC, "Audio")
    if not os.path.isdir(d):
        return []
    return sorted(f for f in os.listdir(d) if f.endswith(".wav"))


def main():
    src_groups = find_sources()
    audio = find_audio()

    # ── collect every file: (group_path, filename, kind) ──
    files = []
    for group, names in sorted(src_groups.items()):
        for n in names:
            files.append((group, n, "source"))
    for n in audio:
        files.append(("Audio", n, "resource"))
    files.append(("", "Assets.xcassets", "resource"))

    def path_of(group, name):
        return os.path.join(group, name) if group else name

    # ── ids ──
    file_ref = {path_of(g, n): oid("fileref", path_of(g, n)) for g, n, _ in files}
    build_file = {path_of(g, n): oid("buildfile", path_of(g, n)) for g, n, _ in files}

    group_paths = sorted({g for g, _, _ in files if g})
    group_ids = {g: oid("group", g) for g in group_paths}

    ids = {
        "project": oid("project"),
        "target": oid("target"),
        "product": oid("product"),
        "main_group": oid("maingroup"),
        "src_group": oid("srcgroup"),
        "products_group": oid("productsgroup"),
        "sources_phase": oid("sourcesphase"),
        "resources_phase": oid("resourcesphase"),
        "frameworks_phase": oid("frameworksphase"),
        "proj_cfg_list": oid("projcfglist"),
        "target_cfg_list": oid("targetcfglist"),
        "proj_debug": oid("projdebug"),
        "proj_release": oid("projrelease"),
        "target_debug": oid("targetdebug"),
        "target_release": oid("targetrelease"),
    }

    FILE_TYPES = {
        ".swift": "sourcecode.swift",
        ".wav": "audio.wav",
        ".xcassets": "folder.assetcatalog",
    }

    def filetype(name):
        return FILE_TYPES.get(os.path.splitext(name)[1], "text")

    out = []
    w = out.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {\n\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")

    # ── PBXBuildFile ──
    w("\n/* Begin PBXBuildFile section */")
    for g, n, _ in files:
        p = path_of(g, n)
        w(f"\t\t{build_file[p]} /* {n} in Build */ = {{isa = PBXBuildFile; "
          f"fileRef = {file_ref[p]} /* {n} */; }};")
    w("/* End PBXBuildFile section */")

    # ── PBXFileReference ──
    w("\n/* Begin PBXFileReference section */")
    for g, n, _ in files:
        p = path_of(g, n)
        w(f"\t\t{file_ref[p]} /* {n} */ = {{isa = PBXFileReference; "
          f"lastKnownFileType = {filetype(n)}; path = {n}; sourceTree = \"<group>\"; }};")
    w(f"\t\t{ids['product']} /* RoyalSpin.app */ = {{isa = PBXFileReference; "
      f"explicitFileType = wrapper.application; includeInIndex = 0; "
      f"path = RoyalSpin.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w("/* End PBXFileReference section */")

    # ── PBXFrameworksBuildPhase ──
    w("\n/* Begin PBXFrameworksBuildPhase section */")
    w(f"\t\t{ids['frameworks_phase']} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (\n\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")

    # ── PBXGroup ──
    w("\n/* Begin PBXGroup section */")

    # root
    w(f"\t\t{ids['main_group']} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{ids['src_group']} /* RoyalSpin */,")
    w(f"\t\t\t\t{ids['products_group']} /* Products */,")
    w("\t\t\t);")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # RoyalSpin source group
    root_files = [(g, n) for g, n, _ in files if not g]
    w(f"\t\t{ids['src_group']} /* RoyalSpin */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for g in group_paths:
        w(f"\t\t\t\t{group_ids[g]} /* {g} */,")
    for g, n in sorted(root_files, key=lambda x: x[1]):
        w(f"\t\t\t\t{file_ref[path_of(g, n)]} /* {n} */,")
    w("\t\t\t);")
    w("\t\t\tpath = RoyalSpin;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # subgroups
    for g in group_paths:
        members = sorted(n for gg, n, _ in files if gg == g)
        w(f"\t\t{group_ids[g]} /* {g} */ = {{")
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for n in members:
            w(f"\t\t\t\t{file_ref[path_of(g, n)]} /* {n} */,")
        w("\t\t\t);")
        w(f"\t\t\tpath = {g};")
        w("\t\t\tsourceTree = \"<group>\";")
        w("\t\t};")

    # products
    w(f"\t\t{ids['products_group']} /* Products */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{ids['product']} /* RoyalSpin.app */,")
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")
    w("/* End PBXGroup section */")

    # ── PBXNativeTarget ──
    w("\n/* Begin PBXNativeTarget section */")
    w(f"\t\t{ids['target']} /* RoyalSpin */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {ids['target_cfg_list']};")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{ids['sources_phase']} /* Sources */,")
    w(f"\t\t\t\t{ids['frameworks_phase']} /* Frameworks */,")
    w(f"\t\t\t\t{ids['resources_phase']} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (\n\t\t\t);")
    w("\t\t\tdependencies = (\n\t\t\t);")
    w("\t\t\tname = RoyalSpin;")
    w("\t\t\tproductName = RoyalSpin;")
    w(f"\t\t\tproductReference = {ids['product']} /* RoyalSpin.app */;")
    w("\t\t\tproductType = \"com.apple.product-type.application\";")
    w("\t\t};")
    w("/* End PBXNativeTarget section */")

    # ── PBXProject ──
    w("\n/* Begin PBXProject section */")
    w(f"\t\t{ids['project']} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    w("\t\t\t\tLastUpgradeCheck = 1600;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{ids['target']} = {{")
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {ids['proj_cfg_list']};")
    w("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);")
    w(f"\t\t\tmainGroup = {ids['main_group']};")
    w(f"\t\t\tproductRefGroup = {ids['products_group']} /* Products */;")
    w("\t\t\tprojectDirPath = \"\";")
    w("\t\t\tprojectRoot = \"\";")
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{ids['target']} /* RoyalSpin */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")

    # ── PBXResourcesBuildPhase ──
    w("\n/* Begin PBXResourcesBuildPhase section */")
    w(f"\t\t{ids['resources_phase']} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for g, n, kind in files:
        if kind == "resource":
            w(f"\t\t\t\t{build_file[path_of(g, n)]} /* {n} */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")

    # ── PBXSourcesBuildPhase ──
    w("\n/* Begin PBXSourcesBuildPhase section */")
    w(f"\t\t{ids['sources_phase']} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for g, n, kind in files:
        if kind == "source":
            w(f"\t\t\t\t{build_file[path_of(g, n)]} /* {n} */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")

    # ── XCBuildConfiguration ──
    common = f"""\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};"""

    target_common = f"""\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Royal Spin";
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIStatusBarHidden = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

    w("\n/* Begin XCBuildConfiguration section */")

    w(f"\t\t{ids['proj_debug']} /* Debug */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(common)
    w("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    w("\t\t\t\tENABLE_TESTABILITY = YES;")
    w("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    w("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\n\t\t\t\t\t\"DEBUG=1\",\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t);")
    w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    w("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
    w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    w("\t\t\t};")
    w("\t\t\tname = Debug;")
    w("\t\t};")

    w(f"\t\t{ids['proj_release']} /* Release */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(common)
    w("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    w("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    w("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    w("\t\t\t};")
    w("\t\t\tname = Release;")
    w("\t\t};")

    for key, name in (("target_debug", "Debug"), ("target_release", "Release")):
        w(f"\t\t{ids[key]} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w(target_common)
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    w("/* End XCBuildConfiguration section */")

    # ── XCConfigurationList ──
    w("\n/* Begin XCConfigurationList section */")
    for key, debug, release, label in (
        ("proj_cfg_list", "proj_debug", "proj_release", "PBXProject"),
        ("target_cfg_list", "target_debug", "target_release", "PBXNativeTarget"),
    ):
        w(f"\t\t{ids[key]} /* Build configuration list for {label} */ = {{")
        w("\t\t\tisa = XCConfigurationList;")
        w("\t\t\tbuildConfigurations = (")
        w(f"\t\t\t\t{ids[debug]} /* Debug */,")
        w(f"\t\t\t\t{ids[release]} /* Release */,")
        w("\t\t\t);")
        w("\t\t\tdefaultConfigurationIsVisible = 0;")
        w("\t\t\tdefaultConfigurationName = Release;")
        w("\t\t};")
    w("/* End XCConfigurationList section */")

    w("\t};")
    w(f"\trootObject = {ids['project']} /* Project object */;")
    w("}")

    os.makedirs(PROJ, exist_ok=True)
    with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
        f.write("\n".join(out) + "\n")

    # Scheme, so `xcodebuild -scheme RoyalSpin` works without opening Xcode first.
    scheme_dir = os.path.join(PROJ, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    with open(os.path.join(scheme_dir, "RoyalSpin.xcscheme"), "w") as f:
        f.write(SCHEME.format(target=ids["target"]))

    n_src = sum(1 for _, _, k in files if k == "source")
    n_res = sum(1 for _, _, k in files if k == "resource")
    print(f"\n  ✓ {os.path.relpath(PROJ, ROOT)}")
    print(f"    {n_src} source files, {n_res} resources")
    print(f"    bundle id {BUNDLE_ID}, iOS {DEPLOYMENT_TARGET}+\n")


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES"
                           buildForProfiling = "YES" buildForArchiving = "YES"
                           buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "RoyalSpin.app"
               BlueprintName = "RoyalSpin"
               ReferencedContainer = "container:RoyalSpin.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
               selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
                 selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0"
                 useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO"
                 debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "RoyalSpin.app"
            BlueprintName = "RoyalSpin"
            ReferencedContainer = "container:RoyalSpin.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES"
                  savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "RoyalSpin.app"
            BlueprintName = "RoyalSpin"
            ReferencedContainer = "container:RoyalSpin.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()
