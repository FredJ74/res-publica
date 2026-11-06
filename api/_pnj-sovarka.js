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
    derives[ligne.id] = profil;
  }
  return derives;
}

export { deriverProfilsSovarka };
