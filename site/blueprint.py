# -*- coding: utf-8 -*-
"""
The blueprint of the paper (MATH-324): which statement of paper/d5.tex is in Lean, by which
declarations, and what it uses. The data are site/blueprint.toml (the one place where a status is
written down); this module reads them, checks them against the paper and the Lean package, and writes

  * a leanblueprint source tree (content.tex, web.tex, macros, plastex.cfg) for `plastex`, whose web
    pages (statements, dependency graph) go to blueprint/ of the site;
  * a Lean file that #checks every declaration named, for CI (.github/workflows/blueprint.yml);

and build_site.py builds results.html and blueprint.html from the same data.

    python3 site/blueprint.py check [--paper PAPER_DIR]        the checks below; without the paper only
                                                             those that do not need it
    python3 site/blueprint.py lean OUT.lean                    the #check file (run in groups/)
    python3 site/blueprint.py tags LOG                         compare the output of `#d5_tags`
                                                             (groups/D5Tags.lean) with the nodes
    python3 site/blueprint.py src [--paper PAPER_DIR] OUT_DIR  the leanblueprint source; without the
                                                             paper the statements are placeholders (CI)

Checks: every labelled statement of the paper has a node and every node a statement; a node with Lean
declarations is one the paper says is formally verified (in the statement, its proof or the section on
the formalization), and a statement the paper calls formally verified has declarations; a
"Computer-assisted" statement is marked computer; every declaration is found in groups/ (by its
namespace and name; that Lean knows it is the CI check), and every declaration of a paper statement is
named in the section on the formalization; a row of results.html marked Lean cites only statements
whose proof is in Lean, and every {{lean:...}} of a row is a declaration of some node. `tags`: the
declarations tagged @[d5 "label"] (or a tag @[d5 XXXX]) in groups/ (GroupDimension/D5Tag.lean, MATH-453) are exactly those of
the nodes, label by label; this file stays the source of truth and the attribute is checked against it.
"""
import json
import pathlib
import re
import sys
import tomllib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = HERE / "blueprint.toml"
GROUPS = ROOT / "groups"
GROUPS_REPO = "https://github.com/ispacex/group-dimension"
SITE = "https://ispacex.github.io/d5/"
ENVS = ("theorem", "proposition", "lemma", "corollary", "question", "remark")
NAMES = {"theorem": "Theorem", "proposition": "Proposition", "lemma": "Lemma", "corollary": "Corollary", "question": "Question",
         "remark": "Remark"}
LEAN_REF = re.compile(r"\{\{lean:([^|}]+)\|([^}]*)\}\}")
NOTE_REF = re.compile(r"\[\[([A-Za-z0-9:._-]+)\|#\]\]")  # a number of the paper in a note


def load():
    data = tomllib.loads(DATA.read_text())
    for label, n in data["nodes"].items():
        n.setdefault("lean", [])
        n.setdefault("proved", False)
        n.setdefault("computer", False)
        n.setdefault("uses", [])
        n.setdefault("uses_drop", [])
        n.setdefault("note", "")
        n.setdefault("note_ru", "")
        n.setdefault("not_in_paper", [])
        unknown = set(n) - {"lean", "proved", "computer", "uses", "uses_drop", "note", "note_ru", "title", "title_ru", "statement",
                                "not_in_paper"}
        if unknown:
            sys.exit(f"blueprint.toml: node {label}: unknown fields {sorted(unknown)}")
        if n["proved"] and not n["lean"]:
            sys.exit(f"blueprint.toml: node {label} is proved but names no Lean declaration")
    return data


# ---------------------------------------------------------------------------------------------
# The Lean package

