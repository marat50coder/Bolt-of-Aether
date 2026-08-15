#!/usr/bin/env python3
"""One-shot patch: adds the BoltPushRelay NSE target, wires PrivacyInfo and
GoogleService-Info.plist into Runner, and attaches Runner.entitlements to the
three Runner build configurations.

Safe to re-run: the script no-ops any block it has already inserted, using
sentinel comments (`/* BoltPushRelay */`, `PrivacyInfo.xcprivacy`, and the
`Runner.entitlements` marker).

Reads the pbxproj as bytes, never adds a BOM, preserves the existing line
endings (LF for this project).
"""
from __future__ import annotations
import pathlib
import re
import sys

PBX = pathlib.Path('ios/Runner.xcodeproj/project.pbxproj')

# ---- known UUIDs already in the project ------------------------------------
PROJECT_UUID    = '97C146E61CF9000F007C117D'
MAIN_GROUP_UUID = '97C146E51CF9000F007C117D'
RUNNER_GROUP    = '97C146F01CF9000F007C117D'
PRODUCTS_GROUP  = '97C146EF1CF9000F007C117D'
RUNNER_TARGET   = '97C146ED1CF9000F007C117D'
RUNNER_RESOURCES_PHASE = '97C146EC1CF9000F007C117D'
RUNNER_DEBUG_CFG   = '97C147061CF9000F007C117D'
RUNNER_RELEASE_CFG = '97C147071CF9000F007C117D'
RUNNER_PROFILE_CFG = '249021D4217E4FDB00AE95B9'
THIN_BINARY_PHASE  = '3B06AD1E1E4923F5004D2608'
RUNNER_INFO_PLIST  = '97C147021CF9000F007C117D'

# ---- fresh UUIDs for NSE + resources (random 24-hex, not a pattern) --------
# Generated once with secrets.token_hex(12).upper(); baked in so re-runs are
# stable / idempotent.
NSE_SRC_REF        = 'A7F31C82D9B4507E4C1AE862'
NSE_INFO_REF       = 'B0E58D194AF126C337895CDA'
NSE_PRODUCT_REF    = '3C97A2E5F81B4D0629E37AB0'  # BoltPushRelay.appex
NSE_GROUP_UUID     = '4E52C761AB8039D1F2C4E980'
NSE_TARGET_UUID    = '6D1FB4A9C520E6738A11B37F'
NSE_TARGET_PROXY   = '81A3D75E29C4F0B6E7130489'
NSE_TARGET_DEP     = '9C4B8F31A0E75D2C6584E1F2'
NSE_CFG_LIST       = 'D82F906A314E5B7C89AC6D53'
NSE_DEBUG_CFG      = '2A85E4C79B106F35D40E7AB1'
NSE_RELEASE_CFG    = '7B198CFE452AD9036C8FE274'
NSE_PROFILE_CFG    = 'E0369D18A7C452BF381F94AE'
NSE_SOURCES_PHASE  = '5F27ACB6809E3D14A2760C58'
NSE_FRAMEWORKS_PHASE = '18C4A907E63D521B9F04B85D'
NSE_RESOURCES_PHASE  = '0D9E6B14A82C7F350169D34E'
NSE_SRC_BUILD      = 'F5A9028DE4137C68B0629A15'
NSE_EMBED_BUILD    = '3B7419E82D0AF6C5183746E9'
EMBED_APPEX_PHASE  = 'AE64071CB238F509D461A7F8'

PRIVACY_INFO_REF   = 'C81D3A97F6420E85B94C7150'
PRIVACY_BUILD_REF  = '20B4E8F1D67C495E802A3B1F'
GOOGLESERVICE_REF  = '6A0F1E5DB7C348290F614C7A'
GOOGLESERVICE_BUILD_REF = '58E37A4C1B90D6F231A5842E'


def already_patched(txt: str) -> bool:
    return '/* BoltPushRelay */' in txt


def insert_after(txt: str, needle: str, block: str) -> str:
    idx = txt.find(needle)
    if idx < 0:
        raise SystemExit(f'FAIL: needle not found: {needle!r}')
    pos = idx + len(needle)
    return txt[:pos] + block + txt[pos:]


def replace_once(txt: str, old: str, new: str) -> str:
    idx = txt.find(old)
    if idx < 0:
        raise SystemExit(f'FAIL: replacement source not found:\n{old!r}')
    return txt[:idx] + new + txt[idx + len(old):]


