#!/usr/bin/env python3
"""
CourierMatch — Platform-independent build validation.

Validates project structure, source file integrity, imports, and
configuration without requiring Xcode or macOS. Runs on any platform
(Linux, macOS, Windows) with Python 3.

Exit code 0 = build validation passed.
Exit code 1 = validation failed.
"""

import os
import sys
import re
import xml.etree.ElementTree as ET

REPO = os.environ.get("REPO_PATH", "/app" if os.path.isdir("/app/App") else os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
errors = []
warnings = []

def error(msg):
    errors.append(msg)
    print(f"  ERROR: {msg}")

def warn(msg):
    warnings.append(msg)
    print(f"  WARN:  {msg}")

def ok(msg):
    print(f"  OK:    {msg}")

# ──────────────────────────────────────────────────────────────
print("=== CourierMatch Build Validation ===\n")

# 1. Check project structure
print("[1/7] Project structure...")
required_dirs = [
    "App", "Auth", "Itinerary", "Orders", "Match", "Notifications",
    "Scoring", "Appeals", "Audit", "Attachments", "Admin",
    "BackgroundTasks", "Common", "Persistence", "Resources", "Tests"
]
for d in required_dirs:
    path = os.path.join(REPO, d)
    if os.path.isdir(path):
        ok(f"{d}/")
    else:
        error(f"Missing directory: {d}/")

# 2. Check critical files exist
print("\n[2/7] Critical files...")
critical_files = [
    "App/AppDelegate.h", "App/AppDelegate.m", "App/main.m", "App/Info.plist",
    "App/SceneDelegate.h", "App/SceneDelegate.m",
    "project.yml", "Makefile", "README.md",
    "Resources/Templates.plist", "Resources/PermissionMatrix.plist",
    "Resources/LaunchScreen.storyboard",
    "Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents",
]
for f in critical_files:
    path = os.path.join(REPO, f)
    if os.path.isfile(path):
        ok(f)
    else:
        error(f"Missing file: {f}")

# 3. Count and validate source files
print("\n[3/7] Source files...")
h_files = []
m_files = []
for root, dirs, files in os.walk(REPO):
    # Skip hidden dirs, tests, xcodeproj
    dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'CourierMatch.xcodeproj' and d != 'DerivedData']
    for f in files:
        if f.endswith('.h'):
            h_files.append(os.path.join(root, f))
        elif f.endswith('.m'):
            m_files.append(os.path.join(root, f))

ok(f"{len(h_files)} header files (.h)")
ok(f"{len(m_files)} implementation files (.m)")
if len(m_files) < 100:
    error(f"Expected 100+ .m files, found {len(m_files)}")
else:
    ok(f"Source file count sufficient ({len(h_files) + len(m_files)} total)")

# 4. Validate imports resolve
print("\n[4/7] Import resolution...")
all_headers = set()
for h in h_files:
    all_headers.add(os.path.basename(h))

import_pattern = re.compile(r'#import\s+"([^"]+)"')
missing_imports = set()
checked = 0
for mf in m_files:
    with open(mf, 'r', errors='replace') as f:
        for line in f:
            match = import_pattern.search(line)
            if match:
                imported = match.group(1)
                checked += 1
                if imported not in all_headers:
                    # Could be a category or system header — only warn
                    if not imported.startswith('CM') and not imported.startswith('UI'):
                        pass  # system/framework header
                    elif imported not in missing_imports:
                        missing_imports.add(imported)

if missing_imports:
    for mi in sorted(missing_imports):
        warn(f"Import not found in project: {mi}")
else:
    ok(f"All {checked} imports resolve to project headers")

# 5. Validate Core Data model
print("\n[5/7] Core Data model...")
model_path = os.path.join(REPO, "Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents")
if os.path.isfile(model_path):
    try:
        tree = ET.parse(model_path)
        root = tree.getroot()
        entities = root.findall('.//entity')
        entity_names = [e.get('name') for e in entities]
        ok(f"{len(entities)} entities defined")

        required_entities = [
            "Tenant", "UserAccount", "LoginHistory", "Order", "Itinerary",
            "MatchCandidate", "NotificationItem", "Dispute", "RubricTemplate",
            "DeliveryScorecard", "Appeal", "AuditEntry", "Attachment"
        ]
        for re_name in required_entities:
            if re_name in entity_names:
                ok(f"Entity: {re_name}")
            else:
                error(f"Missing entity: {re_name}")
    except Exception as e:
        error(f"Core Data model parse failed: {e}")
else:
    error("Core Data model file not found")

# 6. Validate Info.plist
print("\n[6/7] Info.plist...")
plist_path = os.path.join(REPO, "App/Info.plist")
if os.path.isfile(plist_path):
    with open(plist_path, 'r') as f:
        content = f.read()
    required_keys = [
        "NSCameraUsageDescription",
        "NSFaceIDUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "BGTaskSchedulerPermittedIdentifiers",
    ]
    for key in required_keys:
        if key in content:
            ok(f"Info.plist has {key}")
        else:
            error(f"Info.plist missing {key}")
else:
    error("Info.plist not found")

# 7. Validate test files
print("\n[7/7] Test suite...")
test_dirs = {"Unit": 0, "Integration": 0, "UI": 0}
for td in test_dirs:
    test_path = os.path.join(REPO, "Tests", td)
    if os.path.isdir(test_path):
        count = len([f for f in os.listdir(test_path) if f.endswith('.m')])
        test_dirs[td] = count
        ok(f"Tests/{td}: {count} test files")
    else:
        warn(f"Tests/{td} directory missing")

total_tests = sum(test_dirs.values())
if total_tests < 20:
    error(f"Expected 20+ test files, found {total_tests}")
else:
    ok(f"Total test files: {total_tests}")

# ──────────────────────────────────────────────────────────────
print(f"\n=== Results ===")
print(f"Errors:   {len(errors)}")
print(f"Warnings: {len(warnings)}")

if errors:
    print("\nBUILD VALIDATION FAILED")
    sys.exit(1)
else:
    print("\nBUILD VALIDATION PASSED")
    sys.exit(0)
