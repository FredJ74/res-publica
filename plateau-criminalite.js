// Criminalité — lot 1 : équipement et dissimulation (GAME-DESIGN-CRIMINALITE.md §§ 1 et 5, décisions de Fred des 18-19/11/2026).
// Lot 2 : Neutraliser par crime_neutraliser (résolution commune crim_resoudre_interne), cible masquée visée par jeton.
// Lot 3 : Voler (argent, objet au hasard, objet précis) par crime_voler, même résolution commune ; aucun calcul ici.
// Lot 4 : cambriolage — Crocheter / Forcer la porte (crim_crocheter, crim_forcer_porte) sur la porte fermée à clé, puis
// matériel installé, stock et caisse (crim_cambriolage_lire, crim_cambrioler) ; le serveur tranche tout.
// Lot 5 : Empoisonner (crime_empoisonner), Incendier (crime_incendier), Explosifs (crime_explosifs), même résolution commune ;
// aucune estimation de chances ici.
// Lot 6 : Justice — enquête du commissaire sur les plaintes contre X (crim_enquetes_lire, crim_enqueter), textes de l'état
// d'urgence (7 jours, renouvelable) et de la rébellion matée (plus de QHS automatique). Chances et pistes viennent du serveur.
// Lot 7 : Corruption au QHS — « Corrompre le directeur » (crim_corrompre_directeur) et « Corrompre un gardien »
// (crim_corrompre_gardien : évasion facilitée, message, objet, protection), état lu par crim_corruption_qhs_lire.
// Lot 10 : envoi au QHS — écran des envois (crim_qhs_lire / crim_qhs_decider) pour le Ministre de la Justice ou le Premier
// ministre suppléant, et vote au référendum (crim_qhs_voter, boutons des courriers) ; aucun calcul ici.
// Lot 8 : délits d'information — résultat de « Lancer une rumeur » (crimRumeurResultat, réponse de rumeur_lancer) et textes
// des tracts calomnieux (durée du flagrant délit lue dans la réponse du serveur, barème).
// Le serveur tranche tout : jets (se_cacher, crim_fouiller_cachettes), objet porté (crim_revetir / crim_retirer, marque
// `porte_par` dans l'inventaire), liste des présents (crim_presents : caché absent, masqué numéroté sans portrait),
// boutique « Équipement discret » (boutique_discretion_etat / _acheter), événements d'écran (crim_evenements_lire :
// démasquage à l'arrestation, débusqué). Cet écran affiche, rien de plus. Textes : français seulement (traductions à venir).
(function (global) {
'use strict';
const T = {
  fr: {
    shop: 'Équipement discret', buy: 'Acheter', cancel: 'Renoncer', traced: 'achat noté par le vendeur',
    bought: '{nom} acheté pour {paye} {cur}.', wear: 'Revêtir', remove: 'Retirer', worn: 'revêtu',
    woreOk: '{nom} : revêtu.', removedOk: '{nom} : retiré.',
    modeMasque: 'Vous êtes masqué(e) : les autres ne voient qu’un individu masqué.',
    search: '👁 Débusquer quelqu’un de caché (1 PA)',
    searchIntro: 'Vous inspectez la pièce à la recherche de quelqu’un qui s’y cacherait. Coût : <strong>1 PA</strong>.',
    searchOdds: 'Vos chances dépendent de votre perception ; une tenue ninja et la discrétion de celui qui se cache les réduisent. Policiers et agents de sécurité sont avantagés.',
    searchGo: 'Fouiller (1 PA)', searchDone: 'Fouille terminée', searchNone: 'Personne ne se cache ici, semble-t-il.',
    searchFound: 'Vous débusquez : {liste}.', masked: 'un individu masqué',
    flushed: 'Débusqué(e) !', flushedBy: '{par} vous a débusqué(e) : vous n’êtes plus caché(e).',
    flushedAnon: 'Quelqu’un vous a débusqué(e) : vous n’êtes plus caché(e).',
    unmaskTitle: 'Bas les masques !', unmaskText: 'Arrêté(e), vous êtes démasqué(e) : votre masque est rangé dans votre inventaire.',
    hideOk: 'Vous êtes caché(e)', hideOkText: 'Personne ne vous voit tant que vous restez dans cette pièce.',
    hideFail: 'Échec', hideFailText: 'Vous n’avez pas réussi à vous dissimuler. Vous pouvez réessayer.',
    hideCrit: 'Échec critique', hideCritText: 'Vous trébuchez bruyamment derrière le rideau. Votre moral en prend un coup (−15).',
    r_deja_cache: 'Vous êtes déjà caché(e) dans cette pièce.', r_hors_batiment: 'Il faut être dans une pièce.',
    r_pas_a_la_boutique: 'Il faut être dans la boutique.', r_fonds_insuffisants: 'Fonds insuffisants.',
    r_inventaire_plein: 'Inventaire plein.', r_objet_non_revetable: 'Cet objet ne se revêt pas.', r_deja_revetu: 'Vous le portez déjà.',
    r_pas_revetu: 'Vous ne le portez pas.', r_objet_introuvable: 'Objet introuvable : rouvrez votre inventaire.',
    r_emprisonne: 'Impossible en détention.', r_hospitalise: 'Impossible à l’hôpital.', r_pa_insuffisants: 'Pas assez de PA.',
    refused: 'Le serveur a refusé l’opération.',
    nTitle: 'Neutraliser — {nom}',
    nIntro: 'Le serveur tranche tout : réussite, détection, risque d’affrontement. Frapper depuis votre cachette aide ; un gilet pare-balles revêtu protège la cible. Le masque ne donne aucun bonus, mais cache votre identité.',
    nMode: '{label} — {pa} PA', nFeu: ' · −20 DIS', nArmeAbsente: ' (arme absente)',
    nOk: 'Cible neutralisée', nOkText: 'Votre cible s’effondre ; elle est conduite à l’hôpital.',
    nFail: 'Raté', nFailText: 'Votre tentative échoue. Vous pouvez retenter si vous avez encore des PA.',
    nCrit: 'Échec critique', nCritText: 'Maladresse : votre moral en prend un coup (−15).',
    nCombat: 'Affrontement !', nCombatText: 'Votre cible se défend : l’affrontement commence.',
    nIdent: 'Vous avez été identifié(e) : la police vous recherche ({jours} jour(s) de prison d’office).',
    nTrace: 'Quelqu’un vous a repéré(e), mais votre masque a préservé votre identité.',
    r_cible_introuvable: 'Cette personne n’est plus là.', r_pas_au_meme_endroit: 'Votre cible n’est plus dans la pièce.',
    r_arme_manquante: 'Vous n’avez pas l’arme nécessaire.', r_cible_indisponible: 'Cette personne est hors service.',
    r_meme_groupe: 'Vous ne pouvez pas viser un membre de votre groupe.', r_cible_protegee: 'Cette personne ne peut pas être visée.',
    r_cible_non_referencee: 'Cette personne ne peut pas être visée ici.', r_cible_invalide: 'Cible invalide.',
    r_cible_ambigue: 'Plusieurs personnes portent ce nom : impossible de viser.',
    vTitle: 'Voler — {nom}', vMenu: '🤏 Voler quelqu’un (2-3 PA)', vChoisir: 'Qui voulez-vous voler ?', vPersonne: 'Personne à voler ici.',
    vIntro: 'Que cherchez-vous ? Vous ne verrez pas ce que la personne porte. Le serveur tranche tout : réussite, butin, détection, risque d’affrontement. Être caché ne facilite pas le vol mais protège votre identité.',
    vArgent: 'De l’argent liquide — {pa} PA', vHasard: 'Un objet au hasard — {pa} PA', vPrecis: 'Un objet précis — {pa} PA',
    vType: 'Quel type d’objet ?', t_arme: 'Une arme', t_cle: 'Une clé', t_medicament: 'Un médicament', t_nourriture: 'De la nourriture',
    t_vetement: 'Un vêtement', t_graisse: 'Un bocal de graisse', t_document: 'Un document',
    vOk: 'Vol réussi', vOkText: 'Vous dérobez : {butin}.', vOkCrit: 'Personne ne s’est aperçu de rien.',
    vVide: 'Bredouille', vRien: 'Vous ne trouvez rien à prendre.', vTypeAbsent: 'Elle n’a rien de ce genre sur elle.',
    vFail: 'Vol raté', vFailText: 'Votre tentative échoue. Vous gardez votre cachette et pouvez retenter si vous avez des PA.',
    vRemarque: 'Votre victime s’en est aperçue.',
    vCrit: 'Échec critique', vCritText: 'Maladresse : votre moral en prend un coup (−15).',
    vCombat: 'Affrontement !', vCombatText: 'Votre victime vous a pris la main dans le sac et se défend.',
    r_ordre_remplace: 'Ordre remplacé : rouvrez la fiche de la personne.', r_butin_invalide: 'Choix de butin invalide.',
    r_type_invalide: 'Type d’objet invalide.',
    pCrocheter: 'Crocheter — {pa} PA', pForcer: 'Forcer la porte — {pa} PA',
    pNote: 'Crocheter demande un kit de crochetage et ne laisse aucune trace ; forcer la porte détruit la serrure, alerte aussitôt le propriétaire et fait du bruit (un pied-de-biche aide).',
    cOk: 'Serrure crochetée', cOkText: 'La serrure cède sans un bruit. Elle se referme derrière vous.', cKitUse: 'Votre kit est usé : il est hors d’usage.',
    cKitReste: 'Votre kit servira encore {n} fois.', cFail: 'Raté', cFailText: 'La serrure résiste. Vous pouvez réessayer.',
    cCrit: 'Le crochet casse', cCritText: 'Votre kit s’est brisé dans la serrure : le propriétaire en trouvera la trace.',
    fOk: 'Porte forcée', fOkText: 'La serrure saute : le lieu est ouvert. Le propriétaire est prévenu.', fFail: 'La porte tient',
    fFailText: 'La serrure a tenu, et le propriétaire est alerté. Vous pouvez réessayer.',
    r_kit_requis: 'Il vous faut un kit de crochetage.', r_pas_devant_la_porte: 'Il faut se tenir devant cette porte.',
    r_pas_de_serrure: 'Cette porte n’a pas de serrure.', r_porte_ouverte: 'La porte n’est pas fermée à clé.',
    r_cle_detenue: 'Vous en avez la clé.', r_votre_porte: 'C’est votre porte.',
    kTitre: 'Cambrioler', kMenu: '🧰 Emporter ce qu’il y a ici (2 PA)',
    kNote: 'Chaque prise coûte 2 PA. Si quelqu’un est là, c’est un vol sous ses yeux ; sinon, rien ne vous arrête, mais vous pouvez être repéré.',
    kMateriel: 'Matériel installé', kStock: 'Stock du commerce', kCaisse: 'Caisse du commerce', kPrendre: 'Emporter (2 PA)',
    kPiocher: 'Se servir (2 PA)', kRien: 'Rien à emporter ici.', kOk: 'Butin', kOkText: 'Vous emportez : {butin}.',
    kVide: 'Bredouille', kVideText: 'Il n’y avait plus rien à prendre.',
    r_pas_de_commerce: 'Il n’y a pas de commerce ici.', r_stock_vide: 'Plus rien dans ce stock.',
    r_caisse_vide: 'La caisse est vide.', r_deja_a_vous: 'C’est à vous.', r_equipement_introuvable: 'Ce matériel n’est plus là.',
    r_pas_sur_place: 'Ce n’est pas ici.',
    eTitre: 'Empoisonner', eChoisir: 'Qui voulez-vous empoisonner ?', ePersonne: 'Personne à empoisonner ici.',
    eNote: 'Le poison de votre inventaire sera utilisé (usage unique), quoi qu’il arrive. La victime ne saura jamais qui l’a empoisonnée. Agir depuis une cachette aide ; un masque protège votre identité si l’on vous repère.',
    eTotale: 'Poison administré', eTotaleText: 'Votre victime commence à ressentir les effets du poison.',
    ePartielle: 'Poison administré', ePartielleText: 'Votre victime n’a reçu qu’une partie de la dose.',
    eAttenue: 'Dose ratée', eAttenueText: 'Le geste a manqué de précision : l’effet sera faible.',
    eRate: 'Raté', eRateText: 'L’occasion ne s’est pas présentée : le poison est perdu, personne n’a rien vu.',
    eCrit: 'Échec critique', eCritText: 'Vous renversez le poison sous les yeux de tous. Votre moral en prend un coup (−15).',
    r_poison_manquant: 'Vous n’avez pas de poison dans votre inventaire.', r_cible_pj_seulement: 'Seul un joueur peut être empoisonné.',
    r_requete_requise: 'Ordre remplacé : rouvrez la fenêtre.', r_explosif_manquant: 'Vous n’avez pas d’explosifs dans votre inventaire.',
    iTitre: 'Incendier — {nom}', iNote: 'Acte criminel : le bâtiment ferme 1 à 3 jours si le feu prend. Un bidon de carburant dans votre inventaire sera utilisé. Le temps qu’il fait compte. Vous ne serez recherché(e) que si l’on vous repère.',
    iGo: '🔥 Mettre le feu — 3 PA', iOk: 'Incendie déclenché', iOkText: '{nom} est fermé {jours} jour(s).',
    iFail: 'Le feu ne prend pas', iFailText: 'Rien ne se passe ; personne ne vous a remarqué(e).',
    iCritText: 'Vous vous brûlez les doigts devant témoins. Votre moral en prend un coup (−15).', iBidon: 'Un bidon de carburant a été utilisé.',
    xTitre: 'Explosifs — {nom}', xNote: 'Acte criminel grave : le bâtiment ferme 5 jours et toute personne présente dans la pièce est gravement blessée. Une charge d’explosifs sera utilisée. Une explosion prématurée vous blesserait vous-même.',
    xGo: '💣 Déclencher — 3 PA', xOk: 'Explosion', xOkText: '{nom} est fermé 5 jours. Blessé(s) : {n}.',
    xFail: 'Raté', xFailText: 'Le dispositif ne se déclenche pas. Personne n’a rien vu.',
    xPrem: 'Explosion prématurée !', xPremText: 'La charge vous explose entre les mains : vous êtes grièvement blessé(e) et votre moral en prend un coup (−15).',
    jMenu: '🔎 Enquêter sur une plainte contre X ({pa} PA)', jTitre: 'Plaintes contre X',
    jNote: 'Plaintes contre X de votre ville. Une tentative par jour et par plainte ({pa} PA). Les pistes réunies rapprochent vos chances du plafond de l’affaire.',
    jAucune: 'Aucune plainte contre X à instruire dans votre ville.', jEnqueter: 'Enquêter ({pa} PA)', jDeja: 'Déjà tenté aujourd’hui',
    jAffaire: '{acte} — victime : {victime} (jour {jour})', jAuteur: 'Auteur : {auteur}', jInconnu: 'inconnu', jMasque: 'un individu masqué',
    jIssueOk: 'acte réussi', jIssueKo: 'tentative ratée', jIndices: 'Indices : {liste}', jChances: 'Chances d’identification : {taux} %',
    jPistes: 'Pistes : {liste}', jPisteAucune: 'aucune', jTentatives: 'Tentatives : {n}',
    p_trace: 'trace', p_rumeurs: 'rumeurs', p_informateur: 'votre informateur', p_achats: 'achats tracés',
    a_neutraliser: 'Agression', a_voler: 'Vol', a_crocheter: 'Crochetage', a_forcer_porte: 'Effraction', a_cambrioler: 'Cambriolage',
    a_ramasser: 'Objets disparus', a_empoisonner: 'Empoisonnement', a_utiliser_explosifs: 'Explosion', a_incendier: 'Incendie',
    i_arme: 'arme : {v}', i_poison: 'poison : {v}', i_batiment: 'lieu : {v}', i_objet: 'objet : {v}',
    jOk: 'Coupable identifié', jOkText: '{nom} est démasqué(e) : avis de recherche, {jours} jour(s) de prison d’office. La plainte le (la) vise désormais.',
    jFail: 'Pas encore', jFailText: 'L’enquête n’aboutit pas aujourd’hui. Vous pourrez reprendre demain.',
    jAverti: 'Le suspect sait désormais que vous êtes sur ses traces.',
    r_reserve_commissaire: 'Réservé au commissaire de la ville.', r_hors_juridiction: 'Cette affaire relève d’une autre ville.',
    r_aucune_plainte: 'Il n’y a plus de plainte contre X sur cette affaire.', r_deja_identifie: 'Le coupable est déjà identifié.',
    r_une_tentative_par_jour: 'Une seule tentative par jour et par plainte.',
    uEnVigueur: 'L’état d’urgence est en vigueur jusqu’au {date} ; il a été déclaré par {par}.',
    uRenouveler: 'Renouveler pour 7 jours — 3 PA', uLever: 'Lever l’état d’urgence',
    uRenouvele: 'État d’urgence renouvelé', uRenouveleText: 'Il court désormais jusqu’au {date}. {pop} POP, +{inf} INF.',
    uDuree: 'L’état d’urgence dure 7 jours ; le Président peut le renouveler (3 PA et une perte de popularité). Sous l’état d’urgence, le juge fixe librement la peine.',
    bMatee: 'Rébellion matée', bMateeText: 'Les gardiens interviennent avant que les grilles ne cèdent. −25 PV, −15 DIS, +{jours} jour(s) de détention.',
    bProces: 'Vos peines automatiques dépassent 4 jours : un procès décidera d’un éventuel complément.',
    qDirTitre: 'Corrompre le directeur du QHS',
    qDirNote: 'Le directeur ne peut pas vous renvoyer en cellule ordinaire, mais il peut diviser par deux votre peine restante, une seule fois par détention. En cas d’échec : +{jours} jour(s) de peine, l’argent est confisqué et il ne vous recevra plus.',
    qDirGo: 'Proposer {cout} {cur} au directeur ({pa} PA)', qDirFerme: 'Le directeur ne vous recevra plus pendant cette détention.',
    qDirCourt: 'Votre peine restante est trop courte pour être réduite.',
    qGarTitre: 'Corrompre un gardien', qGarNote: 'Une tentative par jour ({pa} PA, {cout} {cur}). En cas d’échec, l’argent est confisqué ; vous pourrez retenter demain.',
    qGarDeja: 'Vous avez déjà tenté votre chance auprès d’un gardien aujourd’hui.',
    qEvasion: 'Évasion facilitée (+{bonus} % à votre prochaine tentative)', qProtection: 'Protection : pas d’interrogatoire musclé jusqu’à votre prochain repos',
    qMessage: 'Faire passer un message à l’extérieur', qObjet: 'Faire remettre un objet à l’extérieur',
    qActif: '(déjà obtenu)', qDest: 'Destinataire (nom exact)', qTexte: 'Votre message', qChoixObjet: 'Objet à confier au gardien',
    qAucunObjet: 'Vous n’avez aucun objet à confier.', qEnvoyer: 'Corrompre le gardien ({pa} PA, {cout} {cur})',
    qReserve: 'Réservé aux détenus du quartier de haute sécurité.',
    qDirOk: 'Le directeur accepte', qDirOkText: 'Votre peine restante est réduite de {gain} jour(s).',
    qDirKo: 'Le directeur refuse', qDirKoText: 'Votre argent est confisqué et votre peine allongée de {jours} jour(s). Il ne vous recevra plus.',
    qGarOk: 'Le gardien accepte', qGarKo: 'Le gardien refuse', qGarKoText: 'Votre argent est confisqué. Vous pourrez retenter demain.',
    qOk_evasion: 'Votre prochaine tentative d’évasion sera facilitée.', qOk_protection: 'Personne ne vous interrogera de force avant votre prochain repos.',
    qOk_message: 'Votre message a été remis à {dest}.', qOk_objet: 'L’objet a été remis à {dest}.',
    qDenonce: 'Vous avez été dénoncé(e) : recherché(e), {jours} jour(s) de prison d’office.',
    r_detenu_qhs_requis: 'Réservé aux détenus du quartier de haute sécurité.', r_directeur_deja_sollicite: 'Le directeur ne vous recevra plus pendant cette détention.',
    r_peine_trop_courte: 'Votre peine restante est trop courte pour être réduite.',
    r_service_deja_actif: 'Vous bénéficiez déjà de ce service.', r_destinataire_introuvable: 'Personne ne porte ce nom.',
    r_destinataire_invalide: 'Destinataire invalide.', r_destinataire_detenu: 'Ce destinataire est lui-même détenu.',
    r_message_invalide: 'Le message est vide ou trop long (1 000 caractères au plus).', r_objet_absent: 'Cet objet n’est plus dans votre inventaire.',
    r_objet_protege: 'Cet objet ne peut pas être confié.', r_service_inconnu: 'Service inconnu.', r_fonds_insuffisants: 'Fonds insuffisants.',
    r_pa_insuffisants: 'Points d’action insuffisants.', r_ordre_supprime: 'Cet ordre n’existe plus.',
    rOkTitre: '🗯 Rumeur lancée !', rCible: 'Cible : {cible}',
    rEffet_pj: '−{perte} POP pour {cible}', rEffet_gouvernement: '−{perte} POP pour {membres} membre(s) du gouvernement de {cible}',
    rEffet_gouvernement0: 'aucun titulaire en poste dans le gouvernement de {cible}', rEffet_pays: '−{perte} IS pour {cible}',
    rEffet_organisation: '−{perte} INF pour l’organisation « {cible} »', rEffet_local: 'aucun effet chiffré (rumeur purement RP)',
    rJournalOk: 'Rumeur lancée contre {cible} : {effet}.',
    rDetecte: 'On vous a reconnu(e) derrière cette rumeur : recherché(e), {jours} jour(s) de prison d’office.',
    rKoTitre: 'Rumeur ratée', rKo0: 'Votre tentative échoue, sans conséquence pour vous cette fois.',
    rKo: 'Votre tentative échoue et se retourne contre vous : −{perte} POP, −{perte} DIS.',
    rCritTitre: 'Calomniateur démasqué',
    rCrit: 'La rumeur se retourne contre vous : on sait que vous avez tenté de calomnier {cible}. −{perte} POP ; recherché(e), {jours} jour(s) de prison d’office.',
    rJournalKo: 'Tentative de rumeur contre {cible} ratée.',
    tFlagrantTitre: 'Flagrant délit !',
    tFlagrant: '{pnj} alerte immédiatement la police. Tous vos tracts calomnieux sont détruits. {jours} jour(s) de détention.',
    tFlagrantJournal: 'Distribution de tract calomnieux à {pnj} — échec critique. Tracts calomnieux détruits, {jours} jour(s) de détention.',
    tMotif: 'Distribution de tracts calomnieux',
    lpTitre: 'Laissez-passer du QHS', lpBouton: 'Laissez-passer du QHS',
    lpNote: 'Tout le monde peut se rendre devant le QHS ; seuls les porteurs d’un laissez-passer valide entrent. Le contrôle regarde le document, pas le visage : un laissez-passer volé ouvre aussi. Un retrait l’invalide partout.',
    lpDelivrer: 'Délivrer', lpNom: 'Nom du bénéficiaire', lpValides: 'Laissez-passer valides', lpAucun: 'Aucun laissez-passer valide.',
    lpLigne: '{nom} — délivré par {par}', lpRetirer: 'Retirer', lpJournal: 'Passages consignés (nom inscrit sur le document)',
    lpAucunPassage: 'Aucun passage consigné.', lpOk: 'Laissez-passer délivré à {nom}.', lpRetire: 'Laissez-passer de {nom} retiré.',
    flpTitre: 'Faux laissez-passer', flpLieu: 'Lieu', flpArchives: 'Archives d’écoute (Sovarka)', flpQhs: 'QHS',
    flpNom: 'Nom inscrit sur le document', flpNote: 'Un faux réussi passe pour un vrai, mais ne sert qu’une fois : il est retenu au contrôle.',
    flpValider: 'Fabriquer', flpNomRequis: 'Inscrivez un nom.',
    r_laissez_passer_requis: 'Entrée réservée aux porteurs d’un laissez-passer valide.', r_autorite_insuffisante: 'Réservé au Ministre de la Justice et aux juges.',
    r_deja_habilite: 'Cette personne a déjà un laissez-passer valide.', r_pas_habilite: 'Cette personne n’a pas de laissez-passer valide.',
    r_personnage_introuvable: 'Personnage introuvable.',
    hTitre: 'Envois au QHS', hBouton: 'Envois au QHS (demandes et référendums)',
    hNote: 'Le QHS est réservé aux détenus très dangereux. Le détenu y purge le reste de sa peine, sans un jour de plus. Un envoi sans consultation est ressenti comme un abus de pouvoir ; un référendum ne coûte rien.',
    hSuppleance: 'Le poste de Ministre de la Justice n’est pas tenu par un joueur : vous décidez à sa place, avec les mêmes règles.',
    hReserve: 'Réservé au Ministre de la Justice, ou au Premier ministre qui le supplée.', hSovarka: 'En Sovarka, le goulag tient lieu de QHS : ses règles d’envoi ne changent pas.',
    hDemandes: 'Demandes en cours', hAucune: 'Aucune demande en cours.', hDetenus: 'Détenus en cellule ordinaire', hAucunDetenu: 'Aucun détenu en cellule ordinaire.',
    hJuge: 'Proposé par le juge {juge}', hInitiative: 'Votre initiative', hFin: 'fin de peine au jour {jour}',
    hValider: 'Envoyer au QHS (−{pm} POP pour vous, −{pg} par membre du gouvernement, rumeur)',
    hReferendum: 'Soumettre au référendum (gratuit)', hRefuser: 'Refuser',
    hEnCours: 'Référendum en cours ; clôture le {date}.', hPerdu: 'Référendum perdu : {oui} oui, {non} non. Le détenu reste en cellule ordinaire.',
    hOutre: 'Envoyer quand même (−{pm} POP pour vous, −{pg} par membre du gouvernement, rumeur)', hRespecter: 'Respecter le vote',
    hVotes: 'Référendums ouverts', hVotesAucun: 'Aucun référendum ouvert dans votre pays de domicile.',
    hQuestion: 'Faut-il envoyer {detenu} au QHS ? Clôture le {date}.', hOui: 'Oui, au QHS', hNon: 'Non', hDejaVote: 'Vous avez voté.',
    hOk_valider: 'Transfert au QHS', hOkText_valider: '{detenu} est transféré(e) au QHS. L’affaire fait jaser : votre popularité tombe à {pop}.',
    hOk_referendum: 'Référendum ouvert', hOkText_referendum: '{n} personne(s) domiciliée(s) ont reçu un courrier ; le vote dure 24 heures.',
    hOk_refuser: 'Demande refusée', hOkText_refuser: '{detenu} reste en cellule ordinaire.',
    hOk_passer_outre: 'Transfert au QHS malgré le non', hOkText_passer_outre: '{detenu} est transféré(e) au QHS. Passer outre au référendum vous coûte cher : popularité à {pop}.',
    hOk_respecter: 'Vote respecté', hOkText_respecter: '{detenu} reste en cellule ordinaire.',
    hKo: 'Décision impossible', hVoteOk: 'Vote enregistré', hVoteOkText: 'Votre voix ({choix}) est comptée.', hVoteKo: 'Vote impossible',
    r_reserve_decideur: 'Réservé au Ministre de la Justice, ou au Premier ministre qui le supplée.', r_sovarka_goulag: 'En Sovarka, le goulag tient lieu de QHS.',
    r_mandat_autre_pays: 'Vous devez être dans votre pays pour exercer cette fonction.', r_detenu_introuvable: 'Cette personne n’est pas détenue dans votre pays.',
    r_deja_qhs: 'Ce détenu est déjà au QHS.', r_detenu_libere: 'Ce détenu a été libéré entre-temps.', r_referendum_en_cours: 'Le référendum est en cours : attendez le résultat.',
    r_demande_close: 'Cette demande est close.', r_reponse_invalide: 'Cette réponse n’est pas possible à ce stade.', r_demande_introuvable: 'Demande introuvable.',
    r_vote_ferme: 'Ce référendum est clos.', r_non_domicilie: 'Seules les personnes domiciliées dans le pays votent.', r_deja_vote: 'Vous avez déjà voté.'
  }
};
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
function langue() { try { const l = global.RPI18n && global.RPI18n.language; return (l && T[l]) ? l : 'fr'; } catch (_) { return 'fr'; } }
function texte(k, v) {
  let s = (T[langue()] && T[langue()][k]) || T.fr[k] || k;
  if (v) s = s.replace(/\{(\w+)\}/g, (m, n) => (v[n] !== undefined ? String(v[n]) : m));
  return s;
}
const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const un = (r) => (Array.isArray(r) ? r[0] : r);
const uuid = () => (global.crypto && global.crypto.randomUUID) ? global.crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
function devise() { return etat().country === 'soviet' ? 'PSK' : 'FR'; }
function motif(r) { const k = 'r_' + (r && r.raison); return T.fr[k] ? texte(k) : texte('refused'); }
function toast(t, b, ok) { if (typeof global.showToast === 'function') global.showToast(t, b, !!ok); }
function appliquerInventaire(r) {
  if (r && typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
  else if (r && Array.isArray(r.inventory) && etat()) etat().inventory = r.inventory;
  if (typeof global.renderInventory === 'function') { try { global.renderInventory(); } catch (_) {} }
}
async function rpc(fn, params) {
  if (typeof global.sbRpc !== 'function') return null;
  return un(await global.sbRpc(fn, params || {}).catch(() => null));
}
function fermerModale() { const m = global.document.getElementById('modal-postes'); if (m) m.classList.remove('open'); }

// ── Boutique « Équipement discret » (armureries, marchés) ───────────────────────────────────────────────────────
// Lieux de vente : copie d'affichage de la table serveur crim_boutiques (le serveur refuse ailleurs).
const LIEUX_BOUTIQUE = [
  ['republic', 'capitale', 'armurerie', 'magasin'], ['republic', 'ville_b', 'armurerie', 'magasin'],
  ['republic', 'ville_a', 'chasse-peche-psm', 'boutique'], ['soviet', 'capitale', 'armurerie', 'magasin'],
  ['soviet', 'ville_a', 'armurerie', 'magasin'], ['republic', 'capitale', 'marche', 'marche_ext'],
  ['republic', 'ville_b', 'marche', 'marche_ext'], ['republic', 'ville_a', 'marche-psm', 'etals'],
  ['soviet', 'capitale', 'marche', 'marche_ext'], ['soviet', 'ville_a', 'marche', 'marche_ext'], ['soviet', 'ville_b', 'marche', 'marche_ext']
];
function ordresBoutiqueDiscretion(buildingId, roomId, ville) {
  const pays = etat().country;
  if (!LIEUX_BOUTIQUE.some(l => l[0] === pays && l[1] === ville && l[2] === buildingId && l[3] === roomId)) return [];
  return [{fn:'boutique_discretion', label:'Équipement discret', pa:0, cost:0, type:'legal', icon:'ti-mask', successRate:100,
    desc:'Masques, tenue ninja et, chez les armuriers, gilet pare-balles, kit de crochetage et pied-de-biche.'}];
}
if (global.window) {
  global.RP_ORDRES_DYNAMIQUES = global.RP_ORDRES_DYNAMIQUES || [];
  if (!global.RP_ORDRES_DYNAMIQUES.includes(ordresBoutiqueDiscretion)) global.RP_ORDRES_DYNAMIQUES.push(ordresBoutiqueDiscretion);
}

let achatEnCours = false;
async function ouvrirBoutiqueDiscretion() {
  const e = await rpc('boutique_discretion_etat');
  if (!e || e.ok !== true) { toast(texte('shop'), motif(e), false); return; }
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('shop');
  let html = '<div class="cpj-dialogue" style="padding:1rem;display:flex;flex-direction:column;gap:.5rem">';
  for (const o of (e.offre || [])) {
    html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem">'
      + '<span>' + esc(o.nom) + (o.trace ? ' <span class="cpj-note" style="font-size:.75rem">(' + esc(texte('traced')) + ')</span>' : '') + '</span>'
      + '<button class="cpj-touche cpj-primaire" data-cle="' + esc(o.cle) + '" onclick="acheterDiscretion(this.dataset.cle)">'
      + esc(texte('buy')) + ' — ' + esc(o.prix) + ' ' + esc(devise()) + '</button></div>';
  }
  html += '<button class="cpj-touche" style="margin-top:.5rem" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div>';
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
async function acheterDiscretion(cle) {
  if (achatEnCours || !cle) return;
  // Vente légale d'une protection : règle générale des interdictions votées, avant tout débit (comme l'ancien achat du gilet).
  if (cle === 'gilet' && typeof global.assembleeControlerVenteLegale === 'function'
      && !(await global.assembleeControlerVenteLegale([{ type: 'protection' }]))) return;
  achatEnCours = true;
  try {
    const r = await rpc('boutique_discretion_acheter', { p_requete: uuid(), p_cle: cle });
    if (!r || r.ok !== true) { toast(texte('shop'), motif(r), false); return; }
    appliquerInventaire(r);
    const s = etat();
    if (s && typeof r.liquide === 'number') s.liquide = r.liquide;
    if (s && typeof r.arg === 'number') s.arg = r.arg;
    fermerModale();
    const nom = (r.inventory || []).slice().reverse().find(i => i && (i.generique_id === cle || (cle === 'gilet' && i.type === 'protection')));
    toast(texte('shop'), texte('bought', { nom: (nom && nom.name) || cle, paye: r.paye, cur: devise() }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { achatEnCours = false; }
}

// ── Revêtir / Retirer (0 PA) ────────────────────────────────────────────────────────────────────────────────────
// Affichage seulement : la catégorie réelle est décidée par crim_objet_categorie_interne côté serveur.
function objetRevetable(item) {
  if (!item) return false;
  return !!item.revetable || item.produitMilitaire === 'gilet_pare_balles' || (item.type === 'protection' && /^gilet/i.test(item.name || ''));
}
function objetPorte(item) { return !!item && !!item.porte_par && item.porte_par === (etat().char && etat().char.name); }
function boutonRevetir(item, idx, style) {
  if (!objetRevetable(item)) return '';
  const porte = objetPorte(item);
  return '<button onclick="' + (porte ? 'crimRetirer' : 'crimRevetir') + '(' + Number(idx) + ')" style="' + (style || '') + '">'
    + '<i class="ti ' + (porte ? 'ti-hanger-off' : 'ti-hanger') + '"></i> ' + esc(texte(porte ? 'remove' : 'wear')) + '</button>';
}
function badgeRevetu(item) { return objetPorte(item) ? ' <span style="color:#8aca6a;font-size:.75rem">(' + esc(texte('worn')) + ')</span>' : ''; }
async function crimPorter(fn, idx) {
  const item = (etat().inventory || [])[idx];
  if (!item) return;
  const r = await rpc(fn, { p_index: idx, p_signature: { name: item.name, type: item.type, stackKey: item.stackKey } });
  if (!r || r.ok !== true) { toast(item.name, motif(r), false); return; }
  appliquerInventaire(r);
  fermerModale();
  toast(item.name, texte(fn === 'crim_revetir' ? 'woreOk' : 'removedOk', { nom: r.objet || item.name })
    + (r.categorie === 'masque' && fn === 'crim_revetir' ? ' ' + texte('modeMasque') : ''), true);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.categorie === 'masque' && typeof global.chargerVraisJoueursPresents === 'function') global.chargerVraisJoueursPresents();
}
const crimRevetir = (idx) => crimPorter('crim_revetir', idx);
const crimRetirer = (idx) => crimPorter('crim_retirer', idx);

// ── Se cacher : messages selon le verdict du serveur (le jet est tiré par se_cacher) ────────────────────────────
function messageSeCacher(v) {
  if (!v || v.ok !== true) {
    if (v && T.fr['r_' + v.raison]) { toast(texte('hideFail'), motif(v), false); return true; }
    return false;
  }
  if (v.cache) toast(texte('hideOk'), texte('hideOkText'), true);
  else if (v.critique) toast(texte('hideCrit'), texte('hideCritText'), false);
  else toast(texte('hideFail'), texte('hideFailText'), false);
  if (typeof v.moral === 'number' && etat()) etat().moral = v.moral;
  return true;
}

// ── Fouiller les cachettes (1 PA), dans le menu « Fouiller ou voler » ───────────────────────────────────────────
function ouvrirFouilleCachettes() {
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('searchGo');
  global.document.getElementById('postes-body').innerHTML = '<div class="cpj-dialogue" style="padding:1rem">'
    + '<p class="cpj-note">' + texte('searchIntro') + '</p><p class="cpj-note">' + esc(texte('searchOdds')) + '</p>'
    + '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">'
    + '<button class="cpj-touche cpj-primaire" onclick="fouilleCachettesConfirmer()">' + esc(texte('searchGo')) + '</button>'
    + '<button class="cpj-touche" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div></div>';
  global.document.getElementById('modal-postes').classList.add('open');
}
async function fouilleCachettesConfirmer() {
  fermerModale();
  const r = await rpc('crim_fouiller_cachettes');
  if (!r || r.ok !== true) { toast(texte('searchDone'), motif(r), false); return; }
  if (etat() && typeof r.pa === 'number') etat().pa = r.pa;
  if (typeof global.updateUI === 'function') global.updateUI();
  const trouves = Array.isArray(r.trouves) ? r.trouves : [];
  if (!trouves.length) { toast(texte('searchDone'), texte('searchNone'), true); return; }
  toast(texte('searchDone'), texte('searchFound', { liste: trouves.map(t => t.masque ? texte('masked') : t.nom).join(', ') }), true);
  if (typeof global.chargerVraisJoueursPresents === 'function') global.chargerVraisJoueursPresents();
}

// ── Neutraliser (lot 2) : crime_neutraliser tranche tout (jet, détection, passage au combat) ─────────────────────
// Aucun taux calculé ici. Un individu masqué est visé par son jeton (crim_presents), jamais par un nom.
function cibleNeutraliser(enc) { try { return JSON.parse(decodeURIComponent(enc)); } catch (_) { return null; } }
function identifiantCible(c) {
  if (!c) return '';
  if (c.jeton) return c.jeton;
  if (c.isPJ) return c.name;
  return c.socleId || c.pnjSocleId || (c.name ? String(c.name).replace(/ \(PNJ\)$/, '') : c.id);
}
function possedeArme(m) {
  if (!m || !m.sousTypes) return true;
  return (etat().inventory || []).some(i => i && i.type === 'arme' && m.sousTypes.includes(i.sousType));
}
function ouvrirNeutraliser(enc) {
  const c = cibleNeutraliser(enc);
  if (!c) return;
  const modes = (typeof global.NEUTRALISER_MODES === 'object' && global.NEUTRALISER_MODES) ? global.NEUTRALISER_MODES
    : (typeof NEUTRALISER_MODES === 'object' ? NEUTRALISER_MODES : {});
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('nTitle', { nom: String(c.name || '').replace(/ \(PNJ\)$/, '') });
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('nIntro')) + '</p>';
  for (const [cle, m] of Object.entries(modes)) {
    const dispo = possedeArme(m);
    html += '<button class="cpj-touche" ' + (dispo ? '' : 'disabled ') + 'onclick="crimNeutraliserConfirmer(\'' + enc + '\',\'' + cle + '\')">'
      + esc(texte('nMode', { label: m.label, pa: m.paPJ })) + (cle === 'feu' ? esc(texte('nFeu')) : '') + (dispo ? '' : esc(texte('nArmeAbsente'))) + '</button>';
  }
  global.document.getElementById('postes-body').innerHTML = html + '</div>';
  global.document.getElementById('modal-postes').classList.add('open');
}
async function crimNeutraliserConfirmer(enc, mode) {
  fermerModale();
  const c = cibleNeutraliser(enc);
  if (!c) return;
  const r = await rpc('crime_neutraliser', { p_cible: identifiantCible(c), p_mode: mode, p_requete: uuid() });
  if (!r || r.ok !== true) { toast(texte('nFail'), motif(r), false); return; }
  if (r.paie && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paie);
  const e = etat();
  if (typeof r.dis === 'number') e.dis = r.dis;
  if (typeof r.moral === 'number') e.moral = r.moral;
  if (Array.isArray(r.recherche)) e.recherche = r.recherche;
  let suite = '';
  if (r.identifie) suite = ' ' + texte('nIdent', { jours: r.peine_jours == null ? '?' : r.peine_jours });
  else if (r.trace) suite = ' ' + texte('nTrace');
  if (r.issue === 'reussite') toast(texte('nOk'), texte('nOkText') + suite, true);
  else if (r.issue === 'combat') toast(texte('nCombat'), texte('nCombatText'), false);
  else if (r.echec_critique) toast(texte('nCrit'), texte('nCritText') + suite, false);
  else toast(texte('nFail'), texte('nFailText') + suite, false);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.issue === 'combat' && Number.isSafeInteger(Number(r.bataille)) && typeof global.ouvrirPanneauCombat === 'function')
    await global.ouvrirPanneauCombat(Number(r.bataille));
}

// ── Voler (lot 3) : crime_voler tranche tout (jet, butin, détection, passage au combat, messages, peine) ─────────
// Déclarations d'ordre lues par le miroir des coûts (ordres_couts : voler 2 PA ; 3 PA pour l'objet précis).
const ORDRES_VOL = {
  argent: { fn: 'voler', label: 'Voler de l’argent liquide', pa: 2, cost: 0 },
  hasard: { fn: 'voler', label: 'Voler un objet au hasard', pa: 2, cost: 0 },
  precis: { fn: 'voler', label: 'Voler un objet précis', pa: 3, cost: 0 }
};
const TYPES_VOL = ['arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse', 'document']; // documents volables (Fred, 20/11/2026)
function titreModale(t) { const e = global.document.getElementById('postes-modal-title'); if (e) e.textContent = t; }
function ouvrirModale(html) {
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
function crimOuvrirVoler(enc) {
  const c = cibleNeutraliser(enc);
  if (!c) return;
  titreModale(texte('vTitle', { nom: String(c.name || '').replace(/ \(PNJ\)$/, '') }));
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('vIntro')) + '</p>';
  html += '<button class="cpj-touche" onclick="crimVolerConfirmer(\'' + enc + '\',\'argent\')">' + esc(texte('vArgent', { pa: ORDRES_VOL.argent.pa })) + '</button>';
  html += '<button class="cpj-touche" onclick="crimVolerConfirmer(\'' + enc + '\',\'hasard\')">' + esc(texte('vHasard', { pa: ORDRES_VOL.hasard.pa })) + '</button>';
  html += '<button class="cpj-touche" onclick="crimVolerTypes(\'' + enc + '\')">' + esc(texte('vPrecis', { pa: ORDRES_VOL.precis.pa })) + '</button>';
  ouvrirModale(html + '</div>');
}
function crimVolerTypes(enc) {
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('vType')) + '</p>';
  for (const t of TYPES_VOL)
    html += '<button class="cpj-touche" onclick="crimVolerConfirmer(\'' + enc + '\',\'precis\',\'' + t + '\')">' + esc(texte('t_' + t)) + '</button>';
  ouvrirModale(html + '</div>');
}
let volEnCours = false;
async function crimVolerConfirmer(enc, butin, type) {
  if (volEnCours) return;
  fermerModale();
  const c = cibleNeutraliser(enc);
  if (!c || !ORDRES_VOL[butin]) return;
  volEnCours = true;
  let r;
  try { r = await rpc('crime_voler', { p_cible: identifiantCible(c), p_butin: butin, p_type: type || null, p_requete: uuid() }); }
  finally { volEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('vFail'), motif(r), false); return; }
  if (r.paie && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paie);
  const e = etat();
  if (typeof r.liquide === 'number') e.liquide = r.liquide;
  if (typeof r.arg === 'number') e.arg = r.arg;
  if (typeof r.moral === 'number') e.moral = r.moral;
  if (Array.isArray(r.recherche)) e.recherche = r.recherche;
  if (r.livre && Array.isArray(r.inventory)) appliquerInventaire(r);
  if (r.sans_risque) {
    toast(texte('vVide'), texte(r.raison_echec === 'type_absent' ? 'vTypeAbsent' : 'vRien'), false);
  } else {
    let suite = '';
    if (r.identifie) suite = ' ' + texte('nIdent', { jours: r.peine_jours == null ? '?' : r.peine_jours });
    else if (r.trace) suite = ' ' + texte('nTrace');
    if (r.issue === 'reussite') toast(texte('vOk'), texte('vOkText', { butin: r.description || '?' }) + (r.reussite_critique ? ' ' + texte('vOkCrit') : '') + suite, true);
    else if (r.issue === 'combat') toast(texte('vCombat'), texte('vCombatText'), false);
    else if (r.echec_critique) toast(texte('vCrit'), texte('vCritText') + suite, false);
    else toast(texte('vFail'), texte('vFailText') + (r.remarque ? ' ' + texte('vRemarque') : '') + suite, false);
  }
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.issue === 'combat' && Number.isSafeInteger(Number(r.bataille)) && typeof global.ouvrirPanneauCombat === 'function')
    await global.ouvrirPanneauCombat(Number(r.bataille));
}
// Menu « Fouiller ou voler » : choisir la personne parmi les présents de la pièce (crim_presents : caché absent,
// masqué par jeton). Les PNJ se volent depuis leur fiche.
async function crimVolerChoisirCible() {
  const r = await rpc('crim_presents');
  const moi = etat().char && etat().char.name;
  const liste = (r && r.ok === true && Array.isArray(r.presents) ? r.presents : []).filter(p => p && p.name !== moi && (!p.masque || p.jeton));
  titreModale(texte('vMenu'));
  if (!liste.length) { ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('vPersonne')) + '</p></div>'); return; }
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('vChoisir')) + '</p>';
  for (const p of liste) {
    const enc = encodeURIComponent(JSON.stringify(p.masque ? { name: p.name, isPJ: true, masque: true, jeton: p.jeton } : { name: p.name, isPJ: true })).replace(/'/g, '%27');
    html += '<button class="cpj-touche" onclick="crimOuvrirVoler(\'' + enc + '\')">' + esc(p.name) + '</button>';
  }
  ouvrirModale(html + '</div>');
}

