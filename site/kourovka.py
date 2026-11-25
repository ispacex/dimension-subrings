# -*- coding: utf-8 -*-
"""
The problems of the Kourovka Notebook, from its LaTeX source, for kourovka.html (MATH-526).

    python3 site/kourovka.py fetch DIR             # the arXiv source of arXiv:1401.0300 (latest version) into DIR
    python3 site/kourovka.py parse TEX OUT.json     # every problem of TEX into OUT.json (site/kourovka-problems.json)
    python3 site/kourovka.py diff OLD.json NEW.json  # what changed between two parses: for the update log
    python3 site/kourovka.py update                 # the weekly step: fetch, parse into site/kourovka-problems.json,
                                                    # log the changes and the day in site/kourovka.json

The Notebook (eds. E. I. Khukhro, V. D. Mazurov) is one file, 21tkt.tex in issue 21; each problem is a
minipage \\bmp ... \\emp whose first words are \\textbf{N.M.}. The marks are the Notebook's own:

    \\textbf{\\zv N.M.}   (*) solved in an update after the last printed issue; the answer follows \\otv
    \\textbf{\\ai N.M.}   (#) an AI system proposed a solution not yet confirmed; the problem counts as open
    \\makebox[25pt][r]{\\zv a)}   the same, for a part of a problem
    after \\label{archiv}  the Archive of Solved Problems: solved, with the answer after the author line

The statement ends with the author line \\hfill \\raisebox{-1ex}{\\sl Name}; what follows is the answer
(\\otv, \\oai lines) and comments. "AI solution confirmed by X" and "unverified AI solution" are read off
the answers and comments, so the AI flags are the editors' words, not ours.

LaTeX is turned into HTML with the math left as $...$ / $$...$$ for KaTeX in the reader's browser; the
Notebook's own macros (\\goth, \\Bbb, \\f, \\Z, ...) are kept and defined for KaTeX in MACROS.
"""
import html
import io
import json
import re
import sys
import tarfile
import unicodedata
import urllib.request

ARXIV = "1401.0300"
DUPLICATES = []

# KaTeX macros for the Notebook's own definitions (preamble of 21tkt.tex) and plain-TeX spellings.
MACROS = {
    "\\goth": "\\mathfrak", "\\frak": "\\mathfrak", "\\Bbb": "\\mathbb", "\\cal": "\\mathscr",
    "\\f": "\\varphi", "\\N": "\\mathbb N", "\\F": "\\mathbb F", "\\Z": "\\mathbb Z", "\\Q": "\\mathbb Q",
    "\\Sy": "\\mathbb S", "\\R": "\\Rightarrow", "\\W": "\\Omega", "\\w": "\\omega", "\\s": "\\sigma",
    "\\Lr": "\\Leftrightarrow", "\\e": "\\varepsilon", "\\g": "\\gamma", "\\G": "\\Gamma", "\\ds": "\\displaystyle",
    "\\hs": "\\,", "\\lb": "", "\\linebreak": "", "\\geq": "\\geqslant", "\\leq": "\\leqslant",
    "\\ge": "\\geqslant", "\\le": "\\leqslant", "\\lefteqn": "", "\\nolinebreak": "", "\\goodbreak": "",
    "\\allowbreak": "", "\\vs": "", "\\hf": "", "\\hfill": "", "\\mb": "", "\\Cal": "\\mathcal",
    "\\mbox": "\\text", "\\sp": "^", "\\sb": "_", "\\break": "", "\\bold": "\\mathbf", "\\germ": "\\mathfrak", "\\rom": "\\mathrm", "\\Bf": "\\mathbf",
}

ACCENT = {"'": "\u0301", "`": "\u0300", '"': "\u0308", "^": "\u0302", "~": "\u0303", "=": "\u0304", ".": "\u0307",
          "u": "\u0306", "v": "\u030c", "H": "\u030b", "c": "\u0327", "k": "\u0328", "r": "\u030a", "d": "\u0323"}
