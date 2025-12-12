#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== [CHECK] Termux Build + GitHub Reality Check ==="
echo "Time: $(date)"
echo

ROOT="${1:-$HOME}"
echo "Searching for git repos under: $ROOT"
echo

# Find candidate repos (limit to depth 5 to keep it fast)
mapfile -t REPOS < <(find "$ROOT" -maxdepth 5 -type d -name ".git" 2>/dev/null | sed 's|/\.git$||' | head -n 20)

if [ "${#REPOS[@]}" -eq 0 ]; then
  echo "No .git repos found under $ROOT (maxdepth 5)."
  echo "Tip: run this from inside your project folder OR pass root path:"
  echo "  bash $0 ~/station_root"
  exit 1
fi

echo "Found repos:"
for r in "${REPOS[@]}"; do echo " - $r"; done
echo

for REPO in "${REPOS[@]}"; do
  echo "------------------------------------------------------------"
  echo "REPO: $REPO"
  echo "------------------------------------------------------------"
  cd "$REPO"

  echo "[1] Local build footprint (top-level):"
  ls -la | sed -n '1,120p'
  echo

  echo "[2] Key folders existence:"
  for p in app backend frontend dashboard scripts ops config .env .env.example requirements.txt pyproject.toml package.json docker-compose.yml Dockerfile README.md; do
    if [ -e "$p" ]; then
      echo "  OK   $p"
    else
      echo "  MISS $p"
    fi
  done
  echo

  echo "[3] Git identity:"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo?"; continue; }
  echo "  Branch: $(git branch --show-current || true)"
  echo "  HEAD:   $(git rev-parse --short HEAD)"
  echo "  Remote: $(git remote -v | head -n 2 | tr '\n' ' ' )"
  echo

  echo "[4] Local status (what is NOT committed):"
  git status --porcelain=v1 || true
  echo

  echo "[5] Last 10 local commits:"
  git --no-pager log --oneline -n 10 || true
  echo

  echo "[6] Remote reality check (origin):"
  if git remote get-url origin >/dev/null 2>&1; then
    ORIGIN_URL="$(git remote get-url origin)"
    echo "  origin url: $ORIGIN_URL"

    # Fetch remote refs (safe)
    git fetch --all --prune >/dev/null 2>&1 || true

    BR="$(git branch --show-current || true)"
    if [ -z "${BR:-}" ]; then BR="main"; fi

    echo "  Remote branches:"
    git branch -r || true
    echo

    echo "[7] Compare local vs origin/$BR:"
    echo "  A) Commits in local not on remote:"
    git --no-pager log --oneline "origin/$BR..$BR" 2>/dev/null || echo "    (none or origin/$BR not found)"
    echo
    echo "  B) Commits on remote not in local:"
    git --no-pager log --oneline "$BR..origin/$BR" 2>/dev/null || echo "    (none or origin/$BR not found)"
    echo

    echo "[8] Diff summary vs origin/$BR:"
    git diff --stat "origin/$BR..$BR" 2>/dev/null || echo "    (no diff or origin/$BR not found)"
    echo

    echo "[9] What files are tracked in repo (top 120):"
    git ls-files | head -n 120 || true
    echo

  else
    echo "  No origin remote configured."
    echo
  fi

done

echo "=== [CHECK] Done ==="
