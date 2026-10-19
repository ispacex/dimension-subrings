# -*- coding: utf-8 -*-
"""
The static site on the D_5 problem: https://ispacex.github.io/d5/

    python3 site/build_site.py --paper PAPER_DIR [OUT_DIR]   # default OUT_DIR: site/out/
    site/two_tier.sh OUT_DIR                                 # search index into the form ispacex's engine reads

PAPER_DIR holds the paper draft, d5.tex and d5-ru.tex (its source is kept elsewhere); both are
compiled here with pdflatex, so the PDFs on the site are always those of the sources read. The
results, the runs and the timeline are written down in this file, in RESULTS, RUNS, FUNNELS and
TIMELINE below: they are the paper's numbers, and a change in the paper means a change here. The
coverage maps are computed from the rules in cover2() and cover3(), which say which theorem or run
settles each (order, rank); nothing is computed anew. The output is a static site (HTML, inline
SVG, KaTeX from jsDelivr, the two PDFs) published from the public repository ispacex/d5 via GitHub
Pages; the code that makes it is this file and the page of the PDF viewer, site/viewer.html.

Links into the paper. The drafts are compiled with hyperref's `destlabel`, so every \\label is a named
destination of the PDF under its own name (`thm:small`, `prop:reduction`, `sec:three`); sections
without a label keep hyperref's name (`section.N`); all sections of the drafts now have one. The viewer, viewer.html (EN, d5.pdf) and
ru/viewer.html (RU, d5-ru.pdf), pdf.js from cdnjs, opens at

    viewer.html#nameddest=thm:small        the statement with that label
    viewer.html#page=6                     a page
    viewer.html?file=d5-ru#nameddest=...   another PDF of paper/ (default: the page's language)

and the plain PDF takes the same fragments (paper/d5.pdf#nameddest=thm:small). In page texts a
reference is written [[label]] ("Thm. 5.4", linked to the viewer at the statement), [[label|#]]
(the number alone, "5.4", for prose: "теоремы [[thm:exp3plus|#]]"), [[label|text]] or [[label|##]] (the
number, not linked: inside another link); in code,
paper_link(label, lang, text). Numbers and pages come from the .aux of the build, never from this
file, and the build stops if a label is not in both drafts. Links to the code and data go to a
pinned commit of this repository through gh(path, text, symbol), which stops the build if the file
(or the declaration) is not there.

Two languages from one source, as in the site of the metalibrary (ispacex/meta-rapacious,
site/build_site.py, whose page shell this is): every text is written twice, side by side, as
t(ru, en); English pages at the root, Russian ones in ru/ under the same file names; hreflang
links to the twin, an EN/RU switch, a System/Light/Dark switch and one search index for both
languages in which every page names its `lang`.
"""
import datetime
import html
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent

args = sys.argv[1:]
if "--paper" not in args or args.index("--paper") + 1 >= len(args):
    sys.exit("usage: build_site.py --paper PAPER_DIR [OUT_DIR]")
i = args.index("--paper")
PAPER = pathlib.Path(args[i + 1]).resolve()
del args[i:i + 2]
OUT = pathlib.Path(args[0]) if args else HERE / "out"

LANGS = ("ru", "en")
SITE_TITLE = {"ru": "Задача о $D_5$", "en": "The $D_5$ problem"}
REPO = "https://github.com/ispacex/dimension-subrings"
PDF = {"en": "d5", "ru": "d5-ru"}  # paper/<name>.pdf of each language


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True, text=True)


# Links to the code and data name a commit, so that what a number rests on stays where it was: the
# last commit that touched the code, the data or the Lean files (a commit of main when the site is
# built from main).
PIN = git("log", "-1", "--format=%H", "--", "compute", "groups", "notes", "scripts").stdout.strip()


def gh(path, text, symbol=None):
    """A link to path (a file or a directory) of this repository at PIN; with symbol, to the line of
    the first `def symbol`/`theorem symbol`/... in the file. Stops the build if either is missing."""
    kind = git("cat-file", "-t", f"{PIN}:{path}").stdout.strip()
    if kind not in ("blob", "tree"):
        sys.exit(f"gh(): {path} is not in {REPO} at {PIN[:7]}")
    href = f"{REPO}/{'blob' if kind == 'blob' else 'tree'}/{PIN}/{path}"
    if symbol:
        lines = git("show", f"{PIN}:{path}").stdout.splitlines()
        pat = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|noncomputable\s+|protected\s+)*"
                         r"(?:theorem|lemma|def|abbrev|instance|structure|class)\s+" + re.escape(symbol) + r"\b")
        at = [k for k, ln in enumerate(lines, 1) if pat.match(ln)]
        if not at:
            sys.exit(f"gh(): no declaration {symbol} in {path} at {PIN[:7]}")
        href += f"#L{at[0]}"
    return f'<a href="{href}">{text}</a>'

NAV = [("index.html", "Сводка", "Summary"), ("coverage.html", "Карта покрытия", "Coverage map"),
       ("results.html", "Результаты", "Results"), ("computations.html", "Вычисления", "Computations"),
       ("timeline.html", "Хронология", "Timeline"), ("open.html", "Открытые вопросы", "Open questions"),
       ("paper.html", "Статья", "Paper"), ("search.html", "Поиск", "Search")]

# Colours: as on the metalibrary site, plus three for the status of a result: computer (--cmp),
# paper (--ppr), both (--both), open (--amb). The SVG pictures use the same custom properties, so
# they follow the theme.
DARK = """--ink:#e6e9ee; --muted:#a3adb9; --line:#38414c; --bg:#14181d; --soft:#1c2128; --bad:#4a2620;
        --badink:#ffb4a2; --ok:#1f3a27; --amb:#4a3d1c; --acc:#7fb0ec; --sel:rgba(127,176,236,.2);
        --cmp:#2f6b45; --ppr:#2f5687; --both:#2c6a72; --open:#7a5d1e; --cellink:#f2f4f7;
        --veil:rgba(0,0,0,.6); --imgpad:6px; color-scheme:dark;"""
CSS = """
:root { --ink:#1f2933; --muted:#52606d; --line:#d9dee5; --bg:#ffffff; --soft:#f4f6f9;
        --bad:#fde8e4; --badink:#a33a1f; --ok:#e7f4ea; --amb:#fff3d6; --acc:#2e6db4; --sel:rgba(46,109,180,.12);
        --cmp:#9fd3ad; --ppr:#a9c6ec; --both:#98d4d6; --open:#f3d38a; --cellink:#1f2933;
        --veil:rgba(15,20,30,.35); --imgpad:0; color-scheme:light; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { """ + DARK + """ } }
:root[data-theme="dark"] { """ + DARK + """ }
"""
CSS += """* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.55 -apple-system, "Segoe UI", Roboto, "DejaVu Sans", sans-serif; }
header { border-bottom:1px solid var(--line); background:var(--soft); }
header .wrap { padding-top:.7rem; padding-bottom:.8rem; }
header .top { display:flex; flex-wrap:wrap; align-items:center; gap:.5rem 1rem; margin-bottom:.6rem; }
header .title { font-weight:600; color:var(--ink); text-decoration:none; }
header .tools { display:flex; align-items:center; gap:.6rem; margin-left:auto; }
.lang { display:inline-flex; border:1px solid var(--line); border-radius:6px; overflow:hidden; font-size:.85rem; line-height:1.6; }
.lang a, .lang strong { padding:0 .6em; text-decoration:none; }
.lang a { color:var(--acc); background:var(--bg); }
.lang strong { background:var(--acc); color:var(--bg); }
.lang > * + * { border-left:1px solid var(--line); }
.theme { display:inline-flex; border:1px solid var(--line); border-radius:6px; overflow:hidden; font-size:.85rem; line-height:1.6; }
.theme button { display:inline-flex; align-items:center; height:1.6em; margin:0; padding:0 .5em; border:0; border-radius:0;
        background:var(--bg); color:var(--muted); font:inherit; cursor:pointer; }
.theme button + button { border-left:1px solid var(--line); }
.theme button:hover { color:var(--acc); }
.theme button:focus-visible { outline:2px solid var(--acc); outline-offset:-2px; }
.theme button[aria-pressed="true"] { background:var(--acc); color:var(--bg); }
.theme svg { width:1em; height:1em; fill:none; stroke:currentColor; stroke-width:2; stroke-linecap:round; }
html:not(.js) .theme { display:none; }
#nav-palette, #nav-open { --p-bg:var(--bg); --p-fg:var(--ink); --p-line:var(--line); --p-sel:var(--sel);
        --p-mark:var(--acc); --p-veil:var(--veil); }
nav { display:flex; flex-wrap:wrap; gap:.4rem; }
nav a { color:var(--acc); text-decoration:none; white-space:nowrap; font-size:.92rem; line-height:1.5;
        padding:.15em .65em; border:1px solid var(--line); border-radius:6px; background:var(--bg); }
nav a:hover, nav a:focus-visible { border-color:var(--acc); }
nav a.cur { background:var(--acc); border-color:var(--acc); color:var(--bg); font-weight:600; }
@media (max-width:520px) { nav { gap:.3rem; } nav a { font-size:.85rem; padding:.1em .5em; } }
.wrap { max-width:1100px; margin:0 auto; padding:.9rem 16px; }
h1 { font-size:1.6rem; margin:.6rem 0 .8rem; } h2 { font-size:1.25rem; margin-top:2rem; }
a { color:var(--acc); } .muted { color:var(--muted); } small { color:var(--muted); }
.tw { overflow-x:auto; margin:1rem 0; border:1px solid var(--line); border-radius:6px; position:relative; }
table { border-collapse:collapse; width:100%; font-size:.9rem; font-variant-numeric:tabular-nums; }
th, td { border-bottom:1px solid var(--line); padding:.3rem .55rem; text-align:center; vertical-align:top; }
th { background:var(--soft); position:sticky; top:0; }
td.l, th.l { text-align:left; } td.r, th.r { text-align:right; }
.box { border-left:4px solid var(--acc); background:var(--soft); padding:.7rem 1rem; margin:1rem 0; border-radius:0 6px 6px 0; }
code { background:var(--soft); padding:0 .25em; border-radius:3px; }
footer { border-top:1px solid var(--line); margin-top:3rem; }
.tag { display:inline-block; font-size:.78rem; line-height:1.5; padding:0 .45em; border-radius:4px; white-space:nowrap;
       color:var(--cellink); border:1px solid var(--line); }
.tag.c { background:var(--cmp); } .tag.p { background:var(--ppr); } .tag.cp { background:var(--both); }
.tag.o { background:var(--open); } .tag.l { background:var(--soft); color:var(--ink); }
.cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(15rem,1fr)); gap:.8rem; margin:1rem 0; }
.card { border:1px solid var(--line); border-radius:8px; padding:.7rem .9rem; background:var(--soft); }
.card h3 { margin:.1rem 0 .4rem; font-size:1rem; } .card .big { font-size:1.35rem; font-weight:600; }
.card p { margin:.3rem 0; font-size:.92rem; }
.fig { overflow-x:auto; margin:1rem 0; } .fig svg { display:block; max-width:100%; height:auto; }
svg text { fill:var(--ink); font:12px -apple-system, "Segoe UI", Roboto, "DejaVu Sans", sans-serif; }
svg .muted { fill:var(--muted); } svg .cell { stroke:var(--bg); stroke-width:2; }
svg .k-c { fill:var(--cmp); } svg .k-p { fill:var(--ppr); } svg .k-cp { fill:var(--both); } svg .k-o { fill:var(--open); }
svg .k-n { fill:var(--soft); } svg .k-x { fill:url(#hatch); } svg .hl { fill:none; stroke:var(--ink); stroke-width:1.5; }
svg .bar { fill:var(--acc); opacity:.75; } svg .bar0 { fill:var(--ok); } svg .axis { stroke:var(--line); }
svg .ct { fill:var(--cellink); font-size:11px; }
ol.tl { list-style:none; padding:0; border-left:2px solid var(--line); margin-left:.4rem; }
ol.tl li { position:relative; padding:0 0 .9rem 1.1rem; }
ol.tl li::before { content:""; position:absolute; left:-.42rem; top:.45rem; width:.7rem; height:.7rem; border-radius:50%;
       background:var(--acc); border:2px solid var(--bg); }
ol.toc { list-style:none; padding-left:0; } ol.toc > li { margin:.55rem 0; } ol.toc ul { margin:.2rem 0 0; padding-left:1.4rem; }
ol.toc .stm { font-size:.88rem; margin:.15rem 0 0 1.4rem; } ol.toc .stm > span { white-space:nowrap; }
ol.toc .stm > span .muted { white-space:normal; }
ol.tl .d { font-weight:600; } ol.tl ul { margin:.2rem 0 0; padding-left:1.1rem; }
"""

KATEX = """<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
 onload="renderMathInElement(document.body,{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false}],
 macros:{'\\\\D':'\\\\Delta','\\\\Z':'\\\\mathbb{Z}'},ignoredTags:['script','noscript','style','textarea','pre','code','svg']})"></script>"""


