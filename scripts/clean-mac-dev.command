#!/bin/bash
# SomAt Dev - Clean Mac Dev (terminal version)
# A small cache cleaner for macOS developers. MIT License.
# Shows the size of each cache, asks what to clean, then reports space freed.
# Items 1-12 are caches that are rebuilt or re-downloaded automatically.
# Items marked [pick] show a list so you choose exactly what to delete.

shopt -s nullglob

# A double-clicked script doesn't load your shell profile, so add the usual
# places where Docker, Homebrew, pnpm and Xcode tools are installed.
for d in "$HOME/.docker/bin" "/Applications/Docker.app/Contents/Resources/bin" \
         "/opt/homebrew/bin" "/usr/local/bin" "$HOME/Library/pnpm" "$HOME/.local/bin"; do
  [ -d "$d" ] && PATH="$PATH:$d"
done
export PATH

# ---- Folders that are emptied -------------------------------------------
NAMES=(
  "Xcode build cache (DerivedData)"
  "Xcode iOS device support files"
  "iOS simulator caches"
  "npm cache"
  "Gradle caches"
  "Gradle wrapper downloads"
  "Gradle daemon logs"
  "Maven downloads (~/.m2/repository)"
  "CocoaPods spec repos"
  "General tool caches (~/.cache)"
  "App caches (~/Library/Caches)"
  "App logs (~/Library/Logs)"
)
PATHS=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  "$HOME/Library/Developer/CoreSimulator/Caches"
  "$HOME/.npm/_cacache"
  "$HOME/.gradle/caches"
  "$HOME/.gradle/wrapper/dists"
  "$HOME/.gradle/daemon"
  "$HOME/.m2/repository"
  "$HOME/.cocoapods/repos"
  "$HOME/.cache"
  "$HOME/Library/Caches"
  "$HOME/Library/Logs"
)

# ---- Cleanups done by running a tool, or by picking from a list ----------
CMD_KEYS=(sim simdev simrt avd sysimg brew pnpm docker trash)
CMD_NAMES=(
  "Old unavailable iOS simulators"
  "iOS simulators [pick]"
  "iOS simulator runtimes [pick]"
  "Android emulators [pick]"
  "Android SDK system images [pick]"
  "Homebrew old versions and downloads"
  "pnpm unused packages"
  "Docker unused images and build cache"
  "Empty the Trash"
)
CMD_TOOLS=(xcrun xcrun xcrun "" "" brew pnpm docker osascript)
CMD_SIZE=(
  ""
  "$HOME/Library/Developer/CoreSimulator/Devices"
  ""
  "$HOME/.android/avd"
  "$HOME/Library/Android/sdk/system-images"
  "" "" "" ""
)

NPATHS=${#PATHS[@]}
NCMDS=${#CMD_KEYS[@]}
LAST=$((NPATHS + NCMDS))
UUID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

free_kb() { df -k "$HOME" | awk 'NR==2 {print $4}'; }

size_kb() {
  if [ -e "$1" ]; then
    du -sk "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

human() {
  awk -v k="${1:-0}" 'BEGIN {
    if (k >= 1048576) printf "%.1f GB", k / 1048576;
    else if (k >= 1024) printf "%.0f MB", k / 1024;
    else printf "%d KB", k;
  }'
}

have() { command -v "$1" >/dev/null 2>&1; }

in_home() {
  case "$1" in
    "$HOME"/?*) return 0 ;;
    *) echo "   skipped (unexpected path): $1"; return 1 ;;
  esac
}

# Remove everything inside a folder, but keep the folder itself.
empty_dir() {
  local p="$1"
  [ -n "$p" ] || return 1
  [ -d "$p" ] || return 0
  in_home "$p" || return 1
  find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
  return 0
}

