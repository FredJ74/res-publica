// FIN DE LA DOUBLE AUTORITÉ SUR LES ORGANISATIONS — ÉTAPE B (02/11/2026, suite de #295 / #219).
//
// L'écran n'a plus le droit d'écrire la table `organisations` (20261102001300 : REVOKE INSERT,
// UPDATE). Ce test garde le terrain conquis :
//   * plus aucune sauvegarde générale (sauvegarderOrga / sbSaveOrganisation) ni écriture REST
//     directe sur `organisations` dans le navigateur ;
//   * les 17 chemins qui avaient une commande #219 la gardent ;
//   * les 16 chemins portés à l'étape B passent chacun par leur porte serveur.
// Référence : outils/audits/ORGANISATIONS-ECRITURES-20261031.md
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const RACINE = new URL('../../', import.meta.url);
const lire = (f) => readFileSync(new URL(f, RACINE), 'utf8');
const CLIENT = readdirSync(new URL('.', RACINE)).filter((f) => /\.js$/.test(f));

export const AVEC_COMMANDE = {
  monterGrade: 'promouvoir', descendreGrade: 'retrograder', exclureMembre: 'exclure',
  demanderAdhesion: 'demander', accepterAdhesion: 'admettre', refuserAdhesion: 'refuser_demande',
  envoyerInvitationOrga: 'inviter', accepterInvitationOrga: 'accepter_invitation',
  refuserInvitationOrga: 'refuser_invitation', sauvegarderOptionsOrga: 'informations',
  renommerOrga: 'informations', toggleVisibiliteOrga: 'visibilite', quitterOrga: 'quitter',
  confirmerDeclenchementElection: 'declencher_election', seProsenterCandidat: 'candidature',
  voterElection: 'vote', verifierElectionsOrganisations: 'avancer_election',
};
// Chemin porté → motif qui prouve qu'il passe par sa porte serveur.
export const PORTES_ETAPE_B = {
  confirmerCreationOrga: /sbOrganisationVie\(null, 'fonder'/,
  chargerOuCreerSyndicatDockersPSM: /sbOrganisationVie\('orga_syndicat_dockers_republic_ville_a', 'dockers_assurer'/,
  validerLancementGreve: /sbOrganisationVie\(orga\.id, 'greve_lancer'/,
  confirmerTerminerGreve: /sbOrganisationVie\(orga\.id, 'greve_terminer'/,
  confirmerAppelGreveGenerale: /sbGreveGeneraleSynchroniser\(ggId\)/,
  repondreAppelGreveGenerale: /sbGreveGeneraleSynchroniser\(ggId\)/,
  verifierAdoptionGreveGenerale: /sbGreveGeneraleSynchroniser\(ggId\)/,
  confirmerRetraitGreveGenerale: /sbGreveGeneraleSynchroniser\(ggId\)/,
  recalculerPuissanceApresRetraitGreveGenerale: /sbGreveGeneraleSynchroniser\(ggId\)/,
  doRejoindreClubSupporters: /sbCaisseCollective\('club_supporters_adherer'/,
  doRecruterMilitants: /sbRecruterMilitant\(/,
  validerLancementRumeur: /sbRpc\('rumeur_lancer'/,
};
// Chemins sans écriture d'organisation à porter : l'effet ne touchait pas l'organisation
// (executerOrdreOrga), ou le parcours est inaccessible (blocus, répression : state.orgas absent),
// ou c'était un faux positif du premier inventaire (commentaire dans getClubSupportersLocal).
export const SANS_ECRITURE = ['executerOrdreOrga', 'confirmerOrganiserBlocus', 'confirmerMobilisationPolice', 'getClubSupportersLocal'];

function fonctions(src) {
  const lignes = src.split('\n'), res = new Map();
  let nom = null, debut = 0;
  lignes.forEach((l, i) => {
    const m = l.match(/^(?:async )?function ([A-Za-z_]+)/);
    if (m) { if (nom) res.set(nom, lignes.slice(debut, i).join('\n')); nom = m[1]; debut = i; }
  });
  if (nom) res.set(nom, lignes.slice(debut).join('\n'));
  return res;
}
const toutes = new Map();
for (const f of CLIENT) for (const [n, c] of fonctions(lire(f))) toutes.set(n, c);
const sansCommentaires = (c) => c.split('\n').filter((l) => !/^\s*\/\//.test(l)).join('\n');

test('aucune sauvegarde générale ni écriture directe de la table organisations dans le navigateur', () => {
  const fautifs = [];
  for (const f of CLIENT) {
    const src = sansCommentaires(lire(f));
    if (/\bsauvegarderOrga\s*\(|\bsbSaveOrganisation\s*\(/.test(src)) fautifs.push(f + ' : sauvegarde générale');
    if (/sb(?:Insert|Upsert|Update|TransportRest)\(\s*(?:'(?:POST|PATCH|PUT)',\s*)?'organisations'/.test(src)) fautifs.push(f + ' : écriture REST');
  }
  assert.deepEqual(fautifs, []);
});

test('les chemins avec commande #219 la gardent', () => {
  for (const [nom, action] of Object.entries(AVEC_COMMANDE)) {
    const corps = toutes.get(nom);
    assert.ok(corps, nom + ' introuvable');
    assert.match(corps, new RegExp("organisationEssayerCommande\\([^,]*,\\s*'" + action + "'"), nom + ' : action ' + action);
  }
});

test('les chemins portés à l’étape B passent par leur porte serveur', () => {
  for (const [nom, motif] of Object.entries(PORTES_ETAPE_B)) {
    const corps = toutes.get(nom);
    assert.ok(corps, nom + ' introuvable');
    assert.match(corps, motif, nom);
  }
  assert.doesNotMatch(toutes.get('doRecruterMilitants'), /membres\.push/, 'le militant est inscrit par le serveur');
  assert.doesNotMatch(toutes.get('validerLancementRumeur'), /orga\.influence\s*=/, "l'influence est retirée par le serveur");
  for (const nom of SANS_ECRITURE) assert.ok(toutes.has(nom), nom + ' introuvable');
});

test('la fermeture de la table est écrite et gardée', () => {
  const m = lire('migrations/20261102001300_organisations_ecriture_ecran_fermee.sql');
  assert.match(m, /REVOKE INSERT, UPDATE ON public\.organisations FROM anon, authenticated/);
  assert.match(m, /DROP POLICY IF EXISTS organisations_ecriture_acteur/);
  assert.match(m, /DROP POLICY IF EXISTS organisations_maj_acteur/);
  assert.match(m, /portages_absents/);
});