// ── Cambriolage (lot 4) ─────────────────────────────────────────────────────────────────────────────────────────
// Déclarations d'ordre lues par le miroir des coûts (ordres_couts).
const ORDRES_CAMBRIOLAGE = {
  crocheter: { fn: 'crocheter', label: 'Crocheter une serrure', pa: 3, cost: 0 },
  forcer: { fn: 'forcer_porte', label: 'Forcer la porte', pa: 2, cost: 0 },
  cambrioler: { fn: 'cambrioler', label: 'Cambrioler', pa: 2, cost: 0 }
};
const attr = (v) => esc(v == null ? '' : v).replace(/'/g, '&#39;');
// Boutons affichés sous « Fermé à clé » (porte d'un local : piece renseignée ; entrée d'un bâtiment : piece nulle).
function crimBoutonsPorte(batiment, piece) {
  const b = attr(batiment), p = piece ? attr(piece) : '';
  return '<div style="display:flex;flex-direction:column;gap:.4rem;margin-top:.6rem">'
    + '<p class="cpj-note" style="text-align:center">' + esc(texte('pNote')) + '</p>'
    + '<button class="cpj-touche" data-b="' + b + '" data-p="' + p + '" onclick="crimPorteAgir(\'crocheter\',this.dataset.b,this.dataset.p)">'
    + esc(texte('pCrocheter', { pa: ORDRES_CAMBRIOLAGE.crocheter.pa })) + '</button>'
    + '<button class="cpj-touche" data-b="' + b + '" data-p="' + p + '" onclick="crimPorteAgir(\'forcer\',this.dataset.b,this.dataset.p)">'
    + esc(texte('pForcer', { pa: ORDRES_CAMBRIOLAGE.forcer.pa })) + '</button></div>';
}
function appliquerVerdict(r) {
  if (r.paie && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paie);
  const e = etat();
  if (typeof r.liquide === 'number') e.liquide = r.liquide;
  if (typeof r.arg === 'number') e.arg = r.arg;
  if (typeof r.moral === 'number') e.moral = r.moral;
  if (Array.isArray(r.recherche)) e.recherche = r.recherche;
  if (Array.isArray(r.inventory)) appliquerInventaire(r);
}
function suiteIdentite(r) {
  if (r.identifie) return ' ' + texte('nIdent', { jours: r.peine_jours == null ? '?' : r.peine_jours });
  if (r.trace && r.detecte) return ' ' + texte('nTrace');
  return '';
}
let porteEnCours = false;
async function crimPorteAgir(geste, batiment, piece) {
  if (porteEnCours || !batiment) return;
  fermerModale();
  porteEnCours = true;
  let r;
  try {
    r = await rpc(geste === 'forcer' ? 'crim_forcer_porte' : 'crim_crocheter', { p_batiment: batiment, p_piece: piece || null, p_requete: uuid() });
  } finally { porteEnCours = false; }
  if (!r || r.ok !== true) { toast(texte(geste === 'forcer' ? 'fFail' : 'cFail'), motif(r), false); return; }
  appliquerVerdict(r);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (geste === 'forcer') {
    if (r.reussi) toast(texte('fOk'), texte('fOkText') + suiteIdentite(r), true);
    else toast(texte('fFail'), texte('fFailText'), false);
  } else if (r.reussi) {
    toast(texte('cOk'), texte('cOkText') + ' ' + (r.kit_detruit ? texte('cKitUse') : texte('cKitReste', { n: r.kit_usages_restants })), true);
  } else if (r.echec_critique) toast(texte('cCrit'), texte('cCritText'), false);
  else toast(texte('cFail'), texte('cFailText'), false);
  // Porte ouverte par le serveur : on entre par la navigation ordinaire (le serveur revérifie).
  if (r.reussi && r.entrer) {
    if (typeof global.serruresPassageAccorde === 'function') global.serruresPassageAccorde(r.entrer.batiment, r.entrer.piece, true);
    if (r.entrer.piece && typeof global.enterRoom === 'function') global.enterRoom(r.entrer.batiment, r.entrer.piece);
    else if (!r.entrer.piece && typeof global.enterBuilding === 'function') global.enterBuilding(r.entrer.batiment);
  }
}
// Ce qui s'emporte ici (crim_cambriolage_lire : ni montant de caisse, ni présence de quiconque).
async function crimOuvrirCambriolage() {
  const r = await rpc('crim_cambriolage_lire');
  titreModale(texte('kTitre'));
  if (!r || r.ok !== true) { toast(texte('kTitre'), motif(r), false); return; }
  const ligne = (libelle, cible, ref, bouton) => '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem;padding:.3rem 0;border-top:1px solid #2a3340">'
    + '<span>' + esc(libelle) + '</span><button class="cpj-touche" data-c="' + cible + '" data-r="' + attr(ref) + '" onclick="crimCambrioler(this.dataset.c,this.dataset.r)">'
    + esc(texte(bouton)) + '</button></div>';
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('kNote')) + '</p>';
  const mat = r.materiel || [], st = r.stock || [];
  if (mat.length) html += '<div class="cpj-titre">' + esc(texte('kMateriel')) + '</div>' + mat.map(m => ligne(m.nom || m.generique, 'materiel', m.id, 'kPrendre')).join('');
  if (st.length) html += '<div class="cpj-titre">' + esc(texte('kStock')) + '</div>' + st.map(x => ligne(x.label || x.produit, 'stock', x.produit, 'kPiocher')).join('');
  if (r.caisse) html += '<div class="cpj-titre">' + esc(texte('kCaisse')) + '</div>' + ligne(texte('kCaisse'), 'caisse', '', 'kPiocher');
  if (!mat.length && !st.length && !r.caisse) html += '<p class="cpj-note">' + esc(texte('kRien')) + '</p>';
  ouvrirModale(html + '</div>');
}
let cambriolageEnCours = false;
async function crimCambrioler(cible, ref) {
  if (cambriolageEnCours) return;
  fermerModale();
  cambriolageEnCours = true;
  let r;
  try { r = await rpc('crim_cambrioler', { p_cible: cible, p_ref: ref || null, p_requete: uuid() }); }
  finally { cambriolageEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('kTitre'), motif(r), false); return; }
  appliquerVerdict(r);
  if (r.issue === 'reussite') {
    if (r.livre) toast(texte('kOk'), texte('kOkText', { butin: r.description || '?' }) + (r.reussite_critique ? ' ' + texte('vOkCrit') : '') + suiteIdentite(r), true);
    else toast(texte('kVide'), texte('kVideText') + suiteIdentite(r), false);
  } else if (r.issue === 'combat') toast(texte('vCombat'), texte('vCombatText'), false);
  else if (r.echec_critique) toast(texte('vCrit'), texte('vCritText') + suiteIdentite(r), false);
  else toast(texte('vFail'), texte('vFailText') + (r.remarque ? ' ' + texte('vRemarque') : '') + suiteIdentite(r), false);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.issue === 'combat' && Number.isSafeInteger(Number(r.bataille)) && typeof global.ouvrirPanneauCombat === 'function')
    await global.ouvrirPanneauCombat(Number(r.bataille));
}