def lean_index(groups=GROUPS):
    """Full name -> (file relative to groups/, line) of every declaration of the package (not PolyData),
    by `namespace`/`end` and the declaration keyword. A sketch of what Lean knows: CI checks the names
    with Lean itself."""
    decl = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)?(?:public\s+|private\s+|noncomputable\s+|protected\s+|nonrec\s+)*"
                      r"(?:theorem|lemma|def|abbrev|instance|structure|class|inductive)\s+([^\s:({\[]+)")
    index = {}
    for f in sorted(groups.rglob("*.lean")):
        rel = f.relative_to(groups).as_posix()
        if rel.startswith((".lake/", "PolyData")):
            continue
        ns = []
        for i, ln in enumerate(f.read_text().splitlines(), 1):
            m = re.match(r"^\s*namespace\s+(\S+)", ln)
            if m:
                ns.append(m.group(1))
                continue
            m = re.match(r"^\s*end\s+(\S+)\s*$", ln)
            if m and ns and ns[-1] == m.group(1):
                ns.pop()
                continue
            m = decl.match(ln)
            if m:
                name = m.group(1)
                full = name[len("_root_."):] if name.startswith("_root_.") else ".".join(ns + [name])
                index.setdefault(full, (rel, i))
    return index


def module_of(rel):
    """GroupDimension/Cert1024/Prop1024.lean -> GroupDimension.Cert1024.Prop1024"""
    return rel[:-len(".lean")].replace("/", ".")


def lean_file(data, index):
    """A Lean file that imports the modules of the declarations and #checks each: it fails to elaborate
    if one is missing."""
    names = sorted({x for n in data["nodes"].values() for x in n["lean"]})
    missing = [x for x in names if x not in index]
    if missing:
        sys.exit(f"blueprint.toml: not found in groups/: {', '.join(missing)}")
    mods = sorted({module_of(index[x][0]) for x in names})
    return ("module\n\n" + "".join(f"public import {m}\n" for m in mods)
            + "\n/-! Generated by site/blueprint.py: every Lean declaration named in site/blueprint.toml. -/\n\n"
            + "".join(f"#check @{x}\n" for x in names))


def tag_pairs(data):
    """The (key, declaration) pairs of the blueprint: one per declaration of a node's `lean`, the key
    being the node's label."""
    return {(label, x) for label, n in data["nodes"].items() for x in n["lean"]}


def tag_entries(log):
    """The (key, declaration) pairs printed by `#d5_tags` (groups/D5Tags.lean): one JSON object
    {"comment", "decl", "key"} per line; the first line of the message carries Lean's prefix."""
    got = set()
    for ln in log.splitlines():
        i = ln.find('{"')
        if i >= 0 and '"key":' in ln:
            e = json.loads(ln[i:])
            got.add((e["key"], e["decl"]))
    return got


def tags(data, log):
    """The attribute @[d5 ...] of groups/ (GroupDimension/D5Tag.lean; MATH-453, MATH-458) against
    blueprint.toml, which stays the source of truth: the (key, declaration) pairs printed by
    `#d5_tags` must be exactly those of the nodes. Keys are the labels of the nodes; a permanent tag
    D5:XXXX (wiki 912) is not registered in blueprint.toml yet (MATH-457), so one in the code is a
    difference too. A list of differences, empty if they agree."""
    got = tag_entries(log)
    want = tag_pairs(data)
    errors = []
    if ": error" in log:
        errors.append("Lean reported an error (see the log)")
    if not got:
        errors.append("no @[d5] entries in the log")
    for key, x in sorted(want - got):
        errors.append(f"{x}: in node {key} of blueprint.toml, but not tagged @[d5 \"{key}\"]")
    for key, x in sorted(got - want):
        if key.startswith("D5:"):
            errors.append(f"{x}: tagged {key}, a tag that no node of blueprint.toml has (tags: MATH-457)")
        else:
            errors.append(f"{x}: tagged @[d5 \"{key}\"], but not in the lean field of node {key}")
    return errors


# ---------------------------------------------------------------------------------------------
# The paper

def end_of_env(tex, env, i):
    """Index just after the \\end{env} closing the environment whose body starts at i."""
    depth = 1
    for m in re.compile(r"\\(begin|end)\{" + env + r"\}").finditer(tex, i):
        depth += 1 if m.group(1) == "begin" else -1
        if depth == 0:
            return m.start(), m.end()
    sys.exit(f"paper: \\begin{{{env}}} at {i} is not closed")


