#!/bin/bash
# Ağ katmanının hiç var olmadığını kanıtlar. CI'da ve pre-commit hook'unda çalışır.
# Bir bulgu = build FAIL. Bu script kaynak ağacının tek kapı bekçisidir.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT" <<'PY'
import os, re, sys

root = sys.argv[1]
# design/ spesifikasyondur, taranmaz. .build ve türetilmiş çıktılar da öyle.
SKIP_DIRS = {".git", ".build", "design", "DerivedData", ".build-notes",
             "__Snapshots__", "Fonts", ".swiftpm", "xcuserdata"}
SCAN_EXT = {".swift", ".plist", ".entitlements"}

# Kelimeyi değil kullanımı arar: "CloudKit" bir test adında geçebilir, ama
# `import CloudKit` ya da `cloudKitDatabase: .automatic` geçemez.
YASAK = re.compile(
    r"URLSession|NSURLSession|"
    r"import\s+CloudKit|CK(Container|Database|Record|Query|Subscription|Asset)\b|"
    r"cloudKitDatabase\s*:\s*\.(automatic|private)|"
    r"import\s+Network\b|NWConnection|NWPathMonitor|NWBrowser|CFNetwork|"
    r"import\s+\w*(Firebase|Analytics|Crashlytics|Amplitude|Sentry|Mixpanel)\w*|"
    r"FirebaseApp|Crashlytics\.|SentrySDK|"
    r"NSAllowsArbitraryLoads|NSAppTransportSecurity|UIBackgroundModes|BGTaskScheduler|"
    r"https?://"
)

def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    out = []
    for line in text.split("\n"):
        in_string = False
        escaped = False
        cleaned = []
        i = 0
        while i < len(line):
            ch = line[i]
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = not in_string
            elif not in_string and ch == "/" and i + 1 < len(line) and line[i + 1] == "/":
                break
            cleaned.append(ch)
            i += 1
        out.append("".join(cleaned))
    return "\n".join(out)

# plist'te XML yorumu ve DOCTYPE satırındaki apple.com URL'i yorum sayılır.
def strip_xml_comments(text: str) -> str:
    text = re.sub(r"<!--.*?-->", " ", text, flags=re.S)
    text = re.sub(r"<!DOCTYPE[^>]*>", " ", text, flags=re.S)
    return text

findings = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcodeproj")]
    for name in filenames:
        ext = os.path.splitext(name)[1]
        if ext not in SCAN_EXT and name != "Package.swift":
            continue
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as handle:
            raw = handle.read()
        body = strip_xml_comments(raw) if ext in {".plist", ".entitlements"} else strip_comments(raw)
        for number, line in enumerate(body.split("\n"), start=1):
            match = YASAK.search(line)
            if match:
                findings.append(f"{rel}:{number}: {match.group(0)} — {line.strip()[:100]}")

if findings:
    print("FAIL · ağ izi bulundu (design/ ve yorumlar hariç):", file=sys.stderr)
    for finding in findings:
        print("  " + finding, file=sys.stderr)
    sys.exit(1)

print("OK · kaynak ağacında ağ katmanı izi yok")
PY
