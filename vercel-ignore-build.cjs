/* Vercel Ignored Build Step: 0 = ignorer, 1 = construire.
 * Toute incertitude conserve le build. Aucun appel distant, aucun secret.
 */
const { execFileSync } = require('node:child_process');
const { readFileSync } = require('node:fs');
function ignorerBuild({ cwd = __dirname, env = process.env } = {}) {
  const git = args => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  try {
    const precedent = env.VERCEL_GIT_PREVIOUS_SHA, courant = env.VERCEL_GIT_COMMIT_SHA;
    if (![precedent, courant].every(s => typeof s === 'string' && /^[a-f0-9]{40}$/.test(s))) return false;
    if (git(['rev-parse', 'HEAD']) !== courant) return false;
    // Clone incomplet, premier build, historique réécrit : construire.
    git(['merge-base', '--is-ancestor', precedent, courant]);
    const exclusions = readFileSync(`${cwd}/.vercelignore`, 'utf8').split(/\r?\n/).map(s => s.trim());
    if (!exclusions.includes('*.md') || exclusions.some(s => s.startsWith('!'))) return false;
    const fichiers = git(['diff', '--name-only', '--no-renames', '-z', precedent, courant, '--']).split('\0').filter(Boolean);
    // Allowlist volontairement étroite ; tout code, SQL, configuration, asset ou
    // fichier inconnu conserve les Preview et le déploiement automatique de main.
    return fichiers.length > 0 && fichiers.every(f => /^(?:[^/]+\.md|(?:outils|historique|baseline)\/.*\.md)$/.test(f));
  } catch {
    return false;
  }
}
if (require.main === module) {
  const ignorer = ignorerBuild();
  console.log(ignorer ? 'Documentation seule : compilation ignoree.' : 'Code, configuration ou comparaison incertaine : build conserve.');
  process.exitCode = ignorer ? 0 : 1;
}
module.exports = { ignorerBuild };