LETTER = {"i": "ı", "j": "ȷ", "l": "ł", "L": "Ł", "o": "ø", "O": "Ø", "ss": "ß", "ae": "æ", "AE": "Æ", "oe": "œ",
          "OE": "Œ", "aa": "å", "AA": "Å", "S": "§", "dag": "†", "P": "¶", "copyright": "©", "ldots": "…", "dots": "…",
          "&": "&amp;", "%": "%", "$": "$", "#": "#", "_": "_", "{": "{", "}": "}", ",": "\u2009", " ": " ", "/": "",
          "-": "", "@": "", "textendash": "–", "textemdash": "—", "quad": "\u2003", "qquad": "\u2003\u2003",
          "ldq": "“", "rdq": "”", "lq": "‘", "rq": "’", "lhd": "⊲", "circ": "∘", "nobreakdash": "", "No": "No.", "TeX": "TeX", "LaTeX": "LaTeX", "S ": "§ ",
          "zv": '<span class="kmark solved" title="solved">*</span>',
          "zva": '<span class="kmark solved" title="solved">*</span>',
          "ai": '<span class="kmark ai" title="unverified AI solution">♯</span>'}
STYLE = {"itshape": "i", "it": "i", "em": "i", "sl": "i", "bf": "b", "tt": "code", "sc": "span", "rm": None, "sf": None, "normalfont": None,
         "small": None, "footnotesize": None, "large": None, "Large": None, "scriptsize": None, "upshape": None}
WRAP = {"textbf": "b", "textit": "i", "emph": "i", "textsl": "i", "texttt": "code", "textsc": "span", "textrm": None,
        "textup": None, "textnormal": None, "mbox": None, "hbox": None, "centerline": None, "smash": None, "text": None, "underline": "u", "uline": "u"}
DROP0 = {"hf", "hfill", "vs", "lb", "linebreak", "newline", "noindent", "par", "smallskip", "medskip", "bigskip",
         "flushbottom", "phantomsection", "ul", "hs", "ds", "vv", "vsh", "sm", "bsl", "bmp", "emp", "rmp", "centering",
         "clearpage", "newpage", "pagebreak", "nopagebreak", "indent", "relax", "protect", "hss", "hfil", "vfill",
         "displaystyle", "nolinebreak", "goodbreak", "allowbreak", "break", "unskip", "null", "kern", "sloppy",
         "raggedright", "leavevmode", "strut", "item", "mb", "thinspace"}
DROP1 = {"label", "pageref", "vspace", "hspace", "index", "enlargethispage", "phantom", "vphantom", "hphantom", "cite"}
DIM = re.compile(r"\s*-?[\d.]+\s*(?:pt|ex|em|cm|mm|in|bp|sp)\b|\s*\\[a-z]+skip\b")


