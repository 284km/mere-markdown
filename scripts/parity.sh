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

# Where the oracle is allowed to be wrong.
#
# The frozen implementation is the oracle for a refactor, not for markdown. Once
# a defect is actually fixed the two must differ, and a gate with nowhere to say
# so is a gate that gets deleted the first time it is right to disagree.
#
# Every line names one output, one file, and the reason. Two ways to fail:
# a difference nobody wrote down, and a line whose difference has gone away —
# because that means either the fix was lost or the entry outlived it, and a
# list of stale permissions is how a gate stops looking.
EXPECT="$ROOT/test/expected_diff.txt"
expected_for() {
  [ -f "$EXPECT" ] || return 1
  # Not `{ exit 0 } END { exit 1 }`: exit from a rule still runs END, and END's
  # exit is the one that counts, so that form always says no.
  awk -v k="$1" -v f="$2" '!/^#/ && NF >= 3 && $1 == k && $2 == f { found = 1 } END { exit !found }' "$EXPECT"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/hit"
pairs=0
mismatch=0
expected=0

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
      if cmp -s "$TMP/oracle" "$TMP/new"; then
        if expected_for "$k" "$base"; then
          echo "STALE     $k  $base  (listed in expected_diff.txt but they agree)"
          mismatch=$((mismatch + 1))
          # Recorded as reached, so the unused-entry pass below does not say the
          # same thing a second time in weaker words.
          echo "$k $base" >> "$TMP/hit"
        fi
      else
        if expected_for "$k" "$base"; then
          expected=$((expected + 1))
          echo "$k $base" >> "$TMP/hit"
        else
          mismatch=$((mismatch + 1))
          echo "MISMATCH  $k  $base"
          diff "$TMP/oracle" "$TMP/new" | head -6
        fi
      fi
    done
  done
  [ "$found" -eq 1 ] || { echo "parity: $d has no .md in it" >&2; exit 1; }
done

# An entry that never came up at all is as stale as one whose difference healed:
# it names a file the run did not reach, so it is permission granted to nothing.
if [ -f "$EXPECT" ]; then
  while read -r k f _rest; do
    case "$k" in ''|'#'*) continue ;; esac
    [ -n "$f" ] || continue
    if ! grep -qx "$k $f" "$TMP/hit"; then
      echo "UNUSED    $k  $f  (listed in expected_diff.txt, never differed in this run)"
      mismatch=$((mismatch + 1))
    fi
  done < "$EXPECT"
fi

echo "parity: $pairs pairs compared, $mismatch mismatched, $expected expected-different"
[ "$mismatch" -eq 0 ] || exit 1