def plain(s):
    """Text for <title>: no KaTeX there."""
    for a, b in (("\\gamma", "γ"), ("\\le", "≤"), ("_5", "₅"), ("_4", "₄"), ("^", ""), ("$", ""), ("\\", "")):
        s = s.replace(a, b)
    return s


PAGES = []  # (lang, file, title, body) of every page, for the search index
ORIGIN = "https://ispacex.github.io"
BASE = "/d5/"  # where GitHub Pages serves the site
SECTION = {"ru": "Задача о D5", "en": "The D5 problem"}


def url(lang, fn):
    return BASE + ("ru/" if lang == "ru" else "") + ("" if fn == "index.html" else fn)


# Link previews (Telegram and the like): Open Graph tags on every page. The image is one card per
# language, site/og-<lang>.png, drawn by site/og_card.py (run it again when the title changes); the
# description is the page's first paragraph when it has no formulas, else the site's.
SITE_DESC = {"ru": "Коуровская тетрадь, задача 20.84: размерные подгруппы и нижний центральный ряд. "
                   "Вычисления, доказательства, черновик статьи.",
             "en": "Kourovka notebook, Problem 20.84: dimension subgroups and the lower central series. "
                   "Computations, proofs and a paper draft."}


def blurb(lang, body):
    m = re.search(r"<p>(.*?)</p>", body, re.S)
    text = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))) if m else ""
    text = " ".join(text.split())
    if len(text) < 60 or "$" in text or "\\" in text:
        return SITE_DESC[lang]
    return text if len(text) <= 200 else text[:200].rsplit(" ", 1)[0] + "…"


def og_tags(lang, fn, title, desc):
    d = html.escape(desc)
    return (f'\n<meta name="description" content="{d}">'
            f'\n<meta property="og:type" content="website">'
            f'\n<meta property="og:site_name" content="{html.escape(plain(SITE_TITLE[lang]))}">'
            f'\n<meta property="og:title" content="{html.escape(title)}">'
            f'\n<meta property="og:description" content="{d}">'
            f'\n<meta property="og:url" content="{ORIGIN}{url(lang, fn)}">'
            f'\n<meta property="og:locale" content="{"ru_RU" if lang == "ru" else "en_US"}">'
            f'\n<meta property="og:image" content="{ORIGIN}{BASE}og-{lang}.png">'
            f'\n<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">'
            f'\n<meta name="twitter:card" content="summary_large_image">')


PLACEHOLDER = {"ru": "Куда идём? например: 3^9, Тахара, ранг 5", "en": "Where to? for example: 3^9, Tahara, rank 5"}


def palette(lang):
    return (f'<script src="/sitesearch/palette.js" data-index="{BASE}nav-index.json" data-mount="header .pal" '
            f'data-search="{url(lang, "search.html")}" data-search-index="{BASE}search-index.json" '
            f'data-placeholder="{PLACEHOLDER[lang]}" defer></script>')


FOOTER = {
    "ru": """Ход работы над задачей 20.84 Коуровской тетради: верно ли $D_5(G)\\subseteq\\gamma_4(G)$ для всякой группы.
Состояние на {date}. Код и данные — <a href="{repo}">ispacex/dimension-subrings</a>.
Распределённые вычислительные мощности щедро предоставлены <a href="https://boinc.berkeley.edu/">BOINC</a>.<br>
Раздел <a href="https://ispacex.github.io/ru/math/">«Математика»</a> на ispacex.github.io.""",
    "en": """Progress on Problem 20.84 of the Kourovka notebook: is $D_5(G)\\subseteq\\gamma_4(G)$ for every group?
As of {date}. Code and data: <a href="{repo}">ispacex/dimension-subrings</a>.
Distributed computing power generously provided by <a href="https://boinc.berkeley.edu/">BOINC</a>.<br>
Part of <a href="https://ispacex.github.io/math/">Mathematics</a> at ispacex.github.io.""",
}
CONTACT = {"ru": 'Связаться с нами: <a href="https://vissi.su">vissi.su</a>',
           "en": 'Contact: <a href="https://vissi.su">vissi.su</a>'}

THEME_KEY = "d5-theme"
THEME_HEAD = ("<script>(function(d){d.classList.add('js');try{var t=localStorage.getItem('" + THEME_KEY + "');"
              "if(t==='light'||t==='dark')d.setAttribute('data-theme',t)}catch(e){}})(document.documentElement)</script>")
THEME_BODY = """<script>(function(){var d=document.documentElement,K='""" + THEME_KEY + """',
b=document.querySelectorAll('.theme button');
function show(){var t=d.getAttribute('data-theme')||'system';
for(var i=0;i<b.length;i++)b[i].setAttribute('aria-pressed',b[i].getAttribute('data-t')===t?'true':'false')}
function set(t){if(t==='light'||t==='dark')d.setAttribute('data-theme',t);else{t='system';d.removeAttribute('data-theme')}show();return t}
for(var i=0;i<b.length;i++)b[i].addEventListener('click',function(){var t=set(this.getAttribute('data-t'));
try{if(t==='system')localStorage.removeItem(K);else localStorage.setItem(K,t)}catch(e){}});
addEventListener('storage',function(e){if(e.key===K)set(e.newValue)});show()})()</script>"""
THEMES = (("system", "как в системе", "system",
           '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor"/>'),
          ("light", "светлая", "light",
           '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4'
           'M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'),
          ("dark", "тёмная", "dark", '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>'))


def theme_switch(lang):
    li = 1 if lang == "ru" else 2
    word = "Тема" if lang == "ru" else "Theme"
    return (f'<span class="theme" role="group" aria-label="{word}">' + "".join(
        f'<button type="button" data-t="{th[0]}" aria-pressed="{"true" if th[0] == "system" else "false"}" '
        f'aria-label="{word}: {th[li]}" title="{word}: {th[li]}">'
        f'<svg viewBox="0 0 24 24" aria-hidden="true">{th[3]}</svg></button>' for th in THEMES) + "</span>")


def page(lang, fn, title, body, date, contact=False):
    body = expand_refs(body, lang)
    PAGES.append((lang, fn, title, body))
    li = 1 if lang == "ru" else 2
    nav = "".join(f'<a href="{n[0]}"{" class=cur aria-current=page" if n[0] == fn else ""}>{n[li]}</a>' for n in NAV)
    twin = {"en": f"ru/{fn}", "ru": f"../{fn}"}[lang]
    other = "en" if lang == "ru" else "ru"
    there = f'<a href="{twin}" hreflang="{other}" lang="{other}">{other.upper()}</a>'
    here = f'<strong lang="{lang}" aria-current="true">{lang.upper()}</strong>'
    switch = (f'<span class="lang" role="group" aria-label="{"Язык" if lang == "ru" else "Language"}">'
              + (here + there if lang == "en" else there + here) + "</span>")
    alt = "".join(f'\n<link rel="alternate" hreflang="{h}" href="{ORIGIN}{url(l, fn)}">'
                  for h, l in (("en", "en"), ("ru", "ru"), ("x-default", "en")))
    if lang == "ru":  # the PDFs are one set for both languages, at the root
        body = body.replace('href="paper/', 'href="../paper/')
    doc = f"""<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
{THEME_HEAD}
<title>{html.escape(plain(title))} — {html.escape(plain(SITE_TITLE[lang]))}</title>{alt}{og_tags(lang, fn, plain(title) if fn == "index.html" else f"{plain(title)} — {plain(SITE_TITLE[lang])}", blurb(lang, body))}
<style>{CSS}</style>{KATEX}</head>
<body><header><div class="wrap"><div class="top"><a class="title" href="index.html">{SITE_TITLE[lang]}</a>
<div class="tools"><span class="pal"></span>{theme_switch(lang)}{switch}</div></div>
<nav aria-label="{"Разделы" if lang == "ru" else "Sections"}">{nav}</nav></div></header>
<main class="wrap"><h1>{title}</h1>
{body}
</main><footer><div class="wrap"><small>{FOOTER[lang].format(date=date[lang], repo=REPO)}</small>{f'<p><small>{CONTACT[lang]}</small></p>' if contact else ""}</div></footer>
{THEME_BODY}
{palette(lang)}
</body></html>"""
    d = OUT if lang == "en" else OUT / "ru"
    d.mkdir(parents=True, exist_ok=True)
    (d / fn).write_text(doc, encoding="utf-8")


PDFJS = "4.9.155"  # pdf.js on cdnjs, the version of the ship viewer of ispacex.github.io
VIEWER_TEXT = {  # (ru, en)
    "S_TOC": ("Содержание", "Contents"), "S_SEARCH": ("Поиск", "Search"), "S_PREV": ("Предыдущая страница", "Previous page"),
    "S_NEXT": ("Следующая страница", "Next page"), "S_PAGE": ("Страница", "Page"), "S_ZOUT": ("Мельче", "Zoom out"),
    "S_ZIN": ("Крупнее", "Zoom in"), "S_FIT": ("По ширине", "Fit width"), "S_DOWNLOAD": ("Скачать PDF", "Download the PDF"),
    "S_PANEL": ("Содержание и поиск", "Contents and search"), "S_SEARCH_PH": ("Поиск по тексту…", "Search the text…"),
    "S_SPREV": ("Предыдущее совпадение", "Previous match"), "S_SNEXT": ("Следующее совпадение", "Next match"),
    "S_LOADING": ("Загрузка PDF…", "Loading the PDF…"),
}
VIEWER_JS = {  # (ru, en), for the script
    "failed": ("Страница {n} не нарисовалась. Измените масштаб или прокрутите мимо и обратно.",
               "Page {n} did not render. Change the zoom, or scroll away and back."),
    "nodest": ("В этом PDF нет места «{d}».", "This PDF has no destination “{d}”."),
    "notoc": ("Оглавления нет", "No contents"), "searching": ("Поиск…", "Searching…"),
    "found": ("Найдено: {n}", "{n} matches"), "nothing": ("Ничего не найдено", "Nothing found"),
    "pageN": ("С. {n}", "P. {n}"),
    "loadfail": ('Не удалось открыть PDF. Скачать: <a href="{url}">{url}</a>', 'Could not open the PDF. Download it: <a href="{url}">{url}</a>'),
}


def viewer(lang):
    """viewer.html of a language: the template site/viewer.html with the texts, the theme and the PDF
    of that language filled in. Not in the search index (it has no text of its own)."""
    li = 0 if lang == "ru" else 1
    other = "en" if lang == "ru" else "ru"
    twin = {"en": "ru/viewer.html", "ru": "../viewer.html"}[lang]
    alt = "".join(f'\n<link rel="alternate" hreflang="{h}" href="{ORIGIN}{url(l, "viewer.html")}">'
                  for h, l in (("en", "en"), ("ru", "ru"), ("x-default", "en")))
    here = f'<strong lang="{lang}" aria-current="true">{lang.upper()}</strong>'
    there = f'<a href="{twin}" hreflang="{other}" lang="{other}">{other.upper()}</a>'
    switch = (f'<span class="lang" role="group" aria-label="{"Язык" if lang == "ru" else "Language"}">'
              + (here + there if lang == "en" else there + here) + "</span>")
    paper_dir = "paper/" if lang == "en" else "../paper/"
    title = ("Черновик статьи" if lang == "ru" else "Paper draft") + " — " + plain(SITE_TITLE[lang])
    fill = {"LANG": lang, "TITLE": html.escape(title), "ALT": alt + og_tags(lang, "viewer.html", title, SITE_DESC[lang]), "THEME_HEAD": THEME_HEAD, "THEME_BODY": THEME_BODY,
            "TOKENS": CSS.split("* { box-sizing")[0], "THEME_SWITCH": theme_switch(lang), "LANG_SWITCH": switch,
            "SITE": html.escape(plain(SITE_TITLE[lang])), "PAPER": "Черновик" if lang == "ru" else "Paper",
            "BACK_TITLE": "К странице статьи" if lang == "ru" else "Back to the paper page",
            "PDF_HREF": paper_dir + PDF[lang] + ".pdf", "PAPER_DIR": paper_dir, "DEFAULT_FILE": PDF[lang], "PDFJS": PDFJS,
            "STRINGS": json.dumps({k: v[li] for k, v in VIEWER_JS.items()}, ensure_ascii=False)}
    fill.update({k: v[li] for k, v in VIEWER_TEXT.items()})
    doc = (HERE / "viewer.html").read_text(encoding="utf-8")
    doc = re.sub(r"__([A-Z_]+?)__", lambda m: fill[m.group(1)] if m.group(1) in fill else m.group(0), doc)
    left = re.findall(r"__[A-Z_]+__", doc)
    if left:
        sys.exit(f"site/viewer.html: unfilled {sorted(set(left))}")
    d = OUT if lang == "en" else OUT / "ru"
    d.mkdir(parents=True, exist_ok=True)
    (d / "viewer.html").write_text(doc, encoding="utf-8")


def tex_text(s):
    """TeX of the pages as searchable bare text."""
    for a, b in (("\\gamma", "γ"), ("\\Delta", "Δ"), ("\\D", "Δ"), ("\\mathbb ", ""), ("\\le", "≤"),
                 ("\\ge", "≥"), ("\\subseteq", "⊆"), ("\\cong", "≅"), ("\\times", "×"), ("\\ne", "≠"),
                 ("\\cap", "∩"), ("\\Omega", "Ω"), ("\\,", " "), ("\\;", " ")):
        s = s.replace(a, b)
    s = re.sub(r"\\[a-zA-Z]+", "", s)
    s = re.sub(r"[_^]\{([^{}]*)\}", r"\1", s)
    s = re.sub(r"[_^](\S)", r"\1", s)
    return re.sub(r"\s+", " ", s.replace("$", "").replace("{", "").replace("}", "")).strip()


