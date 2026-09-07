// =====================
// PLATEAU-FONDS.JS — FONDS DE COMMERCE : MODELE ET VERDICTS PURS (Lot 3.0)
// =====================
// Quatrieme et dernier maillon de la chaine patrimoniale MURS -> LOT -> BAIL -> FONDS.
//
// LE FONDS N'EST PAS L'ADRESSE. C'est la regle qui commande tout ce fichier : un fonds porte un
// identifiant opaque, tire une fois pour toutes a sa creation, et son implantation n'est qu'un
// ATTRIBUT. Demenager, changer de bail ou etre vendu ne change donc jamais son identite -- alors
// que les etablissements PNJ historiques, eux, sont identifies PAR leur adresse
// ('armurerie-republic-ville_a'). Les deux cohabitent dans la meme table sans se confondre, et
// aucun etablissement existant n'a besoin d'etre migre.
//
// CONTRAT DE CE MODULE : pur. Aucune ecriture, aucun DOM, aucun reseau, aucune dependance a state.
// Les mouvements d'argent appartiennent aux RPC transactionnelles (migration_fonds_commerce.sql) ;
// ici on ne fait que dire ce qui est permis, et sous quelles bornes.

// Version du modele. Son ABSENCE identifie un etablissement PNJ historique : c'est le seul
// discriminant necessaire, et il ne demande de toucher a aucune ligne existante.
const FONDS_MODELE_VERSION = 2;

// Cycle de vie. Trois etats suffisent, et ils sont exclusifs :
//   actif      : exploite par son proprietaire, sous un bail en cours ;
//   abandonne  : le bail a pris fin sans que le fonds soit repris -- il n'est plus exploitable par
//                personne, mais son contenu subsiste et le proprietaire des murs en decidera ;
//   supprime   : fin definitive, plus rien a en tirer.
const FONDS_STATUTS = ['actif', 'abandonne', 'supprime'];

// Destinations de lot dans lesquelles un fonds de commerce peut naitre. Un appartement n'accueille
// pas un commerce -- il peut en revanche domicilier une organisation, ce qui est une autre chose
// (locations_actives.data.orgaId) et ne cree aucun fonds.
const FONDS_DESTINATIONS_COMPATIBLES = ['commerce'];

// ---------------------------------------------------------------------------
// REFERENCES TYPEES
// ---------------------------------------------------------------------------
// 'pj:<nom>' | 'orga:<id>' | 'ville:<pays>_<ville>'. Reprend et etend la convention du Lot 1.0 bis.
// La forme publique 'ville:' repond a la question PATRIMONIALE "qui possede les murs ?" pour un
// bien municipal ; elle ne remplace pas destinationLoyer.type='municipal', qui repond a la question
// FINANCIERE "ou va le loyer ?". Les deux coexistent sans se recouvrir.

function refTypee(prefixe, valeur) {
  const v = (typeof valeur === 'string') ? valeur.trim() : '';
  return v ? (prefixe + ':' + v) : null;
}

function refPJ(nom)        { return refTypee('pj', nom); }
function refOrga(orgaId)   { return refTypee('orga', orgaId); }
function refVille(pays, ville) {
  const p = (typeof pays === 'string' && pays.trim()) ? pays.trim() : null;
  const v = (typeof ville === 'string' && ville.trim()) ? ville.trim() : null;
  return (p && v) ? ('ville:' + p + '_' + v) : null;
}

// Decompose une reference. LECTURE DEFENSIVE : une valeur non prefixee est un nom de PJ, forme
// historique encore majoritaire en base (terrains_etat.data.proprietaire). On ne la migre pas.
function decomposerRef(ref) {
  if (typeof ref !== 'string' || !ref.trim()) return { type: null, id: null };
  const r = ref.trim();
  if (r.slice(0, 3) === 'pj:')    return { type: 'pj', id: r.slice(3) };
  if (r.slice(0, 5) === 'orga:')  return { type: 'orga', id: r.slice(5) };
  if (r.slice(0, 6) === 'ville:') return { type: 'ville', id: r.slice(6) };
  return { type: 'pj', id: r };
}

function refEstPJ(ref)    { return decomposerRef(ref).type === 'pj'; }
function refEstOrga(ref)  { return decomposerRef(ref).type === 'orga'; }
function refEstVille(ref) { return decomposerRef(ref).type === 'ville'; }