def optional(tex, j):
    """The optional argument [..] at j (brackets inside braces allowed) and the index after it."""
    if j >= len(tex) or tex[j] != "[":
        return "", j
    depth, k = 0, j
    while True:
        c = tex[k]
        depth += c in "{["
        depth -= c in "}]"
        if depth == 0:
            return tex[j + 1:k], k + 1
        k += 1


def statements(tex):
    """label -> {env, number, title, body, proof, section} for every labelled statement of the paper,
    in order; also the sections: label -> number. Numbers as amsart counts them: theorem-like
    environments share one counter within the section; after \\appendix the sections are A, B, ...
    (build_site.py compares them with the .aux)."""
    body = tex[tex.index("\\begin{document}"):]
    tok = re.compile(r"\\section(\*?)\{|\\appendix\b|\\begin\{(" + "|".join(ENVS) + r")\}")
    out, sections, sec, k, appendix, pos = {}, {}, 0, 0, False, 0
    for m in tok.finditer(body):
        if m.start() < pos:
            continue
        if m.group(0).startswith("\\appendix"):
            appendix, sec = True, 0
            continue
        if m.group(0).startswith("\\section"):
            if m.group(1):
                continue
            sec, k = sec + 1, 0
            title_end = end_of_brace(body, m.end() - 1)
            lab = re.match(r"\s*\\label\{([^{}]*)\}", body[title_end:])
            number = chr(ord("A") + sec - 1) if appendix else str(sec)
            if lab:
                sections[lab.group(1)] = {"number": number, "title": body[m.end():title_end - 1]}
            continue
        env = m.group(2)
        k += 1
        number = f"{chr(ord('A') + sec - 1) if appendix else sec}.{k}"
        title, j = optional(body, m.end())
        end, after = end_of_env(body, env, j)
        text = body[j:end]
        lab = re.search(r"\\label\{([^{}]*)\}", text)
        pos = after
        # the proof: the first proof environment before the next statement or section
        nxt = tok.search(body, after)
        pm = re.compile(r"\\begin\{proof\}").search(body, after, nxt.start() if nxt else len(body))
        proof = ""
        if pm:
            _, j2 = optional(body, pm.end())
            pend, _ = end_of_env(body, "proof", j2)
            proof = body[j2:pend]
        if lab:
            out[lab.group(1)] = {"env": env, "number": number, "title": title,
                                 "body": text.replace(lab.group(0), "").strip(), "proof": proof,
                                 "section": list(sections)[-1] if sections else None}
    return out, sections


def end_of_brace(s, i):
    """s[i] == '{': the index after its matching '}'."""
    depth = 0
    for k in range(i, len(s)):
        depth += s[k] == "{"
        depth -= s[k] == "}"
        if depth == 0:
            return k + 1
    sys.exit("paper: unbalanced braces")


def lean_section(tex):
    a = tex.index("\\label{sec:lean}")
    b = tex.index("\\section", a)
    return tex[a:b]


def mentioned(sec_text):
    """The names in \\texttt of the section on the formalization."""
    return {s.replace("\\_", "_").replace("\\allowbreak", "").replace(" ", "")
            for s in re.findall(r"\\texttt\{([^{}]*)\}", sec_text)}


VERIFIED = re.compile(r"formally verified|formalized|formalised")


# ---------------------------------------------------------------------------------------------
# Status, uses

def uses_of(label, node, stmts, nodes):
    """What the proof uses: the statements its proof in the paper refers to, and the node's own."""
    refs = re.findall(r"\\ref\{([^{}]*)\}", stmts[label]["proof"]) if label in stmts else []
    out = []
    for x in refs + node["uses"]:
        if x in nodes and x != label and x not in node["uses_drop"] and x not in out:
            out.append(x)
    return out


