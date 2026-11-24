// FONCTIONNAIRES DE SOVARKA : AMBIANCE DE SOUPÇON (décisions de Fred du 15/11/2026, GAME-DESIGN-NOVOMIRSK.md).
//
// « Tout fonctionnaire est potentiellement un agent de renseignement qui fait remonter ce qu'il trouve
// anormal ; c'est comme ça qu'ils doivent être perçus. » C'est une AMBIANCE, sans mécanique, sauf décision
// de Fred pour certains PNJ. Pour la renforcer, les fonctionnaires PNJ de Sovarka posent parfois au joueur
// des questions absurdes et parodiques (« Êtes-vous un agent étranger ? Si oui, vous devez vous signaler au
// ministère de la Sécurité du Peuple »). Cela vaut pour TOUS les fonctionnaires PNJ de Sovarka, déjà en
// place compris.
//
// Qui : un PNJ dont la présence dans la pièce est confirmée par la scène serveur, en Sovarka, et qui n'est
// pas dans la liste des PNJ qui ne sont pas fonctionnaires (habitants, détenus, privés, étrangers, cultes).
// En Sovarka l'État possède les murs et le fonds : vendeurs, serveurs et employés des commerces d'État sont
// donc des fonctionnaires.
// Quand : environ une conversation sur quatre. Le tirage est fait ici, au serveur, et il est stable pour un
// même joueur, un même PNJ et un même jour (heure de Paris) : une conversation garde la même humeur d'une
// réplique à l'autre. Le modèle pose la question au plus une fois dans la conversation.

const NON_FONCTIONNAIRES = new Set([
  // Pensionnaires, retraités et détenus
  'sovarka_antonina_doubrova', 'sovarka_matvei_tcherkassov', 'sovarka_nikolai_zakharov', 'evgueni_sudakov',
  'sovarka_timofei_fomine',
  // Habitants des chalets de Starovka (Fred, 18/11/2026)
  'dolgor_tsybikova', 'zorigto_badmaev',
  // Krasnov (bloc 3, 23/11/2026) : habitants des petites maisons, pensionnaire de l'EHPAD, habitué du Bar Sever
  'antonina_merkoulova', 'matvei_rybakov', 'ignat_lykov', 'stepan_kouznetsov', 'matvei_starikov', 'habitue_krasnov', 'prokop_stakanov',
  // Habitués, saltimbanques, revendeurs, artisans et mécaniciens des centres
  'sovarka_ksenia_makarova', 'sovarka_tuya_sanjieva', 'sovarka_varvara_kozlova',
  'sovarka_arkhip_voronine', 'sovarka_altan_namsaraiev', 'sovarka_efim_iakovlev',
  'sovarka_kolia_titov', 'sovarka_ganbold_garmaiev', 'sovarka_tolia_souvorov',
  'sovarka_sava_goussev', 'sovarka_bayar_otchirov', 'sovarka_stas_mironov',
  // Métiers de l'ombre et sécurité privée
  'sovarka_moissei_kisseliov', 'sovarka_khasar_baljirov', 'sovarka_makar_tchernov',
  'sovarka_garri_medvedev', 'sovarka_dorji_filatov', 'sovarka_afanassi_rogov',
  'sovarka_genrikh_vlassov', 'sovarka_temur_dougarov', 'sovarka_gavriil_lavrov',
  // Lobbyistes, élus, supporters, bénévoles
  'sovarka_leonid_orlov', 'sovarka_lobbyiste_pavel_pistonov', 'sovarka_innokenti_partiiev',
  'meneur_des_supporters', 'sovarka_stiopa_le_tambour_ossipov', 'veteran_ilia_krioukov',
  // Loge, Église du Tractorisme, presse étrangère et ambassadeurs étrangers
  'sovarka_venerable_maitre_dimitri_compassov', 'frere_gardien', 'camarade_pontife_tractorenko', 'frere_kolkhoze', 'kouzma_lapchine', 'praskovia_pakhomova',
  'journalistes_accredites', 'hubert_de_la_courtoisie', 'cheikh_rachid_al_diplomi', 'don_esteban_cortesano'
]);

// Exemples donnés au modèle : il en choisit un ou en invente un du même esprit.
const EXEMPLES = [
  "Êtes-vous un agent étranger ? Si oui, vous devez vous signaler au ministère de la Sécurité du Peuple.",
  "Avez-vous eu, depuis votre réveil, une pensée qui ne serait pas conforme au Plan ?",
  "Ce manteau est-il de fabrication sovarkienne ? Je demande pour le registre.",
  "Combien de fois par jour pensez-vous au camarade président Zolotov ? Moins de trois, c'est inquiétant.",
  "Vous souriez beaucoup. C'est un sourire d'ici, ou un sourire importé ?",
  "Connaissez-vous quelqu'un qui connaît quelqu'un qui a déjà lu un journal étranger ?",
  "Votre famille a-t-elle toujours eu ce nom, ou l'a-t-elle choisi pour passer inaperçue ?",
  "Avez-vous dépassé vos objectifs de production cette semaine ? Non ? Et pourquoi, à votre avis ?",
  "Si un inconnu vous proposait des devises étrangères, vous le dénonceriez tout de suite, ou après le déjeuner ?",
  "Vous êtes venu seul ? Personne ne vient jamais vraiment seul, en Sovarka."
];

const normaliser = n => String(n || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

// Jour de Paris (AAAA-MM-JJ) : la conversation du jour garde la même humeur.
function jourParis(maintenant) {
  return new Intl.DateTimeFormat('fr-CA', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(maintenant);
}

// Petite empreinte stable (FNV-1a 32 bits), sans dépendance.
function empreinte(texte) {
  let h = 0x811c9dc5;
  for (const c of String(texte)) { h ^= c.codePointAt(0); h = Math.imul(h, 0x01000193) >>> 0; }
  return h >>> 0;
}

function estFonctionnaireSovarka(profilId, profil, position, scene) {
  if (!profil || !position || position.country !== 'soviet' || !scene || !Array.isArray(scene.personnes)) return false;
  if (NON_FONCTIONNAIRES.has(profilId)) return false;
  return scene.personnes.some(n => normaliser(n) === normaliser(profil.nom));
}

// Rend la consigne à ajouter au prompt système, ou '' (pas de question pour cette conversation).
function consigneSoupconSovarka(profilId, profil, position, scene, joueurId, maintenant = new Date()) {
  if (!joueurId || !estFonctionnaireSovarka(profilId, profil, position, scene)) return '';
  if (empreinte(joueurId + '|' + profilId + '|' + jourParis(maintenant)) % 4 !== 0) return '';
  return "AMBIANCE DE SOVARKA — FONCTIONNAIRE ATTENTIF : comme tout fonctionnaire de Sovarka, tu es peut-être aussi un informateur, "
    + "et le visiteur doit le sentir. Une seule fois dans cette conversation (de préférence dans ta première ou ta deuxième réplique), "
    + "glisse au visiteur une question absurde et parodique de vigilance d'État, posée le plus sérieusement du monde, puis reviens à son sujet. "
    + "Si une telle question figure déjà dans tes répliques précédentes, n'en pose plus. Exemples (choisis-en un ou invente-en un du même esprit) : "
    + EXEMPLES.map(e => '« ' + e + ' »').join(' ')
    + " Ne menace pas, n'arrête personne et n'annonce aucune suite réelle : c'est une manie, pas une procédure.";
}

export { consigneSoupconSovarka, estFonctionnaireSovarka, NON_FONCTIONNAIRES };
