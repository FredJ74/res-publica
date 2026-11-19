#!/usr/bin/env node
'use strict';
// BRANCHEMENT DES NOTIFICATIONS DONT LA TRADUCTION EXISTE DÉJÀ (Claude, 18/11/2026 ; relais de Codex).
// Usage : node outils/generateurs/brancher-toasts-i18n.cjs --audit <dossier de l'audit global> [--ecrire] fichier.js...
// Pour chaque `showToast(titre, corps, …)` dont le corps (texte fixe) ou le titre a déjà une ressource chargée
// (sortie de outils/audits/audit-i18n-global.cjs : ressources.json.gz), ajoute juste après la ligne :
//   globalThis.RPI18nPlateau?.markToast(cléDuCorps | null, <corps>, undefined, <titre>);
// C'est la convention reconnue par l'audit et par i18n/plateau-init.js (markToast ne marque rien si le texte
// affiché diffère). Aucune nouvelle traduction, aucun texte modifié. Un `if (…) showToast(…);` sans accolades
// reçoit des accolades. Le corps n'est recopié que s'il est sans effet de bord (littéral, variable, membre,
// concaténation de ceux-ci). Fichiers du goulag refusés (chantier de Codex). Sans --ecrire : rapport seul.
const fs = require('node:fs'), path = require('node:path'), zlib = require('node:zlib');
const acorn = require(path.join(__dirname, '../audits/i18n-global/node_modules/acorn'));
const args = process.argv.slice(2);
const ecrire = args.includes('--ecrire');
const iAudit = args.indexOf('--audit');
if (iAudit < 0) { console.error('--audit <dossier> requis'); process.exit(2); }
const dossier = args[iAudit + 1];
const fichiers = args.filter((a, i) => !a.startsWith('--') && i !== iAudit + 1);
const reg = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(dossier, 'ressources.json.gz'))));
const utilisable = r => r && r.loaded && r.key && ['available-unreviewed', 'neutral'].includes(r.status?.en);
const parFr = new Map();
for (const r of reg) if (utilisable(r)) { if (!parFr.has(r.fr)) parFr.set(r.fr, []); parFr.get(r.fr).push(r); }
const cleCorps = fr => { const l = parFr.get(fr) || []; return (l.find(r => r.key.startsWith('toastBodies.')) || l.find(r => r.file === 'i18n/toast-bodies-resources.js') || l[0])?.key || null; };
const titreConnu = fr => (parFr.get(fr) || []).some(r => r.file === 'i18n/toast-resources.js');
const sur = n => n && (n.type === 'Literal' || n.type === 'Identifier' ||
  (n.type === 'MemberExpression' && !n.computed && sur(n.object)) ||
  (n.type === 'BinaryExpression' && n.operator === '+' && sur(n.left) && sur(n.right)) ||
  (n.type === 'TemplateLiteral' && n.expressions.every(sur)));
const estMark = st => st?.type === 'ExpressionStatement' && /RPI18nPlateau\??\.markToast/.test(st.__src || '');
let total = 0;
for (const f of fichiers) {
  if (/goulag/i.test(f)) { console.error('refusé (goulag) : ' + f); continue; }
  const src = fs.readFileSync(f, 'utf8');
  let ast; try { ast = acorn.parse(src, { ecmaVersion: 'latest', sourceType: 'script', allowHashBang: true }); }
  catch (e) { console.error('analyse impossible : ' + f + ' ' + e.message); continue; }
  const edits = []; let n = 0;
  const traiter = (st, suivant, dansBloc) => {
    const e = st.type === 'ExpressionStatement' && st.expression.type === 'CallExpression' && st.expression.callee.type === 'Identifier'
      && st.expression.callee.name === 'showToast' ? st.expression : null;
    if (!e || e.arguments.length < 2) return;
    if (suivant) suivant.__src = src.slice(suivant.start, suivant.end);
    if (dansBloc && estMark(suivant)) return;
    const [titre, corps] = e.arguments;
    const titreFr = titre.type === 'Literal' && typeof titre.value === 'string' ? titre.value : null;
    const corpsFr = corps.type === 'Literal' && typeof corps.value === 'string' ? corps.value : null;
    const cle = corpsFr != null ? cleCorps(corpsFr) : null;
    const titreOk = titreFr != null && titreConnu(titreFr);
    if (!cle && !titreOk) return;
    if (!cle && !sur(corps)) return;   // titre seul : le corps est recopié, il doit être sans effet de bord
    const appel = 'globalThis.RPI18nPlateau?.markToast(' + (cle ? JSON.stringify(cle) : 'null') + ', ' + src.slice(corps.start, corps.end)
      + ', undefined, ' + src.slice(titre.start, titre.end) + ');';
    if (dansBloc) edits.push({ at: st.end, text: ' ' + appel });
    else { edits.push({ at: st.start, text: '{ ' }); edits.push({ at: st.end, text: ' ' + appel + ' }' }); }
    n++;
  };
  (function visiter(node) {
    if (!node || typeof node.type !== 'string') return;
    if (node.type === 'BlockStatement' || node.type === 'Program') node.body.forEach((st, i) => traiter(st, node.body[i + 1], true));
    if (node.type === 'IfStatement') { traiter(node.consequent, null, false); if (node.alternate) traiter(node.alternate, null, false); }
    for (const k of Object.keys(node)) { const v = node[k]; if (Array.isArray(v)) v.forEach(visiter); else if (v && typeof v.type === 'string') visiter(v); }
  })(ast);
  edits.sort((a, b) => b.at - a.at);
  let out = src; for (const ed of edits) out = out.slice(0, ed.at) + ed.text + out.slice(ed.at);
  if (ecrire && n) fs.writeFileSync(f, out);
  console.log(f + ' : ' + n + ' notification(s) branchée(s)');
  total += n;
}
console.log('total : ' + total);
