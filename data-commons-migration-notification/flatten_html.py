# -*- coding: utf-8 -*-
#
# © 2026, The Arizona Board of Regents on behalf of The University of Arizona.
# For license information, see https://cyverse.org/license.

"""Flatten a rendered notice into the plain-text alternative that travels beside the HTML."""

import re
import textwrap

WIDTH = 78
MARK = "\x01"            # stands in for a <li> while the tags come off: MARK depth label content

_ENTITIES = {
    "&mdash;": "--", "&ndash;": "-", "&ldquo;": '"', "&rdquo;": '"',
    "&lsquo;": "'", "&rsquo;": "'", "&nbsp;": " ", "&amp;": "&",
    "&lt;": "<", "&gt;": ">", "&#39;": "'", "&#34;": '"',
}


def _mark_items(html: str) -> str:
    """Replace every <li> with a marker, numbered inside an <ol> and bulleted inside a <ul>.

    A numbered list in the HTML has to stay numbered in the text alternative: the notices say
    "I need three things" and then list them, so 1/2/3 in one part and dashes in the other would
    read as two different messages. Tracking a stack keeps a <ul> nested in an <ol> bulleted.
    """
    out, stack, pos = [], [], 0

    for m in re.finditer(r"(?i)<(/?)(ol|ul|li)\b[^>]*>", html):
        out.append(html[pos:m.start()])
        pos = m.end()
        closing, tag = m.group(1), m.group(2).lower()

        if tag == "li":
            if closing:
                out.append("\n\n")
            else:
                numbered = bool(stack) and stack[-1][0] == "ol"

                if numbered:
                    stack[-1][1] += 1

                label = f"{stack[-1][1]}." if numbered else "-"
                out.append(f"\n{MARK}{max(len(stack), 1)} {label} ")
        elif closing:
            if stack:
                stack.pop()
            out.append("\n\n")
        else:
            stack.append([tag, 0])
            out.append("\n\n")       # a nested list must not run on from the text introducing it

    return "".join(out) + html[pos:]


def flatten(html: str) -> str:
    """Strip tags, then rewrap each block so paragraphs read as paragraphs, not as source lines."""
    text = re.sub(r"(?is)<(script|style|head)\b.*?</\1>", "", html)
    text = _mark_items(text)
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</(p|tr|h[1-6]|div)>", "\n\n", text)
    text = re.sub(r"(?i)</t[dh]>", "  ", text)
    text = re.sub(r"<[^>]+>", "", text)

    for entity, char in _ENTITIES.items():
        text = text.replace(entity, char)

    blocks = []

    for block in re.split(r"\n{2,}", text):
        block = re.sub(r"[ \t\n]+", " ", block).strip()

        if not block:
            continue

        if block.startswith(MARK):
            depth, label, block = block[1:].split(" ", 2)
            prefix = "  " + "    " * (int(depth) - 1) + label + " "
        else:
            blocks.append(textwrap.fill(block, WIDTH))
            continue

        blocks.append(textwrap.fill(block, WIDTH - len(prefix), initial_indent=prefix,
                                    subsequent_indent=" " * len(prefix)))

    return "\n\n".join(blocks) + "\n"