// Deux references designent-elles le meme titulaire ? Compare les formes normalisees, pour qu'un
// 'Bomboclat' historique et un 'pj:Bomboclat' typé ne soient jamais pris pour deux personnes.
function memeTitulaire(a, b) {
  const da = decomposerRef(a), db = decomposerRef(b);
  return !!da.type && da.type === db.type && da.id === db.id;
}

// ---------------------------------------------------------------------------
// IDENTITE ET LECTURE D'UN FONDS
// ---------------------------------------------------------------------------

// Identifiant OPAQUE. Ni l'adresse, ni le proprietaire, ni l'enseigne n'y figurent : tous peuvent
// changer, l'identite non. Le compteur et l'alea ne servent qu'a l'unicite.
function nouvelIdFonds(pays, horodatage, alea) {
  const p = (typeof pays === 'string' && pays.trim()) ? pays.trim() : 'republic';
  const t = Math.max(0, Math.floor(Number(horodatage) || 0));
  const a = Math.max(0, Math.floor(Number(alea) || 0));
  return 'fonds-' + p + '-' + t + '-' + a;
}

// Un fonds de commerce, ou un etablissement PNJ historique ? Le discriminant est la version du
// modele, jamais le nom ni l'adresse.
function estFondsCommerce(data) {
  return !!(data && typeof data === 'object' && Number(data.version) >= FONDS_MODELE_VERSION);
}

function statutFonds(data) {
  const s = data && data.statut;
  return (FONDS_STATUTS.indexOf(s) !== -1) ? s : 'actif';
}

function fondsEstActif(data) {
  return estFondsCommerce(data) && statutFonds(data) === 'actif';
}

function caisseFonds(data) {
  const c = Number(data && data.caisse);
  return (isFinite(c) && c > 0) ? Math.floor(c) : 0;
}

// Le proprietaire actuel, sous forme typee. Un etablissement PNJ renvoie null : il n'appartient a
// personne au sens patrimonial.
function proprietaireFonds(data) {
  if (!estFondsCommerce(data)) return null;
  const ref = data.proprietaire;
  return (typeof ref === 'string' && ref.trim()) ? ref.trim() : null;
}

function fondsAppartientA(data, ref) {
  return memeTitulaire(proprietaireFonds(data), ref);
}

// Implantation : ou le fonds est-il exploite, et sous quel bail. Le bail est designe par son id
// canonique (locations_actives.id), pas par une copie de ses champs -- une seule source de verite.
function implantationFonds(data) {
  const i = (data && data.implantation && typeof data.implantation === 'object') ? data.implantation : {};
  return {
    country: i.country || null, city: i.city || null,
    buildingId: i.buildingId || null, roomId: i.roomId || null,
    lotId: i.lotId || null, localKey: i.localKey || null, bailId: i.bailId || null
  };
}

// ---------------------------------------------------------------------------
// COMPATIBILITE DU LOCAL
// ---------------------------------------------------------------------------

// Un fonds ne nait que dans un local a destination commerciale. La destination est celle du LOT
// (subdivisions[].destination) ; un local historique sans destination est commercial par
// construction -- meme lecture defensive qu'au Lot 1.5.1.
function localCompatibleFonds(lot) {
  if (!lot || typeof lot !== 'object') return false;
  const d = (lot.destination === 'appartement') ? 'appartement' : 'commerce';
  return FONDS_DESTINATIONS_COMPATIBLES.indexOf(d) !== -1;
}

// ---------------------------------------------------------------------------
// VERDICTS
// ---------------------------------------------------------------------------
// Aucun de ces verdicts ne deplace d'argent : ils disent ce qui est permis. Le mouvement reel est
// applique par les RPC, qui REVERIFIENT tout sous verrou -- le client n'est jamais cru sur un
// montant ni sur une disponibilite.

