// FICHES DE DIALOGUE DES PNJ RENOMMES EN SOVARKA (06/11/2026, demande de Fred).
//
// Les batiments du gabarit commun portaient en Sovarka les PNJ de Republia. data.js leur donne
// maintenant des noms sovarkiens (PNJ_SOVARKA, appliquee a WORLD.soviet seulement), et chaque
// personne renommee porte un `profilId`. Ce module derive ces profils des fiches de Republia,
// meme methode que les referents de la caserne de Novomirsk (_pnj-referents.js, versSovarka) :
// meme caractere, meme savoir, nouveau nom, pays et ville de Sovarka. Une regle changee dans la
// fiche d'origine change ici aussi, sans seconde copie a tenir.
//
// La table vient de api/_pnj-sovarka-genere.js (node outils/generateurs/generer-pnj-sovarka.cjs).
// Un profil deja declare sous le meme identifiant (referents de la caserne) n'est jamais ecrase.
import { PNJ_SOVARKA_RENOMMES } from './_pnj-sovarka-genere.js';

const sansAccents = (s) => String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '');

// Tous les noms renommes de la meme ville : une fiche cite souvent ses collegues (« le protocole :
// Gerard Tamponneau »). Les plus longs d'abord, pour qu'un nom ne soit pas coupe par un autre.
function remplacementsPour(ligne) {
  const paires = [];
  for (const l of PNJ_SOVARKA_RENOMMES) {
    if (l.ville !== ligne.ville || l.ancien === l.nouveau) continue;
    paires.push([l.ancien, l.nouveau]);
    if (sansAccents(l.ancien) !== l.ancien) paires.push([sansAccents(l.ancien), l.nouveau]);
  }
  paires.sort((x, y) => y[0].length - x[0].length);
  const v = ligne.ville;
  paires.push(
    ['Président de la République', 'Président de Sovarka'], ['President de la Republique', 'President de Sovarka'],
    ['La Tribune de Républia', 'La Pravdovka'], ['La Tribune de Republia', 'La Pravdovka'],
    ["L'Autruche Entravée", 'La Pravdovka'], ["L'Autruche Entravee", 'La Pravdovka'], ['La Tribune', 'La Pravdovka'],
    ['Parti du Centre', 'Parti'],
    ['Port-Sainte-Marie', v], ['Montrouge', v], ['Luthécia', v], ['Luthecia', v],
    ['Républia', 'Sovarka'], ['Republia', 'Sovarka']
  );
  return paires;
}

function convertir(texte, paires) {
  if (typeof texte !== 'string') return texte;
  let t = texte;
  for (const [a, b] of paires) t = t.split(a).join(b);
  // Monnaie de Sovarka : le para sovarkien (PSK), memes chiffres que les FR (decision du 04/11).
  return t.replace(/(\d) FR\b/g, '$1 PSK');
}

// Compléments propres à un PNJ de Sovarka, ajoutés au caractère dérivé (décisions de Fred).
// Bloc 3, point 28 (23/11/2026) : Prokhor Rybakov est le frère cadet de Matveï Rybakov, référent chasse et bûcheronnage
// de Krasnov, qui le taquine (« mon frère, il fouille des valises toute la journée »).
const COMPLEMENTS = {
  sovarka_inspecteur_prokhor_rybakov: "TON FRÈRE AÎNÉ, Matveï Rybakov, est un ancien bûcheron de Krasnov, le référent de la ville pour la chasse et le bûcheronnage. Il se moque de ton métier (« mon frère, il fouille des valises toute la journée ») ; tu lèves les yeux au ciel, mais tu l'aimes bien."
};

function deriverProfilsSovarka(tous) {
  const derives = {};
  for (const ligne of PNJ_SOVARKA_RENOMMES) {
    if (Object.prototype.hasOwnProperty.call(tous, ligne.id)) continue;
    const source = tous[ligne.source];
    if (!source) continue;
    const paires = remplacementsPour(ligne);
    const profil = JSON.parse(JSON.stringify(source), (k, val) => convertir(val, paires));
    profil.nom = ligne.nouveau;
    profil.pays = 'soviet';
    if (COMPLEMENTS[ligne.id]) profil.caractere = [profil.caractere, COMPLEMENTS[ligne.id]].filter(Boolean).join('\n');
    derives[ligne.id] = profil;
  }
  // Redirections (Fred, 23/11/2026, points 42 et 44) : les identifiants de profil des anciens noms de Novomirsk restent
  // servis, avec la fiche du nouveau nom (rien ne casse pour une relation ou un lien enregistrés sous l'ancien identifiant).
  for (const [ancien, nouveau] of Object.entries(ALIAS_PROFILS_SOVARKA)) {
    if (!Object.prototype.hasOwnProperty.call(tous, ancien) && !derives[ancien]) derives[ancien] = derives[nouveau] || tous[nouveau];
  }
  return derives;
}
const ALIAS_PROFILS_SOVARKA = {
  sovarka_secretaire_municipal_arseni_krylov: 'sovarka_valentina_petchatkina',
  sovarka_archiviste_municipale: 'sovarka_ksenia_arkhipova'
};

export { deriverProfilsSovarka };
