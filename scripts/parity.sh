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
# Both directories by default. test/corpus is real documentation, which is the
# only kind of input that can disagree with what the author of a parser imagined;
# test/edge is the imagined kind, and it exists because the real documents turn
# out never to contain an unterminated fence, a table with no body, or a list
# that changes kind without a blank line. Neither corpus can replace the other.
if [ $# -gt 0 ]; then DIRS="$*"; else DIRS="$ROOT/test/corpus $ROOT/test/edge"; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pairs=0
mismatch=0

for d in $DIRS; do
  [ -d "$d" ] || { echo "parity: no corpus at $d" >&2; exit 1; }
  found=0
  for f in "$d"/*.md; do
    [ -e "$f" ] || break
    found=1
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
  [ "$found" -eq 1 ] || { echo "parity: $d has no .md in it" >&2; exit 1; }
done

echo "parity: $pairs pairs compared, $mismatch mismatched"
[ "$mismatch" -eq 0 ] || exit 1