// PRENDRE UN BAIL NE CREE PAS DE FONDS. Le bail donne le droit d'occuper ; exploiter est une
// decision distincte, explicite, et facultative.
function verdictCreationFonds(bail, lot, refDemandeur, apport, fondsDisponibles, fondsExistant) {
  if (!bail) return { ok: false, raison: 'aucun_bail' };
  if (!memeTitulaire(bail.locataire, refDemandeur) && !memeTitulaire(refPJ(bail.locataire), refDemandeur)) {
    return { ok: false, raison: 'pas_titulaire' };
  }
  if (!localCompatibleFonds(lot)) return { ok: false, raison: 'local_incompatible' };
  if (fondsExistant) return { ok: false, raison: 'fonds_deja_present' };

  const montant = Math.floor(Number(apport) || 0);
  if (montant < 0) return { ok: false, raison: 'apport_invalide' };
  // Un apport nul est licite : on peut ouvrir une coquille et l'alimenter ensuite.
  const dispo = Math.max(0, Math.floor(Number(fondsDisponibles) || 0));
  if (montant > dispo) return { ok: false, raison: 'fonds_insuffisants', manque: montant - dispo };

  return { ok: true, raison: null, apport: montant };
}

// REALIMENTER LA CAISSE. Transfert reel depuis le patrimoine du proprietaire, jamais une creation.
// Aucun retrait libre n'est ouvert ici : la seule sortie prevue est l'extraction lors d'une vente
// (voir verdictVenteFonds), pour ne pas creer un canal de blanchiment avant que le moteur
// commercial n'existe.
function verdictAlimentationCaisse(fonds, refDemandeur, montant, fondsDisponibles) {
  if (!estFondsCommerce(fonds)) return { ok: false, raison: 'fonds_absent' };
  if (statutFonds(fonds) !== 'actif') return { ok: false, raison: 'fonds_inactif' };
  if (!fondsAppartientA(fonds, refDemandeur)) return { ok: false, raison: 'pas_proprietaire' };
  const m = Math.floor(Number(montant) || 0);
  if (m <= 0) return { ok: false, raison: 'montant_invalide' };
  const dispo = Math.max(0, Math.floor(Number(fondsDisponibles) || 0));
  if (m > dispo) return { ok: false, raison: 'fonds_insuffisants', manque: m - dispo };
  return { ok: true, raison: null, montant: m };
}

// RETIRER DE LA CAISSE. Symetrique exact de l'alimentation : le proprietaire reprend son propre
// argent, la ou il l'avait mis. Aucun revenu n'est fabrique -- ce qui sort de la caisse entre dans
// le patrimoine, et rien d'autre.
//
// TANT QUE LE FONDS EST A LUI, IL EN DISPOSE. Un loyer impaye, une procedure de recuperation
// ouverte, une eviction demandee : rien de tout cela ne gele ses actifs. Seule l'eviction
// EXECUTEE -- bail termine, fonds passe a 'abandonne' -- ferme ce retrait, parce que le fonds
// n'est alors plus exploitable par personne. Le controle de statut est donc la frontiere exacte
// entre la menace et le fait accompli.
function verdictRetraitCaisse(fonds, refDemandeur, montant) {
  if (!estFondsCommerce(fonds)) return { ok: false, raison: 'fonds_absent' };
  if (statutFonds(fonds) !== 'actif') return { ok: false, raison: 'fonds_inactif' };
  if (!fondsAppartientA(fonds, refDemandeur)) return { ok: false, raison: 'pas_proprietaire' };
  const m = Math.floor(Number(montant) || 0);
  if (m <= 0) return { ok: false, raison: 'montant_invalide' };
  const dispo = caisseFonds(fonds);
  if (m > dispo) return { ok: false, raison: 'caisse_insuffisante', caisse: dispo };
  return { ok: true, raison: null, montant: m, caisseApres: dispo - m };
}

