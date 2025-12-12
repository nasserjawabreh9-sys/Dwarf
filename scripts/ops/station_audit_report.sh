#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${1:-$HOME/station_root}"
cd "$ROOT"

echo "=== STATION AUDIT REPORT ==="
echo "Time: $(date)"
echo "Root: $ROOT"
echo

echo "==[A] Git identity & remote sync =="
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo"; exit 1; }
BR="$(git branch --show-current || true)"
[ -z "${BR:-}" ] && BR="main"
echo "Branch: $BR"
echo "HEAD:   $(git rev-parse --short HEAD)"
echo "Origin: $(git remote get-url origin 2>/dev/null || echo 'NO_ORIGIN')"
echo

git fetch --all --prune >/dev/null 2>&1 || true
echo "-- Commits local not on origin/$BR:"
git --no-pager log --oneline "origin/$BR..$BR" 2>/dev/null || echo "(none or origin/$BR not found)"
echo
echo "-- Commits on origin/$BR not in local:"
git --no-pager log --oneline "$BR..origin/$BR" 2>/dev/null || echo "(none or origin/$BR not found)"
echo
echo "-- Diff stat vs origin/$BR:"
git diff --stat "origin/$BR..$BR" 2>/dev/null || echo "(no diff or origin/$BR not found)"
echo

echo "==[B] Tracked vs Untracked counts =="
TRACKED_COUNT="$(git ls-files | wc -l | tr -d ' ')"
UNTRACKED_COUNT="$(git status --porcelain=v1 | awk '/^\?\? /{c++} END{print c+0}')"
MODIFIED_COUNT="$(git status --porcelain=v1 | awk '/^ M /{c++} END{print c+0}')"
STAGED_COUNT="$(git status --porcelain=v1 | awk '/^M  /{c++} END{print c+0}')"
echo "Tracked files (on GitHub if pushed): $TRACKED_COUNT"
echo "Untracked files (NOT on GitHub):     $UNTRACKED_COUNT"
echo "Modified (not committed yet):        $MODIFIED_COUNT"
echo "Staged (ready to commit):            $STAGED_COUNT"
echo

echo "Untracked list:"
git status --porcelain=v1 | awk '/^\?\? /{print " - " $2}' || true
echo

echo "==[C] Repo size (real disk footprint) =="
echo "-- Total:"
du -sh . 2>/dev/null || true
echo
echo "-- Top 20 largest files:"
find . -type f -printf "%s\t%p\n" 2>/dev/null | sort -nr | head -n 20 | awk '{printf "%10.2f MB  %s\n", $1/1024/1024, $2}'
echo
echo "-- Top 15 largest directories:"
du -sk ./* 2>/dev/null | sort -nr | head -n 15 | awk '{printf "%10.2f MB  %s\n", $1/1024, $2}'
echo

echo "==[D] File types distribution (tracked only) =="
git ls-files > /tmp/_tracked.txt
awk -F. '
  {
    f=$0
    if (f ~ /\/$/) next
    n=split(f,a,".")
    ext=(n>1)?tolower(a[n]):"(noext)"
    cnt[ext]++
  }
  END {
    for (e in cnt) printf "%8d  %s\n", cnt[e], e
  }' /tmp/_tracked.txt | sort -nr | head -n 40
echo

echo "==[E] Sanity checks: required key components exist? =="
REQ=(
  "backend/app/main.py"
  "backend/requirements.txt"
  "frontend/package.json"
  "frontend/src/main.tsx"
  "README.md"
  "run_station.sh"
)
for p in "${REQ[@]}"; do
  if [ -e "$p" ]; then
    echo "OK   $p"
  else
    echo "MISS $p"
  fi
done
echo

echo "==[F] Quick content reality (first lines from key files) =="
for f in backend/app/main.py frontend/package.json README.md; do
  if [ -f "$f" ]; then
    echo "--- $f (head) ---"
    sed -n '1,20p' "$f"
    echo
  fi
done

echo "=== END REPORT ==="