// ── Empoisonner, Incendier, Explosifs (lot 5) ──────────────────────────────────────────────────────────────────
// Cible de l'empoisonnement : présents de la pièce (crim_presents : caché absent, masqué par jeton), PJ seulement.
async function crimOuvrirEmpoisonner() {
  const r = await rpc('crim_presents');
  const moi = etat().char && etat().char.name;
  const liste = (r && r.ok === true && Array.isArray(r.presents) ? r.presents : []).filter(p => p && p.name !== moi && (!p.masque || p.jeton) && p.isPJ !== false);
  titreModale(texte('eTitre'));
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('eNote')) + '</p>';
  if (!liste.length) { ouvrirModale(html + '<p class="cpj-note">' + esc(texte('ePersonne')) + '</p></div>'); return; }
  html += '<p class="cpj-note">' + esc(texte('eChoisir')) + '</p>';
  for (const p of liste) {
    const enc = encodeURIComponent(JSON.stringify(p.masque ? { name: p.name, isPJ: true, masque: true, jeton: p.jeton } : { name: p.name, isPJ: true })).replace(/'/g, '%27');
    html += '<button class="cpj-touche" onclick="crimEmpoisonnerConfirmer(\'' + enc + '\')">' + esc(p.name) + '</button>';
  }
  ouvrirModale(html + '</div>');
}
let poisonEnCours = false;
async function crimEmpoisonnerConfirmer(enc) {
  if (poisonEnCours) return;
  fermerModale();
  const c = cibleNeutraliser(enc);
  if (!c) return;
  poisonEnCours = true;
  let r;
  try { r = await rpc('crime_empoisonner', { p_cible: identifiantCible(c), p_requete: uuid() }); }
  finally { poisonEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('eTitre'), motif(r), false); return; }
  appliquerVerdict(r);
  if (typeof global.updateUI === 'function') global.updateUI();
  const suite = suiteIdentite(r);
  if (r.palier === 'totale') toast(texte('eTotale'), texte('eTotaleText') + suite, true);
  else if (r.palier === 'partielle') toast(texte('ePartielle'), texte('ePartielleText') + suite, true);
  else if (r.palier === 'echec_partiel') toast(texte('eAttenue'), texte('eAttenueText') + suite, false);
  else if (r.echec_critique) toast(texte('eCrit'), texte('eCritText') + suite, false);
  else toast(texte('eRate'), texte('eRateText') + suite, false);
}
function batimentCourant() {
  const e = etat();
  const b = (typeof BUILDINGS !== 'undefined' && BUILDINGS) ? BUILDINGS[e.currentBuilding] : null;
  return b ? { id: e.currentBuilding, nom: b.name || e.currentBuilding } : null;
}
function crimOuvrirSabotage(genre) {
  const b = batimentCourant();
  if (!b) { toast(texte(genre === 'explosifs' ? 'xFail' : 'iFail'), texte('r_hors_batiment'), false); return; }
  const k = genre === 'explosifs' ? 'x' : 'i';
  titreModale(texte(k + 'Titre', { nom: b.nom }));
  ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte(k + 'Note')) + '</p>'
    + '<button class="cpj-touche" onclick="crimSabotageConfirmer(\'' + (genre === 'explosifs' ? 'explosifs' : 'incendie') + '\')">' + esc(texte(k + 'Go')) + '</button></div>');
}
let sabotageEnCours = false;
async function crimSabotageConfirmer(genre) {
  if (sabotageEnCours) return;
  fermerModale();
  const b = batimentCourant();
  if (!b) return;
  sabotageEnCours = true;
  let r;
  try { r = await rpc(genre === 'explosifs' ? 'crime_explosifs' : 'crime_incendier', { p_nom_batiment: b.nom, p_requete: uuid() }); }
  finally { sabotageEnCours = false; }
  if (!r || r.ok !== true) { toast(texte(genre === 'explosifs' ? 'xFail' : 'iFail'), motif(r), false); return; }
  appliquerVerdict(r);
  if (typeof r.hp === 'number') etat().hp = r.hp;
  if (r.issue === 'reussite' && typeof global.chargerBatimentsFermes === 'function') { try { await global.chargerBatimentsFermes(); } catch (_) {} }
  if (typeof global.updateUI === 'function') global.updateUI();
  const suite = suiteIdentite(r);
  if (genre === 'explosifs') {
    if (r.issue === 'reussite') toast(texte('xOk'), texte('xOkText', { nom: b.nom, n: Number(r.victimes) || 0 }) + suite, true);
    else if (r.explosion_prematuree) toast(texte('xPrem'), texte('xPremText') + suite, false);
    else toast(texte('xFail'), texte('xFailText'), false);
    // Animation de résolution (présentation seulement, après le verdict du serveur).
    if (typeof global.ouvrirResolutionSpectaculaire === 'function' && (r.issue === 'reussite' || r.explosion_prematuree)) {
      try { global.ouvrirResolutionSpectaculaire({ type: 'bombe', succes: r.issue === 'reussite', titre: texte(r.issue === 'reussite' ? 'xOk' : 'xPrem'),
        resultatHtml: '<div>' + esc(r.issue === 'reussite' ? texte('xOkText', { nom: b.nom, n: Number(r.victimes) || 0 }) : texte('xPremText')) + esc(suite) + '</div>' }); } catch (_) {}
    }
  } else {
    const bidon = r.bidon ? ' ' + texte('iBidon') : '';
    if (r.issue === 'reussite') toast(texte('iOk'), texte('iOkText', { nom: b.nom, jours: r.jours }) + bidon + suite, true);
    else if (r.echec_critique) toast(texte('iFail'), texte('iCritText') + bidon + suite, false);
    else toast(texte('iFail'), texte('iFailText') + bidon, false);
  }
}