def statuses(data, stmts):
    """label -> one of "lean" (the proof is in Lean, and so are those of everything it uses, all the way
    down), "lean-given" (the proof is in Lean, from statements that are not all: their labels in
    `given`: the statements below it, through those proved in Lean, whose proof is not), "lean-statement"
    (the statement, or a part, is in Lean, not the proof), "computer",
    "paper"; with the uses."""
    nodes = data["nodes"]
    uses = {x: uses_of(x, n, stmts, nodes) for x, n in nodes.items()}
    memo = {}

    def full(x, seen=()):
        if x in memo:
            return memo[x]
        if x in seen:
            sys.exit(f"blueprint: a cycle of uses through {x}")
        n = nodes[x]
        memo[x] = n["proved"] and all(full(y, seen + (x,)) for y in uses[x])
        return memo[x]

    def leaves(x, seen):
        """The statements below x, through proved ones, whose proof is not in Lean."""
        out = []
        for y in uses[x]:
            if y in seen:
                continue
            seen.add(y)
            out += leaves(y, seen) if nodes[y]["proved"] else [y]
        return out

    out = {}
    for x, n in nodes.items():
        if n["proved"]:
            given = leaves(x, set())
            out[x] = {"status": "lean" if full(x) else "lean-given", "given": given}
        elif n["lean"]:
            out[x] = {"status": "lean-statement", "given": []}
        else:
            out[x] = {"status": "computer" if n["computer"] else "paper", "given": []}
        out[x]["uses"] = uses[x]
    return out


# ---------------------------------------------------------------------------------------------
# Checks

