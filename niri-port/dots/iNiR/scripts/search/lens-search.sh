#!/usr/bin/env bash
set -euo pipefail

IMAGE_PATH="${1:-}"
ENGINE_BASE_URL="${2:-https://lens.google.com/uploadbyurl?url=}"
UPLOAD_PRIMARY="${3:-https://0x0.st}"
UPLOAD_FALLBACK_1="${4:-https://litterbox.catbox.moe/resources/internals/api.php}"
UPLOAD_FALLBACK_2="${5:-https://catbox.moe/user/api.php}"

LOG_FILE="/tmp/inir-search.log"
printf 'start %s\n' "$(date -Iseconds)" > "$LOG_FILE"
printf 'image=%s\n' "$IMAGE_PATH" >> "$LOG_FILE"

if [[ -z "$IMAGE_PATH" || ! -s "$IMAGE_PATH" ]]; then
  notify-send "Image search failed" "Selected image is empty or missing." -a "Image Search" -i image -t 3000 || true
  printf 'error=image missing\n' >> "$LOG_FILE"
  exit 1
fi

# Some upload APIs reject files without extension/name. Normalize to a .png temp file.
UPLOAD_FILE="$(mktemp --suffix=.png /tmp/inir-lens-XXXXXX)"
cp "$IMAGE_PATH" "$UPLOAD_FILE"
trap 'rm -f "$UPLOAD_FILE"' EXIT

pick_bin() {
  local fallback="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf '%s' "$fallback"
}

CURL_BIN="$(pick_bin curl "$HOME/.nix-profile/bin/curl" "/run/current-system/sw/bin/curl")"
WLCOPY_BIN="$(pick_bin wl-copy "$HOME/.nix-profile/bin/wl-copy" "/run/current-system/sw/bin/wl-copy")"
XDG_OPEN_BIN="$(pick_bin xdg-open "$HOME/.nix-profile/bin/xdg-open" "/run/current-system/sw/bin/xdg-open")"
GIO_BIN="$(pick_bin gio "$HOME/.nix-profile/bin/gio" "/run/current-system/sw/bin/gio")"
MAGICK_BIN="$(pick_bin '' "$HOME/.nix-profile/bin/magick" "/run/current-system/sw/bin/magick")"
BROWSER_BIN="$(pick_bin '' \
  "$HOME/.nix-profile/bin/firefox" "/run/current-system/sw/bin/firefox" \
  "$HOME/.nix-profile/bin/google-chrome-stable" "/run/current-system/sw/bin/google-chrome-stable" \
  "$HOME/.nix-profile/bin/google-chrome" "/run/current-system/sw/bin/google-chrome")"
WTYPE_BIN="$(pick_bin '' "$HOME/.nix-profile/bin/wtype" "/run/current-system/sw/bin/wtype")"

printf 'bins curl=%s magick=%s browser=%s\n' "$CURL_BIN" "${MAGICK_BIN:-none}" "${BROWSER_BIN:-none}" >> "$LOG_FILE"

escape_url() {
  "$CURL_BIN" -Gso /dev/null -w '%{url_effective}' --data-urlencode "url=$1" ""
}