// ── Justice (lot 6) : enquête du commissaire sur les plaintes contre X ──────────────────────────────────────────────
// Déclaration d'ordre lue par le miroir des coûts (ordres_couts).
const ORDRES_JUSTICE = {
  enqueter: { fn: 'enqueter_plainte', label: 'Enquêter sur une plainte contre X', pa: 2, cost: 0 }
};
let enqueteEnCours = false;
function libelleIndices(ind) {
  const out = [];
  for (const k of ['arme', 'poison', 'batiment', 'objet']) if (ind && ind[k]) out.push(texte('i_' + k, { v: ind[k] }));
  return out.join(', ');
}
function libellePistes(p) {
  const out = [];
  for (const k of ['trace', 'rumeurs', 'informateur', 'achats']) if (p && p[k] === true) out.push(texte('p_' + k));
  return out.length ? out.join(', ') : texte('jPisteAucune');
}
async function crimOuvrirEnquetes() {
  const r = await rpc('crim_enquetes_lire');
  const pa = (r && r.pa) || ORDRES_JUSTICE.enqueter.pa;
  titreModale(texte('jTitre'));
  if (!r || r.ok !== true) { ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note">' + esc(motif(r)) + '</p></div>'); return; }
  const liste = Array.isArray(r.affaires) ? r.affaires : [];
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('jNote', { pa })) + '</p>';
  if (!liste.length) html += '<p class="cpj-note">' + esc(texte('jAucune')) + '</p>';
  for (const a of liste) {
    const acte = T.fr['a_' + a.acte] ? texte('a_' + a.acte) : a.acte;
    const ind = libelleIndices(a.indices);
    html += '<div style="margin:.6rem 0;padding:.5rem 0;border-top:1px solid rgba(169,141,86,.35)">'
      + '<div><strong>' + esc(texte('jAffaire', { acte, victime: a.victime || '?', jour: a.jour == null ? '?' : a.jour })) + '</strong> · '
      + esc(texte(a.issue === 'reussite' ? 'jIssueOk' : 'jIssueKo')) + '</div>'
      + '<p class="cpj-note">' + esc(texte('jAuteur', { auteur: texte(a.masque ? 'jMasque' : 'jInconnu') }))
      + (ind ? ' · ' + esc(texte('jIndices', { liste: ind })) : '') + '</p>'
      + '<p class="cpj-note">' + esc(texte('jPistes', { liste: libellePistes(a.pistes) })) + ' · '
      + esc(texte('jChances', { taux: a.chances == null ? '?' : a.chances })) + ' · ' + esc(texte('jTentatives', { n: a.tentatives || 0 })) + '</p>'
      + (a.deja_aujourdhui ? '<button class="cpj-touche" disabled>' + esc(texte('jDeja')) + '</button>'
        : '<button class="cpj-touche cpj-primaire" onclick="crimEnqueter(' + Number(a.affaire) + ')">' + esc(texte('jEnqueter', { pa })) + '</button>')
      + '</div>';
  }
  ouvrirModale(html + '</div>');
}
async function crimEnqueter(affaire) {
  if (enqueteEnCours || !Number.isSafeInteger(Number(affaire))) return;
  fermerModale();
  enqueteEnCours = true;
  let r;
  try { r = await rpc('crim_enqueter', { p_affaire: Number(affaire), p_requete: uuid() }); }
  finally { enqueteEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('jFail'), motif(r), false); return; }
  if (r.paiement && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paiement);
  if (r.reussi) toast(texte('jOk'), texte('jOkText', { nom: r.coupable || '?', jours: r.jours == null ? '?' : r.jours }), true);
  else toast(texte('jFail'), texte('jFailText') + (r.averti ? ' ' + texte('jAverti') : ''), false);
  if (typeof global.updateUI === 'function') global.updateUI();
}
// Bouton ajouté à la fenêtre « Mener l'enquête » du commissaire.
function crimBoutonEnquetes() {
  return '<button class="cpj-touche cpj-primaire" style="margin-bottom:1rem" onclick="crimOuvrirEnquetes()">'
    + esc(texte('jMenu', { pa: ORDRES_JUSTICE.enqueter.pa })) + '</button>';
}