def patch(txt: str) -> str:
    # ---------- 1. PBXBuildFile section ----------
    txt = insert_after(
        txt, '/* Begin PBXBuildFile section */\n',
        f'\t\t{NSE_SRC_BUILD} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {NSE_SRC_REF} /* NotificationService.swift */; }};\n'
        f'\t\t{NSE_EMBED_BUILD} /* BoltPushRelay.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {NSE_PRODUCT_REF} /* BoltPushRelay.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n'
        f'\t\t{PRIVACY_BUILD_REF} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {PRIVACY_INFO_REF} /* PrivacyInfo.xcprivacy */; }};\n'
        f'\t\t{GOOGLESERVICE_BUILD_REF} /* GoogleService-Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {GOOGLESERVICE_REF} /* GoogleService-Info.plist */; }};\n'
    )

    # ---------- 2. PBXContainerItemProxy section ----------
    txt = insert_after(
        txt, '/* Begin PBXContainerItemProxy section */\n',
        f'\t\t{NSE_TARGET_PROXY} /* PBXContainerItemProxy */ = {{\n'
        f'\t\t\tisa = PBXContainerItemProxy;\n'
        f'\t\t\tcontainerPortal = {PROJECT_UUID} /* Project object */;\n'
        f'\t\t\tproxyType = 1;\n'
        f'\t\t\tremoteGlobalIDString = {NSE_TARGET_UUID};\n'
        f'\t\t\tremoteInfo = BoltPushRelay;\n'
        f'\t\t}};\n'
    )

    # ---------- 3. PBXCopyFilesBuildPhase section (Embed App Extensions) ----
    txt = insert_after(
        txt, '/* Begin PBXCopyFilesBuildPhase section */\n',
        f'\t\t{EMBED_APPEX_PHASE} /* Embed App Extensions */ = {{\n'
        f'\t\t\tisa = PBXCopyFilesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tdstPath = "";\n'
        f'\t\t\tdstSubfolderSpec = 13;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{NSE_EMBED_BUILD} /* BoltPushRelay.appex in Embed App Extensions */,\n'
        f'\t\t\t);\n'
        f'\t\t\tname = "Embed App Extensions";\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )

    # ---------- 4. PBXFileReference section ----------
    txt = insert_after(
        txt, '/* Begin PBXFileReference section */\n',
        f'\t\t{NSE_SRC_REF} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; }};\n'
        f'\t\t{NSE_INFO_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};\n'
        f'\t\t{NSE_PRODUCT_REF} /* BoltPushRelay.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = BoltPushRelay.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
        f'\t\t{PRIVACY_INFO_REF} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; }};\n'
        f'\t\t{GOOGLESERVICE_REF} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; }};\n'
    )

    # ---------- 5. PBXGroup section: create BoltPushRelay group ----------
    txt = insert_after(
        txt, '/* Begin PBXGroup section */\n',
        f'\t\t{NSE_GROUP_UUID} /* BoltPushRelay */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t{NSE_SRC_REF} /* NotificationService.swift */,\n'
        f'\t\t\t\t{NSE_INFO_REF} /* Info.plist */,\n'
        f'\t\t\t);\n'
        f'\t\t\tpath = BoltPushRelay;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};\n'
    )

    # ---------- 5b. Add NSE group to main group children ----------
    txt = replace_once(
        txt,
        f'\t\t{MAIN_GROUP_UUID} = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n'
        f'\t\t\t\t{RUNNER_GROUP} /* Runner */,\n'
        f'\t\t\t\t{PRODUCTS_GROUP} /* Products */,\n',
        f'\t\t{MAIN_GROUP_UUID} = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n'
        f'\t\t\t\t{RUNNER_GROUP} /* Runner */,\n'
        f'\t\t\t\t{NSE_GROUP_UUID} /* BoltPushRelay */,\n'
        f'\t\t\t\t{PRODUCTS_GROUP} /* Products */,\n'
    )

    # ---------- 5c. Add NSE product .appex to Products group ----------
    txt = replace_once(
        txt,
        f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n'
        f'\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n'
        f'\t\t\t);\n',
        f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n'
        f'\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n'
        f'\t\t\t\t{NSE_PRODUCT_REF} /* BoltPushRelay.appex */,\n'
        f'\t\t\t);\n'
    )

    # ---------- 5d. Add PrivacyInfo + GoogleService to Runner group ---------
    txt = replace_once(
        txt,
        f'\t\t{RUNNER_GROUP} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146FA1CF9000F007C117D /* Main.storyboard */,\n'
        f'\t\t\t\t97C146FD1CF9000F007C117D /* Assets.xcassets */,\n'
        f'\t\t\t\t97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */,\n'
        f'\t\t\t\t{RUNNER_INFO_PLIST} /* Info.plist */,\n',
        f'\t\t{RUNNER_GROUP} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146FA1CF9000F007C117D /* Main.storyboard */,\n'
        f'\t\t\t\t97C146FD1CF9000F007C117D /* Assets.xcassets */,\n'
        f'\t\t\t\t97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */,\n'
        f'\t\t\t\t{RUNNER_INFO_PLIST} /* Info.plist */,\n'
        f'\t\t\t\t{PRIVACY_INFO_REF} /* PrivacyInfo.xcprivacy */,\n'
        f'\t\t\t\t{GOOGLESERVICE_REF} /* GoogleService-Info.plist */,\n'
    )

    # ---------- 6. PBXNativeTarget: add BoltPushRelay target ----------
    txt = insert_after(
        txt, '/* Begin PBXNativeTarget section */\n',
        f'\t\t{NSE_TARGET_UUID} /* BoltPushRelay */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget "BoltPushRelay" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t{NSE_SOURCES_PHASE} /* Sources */,\n'
        f'\t\t\t\t{NSE_FRAMEWORKS_PHASE} /* Frameworks */,\n'
        f'\t\t\t\t{NSE_RESOURCES_PHASE} /* Resources */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t);\n'
        f'\t\t\tname = BoltPushRelay;\n'
        f'\t\t\tproductName = BoltPushRelay;\n'
        f'\t\t\tproductReference = {NSE_PRODUCT_REF} /* BoltPushRelay.appex */;\n'
        f'\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        f'\t\t}};\n'
    )

    # ---------- 6b. Wire Embed App Extensions BEFORE Thin Binary in Runner --
    old_runner_phases = (
        f'\t\t{RUNNER_TARGET} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t58BAA4B692F80AB6DD96AB83 /* [CP] Check Pods Manifest.lock */,\n'
        f'\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n'
        f'\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
        f'\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n'
        f'\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n'
        f'\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n'
        f'\t\t\t\t{THIN_BINARY_PHASE} /* Thin Binary */,\n'
        f'\t\t\t\tF95781C7EA153A85081DF2FA /* [CP] Embed Pods Frameworks */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t);\n'
    )
    new_runner_phases = (
        f'\t\t{RUNNER_TARGET} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t58BAA4B692F80AB6DD96AB83 /* [CP] Check Pods Manifest.lock */,\n'
        f'\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n'
        f'\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
        f'\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n'
        f'\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n'
        f'\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n'
        f'\t\t\t\t{EMBED_APPEX_PHASE} /* Embed App Extensions */,\n'
        f'\t\t\t\t{THIN_BINARY_PHASE} /* Thin Binary */,\n'
        f'\t\t\t\tF95781C7EA153A85081DF2FA /* [CP] Embed Pods Frameworks */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t\t{NSE_TARGET_DEP} /* PBXTargetDependency */,\n'
        f'\t\t\t);\n'
    )
    txt = replace_once(txt, old_runner_phases, new_runner_phases)

    # ---------- 7. PBXProject: add NSE target + TargetAttributes -----------
    txt = replace_once(
        txt,
        '\t\t\t\t\t97C146ED1CF9000F007C117D = {\n'
        '\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n'
        '\t\t\t\t\t\tLastSwiftMigration = 1100;\n'
        '\t\t\t\t\t};\n'
        '\t\t\t\t};\n',
        '\t\t\t\t\t97C146ED1CF9000F007C117D = {\n'
        '\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n'
        '\t\t\t\t\t\tLastSwiftMigration = 1100;\n'
        '\t\t\t\t\t};\n'
        f'\t\t\t\t\t{NSE_TARGET_UUID} = {{\n'
        '\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n'
        '\t\t\t\t\t};\n'
        '\t\t\t\t};\n'
    )
    txt = replace_once(
        txt,
        '\t\t\ttargets = (\n'
        f'\t\t\t\t{RUNNER_TARGET} /* Runner */,\n'
        '\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n'
        '\t\t\t);\n',
        '\t\t\ttargets = (\n'
        f'\t\t\t\t{RUNNER_TARGET} /* Runner */,\n'
        f'\t\t\t\t{NSE_TARGET_UUID} /* BoltPushRelay */,\n'
        '\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n'
        '\t\t\t);\n'
    )

    # ---------- 8. Runner Resources phase: add PrivacyInfo + GoogleService --
    txt = replace_once(
        txt,
        f'\t\t{RUNNER_RESOURCES_PHASE} /* Resources */ = {{\n'
        f'\t\t\tisa = PBXResourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */,\n'
        f'\t\t\t\t3B3967161E833CAA004F5970 /* AppFrameworkInfo.plist in Resources */,\n'
        f'\t\t\t\t97C146FE1CF9000F007C117D /* Assets.xcassets in Resources */,\n'
        f'\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n'
        f'\t\t\t);\n',
        f'\t\t{RUNNER_RESOURCES_PHASE} /* Resources */ = {{\n'
        f'\t\t\tisa = PBXResourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */,\n'
        f'\t\t\t\t3B3967161E833CAA004F5970 /* AppFrameworkInfo.plist in Resources */,\n'
        f'\t\t\t\t97C146FE1CF9000F007C117D /* Assets.xcassets in Resources */,\n'
        f'\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n'
        f'\t\t\t\t{PRIVACY_BUILD_REF} /* PrivacyInfo.xcprivacy in Resources */,\n'
        f'\t\t\t\t{GOOGLESERVICE_BUILD_REF} /* GoogleService-Info.plist in Resources */,\n'
        f'\t\t\t);\n'
    )

    # ---------- 9. PBXSourcesBuildPhase + Frameworks + Resources for NSE ---
    txt = insert_after(
        txt, '/* Begin PBXSourcesBuildPhase section */\n',
        f'\t\t{NSE_SOURCES_PHASE} /* Sources */ = {{\n'
        f'\t\t\tisa = PBXSourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{NSE_SRC_BUILD} /* NotificationService.swift in Sources */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    txt = insert_after(
        txt, '/* Begin PBXFrameworksBuildPhase section */\n',
        f'\t\t{NSE_FRAMEWORKS_PHASE} /* Frameworks */ = {{\n'
        f'\t\t\tisa = PBXFrameworksBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    txt = insert_after(
        txt, '/* Begin PBXResourcesBuildPhase section */\n',
        f'\t\t{NSE_RESOURCES_PHASE} /* Resources */ = {{\n'
        f'\t\t\tisa = PBXResourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )

    # ---------- 10. PBXTargetDependency for Runner → NSE -------------------
    txt = insert_after(
        txt, '/* Begin PBXTargetDependency section */\n',
        f'\t\t{NSE_TARGET_DEP} /* PBXTargetDependency */ = {{\n'
        f'\t\t\tisa = PBXTargetDependency;\n'
        f'\t\t\ttarget = {NSE_TARGET_UUID} /* BoltPushRelay */;\n'
        f'\t\t\ttargetProxy = {NSE_TARGET_PROXY} /* PBXContainerItemProxy */;\n'
        f'\t\t}};\n'
    )

    # ---------- 11. XCBuildConfiguration blocks for NSE (NO base cfg ref) --
    nse_cfg_common = (
        f'\t\t\t\tCLANG_ANALYZER_NONNULL = YES;\n'
        f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
        f'\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n'
        f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
        f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
        f'\t\t\t\tDEVELOPMENT_TEAM = LH3A68FPJC;\n'
        f'\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
        f'\t\t\t\tINFOPLIST_FILE = BoltPushRelay/Info.plist;\n'
        f'\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = BoltPushRelay;\n'
        f'\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";\n'
        f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;\n'
        f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n'
        f'\t\t\t\t\t"$(inherited)",\n'
        f'\t\t\t\t\t"@executable_path/Frameworks",\n'
        f'\t\t\t\t\t"@executable_path/../../Frameworks",\n'
        f'\t\t\t\t);\n'
        f'\t\t\t\tMARKETING_VERSION = 1.0.0;\n'
        f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.boltaether.boltaethergame.NotificationService;\n'
        f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
        f'\t\t\t\tSKIP_INSTALL = YES;\n'
        f'\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
        f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
        f'\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n'
    )
    nse_cfg_block = (
        f'\t\t{NSE_DEBUG_CFG} /* Debug */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'{nse_cfg_common}'
        f'\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n'
        f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n'
        f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Debug;\n'
        f'\t\t}};\n'
        f'\t\t{NSE_RELEASE_CFG} /* Release */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'{nse_cfg_common}'
        f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";\n'
        f'\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Release;\n'
        f'\t\t}};\n'
        f'\t\t{NSE_PROFILE_CFG} /* Profile */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'{nse_cfg_common}'
        f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";\n'
        f'\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Profile;\n'
        f'\t\t}};\n'
    )
    txt = insert_after(txt, '/* Begin XCBuildConfiguration section */\n', nse_cfg_block)

    # ---------- 12. XCConfigurationList for NSE ---------------------------
    txt = insert_after(
        txt, '/* Begin XCConfigurationList section */\n',
        f'\t\t{NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget "BoltPushRelay" */ = {{\n'
        f'\t\t\tisa = XCConfigurationList;\n'
        f'\t\t\tbuildConfigurations = (\n'
        f'\t\t\t\t{NSE_DEBUG_CFG} /* Debug */,\n'
        f'\t\t\t\t{NSE_RELEASE_CFG} /* Release */,\n'
        f'\t\t\t\t{NSE_PROFILE_CFG} /* Profile */,\n'
        f'\t\t\t);\n'
        f'\t\t\tdefaultConfigurationIsVisible = 0;\n'
        f'\t\t\tdefaultConfigurationName = Release;\n'
        f'\t\t}};\n'
    )

    # ---------- 13. Attach CODE_SIGN_ENTITLEMENTS to Runner configs -------
    for cfg in (RUNNER_DEBUG_CFG, RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
        # Insert AFTER DEVELOPMENT_TEAM line inside that block.
        needle = f'\t\t{cfg} /* '
        idx = txt.find(needle)
        if idx < 0:
            raise SystemExit(f'FAIL: cfg block not found: {cfg}')
        block_end = txt.find('};\n', idx)
        block = txt[idx:block_end]
        if 'CODE_SIGN_ENTITLEMENTS' in block:
            continue
        team_line = '\t\t\t\tDEVELOPMENT_TEAM = LH3A68FPJC;\n'
        if team_line not in block:
            raise SystemExit(f'FAIL: DEVELOPMENT_TEAM line missing in {cfg}')
        new_block = block.replace(
            team_line,
            team_line + '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n',
            1,
        )
        txt = txt[:idx] + new_block + txt[block_end:]

    return txt


def main() -> int:
    if not PBX.exists():
        print(f'no such file: {PBX}', file=sys.stderr)
        return 1

    raw = PBX.read_bytes()
    if raw.startswith(b'\xef\xbb\xbf'):
        print('FAIL: file has UTF-8 BOM before patch', file=sys.stderr)
        return 1
    txt = raw.decode('utf-8')

    if already_patched(txt):
        print('already patched — no-op')
        return 0

    txt = patch(txt)

    # Sanity: entitlements on Runner configs, not NSE
    for cfg in (RUNNER_DEBUG_CFG, RUNNER_RELEASE_CFG, RUNNER_PROFILE_CFG):
        idx = txt.find(f'\t\t{cfg} /* ')
        block_end = txt.find('};\n', idx)
        assert 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements' in txt[idx:block_end], \
            f'entitlements not set on {cfg}'
    for cfg in (NSE_DEBUG_CFG, NSE_RELEASE_CFG, NSE_PROFILE_CFG):
        idx = txt.find(f'\t\t{cfg} /* ')
        block_end = txt.find('};\n', idx)
        assert 'CODE_SIGN_ENTITLEMENTS' not in txt[idx:block_end], \
            f'entitlements accidentally on NSE {cfg}'
        assert 'baseConfigurationReference' not in txt[idx:block_end], \
            f'NSE {cfg} has baseConfigurationReference — must be absent'

    # NSE group must be inside PBXGroup section, not outside
    g0 = txt.find('/* Begin PBXGroup section */')
    g1 = txt.find('/* End PBXGroup section */')
    assert NSE_GROUP_UUID in txt[g0:g1], 'NSE group outside PBXGroup section'

    # No BOM on write
    PBX.write_bytes(txt.encode('utf-8'))
    print('patched OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
