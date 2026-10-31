// INVENTAIRE FIGÉ DES ÉCRITURES D'ORGANISATIONS PAR LA SAUVEGARDE GÉNÉRALE (31/10/2026, #295 / #219).
//
// Chaque appel à sauvegarderOrga / sbSaveOrganisation est classé :
//   * « commande » : la fonction tente d'abord la commande serveur #219 (organisationEssayerCommande)
//     et ne retombe sur la sauvegarde générale que si le contrat est absent ;
//   * « sans commande » : chemin encore tenu par la sauvegarde générale, à porter avant l'étape B.
// Ajouter un nouvel appel sans le classer ici fait échouer le test : la double autorité ne
// regagne pas de terrain en silence. Référence : outils/audits/ORGANISATIONS-ECRITURES-20261031.md
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const RACINE = new URL('../../', import.meta.url);
const FICHIERS = ['plateau-organisations-quetes.js', 'plateau-politique.js', 'plateau-pnj.js'];

export const AVEC_COMMANDE = {
  monterGrade: 'promouvoir', descendreGrade: 'retrograder', exclureMembre: 'exclure',
  demanderAdhesion: 'demander', accepterAdhesion: 'admettre', refuserAdhesion: 'refuser_demande',
  envoyerInvitationOrga: 'inviter', accepterInvitationOrga: 'accepter_invitation',
  refuserInvitationOrga: 'refuser_invitation', sauvegarderOptionsOrga: 'informations',
  renommerOrga: 'informations', toggleVisibiliteOrga: 'visibilite', quitterOrga: 'quitter',
  confirmerDeclenchementElection: 'declencher_election', seProsenterCandidat: 'candidature',
  voterElection: 'vote', verifierElectionsOrganisations: 'avancer_election',
};
export const SANS_COMMANDE = [
  'confirmerCreationOrga', 'executerOrdreOrga', 'doRecruterMilitants', 'confirmerOrganiserBlocus',
  'doRejoindreClubSupporters', 'getClubSupportersLocal', 'chargerOuCreerSyndicatDockersPSM',
  'validerLancementGreve', 'confirmerTerminerGreve', 'confirmerAppelGreveGenerale',
  'repondreAppelGreveGenerale', 'verifierAdoptionGreveGenerale', 'confirmerRetraitGreveGenerale',
  'recalculerPuissanceApresRetraitGreveGenerale', 'confirmerMobilisationPolice', 'validerLancementRumeur',
];
// Champs que l'étape A (20261031230000) réserve aux commandes : aucun chemin sans commande n'y touche.
const CHAMPS_COMMANDES = /\.(nom|devise|avatar|visible|demandesAdhesion|invitationsEnvoyees|election)\b\s*(=(?!=)|\.push|\.splice)/;

function fonctions(src) {
  const lignes = src.split('\n'), res = [];
  let nom = null, debut = 0;
  lignes.forEach((l, i) => {
    const m = l.match(/^(?:async )?function ([A-Za-z_]+)/);
    if (m) { if (nom) res.push([nom, lignes.slice(debut, i).join('\n')]); nom = m[1]; debut = i; }
  });
  if (nom) res.push([nom, lignes.slice(debut).join('\n')]);
  return res;
}

const ecrivains = new Map();
for (const f of FICHIERS) {
  for (const [nom, corps] of fonctions(readFileSync(new URL(f, RACINE), 'utf8'))) {
    if (['sauvegarderOrga', 'sbSaveOrganisation'].includes(nom)) continue;
    if (/\b(sauvegarderOrga|sbSaveOrganisation)\(/.test(corps)) ecrivains.set(nom, corps);
  }
}

test('chaque écriture par la sauvegarde générale est classée', () => {
  const connus = new Set([...Object.keys(AVEC_COMMANDE), ...SANS_COMMANDE]);
  assert.deepEqual([...ecrivains.keys()].filter((n) => !connus.has(n)), [],
    'Nouvelle écriture d organisation par la sauvegarde générale : passer par une commande serveur ou la classer.');
});

test('les chemins avec commande tentent la commande #219 avant tout repli', () => {
  for (const [nom, action] of Object.entries(AVEC_COMMANDE)) {
    const corps = ecrivains.get(nom);
    assert.ok(corps, nom + ' introuvable');
    const i = corps.indexOf("organisationEssayerCommande("), j = corps.search(/\bsauvegarderOrga\(/);
    assert.ok(i >= 0 && i < j, nom + ' : commande absente ou après la sauvegarde');
    assert.match(corps, new RegExp("organisationEssayerCommande\\([^,]*,\\s*'" + action + "'"), nom + ' : action ' + action);
  }
});

test('aucun chemin sans commande ne modifie un champ réservé aux commandes (étape A)', () => {
  const fautifs = SANS_COMMANDE.filter((n) => ecrivains.has(n) && CHAMPS_COMMANDES.test(ecrivains.get(n).replace(/\{[^{}]*\bnom\s*:[^{}]*\}/g, '')));
  assert.deepEqual(fautifs, []);
});