// ── Corruption au QHS (lot 7) : directeur et gardien ; le serveur tranche (jet, peine, caisse) ──────────────────────
// Déclarations d'ordre (mêmes tarifs que data.js, lues par le miroir des coûts).
const ORDRES_CORRUPTION_QHS = {
  directeur: { fn: 'corrompre_fonct', label: 'Corrompre le directeur', pa: 3, cost: 1500 },
  gardien: { fn: 'corrompre_gardien', label: 'Corrompre un gardien', pa: 2, cost: 800 }
};
let corruptionQhsEnCours = false;
// ── Envoi au QHS (lot 10, § 16) : demandes du juge, initiative du décideur, référendum. Le serveur décide tout ────────
let qhsLu = null, qhsEnCours = false;
function dateCourte(iso) {
  try { return new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); } catch (_) { return String(iso || ''); }
}
function blocVotesQhs(liste) {
  if (!liste || !liste.length) return '<p class="cpj-note">' + esc(texte('hVotesAucun')) + '</p>';
  return liste.map((v) => '<div style="border:1px solid rgba(201,168,76,.25);margin:.4rem 0;padding:.5rem"><p class="cpj-note">'
    + esc(texte('hQuestion', { detenu: v.detenu, date: dateCourte(v.cloture) })) + '</p>'
    + (v.a_vote ? '<p class="cpj-note">' + esc(texte('hDejaVote')) + '</p>'
      : '<button class="cpj-touche cpj-primaire" onclick="crimVoterReferendumQhs(' + Number(v.id) + ',\'oui\')">' + esc(texte('hOui')) + '</button> '
      + '<button class="cpj-touche" onclick="crimVoterReferendumQhs(' + Number(v.id) + ',\'non\')">' + esc(texte('hNon')) + '</button>')
    + '</div>').join('');
}
// ── Laissez-passer (réponses de Fred du 20/11/2026) : registre par lieu, contrôle du document, journal des passages ──
async function crimOuvrirLaissezPasserQhs(lu) {
  const r = lu || await rpc('crim_laissez_passer_qhs_lire');
  titreModale(texte('lpTitre'));
  if (!r || r.ok !== true) { toast(texte('lpTitre'), motif(r), false); return; }
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('lpNote')) + '</p>'
    + '<input id="crim-lp-nom" type="text" maxlength="60" class="cpj-champ" placeholder="' + esc(texte('lpNom')) + '"> '
    + '<button class="cpj-touche cpj-primaire" onclick="crimLaissezPasserQhs(\'delivrer\')">' + esc(texte('lpDelivrer')) + '</button>'
    + '<p class="cpj-titre">' + esc(texte('lpValides')) + '</p>';
  const valides = Array.isArray(r.valides) ? r.valides : [];
  html += valides.length ? valides.map(v => '<div style="margin:.3rem 0">' + esc(texte('lpLigne', { nom: v.nom, par: v.par || '?' }))
      + ' <button class="cpj-touche" onclick="crimLaissezPasserQhs(\'retirer\',' + esc(JSON.stringify(String(v.nom))) + ')">' + esc(texte('lpRetirer')) + '</button></div>').join('')
    : '<p class="cpj-note">' + esc(texte('lpAucun')) + '</p>';
  html += '<p class="cpj-titre">' + esc(texte('lpJournal')) + '</p>' + blocPassages(r.passages) + '</div>';
  ouvrirModale(html);
}
function blocPassages(passages) {
  const p = Array.isArray(passages) ? passages : [];
  return p.length ? p.map(x => '<div class="cpj-note">' + esc(dateCourte(x.le)) + ' — ' + esc(x.nom) + '</div>').join('')
    : '<p class="cpj-note">' + esc(texte('lpAucunPassage')) + '</p>';
}
async function crimLaissezPasserQhs(action, nom) {
  const n = action === 'delivrer' ? String((global.document.getElementById('crim-lp-nom') || {}).value || '').trim() : nom;
  if (!n) { toast(texte('lpTitre'), texte('r_personnage_introuvable'), false); return; }
  const r = await rpc(action === 'delivrer' ? 'crim_laissez_passer_qhs_delivrer' : 'crim_laissez_passer_qhs_retirer', { p_nom: n });
  if (!r || r.ok !== true) { toast(texte('lpTitre'), motif(r), false); return; }
  toast(texte('lpTitre'), action === 'delivrer' ? texte('lpOk', { nom: r.accorde }) : texte('lpRetire', { nom: r.retire }), true);
  crimOuvrirLaissezPasserQhs(r);
}
// Faux laissez-passer : le faussaire choisit le lieu et le nom inscrit ; le serveur reçoit 'faux_laissez_passer|lieu|pays|nom'.
function crimFauxLpOuvrir(mode, pa, cost) {
  titreModale(texte('flpTitre'));
  ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('flpNote')) + '</p>'
    + '<label class="cpj-note">' + esc(texte('flpLieu')) + ' <select id="crim-flp-lieu" class="cpj-champ">'
    + '<option value="archives_ecoute">' + esc(texte('flpArchives')) + '</option><option value="qhs">' + esc(texte('flpQhs')) + '</option></select></label>'
    + '<input id="crim-flp-nom" type="text" maxlength="60" class="cpj-champ" placeholder="' + esc(texte('flpNom')) + '"> '
    + '<button class="cpj-touche cpj-primaire" onclick="crimFauxLpValider(\'' + (mode === 'greffe' ? 'greffe' : 'imprimante') + '\',' + Number(pa || 0) + ',' + Number(cost || 0) + ')">'
    + esc(texte('flpValider')) + '</button></div>');
}
function crimFauxLpValider(mode, pa, cost) {
  const d = global.document;
  const lieu = (d.getElementById('crim-flp-lieu') || {}).value === 'qhs' ? 'qhs' : 'archives_ecoute';
  const nom = String((d.getElementById('crim-flp-nom') || {}).value || '').replace(/\|/g, ' ').trim();
  if (!nom) { toast(texte('flpTitre'), texte('flpNomRequis'), false); return; }
  const pdoc = ['faux_laissez_passer', lieu, lieu === 'qhs' ? (etat().country || 'republic') : 'soviet', nom].join('|');
  const m = d.getElementById('modal-postes'); if (m) m.classList.remove('open');
  if (mode === 'greffe') { if (typeof global.confirmerFalsification === 'function') global.confirmerFalsification(pdoc, pa, cost); }
  else if (typeof global.fauxImprimer === 'function') global.fauxImprimer(pdoc);
}
async function crimOuvrirEnvoisQhs() {
  const r = await rpc('crim_qhs_lire');
  titreModale(texte('hTitre'));
  if (!r || r.ok !== true) { toast(texte('hTitre'), motif(r), false); return; }
  qhsLu = r;
  let html = '<div class="cpj-dialogue">';
  if (!r.decideur) {
    html += '<p class="cpj-note">' + esc(texte(r.sovarka ? 'hSovarka' : 'hReserve')) + '</p>';
    html += '<p class="cpj-titre">' + esc(texte('hVotes')) + '</p>' + blocVotesQhs(r.referendums);
    ouvrirModale(html + '</div>');
    return;
  }
  const v1 = { pm: r.penalite_ministre, pg: r.penalite_gouvernement }, v2 = { pm: 2 * r.penalite_ministre, pg: 2 * r.penalite_gouvernement };
  html += '<p class="cpj-note">' + esc(texte('hNote')) + '</p>';
  if (r.role === 'pm') html += '<p class="cpj-note">' + esc(texte('hSuppleance')) + '</p>';
  html += '<p class="cpj-titre">' + esc(texte('hDemandes')) + '</p>';
  if (!r.demandes.length) html += '<p class="cpj-note">' + esc(texte('hAucune')) + '</p>';
  r.demandes.forEach((d, i) => {
    html += '<div style="border:1px solid rgba(201,168,76,.25);margin:.4rem 0;padding:.5rem"><strong>' + esc(d.detenu) + '</strong>'
      + '<p class="cpj-note">' + esc(d.origine === 'juge' ? texte('hJuge', { juge: d.juge || '?' }) : texte('hInitiative'))
      + (d.motif ? ' — ' + esc(d.motif) : '') + '</p>';
    if (d.statut === 'en_attente') {
      html += '<button class="cpj-touche" onclick="crimQhsDecider(\'d\',' + i + ',\'valider\')">' + esc(texte('hValider', v1)) + '</button> '
        + '<button class="cpj-touche cpj-primaire" onclick="crimQhsDecider(\'d\',' + i + ',\'referendum\')">' + esc(texte('hReferendum')) + '</button> '
        + '<button class="cpj-touche" onclick="crimQhsDecider(\'d\',' + i + ',\'refuser\')">' + esc(texte('hRefuser')) + '</button>';
    } else if (d.statut === 'referendum') {
      html += '<p class="cpj-note">' + esc(texte('hEnCours', { date: dateCourte(d.cloture) })) + '</p>';
    } else if (d.statut === 'referendum_non') {
      const dep = d.depouillement || {};
      html += '<p class="cpj-note">' + esc(texte('hPerdu', { oui: dep.oui == null ? '?' : dep.oui, non: dep.non == null ? '?' : dep.non })) + '</p>'
        + '<button class="cpj-touche" onclick="crimQhsDecider(\'d\',' + i + ',\'passer_outre\')">' + esc(texte('hOutre', v2)) + '</button> '
        + '<button class="cpj-touche cpj-primaire" onclick="crimQhsDecider(\'d\',' + i + ',\'respecter\')">' + esc(texte('hRespecter')) + '</button>';
    }
    html += '</div>';
  });
  html += '<p class="cpj-titre">' + esc(texte('hDetenus')) + '</p>';
  const libres = r.detenus.filter((x) => !x.demande);
  if (!libres.length) html += '<p class="cpj-note">' + esc(texte('hAucunDetenu')) + '</p>';
  r.detenus.forEach((x, i) => {
    if (x.demande) return;
    html += '<div style="border:1px solid rgba(201,168,76,.25);margin:.4rem 0;padding:.5rem"><strong>' + esc(x.nom) + '</strong>'
      + '<p class="cpj-note">' + esc(x.raison || '') + (x.jour_fin != null ? ' — ' + esc(texte('hFin', { jour: x.jour_fin })) : '') + '</p>'
      + '<button class="cpj-touche" onclick="crimQhsDecider(\'t\',' + i + ',\'valider\')">' + esc(texte('hValider', v1)) + '</button> '
      + '<button class="cpj-touche cpj-primaire" onclick="crimQhsDecider(\'t\',' + i + ',\'referendum\')">' + esc(texte('hReferendum')) + '</button></div>';
  });
  html += '<p class="cpj-titre">' + esc(texte('hVotes')) + '</p>' + blocVotesQhs(r.referendums);
  ouvrirModale(html + '</div>');
}
async function crimQhsDecider(genre, i, reponse) {
  if (qhsEnCours || !qhsLu) return;
  const d = genre === 'd' ? (qhsLu.demandes || [])[i] : null, x = genre === 't' ? (qhsLu.detenus || [])[i] : null;
  if (!d && !x) return;
  fermerModale();
  qhsEnCours = true;
  let r;
  try { r = await rpc('crim_qhs_decider', { p_demande: d ? d.id : null, p_detenu: x ? x.nom : null, p_reponse: reponse }); } finally { qhsEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('hKo'), motif(r), false); return; }
  if (typeof r.pop === 'number' && typeof global.adopterJaugeServeur === 'function') global.adopterJaugeServeur('pop', r.pop);
  if (typeof global.updateUI === 'function') global.updateUI();
  toast(texte('hOk_' + reponse), texte('hOkText_' + reponse, { detenu: r.detenu, pop: r.pop == null ? '?' : r.pop,
    n: r.resultat && r.resultat.electeurs != null ? r.resultat.electeurs : '?' }), true);
}
async function crimVoterReferendumQhs(id, choix) {
  if (qhsEnCours) return;
  fermerModale();
  qhsEnCours = true;
  let r;
  try { r = await rpc('crim_qhs_voter', { p_demande: Number(id), p_choix: choix === 'oui' ? 'oui' : 'non' }); } finally { qhsEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('hVoteKo'), motif(r), false); return; }
  toast(texte('hVoteOk'), texte('hVoteOkText', { choix: texte(r.choix === 'oui' ? 'hOui' : 'hNon') }), true);
}