def check(data, index, tex=None):
    nodes = data["nodes"]
    errors = []
    for x, n in nodes.items():
        for y in n["uses"] + n["uses_drop"]:
            if y not in nodes:
                errors.append(f"node {x}: uses {y}, which is not a node")
        for name in n["lean"]:
            if name not in index:
                errors.append(f"node {x}: {name} is not a declaration of groups/")
        if x.startswith("ext:") and not (n.get("statement") and n.get("title") and n.get("title_ru")):
            errors.append(f"node {x}: a result of the literature needs its statement, title and title_ru")
        if "[[" in NOTE_REF.sub("", n["note"] + n["note_ru"]):
            errors.append(f"node {x}: a note refers to the paper otherwise than as [[label|#]]")
        if bool(n["note"]) != bool(n["note_ru"]):
            errors.append(f"node {x}: note and note_ru go together")
    names = {y for n in nodes.values() for y in n["lean"]}
    for k, row in enumerate(data["results"], 1):
        text = " ".join(row.get(f, "") for f in ("ru", "en", "where", "where_ru", "where_en"))
        for name, _ in LEAN_REF.findall(text):
            if name not in names:
                errors.append(f"results row {k}: {{{{lean:{name}}}}} is not a declaration of any node")
        if "l" in row["status"]:
            where = " ".join(row.get(f, "") for f in ("where", "where_ru", "where_en"))
            for lab in re.findall(r"\[\[([A-Za-z0-9:._-]+)", where):
                if lab.split(":")[0] in ("sec", "app", "section", "oq"):
                    continue
                if lab not in nodes or not nodes[lab]["proved"]:
                    errors.append(f"results row {k} is marked Lean but cites [[{lab}]], whose proof is not in Lean")
        if row["status"] not in ("l", "p", "c", "cp", "o"):
            errors.append(f"results row {k}: unknown status {row['status']!r}")
    if tex is not None:
        stmts, sections = statements(tex)
        sec = lean_section(tex)
        said = mentioned(sec)
        for x, n in nodes.items():
            for lab in NOTE_REF.findall(n["note"] + n["note_ru"]):
                if lab not in stmts and lab not in sections:
                    errors.append(f"node {x}: the note refers to [[{lab}|#]], which is not a label of the paper")
        for x in stmts:
            if x not in nodes:
                errors.append(f"the paper's {x} has no node in blueprint.toml")
        for x, n in nodes.items():
            if x.startswith("ext:"):
                if x in stmts:
                    errors.append(f"node {x}: an ext: label is a statement of the paper")
                continue
            if x not in stmts:
                errors.append(f"node {x} is not a labelled statement of the paper")
                continue
            s = stmts[x]
            verified = bool(VERIFIED.search(s["body"] + s["proof"])) or f"\\ref{{{x}}}" in sec
            if n["lean"] and not verified:
                errors.append(f"node {x} names Lean declarations, but the paper does not say it is formally verified")
            if VERIFIED.search(s["body"] + s["proof"][:800]) and not n["lean"]:
                errors.append(f"the paper says {x} is formally verified, but its node names no Lean declaration")
            if "Computer-assisted" in s["title"] and not n["computer"]:
                errors.append(f"{x} is Computer-assisted in the paper, but its node is not marked computer")
        # each declaration of a node is named in an \\item of the section on the formalization that
        # refers to the node's statement
        items = re.split(r"\\item\b", sec)[1:]
        for x, n in nodes.items():
            if x.startswith("ext:") or x not in stmts:
                continue
            here = set().union(*([mentioned(it) for it in items if f"\\ref{{{x}}}" in it] or [set()]))
            for name in n["lean"]:
                if name.split(".")[-1] not in here and name not in n["not_in_paper"]:
                    errors.append(f"node {x}: {name} is not named where the paper's section on the formalization "
                                  f"speaks of {x}")
        # and every declaration that section names belongs to a node (or is listed as not one)
        shorts = {y.split(".")[-1] for y in names}
        decls = {y.split(".")[-1] for y in index}
        for nm in sorted(said):
            short = nm.split(".")[-1]
            if short in decls and short not in shorts and nm not in data.get("section4_not_nodes", []):
                errors.append(f"the paper's section on the formalization names {nm}, which is in no node "
                              "(add it to one, or to section4_not_nodes)")
        # a row of results.html marked Lean cites only statements in Lean with everything below them
        st = statuses(data, stmts)
        for k, row in enumerate(data["results"], 1):
            if "l" not in row["status"]:
                continue
            where = " ".join(row.get(f, "") for f in ("where", "where_ru", "where_en"))
            for lab in re.findall(r"\[\[([A-Za-z0-9:._-]+)", where):
                if lab in nodes and st[lab]["status"] != "lean":
                    errors.append(f"results row {k} is marked Lean but cites [[{lab}]], which is {st[lab]['status']}")
    if errors:
        sys.exit("blueprint check failed:\n  " + "\n  ".join(errors))


# ---------------------------------------------------------------------------------------------
# The leanblueprint source

PLASTEX_CFG = """[general]
renderer=HTML5
copy-theme-extras=yes
plugins=plastexdepgraph plastexshowmore leanblueprint

[document]
toc-depth=2
toc-non-files=True

[files]
directory=../web/
split-level=1

[html5]
localtoc-level=0
extra-css=extra_styles.css
extra-js=copy_tex.js
mathjax-dollars=False
"""

EXTRA_CSS = """.lean-src { font-size: 90%; }
.lean-src code { word-break: break-all; }
.bp-note { font-size: 90%; color: #555; }
"""