class TeX:
    """A small converter of the Notebook's text-mode LaTeX into HTML; math is passed through for KaTeX."""

    def __init__(self, s):
        self.s, self.i, self.unknown = s, 0, set()

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def skip_ws(self):
        while self.peek() in " \t\n" and self.peek():
            self.i += 1

    def opt(self):
        """[...] after a command."""
        self.skip_ws()
        if self.peek() == "[":
            j = self.s.find("]", self.i)
            out = self.s[self.i + 1:j]
            self.i = j + 1
            return out
        return None

    def raw_group(self):
        """{...} as raw text (brace-matched), or one token."""
        self.skip_ws()
        if self.peek() != "{":
            if self.peek() == "\\":
                m = re.match(r"\\([A-Za-z]+|.|$)", self.s[self.i:], re.S)
                self.i += max(m.end(), 1)
                return m.group(0)
            c = self.peek()
            self.i += 1
            return c
        depth, j = 0, self.i
        while j < len(self.s):
            c = self.s[j]
            if c == "\\":
                j += 2
                continue
            depth += c == "{"
            depth -= c == "}"
            if depth == 0:
                break
            j += 1
        out = self.s[self.i + 1:j]
        self.i = j + 1
        return out

    def group(self):
        return TeX.sub(self, self.raw_group())

    @staticmethod
    def sub(parent, s):
        t = TeX(s)
        out = t.run()
        parent.unknown |= t.unknown
        return out

    def math(self, close, display):
        """Up to `close` outside braces: $H\\mbox{ $x$ }$ is one formula."""
        j, depth = self.i, 0
        while j < len(self.s):
            c = self.s[j]
            if c == "\\" and not self.s.startswith(close, j):
                j += 2
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            elif depth <= 0 and self.s.startswith(close, j):
                break
            j += 1
        body = self.s[self.i:j]
        self.i = j + len(close)
        body = body.replace("\\linebreak", " ").replace("\\lb", " ").replace("\\newline", " ")
        body = re.sub(r"\\makebox\[[^\]]*\](\[[^\]]*\])?", r"\\mbox", body)
        body = re.sub(r"\\vspace\*?\{[^}]*\}|\\[vh]skip\s*-?[\d.]+\s*(pt|ex|em|cm|mm)", " ", body)
        body = re.sub(r"\{\\sc\s+([^{}]*)\}", r"\\mathrm{\1}", body)
        body = re.sub(r"\\parbox(\[[^\]]*\])?\{[^}]*\}", r"\\text", body)
        body = re.sub(r"\\root\s*(\S+)\s*\\of", r"\\sqrt[\1]", body)
        body = re.sub(r"\\,\s*_", "{}_", body)
        body = body.replace("<", "\\lt ").replace(">", "\\gt ").replace("&", "&amp;")
        return f"$${body}$$" if display else f"${body}$"

    def run(self):
        out = []
        while self.i < len(self.s):
            c = self.s[self.i]
            if c == "%":
                j = self.s.find("\n", self.i)
                self.i = len(self.s) if j < 0 else j + 1
            elif c == "$":
                if self.peek(1) == "$":
                    self.i += 2
                    out.append(self.math("$$", True))
                else:
                    self.i += 1
                    out.append(self.math("$", False))
            elif c == "{":
                inner = self.raw_group()
                m = re.match(r"\s*\\(itshape|it|em|sl|bf|tt|sc|rm|sf|normalfont|small|footnotesize|large|Large|scriptsize|upshape)(?![A-Za-z])\s*", inner)
                if m:
                    tag = STYLE[m.group(1)]
                    body = TeX.sub(self, inner[m.end():])
                    out.append(f"<{tag}>{body}</{tag}>" if tag else body)
                else:
                    out.append(TeX.sub(self, inner))
            elif c == "}":
                self.i += 1
            elif c == "~":
                self.i += 1
                out.append("\u00a0")
            elif c == "-" and self.s.startswith("---", self.i):
                self.i += 3
                out.append("—")
            elif c == "-" and self.s.startswith("--", self.i):
                self.i += 2
                out.append("–")
            elif c == "`" and self.s.startswith("``", self.i):
                self.i += 2
                out.append("“")
            elif c == "'" and self.s.startswith("''", self.i):
                self.i += 2
                out.append("”")
            elif c == "<":
                self.i += 1
                out.append("&lt;")
            elif c == ">":
                self.i += 1
                out.append("&gt;")
            elif c == "&":
                self.i += 1
                out.append(" ")
            elif c == "\n" and re.match(r"\n[ \t]*\n", self.s[self.i:]):
                m = re.match(r"(\n[ \t]*)+", self.s[self.i:])
                self.i += m.end()
                out.append("\n\n")
            elif c == "\\":
                out.append(self.command())
            else:
                self.i += 1
                out.append(c)
        return "".join(out)

    def command(self):
        m = re.match(r"\\([A-Za-z]+|.|$)", self.s[self.i:], re.S)
        name = m.group(1)
        if not name:
            self.i += 1
            return ""
        self.i += m.end()
        if name == "verb" and self.peek():
            d = self.peek()
            j = self.s.find(d, self.i + 1)
            j = len(self.s) if j < 0 else j
            body = self.s[self.i + 1:j]
            self.i = j + 1
            return "<code>%s</code>" % html.escape(body, quote=False)
        if name == "otv":
            return '<span class="kmark solved" title="solved">*</span> '
        if name == "oai":
            return '<span class="kmark ai" title="unverified AI solution">♯</span> '
        if name in ("[",):
            return self.math("\\]", True)
        if name == "(":
            return self.math("\\)", False)
        if name == "\\":
            self.opt()
            return "<br>"
        if name in ACCENT and not (name.isalpha() and len(name) > 1):
            arg = self.raw_group()
            arg = {"\\i": "i", "\\j": "j"}.get(arg.strip(), arg.strip())
            return unicodedata.normalize("NFC", (arg[:1] + ACCENT[name] + arg[1:]) if arg else "")
        if name == "begin":
            env = self.raw_group()
            if env in ("equation", "equation*", "eqnarray", "eqnarray*", "align", "align*", "gather", "gather*",
                       "multline", "multline*", "displaymath"):
                end = f"\\end{{{env}}}"
                j = self.s.find(end, self.i)
                body = self.s[self.i:j]
                self.i = j + len(end)
                body = body.replace("<", "\\lt ").replace(">", "\\gt ").replace("&", "&amp;")
                kind = "aligned" if env.startswith(("eqnarray", "align")) else ("gathered" if env.startswith(("gather", "multline")) else None)
                body = re.sub(r"\\(nonumber|notag|label\{[^}]*\})", "", body)
                return f"$$\\begin{{{kind}}}{body}\\end{{{kind}}}$$" if kind else f"$${body}$$"
            if env in ("itemize", "enumerate", "description"):
                end = f"\\end{{{env}}}"
                depth, j = 1, self.i
                while depth:
                    a, b = self.s.find(f"\\begin{{{env}}}", j), self.s.find(end, j)
                    if 0 <= a < b:
                        depth, j = depth + 1, a + 1
                    else:
                        depth, j = depth - 1, b + 1
                body = self.s[self.i:j - 1]
                self.i = j - 1 + len(end)
                tag = "ol" if env == "enumerate" else "ul"
                items = re.split(r"\\item(?![A-Za-z])", body)[1:]
                lis = []
                for it in items:
                    lab = re.match(r"\s*\[([^\]]*)\]", it)
                    if lab:
                        it = it[lab.end():]
                    lis.append("<li>" + (TeX.sub(self, lab.group(1)) + " " if lab else "") + TeX.sub(self, it).strip() + "</li>")
                return f"<{tag}>{''.join(lis)}</{tag}>"
            if env in ("array", "tabular"):
                self.raw_group()
            return ""
        if name == "end":
            self.raw_group()
            return ""
        if name in WRAP:
            body = self.group()
            tag = WRAP[name]
            return f"<{tag}>{body}</{tag}>" if tag else body
        if name in ("url", "href"):
            u = re.sub(r"\s+", "", self.raw_group())
            text = self.group() if name == "href" else html.escape(u, quote=False)
            if not re.match(r"https?://", u):
                return text
            return f'<a href="{html.escape(u)}">{text}</a>'
        if name in ("makebox", "framebox"):
            self.opt()
            self.opt()
            return self.group()
        if name == "raisebox":
            self.raw_group()
            self.opt()
            self.opt()
            return self.group()
        if name in ("footnote",):
            return " (" + self.group() + ")"
        if name in ("vskip", "hskip", "kern", "vspace*", "hspace*"):
            m = DIM.match(self.s[self.i:])
            if m:
                self.i += m.end()
            return " "
        if name in DROP1:
            self.raw_group()
            return ""
        if name in DROP0:
            if name in ("item",):
                return "• "
            return ""
        if name in LETTER:
            if name.isalpha() and self.peek() == " ":
                self.i += 1
            return LETTER[name]
        if name in STYLE:  # a switch outside a group: up to the end of the current group, i.e. ignored
            return ""
        if name.isalpha():
            self.unknown.add(name)
            if self.peek() == " ":
                self.i += 1
            return ""
        return name


