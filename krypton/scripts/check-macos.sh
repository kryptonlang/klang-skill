#!/usr/bin/env bash
set -euo pipefail

bundle=0
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Usage: KRYPTON_ROOT=/path/to/krypton [KCC=/path/to/driver] bash check-macos.sh [--bundle]'
    printf '%s\n' 'Runs CLI probes; compiles, but does not launch, the GUI starter.'
    exit 0 ;;
  --bundle) bundle=1; shift ;;
esac
if [[ $# -ne 0 ]]; then echo 'Unknown argument; use --help.' >&2; exit 2; fi
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo 'This verifier requires native macOS arm64.' >&2
  exit 2
fi
if [[ -z "${KRYPTON_ROOT:-}" ]]; then
  echo 'Set KRYPTON_ROOT to the exact checkout or installed payload to test.' >&2
  exit 2
fi
KCC="${KCC:-$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64}"
if [[ ! -x "$KCC" ]]; then echo "Compiler not executable: $KCC" >&2; exit 2; fi
if [[ ! -f "$KRYPTON_ROOT/stdlib/objk.k" || ! -x "$KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64" ]]; then
  echo "Incomplete macOS toolchain root: $KRYPTON_ROOT" >&2
  exit 2
fi
version="$("$KCC" --version)"
case "$version" in
  'kcc version '*) ;;
  *) echo "Not the Krypton compiler: $version" >&2; exit 2 ;;
esac
skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/klang-macos.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export KRYPTON_ROOT
printf '%s\n' "Compiler: $KCC" "$version" "Root: $KRYPTON_ROOT"
for name in data model process foundation; do
  extension=ks
  [[ "$name" != model ]] || extension=k
  "$KCC" "$skill_root/assets/macos/$name.$extension" -o "$work/$name"
  if output="$("$work/$name" 2>&1)"; then status=0; else status=$?; fi
  printf '%s\n' "$output"
  if [[ "$status" -ne 0 || "$output" != *"[PASS] skill $name"* || "$output" == *'[FAIL]'* ]]; then
    echo "Probe did not pass: $name (status $status)" >&2
    exit 1
  fi
done
if output="$("$work/model" --released 2>&1)"; then status=0; else status=$?; fi
if [[ "$status" -eq 0 || "$output" != *'Objective-K: object released'* ]]; then
  printf '%s\n' "$output" 'Released-object rejection did not match the runtime contract.' >&2
  exit 1
fi
echo 'PASS released model rejects stale access'
"$KCC" "$skill_root/assets/macos/app.ks" -o "$work/app"
echo 'PASS GUI starter compile (not launched)'
if [[ "$bundle" == 1 ]]; then
  helper="$KRYPTON_ROOT/scripts/build-objk-app.ks"
  if [[ ! -f "$helper" ]]; then echo "Bundle helper not shipped in this root: $helper" >&2; exit 2; fi
  "$KCC" -r "$helper" "$skill_root/assets/macos/app.ks" SkillProbe \
    --out "$work/SkillProbe.app" --id org.example.klang-skill-probe \
    --version 0.1.0 --compiler "$KCC"
  plutil -lint "$work/SkillProbe.app/Contents/Info.plist"
  codesign --verify --deep --strict "$work/SkillProbe.app"
  echo 'PASS ad-hoc app bundle (not notarized, not launched)'
fi
echo 'PASS macOS skill probes; interactive GUI behavior is a separate check.'
