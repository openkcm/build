#!/bin/bash

set -euo pipefail

# This is a small helper script that takes a list of paths and unfolds them:
#   If the path ends with '/...', the path itself (without '/...') and all of its subfolders are printed.
#   Otherwise, only the path is printed.
#
# Paths that don't exist will cause an error.
#
# Options:
#
#   --absolute
#       If active, converts all paths to absolute paths. Overrides --clean.
#
#   --clean
#       If active, all paths are printed relative to the working directory, with './' and '../' resolved where possible.
#
#   --no-unfold
#       If active, does simply remove '/...' suffixes instead of unfolding the corresponding paths.
#
#   --inline
#       If active, paths are separated by spaces instead of newlines.
#
# Note that each option's flag
# - toggles that option between active and inactive (with inactive being the default when no flag for that option is specified)
# - can be used multiple times, toggling the option on and off as described above
# - affects only the paths that are specified after it in the command

# 'toggle X' flips $X between 'true' and 'false'.
function toggle() {
  if eval \$$1; then
    eval "$1=false"
  else
    eval "$1=true"
  fi
}

absolute=false
clean=false
no_unfold=false
inline=false
inline_printed=false
for f in "$@"; do
  case "$f" in
    "--absolute")
      toggle absolute
      ;;
    "--clean")
      toggle clean
      ;;
    "--no-unfold")
      toggle no_unfold
      ;;
    "--inline")
      toggle inline
      ;;
    *)
      depth_mod=""
      if [[ "$f" == */... ]]; then
        f="${f%/...}" # cut off '/...'
        if $no_unfold; then
          depth_mod="-maxdepth 0"
        fi
      else
        depth_mod="-maxdepth 0"
      fi
      if $absolute; then
        f="$(realpath "$f")"
      elif $clean; then
        f="$(realpath --relative-base="$PWD" "$f")"
      fi
      if tmp=$(find "$f" $depth_mod -type d 2>&1); then
        if $inline; then
          if $inline_printed; then
            echo -n " "
          fi
          echo -n "$tmp"
          inline_printed=true
        else
          if $inline_printed; then
            echo
          fi
          echo "$tmp"
          inline_printed=false
        fi
      else
        echo "error unfolding path '$f': $tmp" >&2
        exit 1
      fi
      ;;
  esac
done