def html_of(tex):
    # a line opening with \makebox[..pt][r]{...} is a new paragraph: the part "a)", "b)" of a problem, or an indent
    tex = re.sub(r"(?:^|\n)[ \t]*(?=\\makebox\[\d+pt\]\[r\]\{)", "\n\n", tex)
    tex = re.sub(r"\\(?:otv|oai)(?![A-Za-z])", lambda m: "\n\n" + m.group(0), tex)
    t = TeX(tex)
    out = t.run()
    out = re.sub(r"\n[ \t\u00a0]*(?=\n)", "\n", out)
    out = re.sub(r"(?<!\n)\n(?!\n)", " ", out)
    paras = [re.sub(r"[ \t]{2,}", " ", p).strip() for p in out.split("\n\n")]
    paras = [p for p in paras if p]
    return "".join(f"<p>{p}</p>" for p in paras), t.unknown


def plain_of(h):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", h)).strip()


AUTHOR = re.compile(r"\\(?:hf|hfill)(?:\s|\\vs|\{\})*\\?(?:raisebox\{[^}]*\}\s*)?\s*\{\s*\{?\s*\\sl\s*((?:[^{}]|\{[^{}]*\})*)\}\s*\}?"
                    r"|\\hf\s*\\raisebox\{-?1ex\}\s*\{\\sl\s*((?:[^{}]|\{[^{}]*\})*)\}")


