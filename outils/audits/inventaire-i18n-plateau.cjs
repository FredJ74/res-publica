'use strict';
// Audit reproductible de surface i18n — sans mutation des joueurs ni du plateau.
// node outils/audits/inventaire-i18n-plateau.cjs
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const excluded = new Set(['node_modules', '.git', 'i18n', 'outils', 'images']);
function visit(dir, output) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) { if (!excluded.has(entry.name)) visit(path.join(dir, entry.name), output); continue; }
    if (!entry.isFile() || !/^(?:plateau.*|data|creation|supabase)\.(?:js|html)$/.test(entry.name)) continue;
    const file = path.join(dir, entry.name);
    const relative = path.relative(root, file);
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    for (let i = 0; i < lines.length; ++i) {
      const line = lines[i];
      const marked = [...line.matchAll(/data-i18n(?:-placeholder)?=["']([^"']+)["']/g)];
      const literals = [...line.matchAll(/(?:textContent|innerText|placeholder)\s*=\s*(['"`])([^'"`]+)\1/g)];
      const jsHtml = /innerHTML\s*=/.test(line);
      if (marked.length || literals.length || jsHtml) {
        output.push({ file: relative, line: i + 1,
          keys: marked.map(m => m[1]),
          literals: literals.map(m => m[2].slice(0, 100)),
          dynamicHTML: jsHtml });
      }
    }
  }
}
const output = [];
visit(root, output);
const counts = {
  scannedFiles: new Set(output.map(x => x.file)).size,
  marked: output.reduce((n, x) => n + x.keys.length, 0),
  literalTextAssignments: output.reduce((n, x) => n + x.literals.length, 0),
  dynamicHTMLSites: output.filter(x => x.dynamicHTML).length
};
console.log(JSON.stringify({ counts, rows: output }, null, 2));
