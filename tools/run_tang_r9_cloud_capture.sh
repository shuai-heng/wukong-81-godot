#!/usr/bin/env bash
set -euo pipefail

# Tang R9 real Godot capture runner.
# Intended for a normal Ubuntu x86_64 machine (cloud VM or local Linux), not GitHub Actions.
# It downloads the official Godot 4.7.2 Linux build, verifies SHA256, imports/parses the project,
# runs Tang contracts + runtime smoke, records a real Godot movie, extracts audit frames, and creates GIF/MP4.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/evidence/tang-r9-real-run"
CACHE="${ROOT}/.local-tools/godot-4.7.2"
GODOT_ZIP="${CACHE}/Godot_v4.7.2-stable_linux.x86_64.zip"
GODOT_BIN="${CACHE}/Godot_v4.7.2-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
GODOT_SHA256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"

mkdir -p "$OUT" "$CACHE"
cd "$ROOT"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 2
  }
}

for c in curl unzip sha256sum ffmpeg xvfb-run; do need_cmd "$c"; done

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "==> Downloading official Godot 4.7.2 Linux x86_64"
  curl -L --fail --retry 3 --connect-timeout 20 -o "$GODOT_ZIP" "$GODOT_URL"
  echo "${GODOT_SHA256}  ${GODOT_ZIP}" | sha256sum -c -
  unzip -o "$GODOT_ZIP" -d "$CACHE" >/dev/null
  chmod +x "$GODOT_BIN"
fi

"$GODOT_BIN" --version | tee "$OUT/godot-version.txt"
if ! "$GODOT_BIN" --version | grep -q '^4\.7\.2'; then
  echo "ERROR: expected Godot 4.7.2" >&2
  exit 3
fi

export XDG_DATA_HOME="$OUT/xdg-data"
export XDG_CONFIG_HOME="$OUT/xdg-config"
export XDG_CACHE_HOME="$OUT/xdg-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

run_headless() {
  local name="$1"; shift
  echo "==> $name"
  "$GODOT_BIN" --headless --path "$ROOT" --audio-driver Dummy --log-file "$OUT/${name}.log" "$@"
}

# 1) Import and parse the real project first.
run_headless import --editor --quit

# 2) Structural/contract gates. These are fast and fail closed.
for test in \
  tests/tang_v6_r3_contract.gd \
  tests/tang_r4_visual_contract.gd \
  tests/tang_r5_contact_feedback_contract.gd \
  tests/tang_r6_form_contract.gd \
  tests/tang_r7_cast_pose_contract.gd \
  tests/tang_r8_release_window_contract.gd; do
  name="$(basename "$test" .gd)"
  run_headless "$name" --script "res://$test"
done

# 3) Runtime smoke: real scenes/main.tscn + TangFighterV6R9 inheritance chain.
run_headless tang-r9-runtime-smoke --script res://tests/tang_r5_runtime_smoke.gd

# 4) Real rendered movie under Xvfb. Godot itself writes the AVI.
MOVIE_AVI="$OUT/tang-r9-godot-real.avi"
MOVIE_MP4="$OUT/tang-r9-godot-real.mp4"
MOVIE_GIF="$OUT/tang-r9-godot-real.gif"
rm -f "$MOVIE_AVI" "$MOVIE_MP4" "$MOVIE_GIF"

echo "==> Recording real Godot movie"
xvfb-run -a -s "-screen 0 1440x900x24" \
  "$GODOT_BIN" --path "$ROOT" \
  --rendering-method gl_compatibility \
  --audio-driver Dummy \
  --fixed-fps 60 \
  --write-movie "$MOVIE_AVI" \
  --log-file "$OUT/tang-r9-movie.log" \
  --script res://tests/tang_v6_movie.gd

# 5) Real rendered pause-frame audit from the running viewport.
echo "==> Capturing real Godot audit frames"
xvfb-run -a -s "-screen 0 1440x900x24" \
  "$GODOT_BIN" --path "$ROOT" \
  --rendering-method gl_compatibility \
  --audio-driver Dummy \
  --log-file "$OUT/tang-r9-frame-audit.log" \
  --script res://tests/tang_r9_frame_audit.gd

# Godot user:// path follows XDG_DATA_HOME. Locate the produced audit directory.
AUDIT_DIR="$(find "$XDG_DATA_HOME" -type d -name 'tang-r9-frame-audit' -print -quit || true)"
if [[ -n "$AUDIT_DIR" ]]; then
  rm -rf "$OUT/frames"
  cp -a "$AUDIT_DIR" "$OUT/frames"
else
  echo "ERROR: real frame audit directory not found" >&2
  exit 4
fi

# 6) Delivery video + quick GIF. No fake storyboard frames.
ffmpeg -y -i "$MOVIE_AVI" -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -an "$MOVIE_MP4" >/dev/null 2>&1
ffmpeg -y -i "$MOVIE_MP4" -vf "fps=15,scale=960:-1:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" -loop 0 "$MOVIE_GIF" >/dev/null 2>&1

# 7) Evidence summary.
{
  echo "Tang R9 real Godot run"
  echo "branch: task/pixel-complete-v6-r5"
  echo "commit: $(git rev-parse HEAD 2>/dev/null || echo archive-no-git)"
  echo "godot: $($GODOT_BIN --version | head -1)"
  echo "movie_avi: $MOVIE_AVI"
  echo "movie_mp4: $MOVIE_MP4"
  echo "movie_gif: $MOVIE_GIF"
  echo "frames: $OUT/frames"
  echo "generated_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$OUT/REAL_RUN_SUMMARY.txt"

echo "==> PASS: real Godot artifacts are in $OUT"