def split_author(body):
    """(statement, authors, rest): the author line is the last \\sl group on a \\hfill before \\ul / \\otv / the end."""
    stop = re.search(r"\\ul\b|\\otv\b|\\oai\b", body)
    head = body[:stop.start()] if stop else body
    last = None
    for m in re.finditer(r"\{\s*\\sl\s+", head):
        last = m
    if not last:
        return head, "", body[len(head):]
    t = TeX(body)
    t.i = last.start()
    raw = t.raw_group()
    authors = plain_of(html_of(re.sub(r"^\s*\\sl\s*", "", raw))[0])
    before = body[:last.start()]
    before = re.sub(r"(\\hfill|\\hf)\s*(\\raisebox\{[^}]*\}\s*)?\{?\s*$", "", before.rstrip())
    before = re.sub(r"\\raisebox\{[^}]*\}\s*\{?\s*$", "", before.rstrip())
    before = re.sub(r"(\\hfill|\\hf)\s*$", "", before.rstrip())
    return before, authors, body[t.i:]


def flags(text):
    """AI flags of an answer or comment, in the editors' words."""
    low = text.lower()
    f = []
    if re.search(r"ai(?: |-)(?:solutions?|proofs?) (confirmed|verified)|ai(?: |-)solutions? by|ai-proof confirmed", low):
        f.append("ai_confirmed")
    if "unverified ai solution" in low:
        f.append("ai_cited")  # an unverified AI solution is cited; the Notebook's own mark is \ai (parse())
    return f


