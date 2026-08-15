#!/bin/bash
# Build numarasını bir artırır. Commit atmaz — sürüm değişikliğini hangi commit'in
# taşıyacağına insan karar verir.
# Kullanım: Scripts/bump-build.sh [yeni-numara]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/Config/Shared.xcconfig"

CURRENT=$(grep -E '^CURRENT_PROJECT_VERSION' "$CONFIG" | sed 's/.*= *//' | tr -d '[:space:]')
if [ -z "$CURRENT" ]; then
  echo "FAIL · CURRENT_PROJECT_VERSION okunamadı: $CONFIG" >&2
  exit 1
fi

NEXT="${1:-$((CURRENT + 1))}"
if ! [[ "$NEXT" =~ ^[0-9]+$ ]]; then
  echo "FAIL · build numarası tam sayı olmalı: $NEXT" >&2
  exit 1
fi
if [ "$NEXT" -le "$CURRENT" ] && [ -z "${1:-}" ]; then
  echo "FAIL · yeni numara mevcuttan büyük olmalı ($CURRENT)" >&2
  exit 1
fi

# App Store Connect aynı build numarasını iki kez kabul etmez; artış tek yönlü.
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEXT/" "$CONFIG"

MARKETING=$(grep -E '^MARKETING_VERSION' "$CONFIG" | sed 's/.*= *//' | tr -d '[:space:]')
echo "build $CURRENT -> $NEXT (sürüm $MARKETING)"
echo "commit atılmadı; değişikliği kendiniz commit edin"