# Show ITEM_LABELS with ITEM_SIZES, ask which to pick, fill PICKED with indexes.
pick_items() {
  PICKED=()
  local n=${#ITEM_LABELS[@]} j sel k
  if [ "$n" -eq 0 ]; then
    echo "   nothing found"
    return
  fi
  j=0
  while [ $j -lt $n ]; do
    printf "     %2d) %-52s %10s\n" $((j + 1)) "${ITEM_LABELS[$j]}" "$(human "${ITEM_SIZES[$j]}")"
    j=$((j + 1))
  done
  printf "   Numbers to DELETE ('a' = all, Enter = skip) > "
  read -r sel
  [ -z "$sel" ] && { echo "   skipped"; return; }
  if [ "$sel" = "a" ] || [ "$sel" = "A" ]; then
    sel=""
    j=1
    while [ $j -le $n ]; do sel="$sel $j"; j=$((j + 1)); done
  fi
  for k in $sel; do
    case "$k" in ''|*[!0-9]*) continue ;; esac
    [ "$k" -ge 1 ] && [ "$k" -le $n ] && PICKED+=($((k - 1)))
  done
  [ ${#PICKED[@]} -eq 0 ] && echo "   nothing valid picked, skipped"
}

do_simdev() {
  echo " - iOS simulators (deleting one removes its installed apps and data;"
  echo "   you can add simulators again in Xcode):"
  ITEM_LABELS=(); ITEM_SIZES=(); ITEM_IDS=()
  local line id name
  while IFS= read -r line; do
    id=$(printf '%s\n' "$line" | grep -oE "$UUID_RE" | head -1)
    [ -n "$id" ] || continue
    name=$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]*\(([0-9A-Fa-f-]{36})\).*//')
    ITEM_IDS+=("$id")
    ITEM_LABELS+=("$name  ($(printf '%s\n' "$line" | grep -oE 'Booted|Shutdown|Creating|Shutting Down' | head -1)) [${id:0:8}]")
    ITEM_SIZES+=("$(size_kb "$HOME/Library/Developer/CoreSimulator/Devices/$id")")
  done < <(xcrun simctl list devices 2>/dev/null)
  pick_items
  local i
  [ ${#PICKED[@]} -gt 0 ] && xcrun simctl shutdown all >/dev/null 2>&1
  for i in "${PICKED[@]}"; do
    echo "   deleting ${ITEM_LABELS[$i]}"
    xcrun simctl delete "${ITEM_IDS[$i]}" 2>/dev/null || echo "   could not delete it"
  done
}

do_simrt() {
  echo " - iOS simulator runtimes (whole iOS versions; re-download in"
  echo "   Xcode > Settings > Components if you need one again):"
  ITEM_LABELS=(); ITEM_SIZES=(); ITEM_IDS=()
  local line id
  while IFS= read -r line; do
    id=$(printf '%s\n' "$line" | grep -oE "$UUID_RE" | head -1)
    [ -n "$id" ] || continue
    ITEM_IDS+=("$id")
    ITEM_LABELS+=("$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]+//; s/ - [0-9A-Fa-f-]{36}//')")
    ITEM_SIZES+=(0)
  done < <(xcrun simctl runtime list 2>/dev/null)
  pick_items
  local i
  for i in "${PICKED[@]}"; do
    echo "   deleting ${ITEM_LABELS[$i]}"
    xcrun simctl runtime delete "${ITEM_IDS[$i]}" 2>/dev/null || echo "   could not delete it"
  done
}

do_avd() {
  echo " - Android emulators (deleting one removes its apps and data;"
  echo "   you can create emulators again in Android Studio's Device Manager):"
  ITEM_LABELS=(); ITEM_SIZES=(); ITEM_PATHS=()
  local d
  for d in "$HOME/.android/avd"/*.avd; do
    [ -d "$d" ] || continue
    ITEM_PATHS+=("$d")
    ITEM_LABELS+=("$(basename "$d" .avd)")
    ITEM_SIZES+=("$(size_kb "$d")")
  done
  pick_items
  local i p
  for i in "${PICKED[@]}"; do
    p="${ITEM_PATHS[$i]}"
    in_home "$p" || continue
    echo "   deleting ${ITEM_LABELS[$i]}"
    rm -rf "$p" "${p%.avd}.ini"
  done
}

do_sysimg() {
  echo " - Android SDK system images (an emulator needs its image; re-install"
  echo "   from Android Studio > Settings > Android SDK > SDK Platforms):"
  ITEM_LABELS=(); ITEM_SIZES=(); ITEM_PATHS=()
  local base="$HOME/Library/Android/sdk/system-images" d
  for d in "$base"/*/*; do
    [ -d "$d" ] || continue
    ITEM_PATHS+=("$d")
    ITEM_LABELS+=("${d#$base/}")
    ITEM_SIZES+=("$(size_kb "$d")")
  done
  pick_items
  local i p
  for i in "${PICKED[@]}"; do
    p="${ITEM_PATHS[$i]}"
    in_home "$p" || continue
    echo "   deleting ${ITEM_LABELS[$i]}"
    rm -rf "$p"
    rmdir "$(dirname "$p")" 2>/dev/null
  done
}

run_cmd() {
  case "$1" in
    sim)
      if have xcrun; then
        echo " - Removing unavailable simulators..."
        xcrun simctl delete unavailable 2>/dev/null
      else
        echo " - Xcode tools not found, simulators skipped"
      fi ;;
    simdev)
      if have xcrun; then do_simdev; else echo " - Xcode tools not found, skipped"; fi ;;
    simrt)
      if have xcrun; then do_simrt; else echo " - Xcode tools not found, skipped"; fi ;;
    avd)
      do_avd ;;
    sysimg)
      do_sysimg ;;
    brew)
      if have brew; then
        echo " - Cleaning Homebrew..."
        brew cleanup -s >/dev/null 2>&1
        hb=$(brew --cache 2>/dev/null)
        case "$hb" in "$HOME"/?*) empty_dir "$hb" ;; esac
      else
        echo " - Homebrew not found, skipped"
      fi ;;
    pnpm)
      if have pnpm; then
        echo " - Pruning pnpm store..."
        pnpm store prune >/dev/null 2>&1
      else
        echo " - pnpm not found, skipped"
      fi ;;
    docker)
      if ! have docker; then
        echo " - Docker not found, skipped"
      fi
      if have docker && ! docker info >/dev/null 2>&1; then
        echo " - Docker Desktop is not running."
        printf "   Start it now so it can be cleaned? (y/N) > "
        read -r ans
        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
          open -a Docker 2>/dev/null
          printf "   waiting for Docker to start"
          w=0
          while [ $w -lt 90 ] && ! docker info >/dev/null 2>&1; do
            printf "."
            sleep 3
            w=$((w + 3))
          done
          echo
        fi
      fi
      if ! have docker; then
        :
      elif ! docker info >/dev/null 2>&1; then
        echo "   Docker is not running, skipped (start Docker Desktop and run again)"
      else
        echo "   Docker is using:"
        docker system df 2>/dev/null | sed 's/^/     /'
        echo " - Docker: this removes ALL stopped containers, unused images,"
        echo "   unused networks and build cache. Volumes are kept."
        printf "   Continue with Docker? (y/N) > "
        read -r ans
        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
          docker system prune -a -f 2>/dev/null | tail -1
        else
          echo "   Docker skipped"
        fi
      fi ;;
    trash)
      echo " - Emptying the Trash..."
      osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1 \
        || echo "   could not empty the Trash (empty it from Finder instead)" ;;
  esac
}