# Copying a selection with formulas puts their TeX source into the clipboard, $...$ inline and $$...$$
# displayed, as KaTeX's copy-tex does on the other pages of the site (these pages have MathJax 3).
COPY_TEX_JS = r"""document.addEventListener("copy", function (event) {
  var sel = window.getSelection(), doc = window.MathJax && MathJax.startup && MathJax.startup.document;
  if (!sel || sel.isCollapsed || !sel.rangeCount || !event.clipboardData || !doc || !doc.math) return;
  for (var item of doc.math) {
    if (!item.typesetRoot) continue;
    item.typesetRoot.setAttribute("data-tex", item.math);
    item.typesetRoot.toggleAttribute("data-tex-display", !!item.display);
  }
  var range = sel.getRangeAt(0), node = range.commonAncestorContainer;
  if (node.nodeType !== 1) node = node.parentNode;
  var inside = node && node.closest("mjx-container[data-tex]"), box = document.createElement("div");
  box.appendChild(inside ? inside.cloneNode(true) : range.cloneContents());
  var found = box.querySelectorAll("mjx-container[data-tex]");
  if (!found.length) return;
  found.forEach(function (c) {
    var d = c.hasAttribute("data-tex-display") ? "$$" : "$";
    c.replaceWith(document.createTextNode(d + c.getAttribute("data-tex").trim() + d));
  });
  event.clipboardData.setData("text/plain", box.textContent);
  event.clipboardData.setData("text/html", box.innerHTML);
  event.preventDefault();
});
"""

TEX_SPECIAL = {"\\": "\\textbackslash{}", "&": "\\&", "%": "\\%", "#": "\\#", "_": "\\_", "{": "\\{", "}": "\\}",
               "$": "\\$", "^": "\\^{}", "~": "\\~{}"}


def tex_inline(s):
    """Plain text of the TOML (notes) as LaTeX text: escape the specials (in one pass), Unicode stays."""
    return "".join(TEX_SPECIAL.get(c, c) for c in s)


def for_plastex(s, stmts, sections, nodes):
    r"""A statement of the paper as content of the blueprint: \ref to a statement that is not a node,
    or to a section, becomes its number; \cite becomes [key, where]; \label goes (the node has it)."""
    def ref(m):
        lab = m.group(1)
        if lab in nodes:
            return m.group(0)
        if lab in stmts:
            return stmts[lab]["number"]
        if lab in sections:
            return sections[lab]["number"]
        return "??"
    s = re.sub(r"\\ref\{([^{}]*)\}", ref, s)
    s = re.sub(r"\\cite\[([^\]]*)\]\{([^{}]*)\}", lambda m: f"[{m.group(2)}, {m.group(1)}]", s)
    s = re.sub(r"\\cite\{([^{}]*)\}", lambda m: f"[{m.group(1)}]", s)
    s = re.sub(r"\\label\{[^{}]*\}", "", s)
    return s.replace("\\allowbreak", "")


def preamble_macros(tex):
    """The paper's own \\newcommand and \\DeclareMathOperator lines, for the blueprint's macros."""
    head = tex[:tex.index("\\begin{document}")]
    return "\n".join(ln for ln in head.splitlines()
                     if ln.startswith(("\\newcommand", "\\renewcommand", "\\DeclareMathOperator")))