def parse(tex):
    arch = tex.find("\\label{archiv}")
    probs, unknown = [], set()
    blocks = []
    for m in re.finditer(r"\\bmp(?![A-Za-z])(.*?)(?:\\emp|\\rmp)(?![A-Za-z])", tex, re.S):
        # one minipage may hold two problems sharing an answer (11.54 and 11.55): split at an inner
        # heading; a piece with no answer of its own gets the next piece's
        pieces = re.split(r"\n\s*(?=(?:\\textbf\{|\{\\bf)\s*(?:\\zva?|\\ai)?\s*\d+\.\d+\.?\s*\})", m.group(1))
        pieces = [x for x in pieces if x.strip()]
        for k, piece in enumerate(pieces):
            blocks.append((m.start(), piece, k + 1 < len(pieces)))
    pending = []  # pieces of one minipage waiting for the answer a later piece carries
    for start, body, more in blocks:
        h = (re.match(r"\s*\\textbf\{\s*(\\zv|\\zva|\\ai|\\oai)?\s*(\d+\.\d+)\.?\s*\}", body)
             or re.match(r"\s*\{\\bf\s*(\\zv|\\zva|\\ai|\\oai)?\s*(\d+\.\d+)\.?\s*\}", body))
        if not h:
            continue
        num, mark = h.group(2), (h.group(1) or "").strip("\\")
        rest = body[h.end():]
        archive = arch >= 0 and start > arch
        stmt, authors, after = split_author(rest)
        st_html, u1 = html_of(stmt)
        an_html, u2 = html_of(after)
        unknown |= u1 | u2
        parts_solved = len(re.findall(r"\\zva?(?![A-Za-z])", stmt))  # "\makebox[25pt][r]{\zv a)}" or "\zva a)" (19.10)
        parts_ai = len(re.findall(r"\\ai(?![A-Za-z])", stmt))
        if archive:
            status = "solved"
        elif mark in ("zv", "zva"):
            status = "solved"
        elif parts_solved:
            status = "partial"
        else:
            status = "open"
        fl = sorted(set(flags(after) + flags(stmt)))
        if mark in ("ai", "oai") or parts_ai:
            fl = sorted((set(fl) - {"ai_cited"}) | {"ai_unverified"})
        probs.append({"n": num, "ed": int(num.split(".")[0]), "archive": archive, "status": status,
                      "mark": {"zv": "*", "zva": "*", "ai": "♯", "oai": "♯"}.get(mark, ""),
                      "ai": fl, "authors": authors,
                      "statement": st_html, "answer": an_html})
        if not an_html and more:
            pending.append(probs[-1])
        elif an_html and pending:
            for q in pending:  # the answer below both: shared
                q["answer"] = an_html
                q["status"] = status if q["status"] == "open" else q["status"]
            pending = []
        if not more:
            pending = []
    seen, out = {}, []
    for p in probs:  # a number twice: the main part first, then the Archive; keep the first and report
        if p["n"] in seen:
            q = seen[p["n"]]
            if p["archive"] and not q["archive"]:  # solved parts in the Archive, the rest still in the main part
                q["archived_parts"] = {"statement": p["statement"], "answer": p["answer"]}
                if q["status"] == "open":
                    q["status"] = "partial"
            else:
                DUPLICATES.append(p["n"])
            continue
        seen[p["n"]] = p
        out.append(p)
    out.sort(key=lambda p: tuple(int(x) for x in p["n"].split(".")))
    return out, unknown


def read_tex(path):
    """The source is UTF-8 with a few lines in CP1251 (Russian names in comments): decoded line by line."""
    out = []
    for line in path.read_bytes().split(b"\n"):
        try:
            out.append(line.decode("utf-8"))
        except UnicodeDecodeError:
            out.append(line.decode("cp1251", errors="replace"))
    return "\n".join(out).replace("\r", "")


def fetch(dirpath):
    import pathlib
    d = pathlib.Path(dirpath)
    d.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(f"https://arxiv.org/e-print/{ARXIV}", headers={"User-Agent": "kourovka-tracker/1.0"})
    data = urllib.request.urlopen(req, timeout=120).read()
    meta = urllib.request.urlopen(urllib.request.Request(f"https://export.arxiv.org/abs/{ARXIV}",
                                                         headers={"User-Agent": "kourovka-tracker/1.0"}), timeout=60).read().decode()
    vers = re.findall(r"\[v(\d+)\]", meta)
    version = f"v{max(map(int, vers))}" if vers else "?"
    with tarfile.open(fileobj=io.BytesIO(data)) as tf:
        names = [m for m in tf.getmembers() if m.name.endswith(".tex") and m.isfile() and "/" not in m.name.strip("./")]
        for mem in names:
            (d / mem.name).write_bytes(tf.extractfile(mem).read())
    tex = max(names, key=lambda m: m.size).name
    (d / "version").write_text(version)
    print(d / tex, version)