def blocks_of(body):
    """The pieces of text of a page (FORMAT.md of sitesearch): paragraphs, list items, table rows,
    each with the heading above it. The SVG pictures are skipped."""
    from html.parser import HTMLParser
    out = []

    class P(HTMLParser):
        BLOCK = {"p", "li", "tr", "h2", "h3"}

        def __init__(self):
            super().__init__()
            self.buf, self.section, self.svg = [], "", 0

        def handle_starttag(self, tag, attrs):
            if tag == "svg":
                self.svg += 1
            elif tag in self.BLOCK:
                self.flush()
            elif tag in ("td", "th") and self.buf:
                self.buf.append(" · ")

        def handle_endtag(self, tag):
            if tag == "svg":
                self.svg -= 1
            elif tag in self.BLOCK:
                text = self.flush()
                if tag in ("h2", "h3"):
                    self.section = text
                elif text:
                    out.append({"text": text, "section": self.section} if self.section else text)

        def handle_data(self, data):
            if not self.svg:
                self.buf.append(data)

        def flush(self):
            text = tex_text(html.unescape("".join(self.buf)))
            self.buf = []
            return text.strip(" ·")

    p = P()
    p.feed(body)
    return out


def write_search(order):
    pages = []
    for lang, fn, title, body in PAGES:
        if fn == "search.html":
            continue
        pages.append({"url": url(lang, fn), "title": tex_text(title), "lang": lang,
                      "section": SECTION[lang], "order": order.get(fn, 9), "blocks": blocks_of(body)})
    (OUT / "search-index.json").write_text(json.dumps({"pages": pages}, ensure_ascii=False, separators=(",", ":")))
    nav = [{k: v for k, v in p.items() if k != "blocks"} for p in pages]
    (OUT / "nav-index.json").write_text(json.dumps({"pages": nav}, ensure_ascii=False, separators=(",", ":")))
    return sum(len(p["blocks"]) for p in pages)


def table(head, rows, ids=None):
    def cell(tag, c):
        if isinstance(c, tuple):
            return f'<{tag} class="{c[1]}">{c[0]}</{tag}>'
        return f"<{tag}>{c}</{tag}>"
    th = "".join(cell("th", h) for h in head)
    body = "".join((f'<tr id="{ids[k]}">' if ids else "<tr>") + "".join(cell("td", c) for c in r) + "</tr>"
                   for k, r in enumerate(rows))
    return f'<div class="tw"><table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table></div>'


def num(n, lang):
    """1396077 -> 1 396 077 (a thin space in both languages, as in the paper)."""
    return f"{n:,}".replace(",", "\u2009")


# ---------------------------------------------------------------------------------------------
# What is known. Status: "c" computer, "p" paper, "cp" computer + paper, "o" open, "l" Lean.
# Refs point to the paper draft (numbers of the version on the site) and to the code.

STATUS = {"c": ("компьютер", "computer"), "p": ("на бумаге", "paper"), "cp": ("компьютер + бумага", "computer + paper"),
          "o": ("открыто", "open"), "l": ("Lean", "Lean")}

RESULTS = [  # (status, ru, en, ref): ref is a str or (ru, en); [[label]] is a link to the statement
    # in the paper, the other links go to what backs a number: a funnel or table of computations.html,
    # the code and data at PIN, the Lean file, open.html or timeline.html. One link per claim.
    ("p", "Сведение: $D_5(G)\\subseteq\\gamma_4(G)$ для всех групп $\\iff$ $D_5(Q)=1$ для всех конечных $2$-групп ступени $3$. Для конечных $G$ порядок не растёт: достаточно $2$-групп порядка не больше $2$-части $|G|$. В Lean доказано при явных гипотезах: теоремы Пасси ($D_4^2\\subseteq\\gamma_4$), Грюнберга и $D_3=\\gamma_3$ (для конечных $G$ теорема Грюнберга не нужна).",
     "Reduction: $D_5(G)\\subseteq\\gamma_4(G)$ for all groups $\\iff$ $D_5(Q)=1$ for all finite $2$-groups of class $3$. For finite $G$ the order does not grow: $2$-groups up to the $2$-part of $|G|$ suffice. Proved in Lean with explicit hypotheses: the theorems of Passi ($D_4^2\\subseteq\\gamma_4$) and Gruenberg and $D_3=\\gamma_3$ (for finite $G$ Gruenberg's theorem is not needed).",
     ("[[prop:reduction]], [[rem:bounded]]; " + gh("groups/GroupDimension/FiniteReduction.lean", "в Lean при гипотезах", "dimensionQuestion5_iff_class_three"),
      "[[prop:reduction]], [[rem:bounded]]; " + gh("groups/GroupDimension/FiniteReduction.lean", "in Lean with hypotheses", "dimensionQuestion5_iff_class_three"))),
    ("l", "Для колец Ли $D_5(L)\\subseteq\\gamma_4(L)$ (<a href=\"https://arxiv.org/abs/2610.02042\">Ионин, Михайлов, Петров, 2026</a>); "
          + gh("notes/formalization-audit.ru.md", "формализация проверена") + ", групповой вопрос "
          + gh("groups/GroupDimension/Statements.lean", "сформулирован в Lean", "DimensionQuestion5") + " рядом.",
     "For Lie rings $D_5(L)\\subseteq\\gamma_4(L)$ (<a href=\"https://arxiv.org/abs/2610.02042\">Ionin, Mikhailov, Petrov, 2026</a>); "
          + gh("notes/formalization-audit.md", "the formalization audited") + ", the group question "
          + gh("groups/GroupDimension/Statements.lean", "stated in Lean", "DimensionQuestion5") + " next to it.",
     "[[sec:lie]], [[sec:lean]]"),
    ("cp", "$D_5(G)\\subseteq\\gamma_4(G)$ для всякой конечной $G$ с силовской $2$-подгруппой <a href=\"computations.html#f210\">порядка $\\le2^{10}$</a>, в частности для всех групп порядка $<2048$.",
     "$D_5(G)\\subseteq\\gamma_4(G)$ for every finite $G$ with Sylow $2$-subgroup <a href=\"computations.html#f210\">of order $\\le2^{10}$</a>, in particular for all groups of order $<2048$.",
     "[[thm:small]](1)"),
    ("cp", "Порядок $2^{11}$, ступень $3$: $D_5=1$ при <a href=\"computations.html#f211\">рангах $2$, $3$, $4$</a> и $\\ge8$; <a href=\"open.html#q-2048\">ранги $5$–$7$ открыты</a>.",
     "Order $2^{11}$, class $3$: $D_5=1$ for <a href=\"computations.html#f211\">ranks $2$, $3$, $4$</a> and $\\ge8$; <a href=\"open.html#q-2048\">ranks $5$–$7$ open</a>.",
     "[[prop:rank8]], [[sec:computations]]"),
    ("l", "Центральные произведения: $D_n(H\\circ E)=D_n(H)$ при $E\\in\\{D_8,Q_8\\}$ и $t\\in\\gamma_2(H)$, а для $E=M_{2^{k+2}}$ — при условии на $g^{-2}s$ (например, $s=g^2$). "
          + gh("compute/central", "Все $386$ кандидатов") + " порядков $2^6$–$2^9$ ему удовлетворяют, так что разложимость $H\\circ E$ с $E\\in\\{D_8,Q_8,M_{16}\\}$ контрпримера не даёт. "
          "Склейка по собственной подгруппе $Z(E)$ закрыта при $\\sigma=g^{2^{j+1}}$ (центральный корень любой степени; <a href=\"open.html#q-central\">остальное открыто</a>); у каждого из $20$ раскладывающихся кандидатов есть разложение, покрытое предложением [[prop:central|#]]. " + gh("groups/GroupDimension/CentralProduct.lean", "Предложение [[prop:central|##]]", "D_n_eq_of_central_product") + " и " + gh("groups/GroupDimension/CentralRoot.lean", "лемма [[lem:root|##]]", "D_n_eq_of_index") + " доказаны в Lean; проверка кандидатов — вычислением.",
     "Central products: $D_n(H\\circ E)=D_n(H)$ for $E\\in\\{D_8,Q_8\\}$ and $t\\in\\gamma_2(H)$, and for $E=M_{2^{k+2}}$ under a condition on $g^{-2}s$ (e.g. $s=g^2$). "
          + gh("compute/central", "All $386$ candidates") + " of orders $2^6$–$2^9$ satisfy it, so splitting off $E\\in\\{D_8,Q_8,M_{16}\\}$ gives no counterexample. "
          "Gluing along a proper subgroup of $Z(E)$ is closed when $\\sigma=g^{2^{j+1}}$ (a central root of any degree; <a href=\"open.html#q-central\">the rest is open</a>); each of the $20$ split candidates has a splitting covered by Prop. [[prop:central|#]]. " + gh("groups/GroupDimension/CentralProduct.lean", "Prop. [[prop:central|##]]", "D_n_eq_of_central_product") + " and " + gh("groups/GroupDimension/CentralRoot.lean", "Lemma [[lem:root|##]]", "D_n_eq_of_index") + " are proved in Lean; the check of the candidates is by computer.",
     "[[prop:central]], [[lem:root]]"),
    ("c", "$D_n(G)=\\gamma_n(G)$ при всех $n$ для всякой конечной группы <a href=\"computations.html#runs\">порядка $<512$</a>.",
     "$D_n(G)=\\gamma_n(G)$ for all $n$ and every finite group <a href=\"computations.html#runs\">of order $<512$</a>.", "[[thm:small]](2)"),
    ("cp", "Нет $3$-кручения в $D_5(G)/\\gamma_5(G)$, если силовская $3$-подгруппа $G$ имеет порядок $\\le3^9$; $D_5=\\gamma_5$ для <a href=\"computations.html#f39\">всех $3$-групп порядка $\\le3^9$</a>.",
     "No $3$-torsion in $D_5(G)/\\gamma_5(G)$ when the Sylow $3$-subgroup of $G$ has order $\\le3^9$; $D_5=\\gamma_5$ for <a href=\"computations.html#f39\">all $3$-groups of order $\\le3^9$</a>.",
     "[[thm:3e9]]"),
    ("l", "$D_5(G)=\\gamma_5(G)$, если $G/\\gamma_2(G)$ конечна и имеет экспоненту $3$ — при любом ранге и порядке. Доказано в Lean вместе с теоремой 6.1 Тахары, на которую опирается доказательство.",
     "$D_5(G)=\\gamma_5(G)$ whenever $G/\\gamma_2(G)$ is finite of exponent $3$, of any rank and order. Proved in Lean, together with Tahara's Theorem 6.1 on which the proof relies.",
     ("[[thm:exp3]]; " + gh("groups/GroupDimension/TaharaTheorem.lean", "Lean", "D_five_eq_gamma_five_of_exp_three"),
      "[[thm:exp3]]; " + gh("groups/GroupDimension/TaharaTheorem.lean", "Lean", "D_five_eq_gamma_five_of_exp_three"))),
    ("l", "Более общо: $D_5(G)=\\gamma_5(G)$, если $G/\\gamma_2(G)\\cong C_{3^a}\\times C_3^{s-1}$, т.е. у неё не больше одного инварианта больше $3$ (в том числе $C_9\\times C_3^{s-1}$). <a href=\"timeline.html#d2026-10-18\">Проверено независимой рецензией</a> и доказано в Lean вместе с теоремой 6.1 Тахары.",
     "More generally: $D_5(G)=\\gamma_5(G)$ whenever $G/\\gamma_2(G)\\cong C_{3^a}\\times C_3^{s-1}$, i.e. it has at most one invariant larger than $3$ (including $C_9\\times C_3^{s-1}$). <a href=\"timeline.html#d2026-10-18\">Checked by an independent review</a> and proved in Lean, together with Tahara's Theorem 6.1.",
     ("[[thm:exp3plus]]; " + gh("groups/GroupDimension/TaharaTheorem.lean", "Lean", "D_five_eq_gamma_five_of_cubes_cyclic"),
      "[[thm:exp3plus]]; " + gh("groups/GroupDimension/TaharaTheorem.lean", "Lean", "D_five_eq_gamma_five_of_cubes_cyclic"))),
    ("l", "$p$ нечётно, $|\\gamma_3/\\gamma_4|=p$, у $\\gamma_2/\\gamma_3$ не больше двух порождающих $\\Rightarrow$ $[\\gamma_2,\\gamma_2]\\subseteq\\gamma_5$. Отсюда: неметабелева $p$-группа ступени $4$ ранга $d$ имеет порядок $\\ge p^{d+5}$.",
     "$p$ odd, $|\\gamma_3/\\gamma_4|=p$, $\\gamma_2/\\gamma_3$ with at most two generators $\\Rightarrow$ $[\\gamma_2,\\gamma_2]\\subseteq\\gamma_5$. Hence a non-metabelian $p$-group of class $4$ and rank $d$ has order $\\ge p^{d+5}$.",
     ("[[lem:lie]], [[prop:metab]]; " + gh("groups/GroupDimension/ClassFourOrder.lean", "Lean", "card_ge_of_not_metabelian"),
      "[[lem:lie]], [[prop:metab]]; " + gh("groups/GroupDimension/ClassFourOrder.lean", "Lean", "card_ge_of_not_metabelian"))),
    ("p", "$p$ нечётно, $P$ ступени $3$ с $|\\gamma_2/\\gamma_3|=p^2$, $|\\gamma_3|=p$ $\\Rightarrow$ у $p$-накрывающей группы $P^{*\\prime\\prime}=1$: все шаг-$1$ потомки метабелевы.",
     "$p$ odd, $P$ of class $3$ with $|\\gamma_2/\\gamma_3|=p^2$, $|\\gamma_3|=p$ $\\Rightarrow$ the $p$-covering group has $P^{*\\prime\\prime}=1$: all step-$1$ descendants are metabelian.",
     "[[thm:pcover]]"),
    ("c", "Факторы ступени $3$ групп рипсовского типа порядков $2^{40}$–$2^{107}$: везде $D_5=1$, в трёх из них $D_4\\ne1$ (" + gh("compute/magnus/README.md", "с сертификатом точности") + ").",
     "Class-$3$ quotients of Rips-type groups of orders $2^{40}$–$2^{107}$: $D_5=1$ in all, $D_4\\ne1$ in three of them (" + gh("compute/magnus/README.md", "with the exactness certificate") + ").",
     ("[[sec:open]], вопрос [[oq:main|#]]", "[[sec:open]], question [[oq:main|#]]")),
    ("c", "Групповой аналог теоремы C при $c=4$: у группы плато $D_6\\ne1$, но $D_7=1$, так что $2c-2$ достигается и аналог, если верен, точен (<a href=\"open.html#q-theoremc\">открытый вопрос</a>).",
     "The group analogue of Theorem C at $c=4$: the plateau group has $D_6\\ne1$ but $D_7=1$, so $2c-2$ is attained and the analogue, if true, is sharp (<a href=\"open.html#q-theoremc\">an open question</a>).",
     ("[[sec:open]], вопрос [[oq:theoremc|#]]", "[[sec:open]], question [[oq:theoremc|#]]")),
]