async function crimOuvrirCorruptionQhs(qui) {
  const o = ORDRES_CORRUPTION_QHS[qui === 'directeur' ? 'directeur' : 'gardien'];
  const r = await rpc('crim_corruption_qhs_lire');
  titreModale(texte(qui === 'directeur' ? 'qDirTitre' : 'qGarTitre'));
  if (!r || r.ok !== true || !r.detenu_qhs) { ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('qReserve')) + '</p></div>'); return; }
  const v = { pa: o.pa, cout: o.cost, cur: devise() };
  let html = '<div class="cpj-dialogue">';
  if (qui === 'directeur') {
    html += '<p class="cpj-note">' + esc(texte('qDirNote', { jours: r.peine_echec_jours == null ? 1 : r.peine_echec_jours })) + '</p>';
    if (r.directeur_tente) html += '<p class="cpj-note">' + esc(texte('qDirFerme')) + '</p>';
    else if (!r.reduction_possible) html += '<p class="cpj-note">' + esc(texte('qDirCourt')) + '</p>';
    else html += '<button class="cpj-touche cpj-primaire" onclick="crimCorrompreDirecteur()">' + esc(texte('qDirGo', v)) + '</button>';
    ouvrirModale(html + '</div>');
    return;
  }
  html += '<p class="cpj-note">' + esc(texte('qGarNote', v)) + '</p>';
  if (r.gardien_aujourdhui) { ouvrirModale(html + '<p class="cpj-note">' + esc(texte('qGarDeja')) + '</p></div>'); return; }
  const inv = (etat().inventory || []).map((it, i) => ({ it, i })).filter((x) => x.it && !objetPorte(x.it));
  const radio = (val, lib, off) => '<label style="display:block;margin:.3rem 0"><input type="radio" name="crim-qhs-service" value="' + val + '"'
    + (off ? ' disabled' : '') + '> ' + esc(lib) + (off ? ' ' + esc(texte('qActif')) : '') + '</label>';
  html += radio('evasion', texte('qEvasion', { bonus: r.bonus_evasion == null ? 25 : r.bonus_evasion }), r.evasion_active)
    + radio('protection', texte('qProtection'), r.protection_active)
    + radio('message', texte('qMessage'), false) + radio('objet', texte('qObjet'), false)
    + '<input id="crim-qhs-dest" class="cpj-champ" style="width:100%;text-align:left;margin-top:.5rem" placeholder="' + esc(texte('qDest')) + '">'
    + '<textarea id="crim-qhs-texte" class="cpj-champ" style="width:100%;text-align:left;margin-top:.4rem" rows="3" maxlength="1000" placeholder="' + esc(texte('qTexte')) + '"></textarea>'
    + (inv.length ? '<select id="crim-qhs-objet" class="cpj-champ" style="width:100%;text-align:left;margin-top:.4rem"><option value="">' + esc(texte('qChoixObjet')) + '</option>'
      + inv.map((x) => '<option value="' + x.i + '">' + esc(x.it.name || x.it.type || '?') + '</option>').join('') + '</select>'
      : '<p class="cpj-note">' + esc(texte('qAucunObjet')) + '</p>')
    + '<button class="cpj-touche cpj-primaire" style="margin-top:.6rem" onclick="crimCorrompreGardien()">' + esc(texte('qEnvoyer', v)) + '</button>';
  ouvrirModale(html + '</div>');
}
function suiteDenonce(r) { return r && r.denonce ? ' ' + texte('qDenonce', { jours: r.peine_jours == null ? '?' : r.peine_jours }) : ''; }
async function crimCorrompreDirecteur() {
  if (corruptionQhsEnCours) return;
  fermerModale();
  corruptionQhsEnCours = true;
  let r;
  try { r = await rpc('crim_corrompre_directeur', { p_requete: uuid() }); } finally { corruptionQhsEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('qDirKo'), motif(r), false); return; }
  appliquerVerdict(r);
  if (typeof r.dis === 'number') etat().dis = r.dis;
  if (typeof r.jour_fin === 'number' && etat().estEmprisonne) etat().estEmprisonne.jourFin = r.jour_fin;
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.reussi) toast(texte('qDirOk'), texte('qDirOkText', { gain: r.gain }), true);
  else toast(texte('qDirKo'), texte('qDirKoText', { jours: r.jours_ajoutes == null ? '?' : r.jours_ajoutes }) + suiteDenonce(r), false);
}
async function crimCorrompreGardien() {
  if (corruptionQhsEnCours) return;
  const doc = global.document;
  const choix = doc.querySelector('input[name="crim-qhs-service"]:checked');
  if (!choix) return;
  const service = choix.value;
  const dest = ((doc.getElementById('crim-qhs-dest') || {}).value || '').trim();
  const msg = ((doc.getElementById('crim-qhs-texte') || {}).value || '').trim();
  const sel = doc.getElementById('crim-qhs-objet');
  const idx = sel && sel.value !== '' ? Number(sel.value) : null;
  const item = idx == null ? null : (etat().inventory || [])[idx];
  if (service === 'objet' && !item) return;
  fermerModale();
  corruptionQhsEnCours = true;
  let r;
  try {
    r = await rpc('crim_corrompre_gardien', { p_service: service, p_destinataire: dest || null, p_texte: msg || null,
      p_index: item ? idx : null, p_signature: item && typeof global.signatureObjetInventaire === 'function' ? global.signatureObjetInventaire(item)
        : (item ? { name: item.name || '', type: item.type || '', stackKey: item.stackKey || '' } : null), p_requete: uuid() });
  } finally { corruptionQhsEnCours = false; }
  if (!r || r.ok !== true) { toast(texte('qGarKo'), r && r.raison === 'une_tentative_par_jour' ? texte('qGarDeja') : motif(r), false); return; }
  appliquerVerdict(r);
  if (typeof r.dis === 'number') etat().dis = r.dis;
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.reussi) toast(texte('qGarOk'), texte('qOk_' + service, { dest: r.destinataire || dest }), true);
  else toast(texte('qGarKo'), texte('qGarKoText') + suiteDenonce(r), false);
}

