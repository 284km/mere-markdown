# mere-markdown

Markdown to HTML, plain text, and a table of contents, written in
[Mere](https://merelang.org/).

Split out of the Mere repository's `contrib/markdown`, which had four consumers
and no gate on its output. This repository exists to give it one, and then to
change its shape: the converter goes to HTML directly from a list of lines, and
a list of lines is not something you can put on a slide, in a terminal, or in a
window.

## Status: mid-refactor, and the old one is watching

    oracle/   the implementation as it stood at the split, frozen, byte for byte
    src/      the one being rewritten onto an AST
    scripts/parity.sh   runs both over both corpora and demands they agree

**HTML now goes through a document.** `src/to_html.mere` is `parse` followed by
`to_html`, and it emits the same bytes as the state machine it replaced. Text and
the table of contents are still on the old path; they move next, and when they do
they will stop disagreeing with HTML, which is a byte difference and therefore
its own commit.

The rewrite has an oracle because the old implementation still runs. Every
document goes through both, for all three outputs, and the bytes have to match.
No expected output was written by hand.

```sh
sh scripts/parity.sh              # 72 pairs, 0 mismatched
sh scripts/parity.sh <other_dir>  # or point it at any directory of .md
```

Two corpora, and neither replaces the other:

- `test/corpus/` is the Mere documentation as of `ea9f11d` — 18 files, 1.2 MB,
  written by somebody who was not thinking about this parser. A corpus written to
  exercise a converter tests the converter's own idea of what markdown is.
- `test/edge/` is the imagined kind, and it exists because the real documents
  turn out never to contain an unterminated fence, a table with a header and no
  body, or a list that changes from bullets to numbers without a blank line.

**The gate has been shown to fail, twice over.** Three poisons, one per output
(`<strong>` to `<b>`, an extra token in the blockquote path, a wider TOC indent),
were each detected: 18 of 18 documents for HTML, 7 of 18 for text — the ones
containing blockquotes — and 17 of 18 for the TOC. Then, after the rewrite, a
fourth poison flipped one boolean in the new parser, the one that records whether
a fence was closed: it was caught on exactly one file, `fence_unterminated.md`,
with the surplus `</code></pre>` as the whole diff. A five-hundred-line rewrite
that goes green on the first run is a claim about the rewrite until something has
made the comparison say no.

## What the AST is for

Three files answer "what is a heading" three different ways, and the docs site
generator in the Mere repository answers it a fourth:

| | judged by | depths |
|---|---|---|
| `to_html.render_line` | `# ` with a space | 1–3 only |
| `to_text.convert_line` | `#` with no space required | any |
| `toc.heading_depth` | counted `#` then a space, or a line of only `#` | any |
| (mere) `contrib/site`'s own TOC builder | `## ` and `### ` literally | 2–3 only |

Only the first tracks fenced code blocks. The other three read every line.
`test/edge/fence_and_escape.md` is eight lines and shows what that costs:

- `## not a heading` **inside a fence** renders as `<pre>` and appears in the
  table of contents as a heading. One line, two answers.
- `#### four hashes` renders as a **paragraph** and appears in the table of
  contents as a **depth-4 heading**. One line, two answers again.
- `<angle> & ampersand` in a paragraph reaches the HTML unescaped. Escaping is
  applied inside code blocks and nowhere else.

None of these are bugs in three places. They are one missing thing in one place:
there is no parse, so there is nothing for the three outputs to be three views
*of*.

    parse   : str list -> block list      <- exists
    to_html : block list -> str           <- exists
    to_text : block list -> str           <- next
    toc     : block list -> heading list  <- next

`toc` will return headings rather than a rendered list, so that a consumer that
wants slugs and anchors builds them itself instead of becoming a fifth
definition.

The document is deliberately shallow for now. A block holds the *raw source* of
its inline content, because the inline scanner does not recurse — `**a `b` c**`
keeps its backticks literally — so a string is what it honestly holds. Splitting
that into spans is a separate commit because it is a separate risk.

## Deliberate differences come one at a time

The three defects above are real, and fixing them changes bytes — which is
exactly what `parity.sh` is built to notice. So they are not fixed during the
refactor. The AST lands with parity green, and each behaviour change is a
separate commit afterwards that says what moved and why. A diff that contains
both an intended change and a regression is a diff in which neither can be seen.

## A note on CommonMark

Inline emphasis here is a plain scan for `**`, with no flanking rules. Under
CommonMark, `の**「強調」**` is not emphasis — the `**` is literal — and under
this parser it is. The corpus contains Japanese, so conformance is not a free
improvement; it is a change to how existing documents look.

The specification's test suite will be run and reported per section, as a count
of what passes rather than a claim of conformance. Sections that are deliberately
not followed will say so.

## License

MIT.