OPEN = [  # (id, ru, en): the id is the anchor on open.html
    ("q-main", "Сам вопрос 20.84: $D_5(Q)=1$ для всех конечных $2$-групп ступени $3$? Контрпример обязан иметь $D_4(Q)\\ne1$ и порядок $\\ge2^{11}$.",
     "Problem 20.84 itself: is $D_5(Q)=1$ for all finite $2$-groups of class $3$? A counterexample must have $D_4(Q)\\ne1$ and order $\\ge2^{11}$."),
    ("q-2048", "Порядок $2^{11}$, ранги $5$–$7$. Ранг $5$ — основная стоимость (по оценке около $100$ процессорных суток); на ранге $7$ штатный ANUPQ переполняется.",
     "Order $2^{11}$, ranks $5$–$7$. Rank $5$ is the bulk of the cost (about $100$ CPU-days by estimate); at rank $7$ the stock ANUPQ overflows."),
    ("q-tahara", "Бывает ли $3$-кручение в $D_5/\\gamma_5$ (достигается ли оценка Тахары $6$)? Минимальный пример — порядка $\\ge3^{10}$, ступени $4$, с циклическим центром и не меньше чем двумя инвариантами $\\ge9$ у $Q/\\gamma_2$.",
     "Is there $3$-torsion in $D_5/\\gamma_5$, i.e. is Tahara's bound $6$ attained? A minimal example has order $\\ge3^{10}$, class $4$, cyclic centre and at least two invariants $\\ge9$ in $Q/\\gamma_2$."),
    ("q-c9c9", "Следующий случай: у $Q/\\gamma_2$ два инварианта $\\ge9$, например $C_9\\times C_9\\times C_3$. Там $\\gamma_2/\\gamma_3$ может иметь экспоненту $9$, и доказательство теоремы [[thm:exp3plus|#]] не проходит.",
     "The next case: $Q/\\gamma_2$ with two invariants $\\ge9$, e.g. $C_9\\times C_9\\times C_3$. There $\\gamma_2/\\gamma_3$ may have exponent $9$, and the proof of Theorem [[thm:exp3plus|#]] does not go through."),
    ("q-nonterminal", "Точный критерий нетерминальности групп типа $(d,2,1)$: при $3^8$ потомки есть у $190$ из $7\\,824$, известные необходимые условия выполнены ещё у $573$ терминальных.",
     "An exact criterion for nonterminality of groups of type $(d,2,1)$: at $3^8$, $190$ of the $7\\,824$ have descendants, and the known necessary conditions also hold for $573$ terminal ones."),
    ("q-theoremc", "Групповой аналог теоремы C: $D_{2c-1}(G)=1$ для метабелевых групп ступени $\\le c$? Открыто при $p=2$, $c\\ge3$ и при нечётном $p$, $c\\ge p+2$.",
     "The group analogue of Theorem C: $D_{2c-1}(G)=1$ for metabelian groups of class $\\le c$? Open for $p=2$, $c\\ge3$ and for odd $p$, $c\\ge p+2$."),
    ("q-central", "Центральные произведения со склейкой по собственной подгруппе, когда $\\sigma$ не является $2^{j+1}$-й степенью: $12$ из $212$ разложений кандидатов порядков $2^8$–$2^9$ ничем не покрыты. Проекцией на $H$ это в общем случае не сделать: у $D_8\\circ_{\\langle t\\rangle}M_{16}$ кольцевое равенство нарушено при $n=4,5$.",
     "Central products glued along a proper subgroup when $\\sigma$ is not a $2^{j+1}$-th power: $12$ of the $212$ splittings of candidates of orders $2^8$–$2^9$ are covered by nothing. A projection to $H$ cannot do it in general: for $D_8\\circ_{\\langle t\\rangle}M_{16}$ the ring equality fails at $n=4,5$."),
]

# Funnels of the searches: (id, ru title, en title, [(ru, en, n)], ref). The last step is the number
# of groups with D_5 != 1 (resp. z in D_5): zero in every search so far.
FUNNELS = [
    ("f210", "Порядок $2^{10}$, ступень $3$", "Order $2^{10}$, class $3$", [
        ("родители порядка $2^9$ (ступень $2$–$3$, циклическая $\\gamma_3$)", "parents of order $2^9$ (class $2$–$3$, cyclic $\\gamma_3$)", 1422862),
        ("шаг-$1$ потомки (ANUPQ)", "step-$1$ descendants (ANUPQ)", 1819675),
        ("ступени $3$", "of class $3$", 88809),
        ("кандидаты: центр цикличен, $n\\in\\gamma_3\\cap M_5$", "candidates: cyclic centre, $n\\in\\gamma_3\\cap M_5$", 3400),
        ("$D_5\\ne1$", "$D_5\\ne1$", 0)], "[[prop:1024]]"),
    ("f211", "Порядок $2^{11}$, ранг $4$", "Order $2^{11}$, rank $4$", [
        ("вершины порядка $2^{10}$, ранг $4$", "vertices of order $2^{10}$, rank $4$", 946663 + 52181),
        ("оставлены отсечением как родители", "kept by the pruning as parents", 52181),
        ("кандидаты порядка $2^{11}$", "candidates of order $2^{11}$", 52568),
        ("$D_5\\ne1$", "$D_5\\ne1$", 0)], ("[[sec:computations]], «Дальнейшее»", "[[sec:computations]], “Next”")),
    ("f38", "Порядок $3^8$", "Order $3^8$", [
        ("все группы порядка $3^8$", "all groups of order $3^8$", 1396077),
        ("ранг $3$ или $4$, ступень $4$", "rank $3$ or $4$, class $4$", 62257),
        ("неметабелевы (все ранга $3$)", "non-metabelian (all of rank $3$)", 904),
        ("$z\\in Q''\\cap M_5$", "$z\\in Q''\\cap M_5$", 699),
        ("$z\\in D_5$", "$z\\in D_5$", 0)], "[[thm:3e9]]"),
    ("f39", "Порядок $3^9$, ранги $3$–$4$", "Order $3^9$, ranks $3$–$4$", [
        ("все группы порядка $3^8$", "all groups of order $3^8$", 1396077),
        ("родители: ранг $3$–$4$, ступень $3$–$4$", "parents: rank $3$–$4$, class $3$–$4$", 771597),
        ("проходят фильтр по $p$-накрытию", "pass the $p$-cover filter", 3986),
        ("шаг-$1$ потомки", "step-$1$ descendants", 305583),
        ("ступень $4$, $Q''\\ne1$, центр цикличен", "class $4$, $Q''\\ne1$, cyclic centre", 64362),
        ("кандидаты: $z\\in Q''\\cap M_5$", "candidates: $z\\in Q''\\cap M_5$", 62245),
        ("$z\\in D_5$", "$z\\in D_5$", 0)], "[[thm:3e9]]"),
]

RUNS = [  # (what ru, what en, groups, result ru, result en, cost ru, cost en, code)
    ("все $2$-группы порядков $8$–$128$", "all $2$-groups of orders $8$–$128$", 2665,
     "$D_n=\\gamma_n$ при всех $n$", "$D_n=\\gamma_n$ for all $n$", "", "", "compute"),
    ("группы порядка $2^8$ ступени $\\ge3$", "groups of order $2^8$ of class $\\ge3$", 24328,
     "$D_n=\\gamma_n$ при всех $n$", "$D_n=\\gamma_n$ for all $n$", "", "", "compute"),
    ("метабелевы группы порядка $2^9$ ступени $3$ (сито Дженнингса)", "metabelian groups of order $2^9$ of class $3$ (Jennings sieve)", 1587389,
     "после сита $2792$, у всех $D_4=D_5=1$", "$2792$ left by the sieve, all $D_4=D_5=1$", "", "", "compute"),
    ("порядок $2^{10}$, ступень $3$ (ANUPQ)", "order $2^{10}$, class $3$ (ANUPQ)", 3400,
     "у всех кандидатов $D_4=D_5=1$", "all candidates $D_4=D_5=1$", "$63$ + $21$ проц.-ч", "$63$ + $21$ CPU-h", "compute/pq1024"),
    ("порядок $2^{11}$, ранги $2$, $3$, $4$", "order $2^{11}$, ranks $2$, $3$, $4$", 17 + 586 + 52568,
     "у всех кандидатов $D_4=D_5=1$", "all candidates $D_4=D_5=1$", "$\\approx20$ проц.-ч (ранг $4$)", "$\\approx20$ CPU-h (rank $4$)", "compute/pq2048"),
    ("все $3$-группы порядков $3^4$–$3^6$", "all $3$-groups of orders $3^4$–$3^6$", 586,
     "$D_n=\\gamma_n$ при всех $n$", "$D_n=\\gamma_n$ for all $n$", "", "", "compute"),
    ("порядок $3^7$, ступень $4$, после сита", "order $3^7$, class $4$, after the sieve", 1202,
     "$D_5=1$ двумя методами", "$D_5=1$ by two methods", "", "", "compute"),
    ("порядок $3^8$, неметабелевы ступени $4$", "order $3^8$, non-metabelian of class $4$", 699,
     "$z\\notin D_5$ у всех", "$z\\notin D_5$ in all", "$26$ мин", "$26$ min", "compute/magnus"),
    ("порядок $3^9$, ранги $3$–$4$", "order $3^9$, ranks $3$–$4$", 62245,
     "$z\\notin D_5$ у всех; копредставления перепроверены ANUPQ", "$z\\notin D_5$ in all; presentations rechecked with ANUPQ",
     "$3$ ч $21$ мин на $4$ ядрах", "$3$ h $21$ min on $4$ cores", "compute/magnus"),
    ("случайные группы с $Q/\\gamma_2$ экспоненты $3$, $3^{10}$–$3^{79}$", "random groups with $Q/\\gamma_2$ of exponent $3$, $3^{10}$–$3^{79}$", 169,
     "$D_5=1$ у всех (проверка теоремы [[thm:exp3|#]])", "$D_5=1$ in all (a check of Thm. [[thm:exp3|#]])", "$5$ мин", "$5$ min", "compute/magnus"),
    ("факторы групп рипсовского типа, $2^{40}$–$2^{107}$", "quotients of Rips-type groups, $2^{40}$–$2^{107}$", 14,
     "$D_5=1$; $D_4\\ne1$ в трёх", "$D_5=1$; $D_4\\ne1$ in three", "", "", "compute/magnus"),
]