def src(data, index, out, tex=None, pin=None, paper_url=SITE + "viewer.html"):
    """Write the leanblueprint source tree into out/ (out/src/ for plastex, the pages in out/web/)."""
    nodes = data["nodes"]
    stmts, sections = statements(tex) if tex else ({}, {})
    st = statuses(data, stmts)
    srcdir = out / "src"
    (srcdir / "macros").mkdir(parents=True, exist_ok=True)
    pin = pin or "main"
    macros = preamble_macros(tex) if tex else "\\newcommand{\\Z}{\\mathbb{Z}}\n\\newcommand{\\D}{\\Delta}"
    # the macros go into web.tex itself: plasTeX finds \\input files with kpsewhich, which a machine
    # without TeX does not have
    common = ("% generated by site/blueprint.py from the paper's preamble\n" + macros + "\n"
              + "\\providecommand{\\texorpdfstring}[2]{#1}\n"
              + "\n".join(f"\\newtheorem{{{e}}}[theorem]{{{NAMES[e]}}}" for e in ENVS if e != "theorem") + "\n"
              + "\\newtheorem{known}{Known result}\n")
    (srcdir / "macros" / "common.tex").write_text(common)
    (srcdir / "plastex.cfg").write_text(PLASTEX_CFG)
    (srcdir / "extra_styles.css").write_text(EXTRA_CSS)
    (srcdir / "copy_tex.js").write_text(COPY_TEX_JS)
    (srcdir / "web.tex").write_text(f"""\\documentclass{{article}}
\\usepackage{{amssymb,amsthm,mathtools}}
\\usepackage{{hyperref}}
\\usepackage[showmore, dep_graph, thms={"+".join(ENVS)}+known]{{blueprint}}
\\newtheorem{{theorem}}{{Theorem}}[section]
{common}
\\home{{{SITE}blueprint.html}}
\\github{{{GROUPS_REPO}}}
\\dochome{{{SITE}blueprint/docs}}
\\title{{The $D_5$ paper: blueprint}}
\\author{{generated from the paper and site/blueprint.toml}}
\\begin{{document}}
\\maketitle
\\input{{content.tex}}
\\end{{document}}
""")
    parts = ["% generated by site/blueprint.py: statements from paper/d5.tex, the rest from site/blueprint.toml\n"]
    parts.append("This blueprint follows the paper \\href{" + SITE + "paper.html}{On the inclusion $D_5(G)\\subseteq\\gamma_4(G)$}: "
                 "every labelled statement, with the Lean declarations of \\href{" + GROUPS_REPO + "}{group-dimension} that "
                 "state or prove it, and what its proof uses. Numbers are those of the paper. A green border means "
                 "the statement is in Lean; a green background, that its proof is too, from the statements it uses. "
                 "The last section lists results of the literature that the formalization proves as well.\n")

    def note_tex(s):
        """A note as LaTeX text: [[label|#]] becomes the paper's number (the label, without the paper)."""
        parts = NOTE_REF.split(s)
        out = ""
        for k, part in enumerate(parts):
            if k % 2 == 0:
                out += tex_inline(part)
            else:
                num = stmts.get(part, sections.get(part, {})).get("number")
                out += num if num else f"\\texttt{{{tex_inline(part)}}}"
        return out

    def lean_links(n):
        if not n["lean"]:
            return ""
        links = []
        for name in n["lean"]:
            rel, line = index[name]
            links.append(f"\\href{{{GROUPS_REPO}/blob/{pin}/{rel}\\#L{line}}}{{\\texttt{{{tex_inline(name)}}}}}")
        return "\n\n\\textbf{Lean:} " + ", ".join(links) + "."

    def node_tex(x, n, env, number, title, body):
        s = st[x]
        head = f"\\begin{{{env}}}" + (f"[{title}]" if title else "") + f"\\label{{{x}}}\n"
        if n["lean"]:
            head += "\\lean{" + ", ".join(n["lean"]) + "}\\leanok\n"
        stat = body + lean_links(n)
        if n["note"]:
            stat += f"\n\n\\textit{{{note_tex(n['note'])}}}"
        proof = ""
        if True:  # every node has a proof block: it carries \\leanok, \\uses and the pointer to the paper
            proof = "\\begin{proof}\n" + ("\\leanok\n" if n["proved"] else "")
            if s["uses"]:
                proof += "\\uses{" + ", ".join(s["uses"]) + "}\n"
            where = (f"\\href{{{paper_url}\\#nameddest={x}}}{{the paper}}" if not x.startswith("ext:")
                     else "the paper's section on the formalization")
            kind = {"lean": "In Lean.", "lean-given": "In Lean, from statements that are not all in Lean.",
                    "lean-statement": ("A part is in Lean, not the whole proof." if n["computer"]
                                       else "Only the statement is in Lean."),
                    "computer": "Computer-assisted; not formalized.", "paper": "By hand; not formalized."}[s["status"]]
            if n["computer"] and s["status"].startswith("lean"):
                kind += " Computer-assisted in part."
            proof += f"See {where}. {kind}\n\\end{{proof}}\n"
        number_set = ""
        if number:
            k = int(number.split(".")[1])
            number_set = f"\\setcounter{{theorem}}{{{k - 1}}}\n"
        return number_set + head + stat + f"\n\\end{{{env}}}\n" + proof

    if tex:
        order = list(stmts)
        bysec = {}
        for x in order:
            bysec.setdefault(stmts[x]["section"], []).append(x)
        appendix_done = False
        for lab, sinfo in sections.items():
            if sinfo["number"].isalpha() and not appendix_done:
                parts.append("\\appendix\n")
                appendix_done = True
            parts.append(f"\\section{{{for_plastex(sinfo['title'], stmts, sections, nodes)}}}\\label{{{lab}}}\n")
            xs = bysec.get(lab, [])
            if not xs:
                parts.append("No labelled statements in this section of the paper.\n")
            for x in xs:
                s = stmts[x]
                parts.append(node_tex(x, nodes[x], s["env"], s["number"], for_plastex(s["title"], stmts, sections, nodes),
                                      for_plastex(s["body"], stmts, sections, nodes)))
    else:
        parts.append("\\section{Statements of the paper}\n")
        for x, n in nodes.items():
            if x.startswith("ext:"):
                continue
            kind = {"thm": "theorem", "prop": "proposition", "lem": "lemma", "cor": "corollary", "rem": "remark", "q": "question"}[x.split(":")[0]]
            parts.append(node_tex(x, n, kind, None, "",
                                  f"The statement \\texttt{{{tex_inline(x)}}} of the paper (placeholder: built without the paper)."))
    # numbered on their own (Known result 1, 2, ...), not as the last section of the paper
    parts.append("\\section*{Results of the literature proved in the formalization}\n")
    for x, n in nodes.items():
        if x.startswith("ext:"):
            parts.append(node_tex(x, n, "known", None, n.get("title", ""), n["statement"]))
    (srcdir / "content.tex").write_text("\n".join(parts))
    # the "documentation" the \lean links point to: \dochome/find/#doc/<name> -> the source at the pin
    targets = {name: f"{GROUPS_REPO}/blob/{pin}/{index[name][0]}#L{index[name][1]}"
               for n in nodes.values() for name in n["lean"]}
    return targets