// VENDRE LE FONDS. La caisse N'EST PAS comprise dans la vente : elle est extraite au vendeur
// AVANT le transfert, et le fonds change de mains a caisse nulle. Prix de vente et tresorerie du
// fonds sont deux grandeurs distinctes qu'on ne melange jamais.
// Le bail SUIT le fonds : meme local, memes murs, meme ligne de bail -- seul son titulaire change,
// ce qui preserve son historique au lieu de le detruire puis le recreer.
function verdictVenteFonds(fonds, refVendeur, refAcheteur, prix, fondsAcheteur) {
  if (!estFondsCommerce(fonds)) return { ok: false, raison: 'fonds_absent' };
  if (statutFonds(fonds) !== 'actif') return { ok: false, raison: 'fonds_inactif' };
  if (!fondsAppartientA(fonds, refVendeur)) return { ok: false, raison: 'pas_proprietaire' };
  const da = decomposerRef(refAcheteur);
  if (!da.type || !da.id) return { ok: false, raison: 'acheteur_invalide' };
  if (da.type === 'ville') return { ok: false, raison: 'acheteur_invalide' };
  if (memeTitulaire(refVendeur, refAcheteur)) return { ok: false, raison: 'acheteur_identique' };

  const p = Math.floor(Number(prix) || 0);
  if (p < 0) return { ok: false, raison: 'prix_invalide' };
  const dispo = Math.max(0, Math.floor(Number(fondsAcheteur) || 0));
  if (p > dispo) return { ok: false, raison: 'acheteur_insolvable', manque: p - dispo };

  return { ok: true, raison: null, prix: p, caisseExtraite: caisseFonds(fonds) };
}

// ---------------------------------------------------------------------------
// FIN DE BAIL
// ---------------------------------------------------------------------------
// Trois causes, une seule mecanique. Le fonds n'est JAMAIS donne au proprietaire des murs : il
// cesse simplement d'occuper le local et devient abandonne, avec son contenu.

const CAUSES_FIN_BAIL = ['resiliation_volontaire', 'accord_amiable', 'eviction_judiciaire',
                         'succession_sans_heritier'];

function causeFinBailValide(cause) {
  return CAUSES_FIN_BAIL.indexOf(cause) !== -1;
}

function verdictResiliationVolontaire(bail, refDemandeur) {
  if (!bail) return { ok: false, raison: 'aucun_bail' };
  if (!memeTitulaire(bail.locataire, refDemandeur) && !memeTitulaire(refPJ(bail.locataire), refDemandeur)) {
    return { ok: false, raison: 'pas_titulaire' };
  }
  return { ok: true, raison: null, cause: 'resiliation_volontaire' };
}

// Le devenir du fonds a la fin du bail, quelle qu'en soit la cause. Aucune destruction automatique
// de contenu, aucun transfert gratuit : l'exploitation cesse, c'est tout.
function devenirFondsFinBail(fonds) {
  if (!estFondsCommerce(fonds)) return { statut: null, exploitable: false };
  return { statut: 'abandonne', exploitable: false, contenuConserve: true,
           proprietaireInchange: proprietaireFonds(fonds) };
}

// Un fonds abandonne n'est exploitable par PERSONNE -- ni son ancien proprietaire, qui en reste
// pourtant nominalement titulaire, ni le proprietaire des murs, a qui rien n'a ete donne.
function fondsExploitablePar(fonds, ref) {
  if (!fondsEstActif(fonds)) return false;
  return fondsAppartientA(fonds, ref);
}

// ---------------------------------------------------------------------------
// ARCHIVE D'UN BAIL
// ---------------------------------------------------------------------------
// locations_actives reste STRICTEMENT la table des baux en cours. Un bail termine part dans
// locations_archives, append-only, sur la doctrine de dossiers_urbanisme : on n'y reecrit jamais.
// Cette fonction fabrique la ligne ; c'est la RPC qui l'ecrit, dans la meme transaction que la
// suppression du bail actif -- jamais l'une sans l'autre.
function ligneArchiveBail(bail, options) {
  const o = options || {};
  const b = bail || {};
  return {
    bail_id: o.bailId || b.id || null,
    country: b.country || null,
    city: b.city || null,
    building_id: b.buildingId || null,
    room_id: b.roomId || null,
    lot_id: b.lotId || null,
    locataire: b.locataire || null,
    proprietaire_murs: o.proprietaireMurs || null,
    loyer: Math.max(0, Math.floor(Number(b.prix) || 0)),
    debut: (typeof b.depuis === 'number') ? b.depuis : null,
    fin_cause: causeFinBailValide(o.cause) ? o.cause : 'resiliation_volontaire',
    fonds_id: o.fondsId || null,
    indemnite: Math.max(0, Math.floor(Number(o.indemnite) || 0)),
    data: { bail: b, orgaId: b.orgaId || null, impaye: b.impaye || null,
            transfertsFonds: o.transfertsFonds || null }
  };
}