// ── Lot 8 : délits d'information — résultat de « Lancer une rumeur » (rumeur_lancer) ─────────────────────────────
// Le serveur tranche tout (jet, échec critique, détection après réussite, perte, peine d'office) ; ceci n'affiche que sa réponse.
function crimRumeurResultat(v, type, cible, texteRumeur) {
  const e = etat();
  if (typeof v.pa === 'number') e.pa = v.pa;
  if (typeof global.adopterJaugeServeur === 'function') global.adopterJaugeServeur('pop', v.pop);
  if (Array.isArray(v.recherche)) e.recherche = v.recherche;
  if (typeof v.dis === 'number') e.dis = v.dis;
  const jours = v.peine_jours == null ? '?' : v.peine_jours;
  const journal = (t, c) => { if (typeof global.addJournalEntry === 'function') global.addJournalEntry(t, c); };
  if (v.reussi) {
    if (type === 'organisation' && typeof global.chargerOrganisations === 'function') global.chargerOrganisations();
    const cle = type === 'gouvernement' && !(v.membres > 0) ? 'rEffet_gouvernement0' : 'rEffet_' + type;
    const effet = texte(T.fr[cle] ? cle : 'rEffet_local', { perte: v.perte, membres: v.membres, cible });
    titreModale(texte('rOkTitre'));
    ouvrirModale('<div class="cpj-dialogue"><p class="cpj-note"><em>« ' + esc(texteRumeur) + ' »</em></p><p class="cpj-note">'
      + esc(texte('rCible', { cible })) + '</p>' + (v.identifie ? '<p class="cpj-note">' + esc(texte('rDetecte', { jours })) + '</p>' : '') + '</div>');
    journal(texte('rJournalOk', { cible, effet }), 'event-good');
    if (v.identifie) toast(texte('rOkTitre'), texte('rDetecte', { jours }), false);
  } else {
    fermerModale();
    const corps = v.echec_critique ? texte('rCrit', { cible, perte: v.perte, jours })
      : (v.perte > 0 ? texte('rKo', { perte: v.perte }) : texte('rKo0'));
    toast(texte(v.echec_critique ? 'rCritTitre' : 'rKoTitre'), corps, false);
    journal(texte('rJournalKo', { cible }) + ' ' + corps, 'event-bad');
  }
  if (typeof global.updateUI === 'function') global.updateUI();
}
function crimTractFlagrant(pnj, jours) {
  const j = jours == null ? '?' : jours;
  return { titre: texte('tFlagrantTitre'), corps: texte('tFlagrant', { pnj, jours: j }), journal: texte('tFlagrantJournal', { pnj, jours: j }),
    motif: texte('tMotif') };
}