FIND_HTML = """<!doctype html><meta charset="utf-8"><title>Lean declaration</title>
<script>var T=%s;var h=decodeURIComponent(location.hash.replace(/^#doc\\//,''));
if(T[h])location.replace(T[h]);else document.write('Not a declaration of the blueprint: '+h.replace(/</g,'&lt;'));</script>
"""


def find_page(targets):
    return FIND_HTML % json.dumps(targets, ensure_ascii=False)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    paper = None
    if "--paper" in args:
        i = args.index("--paper")
        paper = pathlib.Path(args[i + 1])
        del args[i:i + 2]
    tex = (paper / "d5.tex").read_text() if paper else None
    data = load()
    index = lean_index()
    if cmd == "check":
        check(data, index, tex)
        st = statuses(data, statements(tex)[0] if tex else {})
        counts = {}
        for v in st.values():
            counts[v["status"]] = counts.get(v["status"], 0) + 1
        print("blueprint: ok,", len(data["nodes"]), "nodes", counts, "|", len(data["results"]), "rows of results.html")
    elif cmd == "lean":
        check(data, index)
        pathlib.Path(args[0]).write_text(lean_file(data, index))
    elif cmd == "tags":
        errors = tags(data, pathlib.Path(args[0]).read_text())
        if errors:
            sys.exit("blueprint: @[d5] tags and blueprint.toml differ:\n  " + "\n  ".join(errors))
        print("blueprint: the @[d5] tags of groups/ are exactly the", len(tag_pairs(data)), "(label, declaration) pairs of the nodes")
    elif cmd == "src":
        check(data, index, tex)
        out = pathlib.Path(args[0])
        pin = None
        if GROUPS.joinpath(".git").exists():
            import subprocess
            pin = subprocess.run(["git", "-C", str(GROUPS), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        targets = src(data, index, out, tex, pin)
        (out / "find.html").write_text(find_page(targets))
        print("blueprint source written to", out / "src", "| groups at", (pin or "?")[:7])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