TIMELINE = [  # (iso date, [(ru, en)])
    ("2026-10-14", [
        ("Проверена формализация Ионина–Михайлова–Петрова в Lean (сборка, аксиомы).",
         "The Lean formalization of Ionin–Mikhailov–Petrov audited (build, axioms)."),
        ("Размерные подгруппы групп в Lean: $\\gamma_n\\subseteq D_n$, $D_2=\\gamma_2$, вопрос о $D_5$ сформулирован.",
         "Group dimension subgroups in Lean: $\\gamma_n\\subseteq D_n$, $D_2=\\gamma_2$, the $D_5$ question stated."),
        ("Черновик статьи: сведение к $2$-группам ступени $3$; где не переносится доказательство для колец Ли.",
         "Paper draft: the reduction to $2$-groups of class $3$; where the Lie-ring proof does not transfer.")]),
    ("2026-10-15", [
        ("Точное вычисление $D_n$ для малых $p$-групп: все $2$-группы до $2^7$, $2^8$ ступени $\\ge3$, метабелевы $2^9$ ступени $3$, $3$-группы до $3^6$.",
         "Exact computation of $D_n$ for small $p$-groups: all $2$-groups up to $2^7$, $2^8$ of class $\\ge3$, metabelian $2^9$ of class $3$, $3$-groups up to $3^6$."),
        ("Оценка Тахары сверена с оригиналом; нет $3$-кручения до $3^7$ (Гупта–Тахара).",
         "Tahara's bound checked against the original; no $3$-torsion up to $3^7$ (Gupta–Tahara)."),
        ("Усечённая алгебра Магнуса: факторы групп рипсовского типа, $D_4\\ne1$ при $2^{84}$, $2^{90}$, $2^{107}$ доказано, $D_5=1$.",
         "Truncated Magnus algebra: quotients of Rips-type groups, $D_4\\ne1$ at $2^{84}$, $2^{90}$, $2^{107}$ proved, $D_5=1$.")]),
    ("2026-10-16", [
        ("Порядок $2^{10}$ закрыт: лемма о минимальном контрпримере, ANUPQ, $3400$ кандидатов.",
         "Order $2^{10}$ closed: the minimal-counterexample lemma, ANUPQ, $3400$ candidates."),
        ("Отсечение без потерь в дереве $2$-групп для $2^{11}$; ранги $2$–$3$ и $\\ge8$ закрыты.",
         "Lossless pruning of the $2$-group tree for $2^{11}$; ranks $2$–$3$ and $\\ge8$ closed."),
        ("$2^{11}$, ранг $4$: $52\\,568$ кандидатов, у всех $D_4=D_5=1$.",
         "$2^{11}$, rank $4$: $52\\,568$ candidates, all with $D_4=D_5=1$.")]),
    ("2026-10-17", [
        ("Групповой аналог теоремы C: у группы плато $D_7=1$; первый поиск при $c=4$; при $c=5$ $D_7\\ne1$, но $D_8\\cap\\gamma_5=1$.",
         "The group analogue of Theorem C: $D_7=1$ for the plateau group; the first search at $c=4$; at $c=5$, $D_7\\ne1$ but $D_8\\cap\\gamma_5=1$."),
        ("Порядок $3^8$: полный перебор, $904$ неметабелевы группы, у всех $D_5=1$.",
         "Order $3^8$: the full scan, $904$ non-metabelian groups, $D_5=1$ in all."),
        ("Порядок $3^9$: фильтр по $p$-накрытию, $62\\,245$ кандидатов, у всех $D_5=1$; ранг $5$ исключён на бумаге.",
         "Order $3^9$: the $p$-cover filter, $62\\,245$ candidates, $D_5=1$ in all; rank $5$ excluded on paper."),
        ("На бумаге: $D_5=\\gamma_5$ при $Q/\\gamma_2$ экспоненты $3$; лемма о кольцах Ли; $P^{*\\prime\\prime}=1$. Две независимые построчные рецензии.",
         "On paper: $D_5=\\gamma_5$ for $Q/\\gamma_2$ of exponent $3$; the Lie-ring lemma; $P^{*\\prime\\prime}=1$. Two independent line-by-line reviews.")]),
    ("2026-10-18", [
        ("На бумаге: $D_5=\\gamma_5$, если у $Q/\\gamma_2$ не больше одного инварианта больше $3$ (в том числе $C_9\\times C_3^{s-1}$); независимая рецензия ошибок не нашла.",
         "On paper: $D_5=\\gamma_5$ when $Q/\\gamma_2$ has at most one invariant larger than $3$ (including $C_9\\times C_3^{s-1}$); an independent review found no errors."),
        ("Литература: что на самом деле анонсировал Тахара (с. 173) и поиск его отдельной работы.",
         "References: what Tahara actually announced (p. 173), and the search for his separate paper."),
        ("Проверка вычислением для $C_9\\times C_3^{s-1}$ и $C_{27},C_{81}\\times C_3^{s-1}$: $2\\,057$ групп, $4\\,537$ элементов $z$, ни один не лежит в $D_5$.",
         "Computer check for $C_9\\times C_3^{s-1}$ and $C_{27},C_{81}\\times C_3^{s-1}$: $2\\,057$ groups, $4\\,537$ elements $z$, none in $D_5$."),
        ("Аудит ANUPQ (<a href=\"https://ispacex.github.io/gap/\">ispacex.github.io/gap</a>): шаг порождения для $3^9$ повторён на исправленной версии, результат совпал побайтно.",
         "ANUPQ audit (<a href=\"https://ispacex.github.io/gap/\">ispacex.github.io/gap</a>): the $3^9$ descendant step was repeated with the fixed version, and the result is byte-identical."),
        ("На бумаге: $D_n(H\\circ E)=D_n(H)$ для центральных произведений с $D_8$, $Q_8$ и $M_{2^{k+2}}$ (присоединение центрального квадратного корня); у всех $386$ кандидатов порядков $2^6$–$2^9$ условия выполнены. Две независимые рецензии.",
         "On paper: $D_n(H\\circ E)=D_n(H)$ for central products with $D_8$, $Q_8$ and $M_{2^{k+2}}$ (adjoining a central square root); all $386$ candidates of orders $2^6$–$2^9$ satisfy the conditions. Two independent reviews."),
        ("На бумаге: склейка по собственной подгруппе $Z(E)$ — лемма о центральном корне любой степени (лемма 5.9). Перебор разложений $386$ кандидатов: $20$ раскладываются, у каждого есть разложение, покрытое предложением 5.8. Независимая рецензия и пересчёт другим методом.",
         "On paper: gluing along a proper subgroup of $Z(E)$ — a lemma on central roots of any degree (Lemma 5.9). The splittings of the $386$ candidates: $20$ split, each has a splitting covered by Prop. 5.8. An independent review and a recount by another method."),
        ("Lean: лемма 5.9 (центральный корень любой степени) доказана в Lean, без <code>sorry</code>, только стандартные аксиомы; начата формализация остальных результатов «на бумаге».",
         "Lean: Lemma 5.9 (a central root of any degree) is proved in Lean, with no <code>sorry</code> and only the standard axioms; formalizing the other paper results has started."),
        ("Lean: предложение 5.8 доказано в Lean во всех случаях ($D_8$, $Q_8$, $M_{2^{k+2}}$), вместе с кольцевым утверждением $\\mathbb Z[H]\\cap\\Delta(Q)^n=\\Delta(H)^n$; $Q_8$ и $M_{2^{k+2}}$ сводятся к $D_8$ через одну надгруппу $(Q\\times\\mathbb Z)/\\langle(s,-2)\\rangle$.",
         "Lean: Prop. 5.8 is proved in Lean in all cases ($D_8$, $Q_8$, $M_{2^{k+2}}$), with the ring statement $\\mathbb Z[H]\\cap\\Delta(Q)^n=\\Delta(H)^n$; $Q_8$ and $M_{2^{k+2}}$ reduce to $D_8$ through one overgroup $(Q\\times\\mathbb Z)/\\langle(s,-2)\\rangle$."),
        ("Lean: сведение (предложение 2.1, замечание 2.3) доказано по модулю явных гипотез — теорем Пасси, Грюнберга и $D_3=\\gamma_3$: от ступени $\\le3$ к конечно порождённым группам и к конечным $2$-группам ступени $3$; для конечных групп теорема Грюнберга не нужна.",
         "Lean: the reduction (Prop. 2.1, Remark 2.3) is proved modulo explicit hypotheses — the theorems of Passi and Gruenberg and $D_3=\\gamma_3$: from class $\\le3$ to finitely generated groups and to finite $2$-groups of class $3$; for finite groups Gruenberg's theorem is not needed."),
        ("Lean: лемма 6.3 и предложение 6.5 ($[\\gamma_2,\\gamma_2]\\subseteq\\gamma_5$; неметабелева $p$-группа ступени $4$ ранга $d$ имеет порядок $\\ge p^{d+5}$) доказаны в Lean без гипотез; вместо кольца Ли — группа $G/\\gamma_5$ и тождество Холла — Витта.",
         "Lean: Lemma 6.3 and Prop. 6.5 ($[\\gamma_2,\\gamma_2]\\subseteq\\gamma_5$; a non-metabelian $p$-group of class $4$ and rank $d$ has order $\\ge p^{d+5}$) are proved in Lean with no hypotheses; instead of the Lie ring, the group $G/\\gamma_5$ and the Hall–Witt identity."),
        ("Lean: теоремы 6.6 и 6.8 ($D_5=\\gamma_5$ при $G/\\gamma_2\\cong C_{3^a}\\times C_3^{s-1}$) доказаны в Lean по модулю теоремы 6.1 Тахары, записанной явной гипотезой и сверенной со сканом; оба подслучая, включая строку $s$ условия (E).",
         "Lean: Theorems 6.6 and 6.8 ($D_5=\\gamma_5$ for $G/\\gamma_2\\cong C_{3^a}\\times C_3^{s-1}$) are proved in Lean modulo Tahara's Theorem 6.1, stated as an explicit hypothesis and checked against the scan; both subcases, including the row $s$ of condition (E).")]),
    ("2026-10-19", [
        ("Lean: теорема 6.1 Тахары (описание $D_5$ для конечных групп ступени $\\le4$) доказана в Lean, без <code>sorry</code>, только стандартные аксиомы; теоремы 6.6 и 6.8 теперь доказаны в Lean без гипотез. При формализации найдена опечатка в нашей записи условия (C₂) Тахары; исправлена до доказательства.",
         "Lean: Tahara's Theorem 6.1 (the description of $D_5$ for finite groups of class $\\le4$) is proved in Lean, with no <code>sorry</code> and only the standard axioms; Theorems 6.6 and 6.8 are now proved in Lean with no hypotheses. The formalization found a typo in our transcription of Tahara's condition (C₂); it was fixed before the proof.")]),
]


def cover2(n, d):
    """Status of 'D_5(Q)=1 for all 2-groups Q of order 2^n, rank d, class 3' (None: no such group)."""
    if d > n - 2:  # class 3 needs |gamma_2/gamma_3|, |gamma_3| >= 2
        return None
    if n <= 9:
        return "c", "[[prop:computer]]"
    if n == 10:
        return "cp", "[[prop:1024]]"
    if d in (2, 3, 4, 8):
        return "cp", "[[prop:rank8]]" if d == 8 else "[[sec:computations]]"
    if d == 9:
        return "p", "[[prop:rank8]]"
    return "o", None


def cover3(n, d):
    """Status of 'D_5(Q)=gamma_5(Q) for all 3-groups Q of order 3^n and rank d'."""
    if d > n:
        return None
    if d == 1 or n <= 7 or d == 2 or n < d + 5:
        # cyclic; or Q/gamma_5 of class <= 4 is metabelian (Prop. 6.5: non-metabelian needs
        # order >= 3^(d+5); for d = 2, gamma_2/gamma_3 is cyclic) and Gupta-Tahara applies
        return "p", "[[prop:metab]] + [GT85]"
    if n == 8:
        return "cp", "[[thm:exp3]], [[thm:3e9]]"
    if n == 9:
        return "c", "[[thm:3e9]]"
    return "o", "[[thm:exp3plus]]"  # open; the part with at most one invariant > 3 in Q/gamma_2 is proved