// ── Événements d'écran : « Bas les masques ! » (arrestation d'un PJ masqué), débusqué ───────────────────────────
function injecterStyle() {
  const doc = global.document;
  if (!doc || doc.getElementById('crim-style')) return;
  const st = doc.createElement('style');
  st.id = 'crim-style';
  st.textContent = '#crim-demasque{position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;justify-content:center;'
    + 'background:rgba(12,16,22,.88);padding:16px;animation:crimFond .4s ease-out}'
    + '#crim-demasque .crim-scene{position:relative;width:min(340px,90vw);text-align:center;color:#e8eef5}'
    + '#crim-demasque .crim-visage{position:relative;width:160px;height:160px;margin:0 auto 1rem;border-radius:50%;'
    + 'background:radial-gradient(circle at 50% 40%,#e9c9a6 0 55%,#c9a37f 56% 100%);box-shadow:0 0 0 4px #2b3644}'
    + '#crim-demasque .crim-oeil{position:absolute;top:58px;width:16px;height:16px;border-radius:50%;background:#1d2530}'
    + '#crim-demasque .crim-oeil.g{left:46px}#crim-demasque .crim-oeil.d{right:46px}'
    + '#crim-demasque .crim-bouche{position:absolute;left:58px;top:104px;width:44px;height:14px;border-radius:0 0 22px 22px;background:#7a3a3a}'
    + '#crim-demasque .crim-masque{position:absolute;left:18px;top:40px;width:124px;height:52px;border-radius:26px 26px 40px 40px;'
    + 'background:linear-gradient(90deg,#7b2fbe,#d4af37 50%,#7b2fbe);box-shadow:0 2px 6px rgba(0,0,0,.5);'
    + 'animation:crimArrache 1.4s .6s cubic-bezier(.5,-0.4,.7,1) forwards}'
    + '#crim-demasque .crim-masque::before,#crim-demasque .crim-masque::after{content:"";position:absolute;top:16px;width:26px;height:18px;'
    + 'border-radius:50%;background:#10151c}#crim-demasque .crim-masque::before{left:22px}#crim-demasque .crim-masque::after{right:22px}'
    + '#crim-demasque .crim-titre{font-family:Bebas Neue,Arial Narrow,sans-serif;font-size:2.2rem;letter-spacing:.08em;color:#ffd98a;'
    + 'opacity:0;animation:crimTitre .5s 1.6s ease-out forwards}'
    + '#crim-demasque .crim-texte{font-size:.95rem;opacity:0;animation:crimTitre .5s 2s ease-out forwards}'
    + '@keyframes crimFond{from{opacity:0}to{opacity:1}}'
    + '@keyframes crimArrache{0%{transform:none}25%{transform:translateY(-6px) rotate(-4deg)}100%{transform:translate(160px,-220px) rotate(70deg);opacity:0}}'
    + '@keyframes crimTitre{from{opacity:0;transform:scale(.6)}to{opacity:1;transform:none}}'
    + '@media (prefers-reduced-motion:reduce){#crim-demasque *{animation-duration:.01s!important;animation-delay:0s!important}}';
  doc.head.appendChild(st);
}
function animationDemasquage() {
  const doc = global.document;
  if (!doc || !doc.body || doc.getElementById('crim-demasque')) return;
  injecterStyle();
  const f = doc.createElement('div');
  f.id = 'crim-demasque';
  f.setAttribute('role', 'dialog');
  f.innerHTML = '<div class="crim-scene"><div class="crim-visage"><span class="crim-oeil g"></span><span class="crim-oeil d"></span>'
    + '<span class="crim-bouche"></span><span class="crim-masque"></span></div>'
    + '<div class="crim-titre">' + esc(texte('unmaskTitle')) + '</div><div class="crim-texte">' + esc(texte('unmaskText')) + '</div>'
    + '<button class="cpj-touche" style="margin-top:1rem" onclick="document.getElementById(\'crim-demasque\').remove()">OK</button></div>';
  f.addEventListener('click', (e) => { if (e.target === f) f.remove(); });
  doc.body.appendChild(f);
}
let lectureEnCours = false;
async function lireEvenementsCrim() {
  if (lectureEnCours || !(etat().char && etat().char.name)) return;
  lectureEnCours = true;
  try {
    const r = await rpc('crim_evenements_lire');
    if (!r || r.ok !== true) return;
    for (const ev of (r.evenements || [])) {
      if (ev.type === 'demasque') animationDemasquage();
      else if (ev.type === 'debusque') {
        toast(texte('flushed'), ev.donnees && ev.donnees.par ? texte('flushedBy', { par: ev.donnees.par }) : texte('flushedAnon'), false);
        inscrireDebusquage(ev.donnees || {});
      }
      else if (ev.type === 'journal') inscrireAuJournal(ev.donnees || {});
    }
  } finally { lectureEnCours = false; }
}
// VICTIMES PRÉVENUES PAR LE JOURNAL (Fred, 20/11/2026) : tout crime s'inscrit au journal d'événements, plus jamais par
// un courrier « Événement ». Le serveur a déjà appliqué l'anonymat ; le texte est affiché en texte brut (échappé).
function texteBrut(v) { return String(v == null ? '' : v).replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim(); }
// DÉBUSQUÉ (Fred, 20/11/2026) : une ligne au journal ; un débusqué masqué le reste, et on le lui rappelle.
function ligneDebusquage(d) {
  const ligne = d.par
    ? trad('flushedLog.by', '{{nom}} a fouillé la pièce et vous a débusqué(e) : vous n’êtes plus caché(e).', { nom: texteBrut(d.par) })
    : trad('flushedLog.masked', 'Un individu masqué a fouillé la pièce et vous a débusqué(e) : vous n’êtes plus caché(e).');
  return ligne + (d.vous_masque ? ' ' + trad('flushedLog.stillMasked', 'Vous restez masqué(e).') : '');
}
function inscrireDebusquage(d) {
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry(esc(ligneDebusquage(d)), 'event-bad');
}
function inscrireAuJournal(d) {
  const sujet = texteBrut(d.sujet), corps = texteBrut(d.texte);
  const ligne = esc(sujet && corps ? sujet + ' — ' + corps : (sujet || corps));
  if (ligne && typeof global.addJournalEntry === 'function') global.addJournalEntry(ligne, 'event-bad');
}

// STATUT DE DISCRÉTION, POUR MOI SEUL (Fred, 20/11/2026) : « Masqué », « Caché », « Masqué et caché » sous mon nom, avec
// en infobulle ce que les autres voient. Lu au serveur (crim_mon_statut_discretion), jamais montré aux autres.
function trad(cle, secours, valeurs) {
  const t = (global.i18next && typeof global.i18next.t === 'function') ? global.i18next.t(cle, Object.assign({ defaultValue: secours }, valeurs || {})) : null;
  let r = (typeof t === 'string' && t && t !== cle) ? t : secours;
  Object.keys(valeurs || {}).forEach(k => { r = r.split('{{' + k + '}}').join(String(valeurs[k])); });
  return r;
}
function libellesStatutDiscretion(mode, numero) {
  const masque = mode === 'masque' || mode === 'cache_masque', cache = mode === 'cache' || mode === 'cache_masque';
  if (!masque && !cache) return null;
  const libelle = masque && cache ? trad('discretionStatus.both', 'Masqué et caché')
    : masque ? trad('discretionStatus.masked', 'Masqué') : trad('discretionStatus.hidden', 'Caché');
  const info = cache ? trad('discretionStatus.hiddenTip', 'Vous n’apparaissez pas dans la liste des présents.')
    : (numero ? trad('discretionStatus.maskedTip', 'Les autres vous voient comme Individu masqué n° {{numero}}.', { numero })
              : trad('discretionStatus.maskedTipNoNumber', 'Les autres vous voient comme un individu masqué.'));
  return { libelle, info };
}
let statutEnCours = false;
async function rafraichirStatutDiscretion() {
  const doc = global.document;
  if (statutEnCours || !doc || !(etat().char && etat().char.name)) return;
  statutEnCours = true;
  try {
    const r = await rpc('crim_mon_statut_discretion');
    if (!r || r.ok !== true) return;
    const l = libellesStatutDiscretion(r.mode, r.numero);
    let el = doc.getElementById('rp-statut-discretion');
    if (!l) { if (el) el.remove(); return; }
    if (!el) {
      const ancre = doc.getElementById('char-fullname-left');
      if (!ancre || !ancre.parentNode) return;
      el = doc.createElement('div');
      el.id = 'rp-statut-discretion';
      el.style.cssText = 'display:inline-block;margin:.25rem 0;padding:.1rem .5rem;border:1px solid #6a5a30;border-radius:3px;font-size:.72rem;color:#C9A84C;cursor:help';
      ancre.parentNode.insertBefore(el, ancre.nextSibling);
    }
    el.textContent = '🎭 ' + l.libelle;
    el.title = l.info;
  } finally { statutEnCours = false; }
}
function demarrer() {
  setTimeout(lireEvenementsCrim, 8000);
  setInterval(lireEvenementsCrim, 60000);
  setTimeout(rafraichirStatutDiscretion, 9000);
  setInterval(rafraichirStatutDiscretion, 60000);
}
if (global.document && global.setTimeout) {
  if (global.document.readyState !== 'loading') demarrer();
  else global.document.addEventListener('DOMContentLoaded', demarrer);
}

global.RPCriminalite = { ligneDebusquage, rafraichirStatutDiscretion, libellesStatutDiscretion, inscrireAuJournal, T, texte, blocPassages, objetRevetable, objetPorte, ordresBoutiqueDiscretion, LIEUX_BOUTIQUE, identifiantCible, ORDRES_VOL, TYPES_VOL, ORDRES_CAMBRIOLAGE,
  ORDRES_JUSTICE, crimBoutonEnquetes, ORDRES_CORRUPTION_QHS };
Object.assign(global, { ouvrirBoutiqueDiscretion, acheterDiscretion, boutonRevetir, badgeRevetu, crimRevetir, crimRetirer,
  messageSeCacher, ouvrirFouilleCachettes, fouilleCachettesConfirmer, lireEvenementsCrim, animationDemasquage,
  ouvrirNeutraliser, crimNeutraliserConfirmer, crimOuvrirVoler, crimVolerTypes, crimVolerConfirmer, crimVolerChoisirCible,
  crimBoutonsPorte, crimPorteAgir, crimOuvrirCambriolage, crimCambrioler,
  crimOuvrirEmpoisonner, crimEmpoisonnerConfirmer, crimOuvrirSabotage, crimSabotageConfirmer, crimOuvrirEnquetes, crimEnqueter,
  crimOuvrirCorruptionQhs, crimCorrompreDirecteur, crimCorrompreGardien, crimRumeurResultat, crimTractFlagrant,
  crimOuvrirEnvoisQhs, crimQhsDecider, crimVoterReferendumQhs, crimOuvrirLaissezPasserQhs, crimLaissezPasserQhs, crimFauxLpOuvrir, crimFauxLpValider });
})(typeof window !== 'undefined' ? window : globalThis);
