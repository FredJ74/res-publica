// =====================
// ANTENNES LOCALES DE PRESSE — interview d'accueil des nouveaux personnages
// (décisions de Fred du 21/11/2026, GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md, point 1)
// =====================
// Module (fichier api/_*.js : jamais une fonction Vercel). Une ville = une antenne = un journaliste.
// L'invitation au portrait d'accueil est envoyée par le journaliste de l'antenne de la ville où se
// trouve le personnage. Jodie Moitout est à l'antenne de Luthécia : elle n'interviewe que là.
//
// Seules les antennes dont le journaliste est NOMMÉ dans le jeu figurent ici (data.js, relu le
// 22/11/2026). Une antenne sans journaliste nommé n'envoie aucune invitation : Fred fournira le nom
// et le portrait (voir ANTENNES_SANS_JOURNALISTE, simple liste pour le rapport et les bancs).
//
// Copie conforme dans le navigateur : PRESSE_ANTENNES_ACCUEIL (plateau-communication.js). Le banc
// outils/bancs/banc-interview-accueil-antennes-20261122.cjs vérifie que les deux listes sont identiques.

export const ANTENNES_PRESSE = Object.freeze([
  { pays: 'republic', ville: 'capitale', villeNom: 'Luthécia',          paysNom: 'Républia', journaliste: 'Jodie Moitout',   journal: "L'Autruche Entravée" },
  { pays: 'republic', ville: 'ville_a',  villeNom: 'Port-Sainte-Marie', paysNom: 'Républia', journaliste: 'Annie Houininon', journal: 'La Tribune de Républia' },
  { pays: 'republic', ville: 'ville_b',  villeNom: 'Montrouge',         paysNom: 'Républia', journaliste: 'Arthur Lutte',    journal: 'La Tribune de Républia' },
  { pays: 'soviet',   ville: 'capitale', villeNom: 'Novomirsk',         paysNom: 'Sovarka',  journaliste: 'Zoïa Glazounova', journal: 'La Voix de Sovarka' },
  { pays: 'soviet',   ville: 'ville_a',  villeNom: 'Starovka',          paysNom: 'Sovarka',  journaliste: 'Saran Batbayar',  journal: 'La Voix de Sovarka' },
  { pays: 'soviet',   ville: 'ville_b',  villeNom: 'Krasnov',           paysNom: 'Sovarka',  journaliste: 'Anatoli Kolosov', journal: 'La Voix de Sovarka' }
].map(a => Object.freeze(a)));

// Villes des pays non jouables (El Estado, Khalija) : leurs rédactions n'ont que des PNJ génériques
// (« Periodista Miedo », « Journaliste Local », « Journaliste Pétrole »…), pas de journaliste nommé.
export const ANTENNES_SANS_JOURNALISTE = Object.freeze([
  'narco/capitale', 'narco/ville_a', 'narco/ville_b',
  'khalija/capitale', 'khalija/ville_a', 'khalija/ville_b'
]);

export const TITRE_PORTRAIT = 'Un jour, un portrait : ';

// Le sujet de Jodie reste mot pour mot celui d'avant (« Un portrait pour L'Autruche Entravée ? ») :
// les invitations et refus déjà en base restent reconnus.
export function sujetInvitation(antenne) { return 'Un portrait pour ' + antenne.journal + ' ?'; }
export function sujetRefus(antenne) { return sujetInvitation(antenne) + ' (classé)'; }

export function antennePour(pays, ville) {
  return ANTENNES_PRESSE.find(a => a.pays === pays && a.ville === ville) || null;
}
export function antenneDuJournaliste(nom) {
  return ANTENNES_PRESSE.find(a => a.journaliste === nom) || null;
}
export function journalistesPresse() {
  return [...new Set(ANTENNES_PRESSE.map(a => a.journaliste))];
}
