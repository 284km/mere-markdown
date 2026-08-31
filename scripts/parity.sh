#!/bin/sh
# parity.sh - the old implementation, kept, is the oracle for the new one.
#
# oracle/ is frozen: it is the implementation as it stood in the Mere repository
# at the time of the split, byte for byte. src/ is the one being rewritten onto
# an AST. For every document in the corpus and every one of the three outputs,
# the two must agree byte for byte.
#
# A PROGRAM THAT DOES NOT RUN IS A FAILURE. Comparing the output of a program
# that failed to start with the output of another that failed to start is two
# empty strings agreeing, which is not agreement about markdown.
#
#   sh scripts/parity.sh [corpus_dir]
#
# Needs a built mere on PATH, or MERE pointing at one.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "parity: no mere - set MERE=/path/to/mere.exe" >&2; exit 1; }
CORPUS="${1:-$ROOT/test/corpus}"
[ -d "$CORPUS" ] || { echo "parity: no corpus at $CORPUS" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pairs=0
mismatch=0

for f in "$CORPUS"/*.md; do
  [ -e "$f" ] || { echo "parity: corpus is empty" >&2; exit 1; }
  base="$(basename "$f")"
  for k in html text toc; do
    for side in oracle new; do
      if ! "$MERE" "$ROOT/test/drv/$side/$k.mere" "$f" > "$TMP/$side" 2> "$TMP/$side.err"; then
        echo "parity: $side/$k.mere did not run on $base" >&2
        cat "$TMP/$side.err" >&2
        exit 1
      fi
    done
    pairs=$((pairs + 1))
    if ! cmp -s "$TMP/oracle" "$TMP/new"; then
      mismatch=$((mismatch + 1))
      echo "MISMATCH  $k  $base"
      diff "$TMP/oracle" "$TMP/new" | head -6
    fi
  done
done

echo "parity: $pairs pairs compared, $mismatch mismatched"
[ "$mismatch" -eq 0 ] || exit 1