def grid(rows, cols, cover, p, lang, highlight=()):
    """A coverage map as inline SVG: rows = orders p^n, columns = ranks d."""
    t = (lambda ru, en: ru if lang == "ru" else en)
    cw, ch, left, top = 46, 30, 64, 34
    w, h = left + cw * len(cols) + 8, top + ch * len(rows) + 8
    s = [f'<svg viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{t("Карта покрытия", "Coverage map")}">',
         ('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
          '<rect width="6" height="6" style="fill:var(--open)"/><line x1="0" y1="0" x2="0" y2="6" style="stroke:var(--ppr);stroke-width:3"/></pattern></defs>'
          if p == 3 else ""),  # one pattern per page: only the 3-group map is hatched
         f'<text x="{left + cw * len(cols) / 2}" y="12" text-anchor="middle" class="muted">{t("ранг", "rank")} $d$</text>'.replace("$d$", "d"),
         f'<text x="6" y="{top - 8}" class="muted">{t("порядок", "order")}</text>']
    for j, d in enumerate(cols):
        s.append(f'<text x="{left + cw * j + cw / 2}" y="{top - 8}" text-anchor="middle">{d}</text>')
    for i, n in enumerate(rows):
        y = top + ch * i
        s.append(f'<text x="{left - 8}" y="{y + ch / 2 + 4}" text-anchor="end">{p}<tspan dy="-6" font-size="9">{n}</tspan></text>')
        for j, d in enumerate(cols):
            x = left + cw * j
            c = cover(n, d)
            if c is None:
                s.append(f'<rect class="cell k-n" x="{x}" y="{y}" width="{cw}" height="{ch}" rx="3"/>')
                continue
            k, where = c
            kind = "x" if (k == "o" and p == 3) else k
            tip = f"{p}{str(n).translate(SUP)}, d = {d}: {STATUS[k][0 if lang == 'ru' else 1]}" + (f" ({refs_plain(where, lang)})" if where else "")
            if kind == "x":
                tip += t(" — доказан случай, когда у $Q/\\gamma_2$ не больше одного инварианта $>3$", " — the case of $Q/\\gamma_2$ with at most one invariant $>3$ is proved").replace("$", "").replace("\\gamma_2", "γ₂")
            lab = {"c": "C", "p": "P", "cp": "C+P", "o": "?", "x": "?"}[kind]
            cell = (f'<rect class="cell k-{kind}" x="{x}" y="{y}" width="{cw}" height="{ch}" rx="3"><title>{html.escape(tip)}</title></rect>'
                    f'<text class="ct" x="{x + cw / 2}" y="{y + ch / 2 + 4}" text-anchor="middle">{lab}</text>')
            first = PAPER_REF.search(where or "")
            if first:  # the cell opens the statement it rests on
                cell = f'<a href="{paper_href(first.group(1))}">{cell}</a>'
            s.append(cell)
            if (n, d) in highlight:
                s.append(f'<rect class="hl" x="{x + 1}" y="{y + 1}" width="{cw - 2}" height="{ch - 2}" rx="3"/>')
    s.append("</svg>")
    return '<div class="fig">' + "".join(s) + "</div>"


def legend(lang, three=False):
    t = (lambda ru, en: ru if lang == "ru" else en)
    items = [("c", "C", t("компьютер", "computer")), ("cp", "C+P", t("компьютер + бумага", "computer + paper")),
             ("p", "P", t("на бумаге", "paper")), ("o", "?", t("открыто", "open"))]
    out = " ".join(f'<span class="tag {k}">{lab}</span> {txt}' for k, lab, txt in items)
    if three:
        out = out.replace('<span class="tag o">?</span> ' + t("открыто", "open"),
                          '<span class="tag o" style="background:repeating-linear-gradient(45deg,var(--open) 0 4px,var(--ppr) 4px 7px)">?</span> '
                          + t("открыто; доказан случай, когда у $Q/\\gamma_2$ не больше одного инварианта $>3$ (теорема [[thm:exp3plus|#]])",
                              "open; the case of $Q/\\gamma_2$ with at most one invariant $>3$ proved ([[thm:exp3plus]])"))
    return f"<p><small>{out}. {t('Пустые клетки: таких групп нет.', 'Empty cells: no such groups.')}</small></p>"


def funnel(steps, lang):
    """Horizontal bars on a log scale; the last step (the count of counterexamples) drawn as a mark."""
    import math
    li = 0 if lang == "ru" else 1
    w, lw, bh, gap = 760, 330, 20, 8
    big = max(n for *_, n in steps)
    h = (bh + gap) * len(steps) + 6
    s = [f'<svg viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img">']
    for i, st in enumerate(steps):
        n = st[2]
        y = 4 + i * (bh + gap)
        label = svg_text(st[li])
        s.append(f'<text x="{lw - 8}" y="{y + bh / 2 + 4}" text-anchor="end">{html.escape(label)}</text>')
        if n == 0:
            s.append(f'<rect class="bar0" x="{lw}" y="{y}" width="{bh}" height="{bh}" rx="3"/>'
                     f'<text x="{lw + bh / 2}" y="{y + bh / 2 + 4}" text-anchor="middle">0</text>')
            continue
        bw = max(2, (w - lw - 90) * math.log10(n + 1) / math.log10(big + 1))
        s.append(f'<rect class="bar" x="{lw}" y="{y}" width="{bw:.1f}" height="{bh}" rx="3"/>'
                 f'<text x="{lw + bw + 6:.1f}" y="{y + bh / 2 + 4}">{num(n, lang)}</text>')
    s.append("</svg>")
    return '<div class="fig">' + "".join(s) + "</div>"


SUP = str.maketrans("0123456789+-", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻")
SUB = str.maketrans("0123456789", "₀₁₂₃₄₅₆₇₈₉")


def svg_text(s):
    """TeX of a short label for SVG, where there is no KaTeX: exponents and indices as Unicode."""
    for a, b in (("\\gamma", "γ"), ("\\ne", "≠"), ("\\in", "∈"), ("\\cap", "∩"), ("''", "″")):
        s = s.replace(a, b)
    s = re.sub(r"\^\{([0-9+-]+)\}", lambda m: m.group(1).translate(SUP), s)
    s = re.sub(r"\^([0-9])", lambda m: m.group(1).translate(SUP), s)
    s = re.sub(r"_\{?([0-9]+)\}?", lambda m: m.group(1).translate(SUB), s)
    return s.replace("$", "")


def ref(s, lang):
    """A reference of RESULTS or FUNNELS: one string for both languages, or (ru, en)."""
    return s if isinstance(s, str) else s[0 if lang == "ru" else 1]


def tag(k, lang):
    return f'<span class="tag {k}">{STATUS[k][0 if lang == "ru" else 1]}</span>'


# ---------------------------------------------------------------------------------------------
# The paper

def braced(s, i):
    """s[i] == '{': the text up to the matching brace, and the index after it."""
    depth, j = 0, i
    while True:
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j + 1
        j += 1


def tex_inline(s):
    """A bit of LaTeX prose for HTML: math is left to KaTeX, a few text macros are translated."""
    s = re.sub(r"\\label\{[^}]*\}", "", s)
    s = re.sub(r"~?\\cite(\[[^\]]*\])?\{([^}]*)\}", lambda m: f" [{m.group(2)}{', ' + m.group(1)[1:-1] if m.group(1) else ''}]", s)
    for a, b in (("\\emph{", "<em>"), ("\\textbf{", "<b>"), ("\\textnormal{", "<span>")):
        while a in s:
            i = s.index(a)
            inner, j = braced(s, i + len(a) - 1)
            close = {"<em>": "</em>", "<b>": "</b>", "<span>": "</span>"}[b]
            s = s[:i] + b + inner + close + s[j:]
    for a, b in (("---", "—"), ("--", "–"), ("~", " "), ("``", "“"), ("''", "”"), ("<<", "«"), (">>", "»"),
                 ("\\,", " "), ("\\ ", " ")):
        s = s.replace(a, b)
    s = re.sub(r"\\S(?![A-Za-z])", "§", s)
    return s.strip()


def read_abstract(tex):
    s = tex.read_text(encoding="utf-8")
    a = s.index("\\begin{abstract}") + len("\\begin{abstract}")
    return tex_inline(s[a:s.index("\\end{abstract}")])


def groups(s, k=None):
    """The top-level {...} groups of s, in order (the first k): '{1}{The question}' -> ['1', 'The question']."""
    out, i = [], 0
    while k is None or len(out) < k:
        i = s.find("{", i)
        if i < 0:
            break
        g, i = braced(s, i)
        out.append(g)
    return out


# What a label names, by its prefix (the drafts keep to it): words for the links, full and short.
KINDS = {"thm": ("Теорема", "Теор.", "Theorem", "Thm."), "prop": ("Предложение", "Предл.", "Proposition", "Prop."),
         "lem": ("Лемма", "Лемма", "Lemma", "Lemma"), "rem": ("Замечание", "Зам.", "Remark", "Rem."),
         "q": ("Вопрос", "Вопрос", "Question", "Question"), "sec": ("Раздел", "§", "Section", "§"),
         "section": ("Раздел", "§", "Section", "§"),
         "oq": ("Открытый вопрос", "вопрос", "Open question", "question")}


def read_aux(aux, tex):
    r"""Labels, named destinations and contents of one compiled draft, from its .aux.

    labels: label -> (number, page) for every label that names a destination of the PDF (destlabel
    renames the anchor of the first \label after it); toc: (level, number, title, page, dest) of the
    sections and subsections; titles: label -> the optional argument of its theorem environment."""
    rename = dict(re.findall(r"\\hyper@newdestlabel\{([^{}]*)\}\{([^{}]*)\}", aux))
    named = set(rename.values())
    labels = {}
    for m in re.finditer(r"\\newlabel\{([^{}]*)\}\{", aux):
        g = groups(braced(aux, m.end() - 1)[0])
        if m.group(1) in named and len(g) >= 4:
            labels[m.group(1)] = (g[0], int(g[1]))
    toc = []
    for m in re.finditer(r"\\contentsline \{(section|subsection)\}\{", aux):
        g = groups(aux[m.end() - 1:], 3)
        head, page, anchor = g[0], g[1], g[2]
        _, number, title = groups(head)[-3:]
        dest = rename.get(anchor, anchor)
        toc.append((m.group(1), number, title, int(page), dest))
        if dest == anchor and number:  # a section without a label: hyperref's name, section.N
            labels[dest] = (number, int(page))
    titles = {}
    for m in re.finditer(r"\\begin\{(theorem|proposition|lemma|remark|question)\}", tex):
        j = m.end()
        opt = ""
        if tex[j] == "[":  # the optional argument, brackets inside braces allowed
            depth, k = 0, j
            while True:
                c = tex[k]
                depth += c in "{["
                depth -= c in "}]"
                if depth == 0:
                    break
                k += 1
            opt, j = tex[j + 1:k], k + 1
        lab = re.match(r"\s*\\label\{([^{}]*)\}", tex[j:])
        if lab:
            titles[lab.group(1)] = opt
    return {"labels": labels, "toc": toc, "titles": titles}


PAPERS = {}  # lang -> read_aux() of its draft, filled by main()
PAPER_REF = re.compile(r"\[\[([A-Za-z0-9:._-]+)(?:\|([^\]]*))?\]\]")
USED = set()  # labels the pages link to


def paper_entry(label, lang):
    """(kind words, number, page) of a label, or stop the build: it must be in both drafts, with the
    same number."""
    for l in LANGS:
        if label not in PAPERS[l]["labels"]:
            sys.exit(f"the site links to [[{label}]], which is not a label of {PDF[l]}.tex "
                     f"(labels: {', '.join(sorted(PAPERS[l]['labels']))})")
    if PAPERS["ru"]["labels"][label][0] != PAPERS["en"]["labels"][label][0]:
        sys.exit(f"[[{label}]] has different numbers in the two drafts: {PAPERS['ru']['labels'][label][0]}, "
                 f"{PAPERS['en']['labels'][label][0]}")
    kind = re.split(r"[:.]", label)[0]
    if kind not in KINDS:
        sys.exit(f"[[{label}]]: unknown kind {kind!r} (known: {', '.join(KINDS)})")
    USED.add(label)
    number, pg = PAPERS[lang]["labels"][label]
    return KINDS[kind][:2] if lang == "ru" else KINDS[kind][2:], number, pg


def paper_href(label, viewer=""):
    """The viewer at the destination; viewer: the path of viewer.html from the page."""
    return f"{viewer}viewer.html#nameddest={label}"


def paper_text(label, lang, short=True):
    (full, abbr), number, pg = paper_entry(label, lang)
    word = abbr if short else full
    return f"{word}{number}" if word == "§" else f"{word}\u00a0{number}"


def paper_link(label, lang, text=None, viewer=""):
    """A link to the statement with this \\label in the paper of the page's language, opening the viewer
    at it; text: what the link says (default "Thm. 5.4"; "#" for the number alone)."""
    (full, abbr), number, pg = paper_entry(label, lang)
    if text is None:
        text = paper_text(label, lang)
    elif text == "#":
        text = number
    tip = (f"{full} {number}, с. {pg} черновика" if lang == "ru" else f"{full} {number}, p. {pg} of the draft")
    if full == "Раздел" or full == "Section":
        tip = (f"§{number}, с. {pg} черновика" if lang == "ru" else f"§{number}, p. {pg} of the draft")
    return f'<a class="pl" href="{paper_href(label, viewer)}" title="{html.escape(tip)}">{text}</a>'


def expand_refs(s, lang):
    """[[label]], [[label|#]], [[label|text]] -> paper_link(); [[label|##]] -> the number alone, not a link
    (inside the text of another link)."""
    return PAPER_REF.sub(lambda m: paper_entry(m.group(1), lang)[1] if m.group(2) == "##"
                         else paper_link(m.group(1), lang, m.group(2)), s)


def refs_plain(s, lang):
    """The references of s as plain text (for SVG titles, where there are no links)."""
    return PAPER_REF.sub(lambda m: paper_text(m.group(1), lang) if m.group(2) in (None, "") else
                         (paper_entry(m.group(1), lang)[1] if m.group(2) == "#" else m.group(2)), s)


def build_pdfs(dest):
    """Compile both drafts in a scratch copy of PAPER (twice, for the references), with every \\label a
    named destination (hyperref's destlabel, passed on the command line: the sources stay as they are).
    Yields the name, the number of pages and read_aux() of each."""
    with tempfile.TemporaryDirectory() as tmp:
        for f in PAPER.glob("*.tex"):
            shutil.copy(f, tmp)
        for name in PDF.values():
            for _ in range(2):
                r = subprocess.run(["pdflatex", "-interaction=nonstopmode", "-halt-on-error", f"-jobname={name}",
                                    f"\\PassOptionsToPackage{{destlabel}}{{hyperref}}\\input{{{name}.tex}}"],
                                   cwd=tmp, capture_output=True, text=True, errors="replace")
                if r.returncode:
                    sys.exit(f"pdflatex failed on {name}.tex:\n" + r.stdout[-2000:])
            log = (pathlib.Path(tmp) / (name + ".log")).read_text(errors="replace")
            if "undefined" in log and "Reference" in log:
                sys.exit(f"{name}.tex: undefined references")
            pages = re.search(r"Output written on .*?\((\d+) pages", log)
            shutil.copy(pathlib.Path(tmp) / (name + ".pdf"), dest / (name + ".pdf"))
            aux = read_aux((pathlib.Path(tmp) / (name + ".aux")).read_text(errors="replace"),
                           (PAPER / (name + ".tex")).read_text(encoding="utf-8"))
            yield name, int(pages.group(1)) if pages else None, aux


def paper_date():
    r = subprocess.run(["git", "-C", str(PAPER), "log", "-1", "--format=%cs", "--", "."], capture_output=True, text=True)
    return r.stdout.strip() or datetime.date.today().isoformat()


RU_MONTHS = ("января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря")


def fmt_date(iso):
    d = datetime.date.fromisoformat(iso)
    return {"ru": f"{d.day} {RU_MONTHS[d.month - 1]} {d.year}", "en": f"{d.day} {d.strftime('%B')} {d.year}"}


# ---------------------------------------------------------------------------------------------

def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "paper").mkdir(parents=True)
    pdfs = {}
    for name, n, aux in build_pdfs(OUT / "paper"):
        pdfs[name] = n
        PAPERS[next(l for l in LANGS if PDF[l] == name)] = aux
    pdate = paper_date()
    date = fmt_date(max(pdate, TIMELINE[-1][0]))
    paper = {lang: read_abstract(PAPER / f"{PDF[lang]}.tex") for lang in LANGS}
    for lang in LANGS:
        site(lang, date, paper, pdfs, fmt_date(pdate))
        viewer(lang)
    nblocks = write_search({h: i for i, (h, _, _) in enumerate(NAV)})
    print("search index:", sum(1 for p in PAGES if p[1] != "search.html"), "pages,", nblocks, "blocks")
    for lang in LANGS:
        shutil.copy(HERE / f"og-{lang}.png", OUT / f"og-{lang}.png")
    (OUT / ".nojekyll").write_text("")
    print("site written to", OUT, "| paper of", pdate, "| pages:", pdfs, "| paper links:", len(USED), "labels",
          "| code at", PIN[:7])