def diff(old, new):
    o = {p["n"]: p for p in old["problems"]}
    lines = []
    for p in new["problems"]:
        q = o.get(p["n"])
        if not q:
            lines.append(f"{p['n']}: new problem")
            continue
        if q["status"] != p["status"]:
            lines.append(f"{p['n']}: {q['status']} -> {p['status']}")
        if q["ai"] != p["ai"]:
            lines.append(f"{p['n']}: AI {','.join(q['ai']) or '-'} -> {','.join(p['ai']) or '-'}")
    for n in o.keys() - {p["n"] for p in new["problems"]}:
        lines.append(f"{n}: gone")
    return lines


def update():
    """fetch + parse + diff; the new parse replaces site/kourovka-problems.json, and kourovka.json gets
    the day of the check and, if anything changed, a log line naming the problems (the notes are by hand)."""
    import datetime
    import pathlib
    import tempfile
    here = pathlib.Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory() as tmp:
        fetch(tmp)
        tex = max(pathlib.Path(tmp).glob("*.tex"), key=lambda f: f.stat().st_size)
        ver = (pathlib.Path(tmp) / "version").read_text().strip()
        probs, unknown = parse(read_tex(tex))
    new = {"source": f"arXiv:{ARXIV}{ver}", "file": tex.name, "macros": MACROS, "problems": probs}
    path = here / "kourovka-problems.json"
    old = json.loads(path.read_text(encoding="utf-8"))
    changes = diff(old, new)
    if old["source"] != new["source"]:
        changes.insert(0, f"source {old['source']} -> {new['source']}")
    path.write_text(json.dumps(new, ensure_ascii=False, indent=0, separators=(",", ":")) + "\n", encoding="utf-8")
    notes = here / "kourovka.json"
    d = json.loads(notes.read_text(encoding="utf-8"))
    today = datetime.date.today().isoformat()
    d["checked"] = today
    if changes:
        short = "; ".join(changes[:40]) + (f"; … ({len(changes)} in all)" if len(changes) > 40 else "")
        d["log"].append({"date": today, "ru": f"Тетрадь: {short}.", "en": f"Notebook: {short}."})
    notes.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(new["source"], len(probs), "problems;", len(changes), "changes")
    print("\n".join(changes) or "no changes in the Notebook")
    if unknown:
        print("unknown commands (dropped):", " ".join(sorted(unknown)))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "fetch":
        fetch(sys.argv[2])
    elif cmd == "parse":
        import pathlib
        tex = pathlib.Path(sys.argv[2])
        probs, unknown = parse(read_tex(tex))
        ver = (tex.parent / "version").read_text().strip() if (tex.parent / "version").exists() else "?"
        doc = {"source": f"arXiv:{ARXIV}{ver}", "file": tex.name, "macros": MACROS, "problems": probs}
        pathlib.Path(sys.argv[3]).write_text(json.dumps(doc, ensure_ascii=False, indent=0, separators=(",", ":")) + "\n",
                                             encoding="utf-8")
        st = {}
        for p in probs:
            st[p["status"]] = st.get(p["status"], 0) + 1
        ai = {}
        for p in probs:
            for f in p["ai"]:
                ai[f] = ai.get(f, 0) + 1
        print(len(probs), "problems", st, "AI", ai)
        if DUPLICATES:
            print("numbers twice (first kept):", " ".join(DUPLICATES))
        if unknown:
            print("unknown commands (dropped):", " ".join(sorted(unknown)))
    elif cmd == "diff":
        a, b = (json.load(open(x, encoding="utf-8")) for x in sys.argv[2:4])
        print("\n".join(diff(a, b)) or "no changes")
    elif cmd == "update":
        update()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