clear
echo "======================================================"
echo "  SomAt Dev - Clean Mac Dev"
echo "======================================================"
echo
START_FREE=$(free_kb)
echo "Free disk space now: $(human "$START_FREE")"
echo
echo "Measuring, please wait..."
echo

SIZES=()
TOTAL=0
i=0
while [ $i -lt $NPATHS ]; do
  s=$(size_kb "${PATHS[$i]}")
  s=${s:-0}
  SIZES[$i]=$s
  TOTAL=$((TOTAL + s))
  i=$((i + 1))
done

echo "  Caches (safe, rebuilt automatically):"
i=0
while [ $i -lt $NPATHS ]; do
  printf "  %2d) %-40s %10s\n" $((i + 1)) "${NAMES[$i]}" "$(human "${SIZES[$i]}")"
  i=$((i + 1))
done
echo
echo "  Tools and [pick] lists (you choose what goes):"
i=0
while [ $i -lt $NCMDS ]; do
  info=""
  if [ "${CMD_KEYS[$i]}" = docker ] && ! have docker && [ -d /Applications/Docker.app ]; then
    info="(Docker CLI not found)"
  elif [ -n "${CMD_TOOLS[$i]}" ] && ! have "${CMD_TOOLS[$i]}"; then
    info="(not installed)"
  elif [ "${CMD_KEYS[$i]}" = docker ]; then
    dk=$(size_kb "$HOME/Library/Containers/com.docker.docker")
    if docker info >/dev/null 2>&1; then info=$(human "$dk"); else info="$(human "$dk"), not running"; fi
  elif [ -n "${CMD_SIZE[$i]}" ]; then
    info=$(human "$(size_kb "${CMD_SIZE[$i]}")")
  fi
  printf "  %2d) %-40s %10s\n" $((NPATHS + i + 1)) "${CMD_NAMES[$i]}" "$info"
  i=$((i + 1))
done
echo
echo "  Caches 1-$NPATHS total: $(human "$TOTAL")"
echo
echo "Tip: quit Xcode, Android Studio, emulators and browsers first."
echo
echo "Type the numbers to clean, separated by spaces (example: 1 3 11),"
echo "or 'a' for everything, or just press Enter to cancel."
echo "[pick] items always show their own list, so nothing there goes without asking."
printf "> "
read -r CHOICE

if [ -z "$CHOICE" ]; then
  echo "Nothing was deleted."
  exit 0
fi

if [ "$CHOICE" = "a" ] || [ "$CHOICE" = "A" ] || [ "$CHOICE" = "all" ]; then
  CHOICE=""
  n=1
  while [ $n -le $LAST ]; do
    CHOICE="$CHOICE $n"
    n=$((n + 1))
  done
fi

echo
for n in $CHOICE; do
  case "$n" in
    ''|*[!0-9]*) echo " - '$n' is not a number, skipped"; continue ;;
  esac
  if [ "$n" -ge 1 ] && [ "$n" -le $NPATHS ]; then
    idx=$((n - 1))
    echo " - Cleaning ${NAMES[$idx]}..."
    empty_dir "${PATHS[$idx]}"
  elif [ "$n" -gt $NPATHS ] && [ "$n" -le $LAST ]; then
    run_cmd "${CMD_KEYS[$((n - NPATHS - 1))]}"
  else
    echo " - $n is not on the list, skipped"
  fi
done

sleep 2
END_FREE=$(free_kb)
FREED=$((END_FREE - START_FREE))
[ "$FREED" -lt 0 ] && FREED=0
echo
echo "======================================================"
echo "  Done. Freed about $(human "$FREED")"
echo "  Free disk space now: $(human "$END_FREE")"
echo "======================================================"
echo
echo "You can close this window."