def site(lang, date, paper, pdfs, pdate):
    def t(ru, en):
        return ru if lang == "ru" else en
    li = 0 if lang == "ru" else 1

    def P(fn, title, body, contact=False):
        page(lang, fn, title, body, date, contact)

    # ---------- summary ----------
    n2 = sum(1 for n in range(4, 12) for d in range(2, 10) if cover2(n, d) and cover2(n, d)[0] != "o")
    o2 = sum(1 for n in range(4, 12) for d in range(2, 10) if cover2(n, d) and cover2(n, d)[0] == "o")
    P("index.html", t("Задача о $D_5$: где мы сейчас", "The $D_5$ problem: where we are"), t(f"""
<div class="box"><p><b>Вопрос</b> (Коуровская тетрадь, задача 20.84). Пусть $\\Delta$&nbsp;— фундаментальный идеал $\\mathbb Z[G]$,
$D_n(G)=G\\cap(1+\\Delta^n)$&nbsp;— размерные подгруппы, $\\gamma_n(G)$&nbsp;— нижний центральный ряд. Всегда $\\gamma_n\\subseteq D_n$,
и $D_n=\\gamma_n$ при $n\\le3$; при $n=4$ это неверно (Рипс). <b>Верно ли $D_5(G)\\subseteq\\gamma_4(G)$ для всякой группы?</b></p>
<p>Для колец Ли ответ «да» (Ионин, Михайлов, Петров, 2026, с формализацией в Lean). Для групп вопрос открыт;
мы его не решили. Здесь — что доказано, что посчитано и что осталось.</p></div>
<div class="cards">
<div class="card"><h3>$2$-кручение: $D_5\\subseteq\\gamma_4$</h3><div class="big">до $2^{{10}}$</div>
<p>Верно для всякой конечной группы с силовской $2$-подгруппой порядка $\\le2^{{10}}$, в частности для всех групп порядка $<2048$.</p>
<p>Порядок $2^{{11}}$: закрыты ранги $2$–$4$ и $\\ge8$, открыты $5$–$7$.</p></div>
<div class="card"><h3>$3$-кручение: $D_5=\\gamma_5$</h3><div class="big">до $3^9$</div>
<p>Нет $3$-кручения в $D_5/\\gamma_5$, если силовская $3$-подгруппа имеет порядок $\\le3^9$.</p>
<p>На бумаге — для всех групп, у которых $G/\\gamma_2$ имеет не больше одного инварианта больше $3$ (например, экспоненту $3$ или $C_9\\times C_3^{{s-1}}$), любого порядка.</p></div>
<div class="card"><h3>Кольца Ли и Lean</h3><div class="big">доказано</div>
<p>$D_5(L)\\subseteq\\gamma_4(L)$ для колец Ли; формализация проверена. Групповой вопрос и сведение к $2$-группам ступени $3$ сформулированы в Lean.</p></div>
<div class="card"><h3>Контрпримеров</h3><div class="big">0</div>
<p>Ни в одной из посчитанных групп $D_5\\ne\\gamma_5$; везде $D_n=\\gamma_n$ при всех $n$. Больше ста тысяч кандидатов, все вычисления точные.</p></div>
</div>
<h2>Карта покрытия: $2$-группы ступени $3$</h2>
<p>Клетка&nbsp;— все $2$-группы ступени $3$ данного порядка и ранга; закрыта, если для всех них $D_5=1$.
Закрыто {n2} клеток, открыто {o2}. Подробнее&nbsp;— <a href="coverage.html">карта покрытия</a>.</p>
""", f"""
<div class="box"><p><b>The question</b> (Kourovka notebook, Problem 20.84). Let $\\Delta$ be the augmentation ideal of $\\mathbb Z[G]$,
$D_n(G)=G\\cap(1+\\Delta^n)$ the dimension subgroups and $\\gamma_n(G)$ the lower central series. Always $\\gamma_n\\subseteq D_n$,
and $D_n=\\gamma_n$ for $n\\le3$; for $n=4$ this fails (Rips). <b>Is $D_5(G)\\subseteq\\gamma_4(G)$ for every group?</b></p>
<p>For Lie rings the answer is yes (Ionin, Mikhailov, Petrov, 2026, formalized in Lean). For groups it is open,
and we have not solved it. This site shows what is proved, what is computed, and what is left.</p></div>
<div class="cards">
<div class="card"><h3>$2$-torsion: $D_5\\subseteq\\gamma_4$</h3><div class="big">up to $2^{{10}}$</div>
<p>True for every finite group whose Sylow $2$-subgroup has order $\\le2^{{10}}$, in particular for all groups of order $<2048$.</p>
<p>Order $2^{{11}}$: ranks $2$–$4$ and $\\ge8$ closed, $5$–$7$ open.</p></div>
<div class="card"><h3>$3$-torsion: $D_5=\\gamma_5$</h3><div class="big">up to $3^9$</div>
<p>No $3$-torsion in $D_5/\\gamma_5$ when the Sylow $3$-subgroup has order $\\le3^9$.</p>
<p>On paper for all groups whose $G/\\gamma_2$ has at most one invariant larger than $3$ (e.g. exponent $3$, or $C_9\\times C_3^{{s-1}}$), of any order.</p></div>
<div class="card"><h3>Lie rings and Lean</h3><div class="big">proved</div>
<p>$D_5(L)\\subseteq\\gamma_4(L)$ for Lie rings; the formalization audited. The group question and the reduction to $2$-groups of class $3$ are stated in Lean.</p></div>
<div class="card"><h3>Counterexamples</h3><div class="big">0</div>
<p>No computed group has $D_5\\ne\\gamma_5$; in all of them $D_n=\\gamma_n$ for every $n$. Over a hundred thousand candidates, all computations exact.</p></div>
</div>
<h2>Coverage map: $2$-groups of class $3$</h2>
<p>A cell stands for all $2$-groups of class $3$ of the given order and rank; it is closed when all of them have $D_5=1$.
{n2} cells are closed and {o2} open. More on the <a href="coverage.html">coverage map</a> page.</p>
""") + grid(range(4, 12), range(2, 10), cover2, 2, lang, highlight={(11, 5), (11, 6), (11, 7)}) + legend(lang) + t("""
<h2>Последнее</h2>""", """
<h2>Latest</h2>""") + "<ul>" + "".join(f"<li>{x[li]}</li>" for x in TIMELINE[-1][1]) + "</ul>" + t(f"""
<p>Черновик статьи (от {pdate['ru']}): <a href="viewer.html">по-русски</a>, <a href="../viewer.html" hreflang="en">по-английски</a>
(PDF: <a href="paper/d5-ru.pdf">RU</a>, <a href="paper/d5.pdf">EN</a>); вся история&nbsp;— <a href="timeline.html">хронология</a>.</p>""", f"""
<p>The paper draft (of {pdate['en']}): <a href="viewer.html">English</a>, <a href="ru/viewer.html" hreflang="ru">Russian</a>
(PDF: <a href="paper/d5.pdf">EN</a>, <a href="paper/d5-ru.pdf">RU</a>); the whole story is in the <a href="timeline.html">timeline</a>.</p>"""), contact=True)

    # ---------- coverage ----------
    P("coverage.html", t("Карта покрытия", "Coverage map"), t("""
<p>Каждая клетка&nbsp;— все группы данного порядка и ранга (числа порождающих). Цвет говорит, чем закрыт вопрос для всех них:
вычислением, доказательством или обоими вместе. Наведите на клетку&nbsp;— появится ссылка на утверждение черновика; щелчок открывает это утверждение.</p>
<h2 id="c2">$2$-группы ступени $3$: $D_5(Q)=1$?</h2>
<p>Это и есть задача 20.84: по сведению (предложение [[prop:reduction|#]]) $D_5\\subseteq\\gamma_4$ для всех групп тогда и только тогда,
когда $D_5(Q)=1$ для всех конечных $2$-групп ступени $3$. Ступень $3$ требует $d\\le n-2$ при порядке $2^n$.
Обведены открытые клетки порядка $2^{11}$: ранги $5$–$7$.</p>""", """
<p>Each cell stands for all groups of the given order and rank (number of generators). The colour says what settles the
question for all of them: a computation, a proof, or both. Hover over a cell for the statement of the draft it rests on; a click opens that statement.</p>
<h2 id="c2">$2$-groups of class $3$: is $D_5(Q)=1$?</h2>
<p>This is Problem 20.84 itself: by the reduction (Proposition [[prop:reduction|#]]), $D_5\\subseteq\\gamma_4$ for all groups if and only if
$D_5(Q)=1$ for every finite $2$-group of class $3$. Class $3$ forces $d\\le n-2$ at order $2^n$.
The open cells at order $2^{11}$, ranks $5$–$7$, are outlined.</p>""")
      + grid(range(4, 12), range(2, 10), cover2, 2, lang, highlight={(11, 5), (11, 6), (11, 7)}) + legend(lang) + t("""
<ul>
<li>До $2^8$&nbsp;— решётка $\\Delta^n$ для всех групп; $2^9$&nbsp;— сито Дженнингса и решётка.</li>
<li>$2^{10}$&nbsp;— лемма о минимальном контрпримере: достаточно шаг-$1$ потомков групп порядка $2^9$ (ANUPQ), $3400$ кандидатов.</li>
<li>$2^{11}$&nbsp;— то же с отсечением целых поддеревьев; ранг $8$&nbsp;— квадратичными формами и леммой [[lem:z4|#]], ранг $9$ невозможен.</li>
</ul>
<h2 id="c3">$3$-группы: $D_5(Q)=\\gamma_5(Q)$?</h2>
<p>Это вопрос о $3$-кручении в $D_5/\\gamma_5$ (оценка Тахары: экспонента делит $6$). Клетки «на бумаге» закрыты так:
если $Q/\\gamma_5$ метабелева, то $D_5=\\gamma_5$ по Гупте–Тахаре, а неметабелева группа ступени $4$ ранга $d$ имеет порядок
$\\ge3^{d+5}$ (предложение [[prop:metab|#]]); при $d=2$ фактор $\\gamma_2/\\gamma_3$ цикличен. Остальное&nbsp;— перебор до $3^9$.
Открытые клетки заштрихованы: в них доказан случай, когда у $Q/\\gamma_2$ не больше одного инварианта $>3$ (теорема [[thm:exp3plus|#]]).</p>""", """
<ul>
<li>Up to $2^8$: the lattice $\\Delta^n$ for all groups; $2^9$: the Jennings sieve and the lattice.</li>
<li>$2^{10}$: the minimal-counterexample lemma reduces to step-$1$ descendants of groups of order $2^9$ (ANUPQ), $3400$ candidates.</li>
<li>$2^{11}$: the same, with whole subtrees cut; rank $8$ by quadratic forms and Lemma [[lem:z4|#]], rank $9$ impossible.</li>
</ul>
<h2 id="c3">$3$-groups: is $D_5(Q)=\\gamma_5(Q)$?</h2>
<p>This is the question of $3$-torsion in $D_5/\\gamma_5$ (Tahara: the exponent divides $6$). The “paper” cells are closed thus:
if $Q/\\gamma_5$ is metabelian, then $D_5=\\gamma_5$ by Gupta–Tahara, and a non-metabelian group of class $4$ and rank $d$
has order $\\ge3^{d+5}$ (Proposition [[prop:metab|#]]); for $d=2$ the factor $\\gamma_2/\\gamma_3$ is cyclic. The rest is the search up to $3^9$.
Open cells are hatched: there the case of $Q/\\gamma_2$ with at most one invariant $>3$ is proved (Theorem [[thm:exp3plus|#]]).</p>""")
      + grid(range(4, 13), range(2, 9), cover3, 3, lang) + legend(lang, three=True))

    # ---------- results ----------
    rows = [(tag(k, lang), (r[li], "l"), (ref(where, lang), "l")) for k, *r, where in RESULTS]
    rids = []  # row anchors, by the first label of the row: results.html#r-thm-small, #r-thm-small-2
    for *_, where in RESULTS:
        rid = "r-" + re.sub(r"[:.]", "-", PAPER_REF.search(ref(where, "en")).group(1))
        rids.append(rid if rid not in rids else f"{rid}-{sum(1 for x in rids if x.startswith(rid))+1}")
    P("results.html", t("Результаты", "Results"), t(f"""
<p>Главные утверждения черновика с их статусом. Номера&nbsp;— по <a href="paper.html">версии статьи на этом сайте</a>;
ссылка на номер открывает статью на этом утверждении, ссылки в тексте ведут к вычислению, коду и данным (коммит
<a href="{REPO}/tree/{PIN}"><code>{PIN[:7]}</code></a>), файлам Lean и открытым вопросам.
<span class="tag c">компьютер</span>&nbsp;— проверено точным вычислением (решётки по модулю $p^E$ в форме Хауэлла или усечённая
алгебра Магнуса, с сертификатом точности); <span class="tag p">на бумаге</span>&nbsp;— доказано; <span class="tag l">Lean</span>&nbsp;— формально проверено.</p>""", f"""
<p>The main statements of the draft with their status. Numbers refer to the <a href="paper.html">version of the paper on this site</a>;
a number opens the paper at the statement, and the links in the text lead to the computation, the code and data (commit
<a href="{REPO}/tree/{PIN}"><code>{PIN[:7]}</code></a>), the Lean files and the open questions.
<span class="tag c">computer</span>: checked by an exact computation (lattices modulo $p^E$ in Howell form, or the truncated
Magnus algebra, with the exactness certificate); <span class="tag p">paper</span>: proved; <span class="tag l">Lean</span>: formally verified.</p>""")
      + table([t("Статус", "Status"), (t("Утверждение", "Statement"), "l"), (t("Где", "Where"), "l")], rows, rids))

    # ---------- computations ----------
    body = t("""
<p>Каждый перебор устроен как воронка: от всех групп (или родителей в дереве $p$-групп) к немногим кандидатам,
которым считается $D_5$. Шкала логарифмическая. На последней ступени каждой воронки&nbsp;— ноль.</p>""", """
<p>Each search is a funnel: from all groups (or parents in the $p$-group tree) down to a few candidates whose $D_5$
is computed. The scale is logarithmic. The last step of every funnel is zero.</p>""")
    for fid, ru, en, steps, where in FUNNELS:
        body += f'<h2 id="{fid}">{t(ru, en)}</h2>' + funnel(steps, lang) + f"<p><small>{ref(where, lang)}</small></p>"
    rrows = []
    for r in RUNS:
        code = gh(r[7], f"<code>{r[7]}</code>") if r[7] else ""
        rrows.append(((r[li], "l"), (num(r[2], lang), "r"), (r[3 + li], "l"), (r[5 + li], "l"), (code, "l")))
    body += t('<h2 id="runs">Все прогоны</h2>', '<h2 id="runs">All runs</h2>') + table(
        [(t("Что", "What"), "l"), (t("Групп", "Groups"), "r"), (t("Итог", "Result"), "l"), (t("Время", "Time"), "l"),
         (t("Код", "Code"), "l")], rrows) + t("""
<p><small>Метод: для конечной $G$ решётка $\\Delta^n$ строится в форме Хауэлла над $\\mathbb Z/p^E$; невхождение $g-1\\notin\\Delta^n+p^E\\Delta$
доказывает $g\\notin D_n$, вхождение подтверждается сертификатом $p^{E-1}\\Delta\\subseteq\\Delta^n+p^E\\Delta$. Для больших групп&nbsp;—
усечённая алгебра Магнуса $\\mathbb Z[G]/\\Delta^n\\cong T_{\\lt n}(\\mathbb Z^k)/I_n$ по копредставлению на $k$ порождающих.
Проверки: два независимых метода, PARI/GP, известные значения.</small></p>""", """
<p><small>Method: for finite $G$ the lattice $\\Delta^n$ is computed in Howell form over $\\mathbb Z/p^E$; non-membership $g-1\\notin\\Delta^n+p^E\\Delta$
proves $g\\notin D_n$, membership is confirmed by the certificate $p^{E-1}\\Delta\\subseteq\\Delta^n+p^E\\Delta$. For large groups:
the truncated Magnus algebra $\\mathbb Z[G]/\\Delta^n\\cong T_{\\lt n}(\\mathbb Z^k)/I_n$ of a presentation on $k$ generators.
Checks: two independent methods, PARI/GP, known values.</small></p>""")
    P("computations.html", t("Вычисления", "Computations"), body)

    # ---------- timeline ----------
    items = "".join(f'<li id="d{d}"><span class="d">{fmt_date(d)[lang]}</span><ul>' + "".join(f"<li>{x[li]}</li>" for x in xs)
                    + "</ul></li>" for d, xs in reversed(TIMELINE))
    P("timeline.html", t("Хронология", "Timeline"), t("<p>Что и когда сделано, от последнего к первому.</p>",
                                                       "<p>What was done and when, latest first.</p>")
      + f'<ol class="tl">{items}</ol>')

    # ---------- open questions ----------
    P("open.html", t("Открытые вопросы", "Open questions"), t("""
<p>Что осталось, по убыванию важности.</p>""", """
<p>What is left, most important first.</p>""") + "<ol>" + "".join(
        f'<li id="{x[0]}"><p>{x[1 + li]}</p></li>' for x in OPEN) + "</ol>")

    # ---------- paper ----------
    # The contents from the .aux of the build: every entry has an anchor here and opens the viewer at
    # its destination; under each section, the numbered statements of it, each with the anchor of its
    # label (paper.html#thm:small).
    abstract = paper[lang]
    P_ = PAPERS[lang]
    if [e[1] for e in P_["toc"] if e[0] == "section"] != [e[1] for e in PAPERS["en" if lang == "ru" else "ru"]["toc"] if e[0] == "section"]:
        sys.exit("the two drafts have different sections")
    pp = t("с.", "p.")

    def statements(sec):
        labs = [lb for lb, (n, _) in P_["labels"].items() if re.split(r"[:.]", lb)[0] not in ("sec", "section")
                and n.split(".")[0] == sec]
        labs.sort(key=lambda lb: [int(x) for x in P_["labels"][lb][0].split(".")])
        out = []
        for lb in labs:
            ttl = P_["titles"].get(lb, "")
            if ttl.startswith("{") and braced(ttl, 0)[1] == len(ttl):
                ttl = ttl[1:-1]
            ttl = "" if not ttl or ttl.startswith("\\textbf{[") else f' <span class="muted">({tex_inline(ttl)})</span>'
            out.append(f'<span id="{lb}">{paper_link(lb, lang)}{ttl}</span>')
        return f'<div class="stm">{" · ".join(out)}</div>' if out else ""

    items, sub, k = [], [], 0
    for level, number, title, pg, dest in P_["toc"] + [("end", "", "", 0, "")]:
        if level != "subsection" and sub:
            items[-1] = items[-1].replace("</li>", "<ul>" + "".join(sub) + "</ul></li>")
            sub = []
        if level == "end":
            break
        entry = (f'<a href="{paper_href(dest)}">{tex_inline(title)}</a> <small>{pp}&nbsp;{pg}</small>')
        if level == "section":
            sid = dest if ":" in dest else (f"sec-{number}" if number else "references")
            k = number
            items.append(f'<li id="{sid}"{"" if number else " class=nonum"}>{(number + ". ") if number else ""}{entry}'
                         f'{statements(number) if number else ""}</li>')
        else:
            sub.append(f'<li id="sec-{k}-{len(sub) + 1}">{entry}</li>')
    P("paper.html", t("Черновик статьи", "Paper draft"), t(f"""
<p>Версия от {pdate['ru']}. Читать: <a href="viewer.html"><b>по-русски</b></a> ({pdfs.get('d5-ru')} с.),
<a href="../viewer.html" hreflang="en"><b>по-английски</b></a> ({pdfs.get('d5')} с.); скачать PDF: <a href="paper/d5-ru.pdf">RU</a>,
<a href="paper/d5.pdf">EN</a>. Это черновик: статус каждого утверждения отмечен в тексте
(<b>[Lean]</b>, <b>[на бумаге]</b>, <b>[компьютер]</b>, <b>[открыто]</b>).</p>
<p><small>На любое место статьи можно сослаться: <code>viewer.html#nameddest=thm:small</code> открывает теорему с меткой
<code>thm:small</code>, <code>viewer.html#page=6</code>&nbsp;— страницу; метки&nbsp;— в содержании ниже (у каждого пункта есть и якорь
на этой странице). То же работает с самим PDF: <code>paper/d5-ru.pdf#nameddest=thm:small</code>.</small></p>""", f"""
<p>Version of {pdate['en']}. Read it: <a href="viewer.html"><b>in English</b></a> ({pdfs.get('d5')} pp.),
<a href="ru/viewer.html" hreflang="ru"><b>in Russian</b></a> ({pdfs.get('d5-ru')} pp.); download the PDF: <a href="paper/d5.pdf">EN</a>,
<a href="paper/d5-ru.pdf">RU</a>. This is a draft: the status of every statement is marked in the text
(<b>[Lean]</b>, <b>[paper]</b>, <b>[computer]</b>, <b>[open]</b>).</p>
<p><small>Any place of the paper can be linked to: <code>viewer.html#nameddest=thm:small</code> opens the theorem labelled
<code>thm:small</code>, <code>viewer.html#page=6</code> a page; the labels are in the contents below (each entry also has an anchor
on this page). The same works with the PDF itself: <code>paper/d5.pdf#nameddest=thm:small</code>.</small></p>""") + t("<h2>Аннотация</h2>", "<h2>Abstract</h2>")
      + f"<p>{abstract}</p>" + t("<h2>Содержание</h2>", "<h2>Contents</h2>")
      + f'<ol class="toc">{"".join(items)}</ol>')

    # ---------- search ----------
    P("search.html", t("Поиск по сайту", "Site search"), t("""
<p><input type="search" id="q" placeholder="например: 3^9, Тахара, ранг 5, ANUPQ" autocomplete="off" spellcheck="false"
 style="padding:.45em .6em;width:100%;max-width:32em;font-size:1em"></p>
<p id="status"></p>
<ul id="results" style="list-style:none;padding:0"></ul>
<p><small>Ищет по тексту всех страниц, включая строки таблиц. Несколько слов — найдутся места, где есть все они.
Поиск — движок сайта <a href="https://ispacex.github.io/search/">ispacex.github.io</a>; ⌘K / Ctrl-K на любой странице открывает переход по разделам.</small></p>
""", """
<p><input type="search" id="q" placeholder="for example: 3^9, Tahara, rank 5, ANUPQ" autocomplete="off" spellcheck="false"
 style="padding:.45em .6em;width:100%;max-width:32em;font-size:1em"></p>
<p id="status"></p>
<ul id="results" style="list-style:none;padding:0"></ul>
<p><small>Searches the text of every page, table rows included. Several words find the places that contain all of them.
This page searches the English pages; <a href="ru/search.html" hreflang="ru">the Russian search</a> searches the Russian ones.
The search is the engine of <a href="https://ispacex.github.io/en/search/">ispacex.github.io</a>; ⌘K / Ctrl-K on any page opens the jump to a section.</small></p>
""") + f"""<style>#results li{{margin:0 0 1.1em}} #results .where{{font-size:.85em;color:var(--muted)}} #results mark{{background:rgba(255,200,80,.35);color:inherit}}</style>
<script src="/sitesearch/search.js"></script>
<script>SiteSearch.mount({{input: 'q', status: 'status', results: 'results', sources: [{{ url: '{BASE}search-index.json' }}]}});</script>""")


if __name__ == "__main__":
    main()