extract_url() {
  local text="$1"
  if [[ "$text" =~ (https?://[^[:space:]\"]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

urlencode() {
  local s="$1"
  local i c out=""
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:$i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v out '%s%%%02X' "$out" "'$c" ;;
    esac
  done
  printf '%s' "$out"
}

normalize_uploaded_url() {
  local raw="$1"
  local fixed="$raw"

  # Prefer https URLs for search engines.
  fixed="${fixed/http:\/\//https://}"

  # tmpfiles API may return a page URL; convert to direct download URL.
  if [[ "$fixed" =~ ^https://tmpfiles\.org/([^/]+)/([^/?#]+)$ ]]; then
    fixed="https://tmpfiles.org/dl/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi

  printf '%s' "$fixed"
}

upload_and_get_url() {
  local file="$1"
  local resp url

  resp="$("$CURL_BIN" -sf --connect-timeout 2 --max-time 4 -F "file=@${file};type=image/png;filename=capture.png" "$UPLOAD_PRIMARY" 2>/dev/null || true)"
  url="$(extract_url "$resp")"
  if [[ -n "$url" ]]; then printf '%s' "$url"; return 0; fi

  resp="$("$CURL_BIN" -s --connect-timeout 2 --max-time 5 -F reqtype=fileupload -F time=1h -F "fileToUpload=@${file};type=image/png;filename=capture.png" "$UPLOAD_FALLBACK_1" 2>/dev/null || true)"
  url="$(extract_url "$resp")"
  if [[ -n "$url" ]]; then printf '%s' "$url"; return 0; fi

  resp="$("$CURL_BIN" -s --connect-timeout 2 --max-time 5 -F reqtype=fileupload -F "fileToUpload=@${file};type=image/png;filename=capture.png" "$UPLOAD_FALLBACK_2" 2>/dev/null || true)"
  url="$(extract_url "$resp")"
  if [[ -n "$url" ]]; then printf '%s' "$url"; return 0; fi

  return 1
}

notify-send "Image search" "Uploading selection..." -a "Image Search" -i image -t 1200 || true

# Shrink/optimize the selected image to speed up upload.
if [[ -n "${MAGICK_BIN:-}" ]]; then
  "$MAGICK_BIN" "$UPLOAD_FILE" -strip -resize "1440x1440>" -quality 82 "$UPLOAD_FILE" >/dev/null 2>&1 || true
fi

uploaded_url=""
if uploaded_url="$(upload_and_get_url "$UPLOAD_FILE" 2>/dev/null)"; then
  uploaded_url="$(normalize_uploaded_url "$uploaded_url")"
  encoded_uploaded_url="$(urlencode "$uploaded_url")"
  if [[ "$ENGINE_BASE_URL" == *"yandex."* ]]; then
    target_url="https://yandex.com/images/search?rpt=imageview&img_url=${encoded_uploaded_url}&url=${encoded_uploaded_url}"
  else
    target_url="${ENGINE_BASE_URL}${encoded_uploaded_url}"
  fi
  printf 'uploaded=%s\n' "$uploaded_url" >> "$LOG_FILE"
  printf 'target=%s\n' "$target_url" >> "$LOG_FILE"

  if [[ -n "${BROWSER_BIN:-}" ]]; then
    "$BROWSER_BIN" --new-window "$target_url" >/dev/null 2>&1 & disown
  else
    "$XDG_OPEN_BIN" "$target_url" >/dev/null 2>&1 || "$GIO_BIN" open "$target_url" >/dev/null 2>&1 || true
  fi

  notify-send "Image search ready" "Opened image search results." -a "Image Search" -i image -t 2800 || true
  printf 'status=opened_result\n' >> "$LOG_FILE"
  exit 0
fi

# Fallback: open Lens page and copy image to clipboard.
"$WLCOPY_BIN" < "$IMAGE_PATH" >/dev/null 2>&1 || true
if [[ -n "${BROWSER_BIN:-}" ]]; then
  "$BROWSER_BIN" --new-window "https://lens.google.com/" >/dev/null 2>&1 & disown
else
  "$XDG_OPEN_BIN" "https://lens.google.com/" >/dev/null 2>&1 || "$GIO_BIN" open "https://lens.google.com/" >/dev/null 2>&1 || true
fi
( sleep 1.2; if [[ -n "${WTYPE_BIN:-}" ]]; then
    "$WTYPE_BIN" -M ctrl v -m ctrl >/dev/null 2>&1 || true
    sleep 0.25
    "$WTYPE_BIN" -M shift Insert -m shift >/dev/null 2>&1 || true
    sleep 0.35
    "$WTYPE_BIN" -M ctrl v -m ctrl >/dev/null 2>&1 || true
fi ) & disown
notify-send "Image search fallback" "Opened Lens and trying auto-paste." -a "Image Search" -i image -t 3200 || true
printf 'status=fallback_open_lens\n' >> "$LOG_FILE"
exit 0
