#!/usr/bin/env node
// Renders repo-root PRIVACY.md / TERMS.md into static HTML in public/,
// immediately before every deploy — same "copy right before deploying,
// never commit the generated copy" discipline this directory already uses
// for stories.json (see README.md), so the .md files stay the single
// source of truth instead of a second hand-maintained copy silently
// drifting out of sync.
//
// Deliberately a hand-rolled converter, not a markdown library: the two
// source docs only ever use a small, fixed set of markdown (h1/h2, bold,
// links, bullet lists, paragraphs) and this directory has no package.json/
// npm install step today — adding a dependency here would be a bigger
// change than the four constructs actually in use are worth.
'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const PUBLIC_DIR = path.resolve(__dirname, '..', 'public');

const PAGES = [
  { source: 'PRIVACY.md', output: 'privacy.html', title: 'Privacy Policy — Save My Life' },
  { source: 'TERMS.md', output: 'terms.html', title: 'Terms of Service — Save My Life' },
];

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

// Inline spans only — bold, italics, and links. Applied after escaping the
// raw text, so the replacement markup itself is safe to introduce. Bold
// runs before italics so a `**bold**` pair's own asterisks are already
// consumed and can't be mistaken for a `*italic*` pair.
function renderInline(text) {
  let html = escapeHtml(text);
  html = html.replace(/`(.+?)`/g, '<code>$1</code>');
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return html;
}

function renderMarkdownBody(markdown) {
  const lines = markdown.split('\n');
  const htmlParts = [];
  let paragraphLines = [];
  let listItems = [];

  function flushParagraph() {
    if (paragraphLines.length > 0) {
      htmlParts.push(`<p>${renderInline(paragraphLines.join(' '))}</p>`);
      paragraphLines = [];
    }
  }

  function flushList() {
    if (listItems.length > 0) {
      const items = listItems.map((item) => `<li>${renderInline(item)}</li>`).join('\n      ');
      htmlParts.push(`<ul>\n      ${items}\n    </ul>`);
      listItems = [];
    }
  }

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();

    if (line.startsWith('# ')) {
      flushParagraph();
      flushList();
      // The h1 is rendered separately as the page's own <h1> below —
      // skip it here so it isn't duplicated.
      continue;
    }
    if (line.startsWith('## ')) {
      flushParagraph();
      flushList();
      htmlParts.push(`<h2>${renderInline(line.slice(3))}</h2>`);
      continue;
    }
    if (/^-\s/.test(line)) {
      flushParagraph();
      listItems.push(line.replace(/^-\s/, ''));
      continue;
    }
    if (line.trim() === '') {
      flushParagraph();
      flushList();
      continue;
    }
    // An indented continuation of the line above: while a list item is
    // still open, this is that item's own wrapped second line (source docs
    // wrap long bullets across lines with a 2-space indent), not a new
    // paragraph — append it to the last item instead of starting one.
    if (listItems.length > 0) {
      listItems[listItems.length - 1] += ` ${line.trim()}`;
      continue;
    }
    paragraphLines.push(line.trim());
  }
  flushParagraph();
  flushList();

  return htmlParts.join('\n    ');
}

// Cross-references to the sibling doc read fine as a repo-relative filename
// in the .md source itself, but on the live hosted page they should be a
// real link to the sibling page rather than a dead filename mention.
function linkSiblingDocReferences(html) {
  return html
    .replace(/PRIVACY\.md/g, '<a href="/privacy">PRIVACY.md</a>')
    .replace(/TERMS\.md/g, '<a href="/terms">TERMS.md</a>');
}

function renderPage({ source, output, title }) {
  const markdown = fs.readFileSync(path.join(REPO_ROOT, source), 'utf8');
  const firstLine = markdown.split('\n', 1)[0];
  const heading = firstLine.startsWith('# ') ? firstLine.slice(2) : title;
  const body = linkSiblingDocReferences(renderMarkdownBody(markdown));

  const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(title)}</title>
    <style>
      :root { color-scheme: light dark; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        max-width: 680px;
        margin: 0 auto;
        padding: 32px 20px 64px;
        line-height: 1.55;
        color: #1a1a1a;
        background: #fefefe;
      }
      @media (prefers-color-scheme: dark) {
        body { color: #e6e6e6; background: #15181c; }
        a { color: #7ab8ff; }
      }
      h1 { font-size: 1.6rem; margin-bottom: 4px; }
      h2 { font-size: 1.05rem; margin-top: 28px; }
      p, li { font-size: 0.95rem; }
      ul { padding-left: 22px; }
      code { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 0.88em; }
      a { color: #0a5cff; word-break: break-word; }
    </style>
  </head>
  <body>
    <h1>${escapeHtml(heading)}</h1>
    ${body}
  </body>
</html>
`;

  fs.mkdirSync(PUBLIC_DIR, { recursive: true });
  fs.writeFileSync(path.join(PUBLIC_DIR, output), html, 'utf8');
  console.log(`Rendered ${source} -> public/${output}`);
}

for (const page of PAGES) {
  renderPage(page);
}
