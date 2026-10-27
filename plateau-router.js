// =====================
// PLATEAU-ROUTER.JS
// Routeur central des ordres (doOrder) — appelle des fonctions de TOUS les autres
// fichiers thematiques. DOIT ETRE CHARGE EN DERNIER dans plateau.html.
// =====================

// ORDERS SYSTEM
// =====================
function doOrder(fn, pa, cost, label, desc, successRate) {
  // ORDRE COURANT (chantier C, 13 septembre 2026). deduireCoutOrdre ne recoit que
  // {pa, cost} de ses 268 appelants : elle ne sait pas QUEL ordre elle facture, et
  // le serveur en a besoin pour verifier que le cout annonce est bien un cout
  // declare. On le depose ici, au seul point de passage obligatoire, plutot que de
  // modifier 268 signatures. Les handlers qui facturent apres une confirmation
  // differee (modale) peuvent le passer explicitement via l'option `fn`.
  if (typeof state !== 'undefined') state._ordreEnCours = fn;
  if (fn === 'publicite_premium') { ouvrirPublicitePremium(); return; }
  if (typeof queteAccueilNotifierOrdre === 'function') queteAccueilNotifierOrdre(fn);
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  // Verrou chambres de la clinique privee (finalisation chambres clinique, 31 aout 2026) : les
  // soins deplaces de reception_clinique vers les 10 chambres restent reserves au patient
  // auquel la chambre est attribuee -- un visiteur autorise peut entrer mais jamais se soigner
  // a la place du patient. Verifie EN PREMIER, avant tout debit PA/FR (garantie explicite).
  if (typeof estOrdreMedicalReserveAuPatient === 'function' && estOrdreMedicalReserveAuPatient(state.currentBuilding, state.currentRoom, fn)) {
    showToast('Réservé au patient', 'Ces soins sont réservés au patient auquel cette chambre est attribuée.', false);
    return;
  }

  // Droits generiques sur un local (Lot 1.2) : murs / locataire / fonds. C'est ICI qu'est la
  // securite reelle -- le grisage de renderRoomActions n'est qu'une anticipation, contournable
  // par un appel direct a doOrder(). Verifie AVANT tout debit PA/FR, sur la meme definition
  // d'ordre que celle reellement affichee (definitionOrdreDansPiece reproduit la fusion
  // room.orders + ctx.orders + ctx.roomOverrides, pour qu'un ordre declare dans un
  // buildingContext ne puisse pas echapper a la garde). Aucun ordre du jeu ne declare
  // requiresRole a ce jour : strictement no-op sur l'existant.
  if (typeof verdictRoleOrdre === 'function') {
    const verdictRoleOrdreCourant = verdictRoleOrdre(state.currentBuilding, state.currentRoom, fn);
    if (verdictRoleOrdreCourant.bloque) {
      showToast('Accès refusé', verdictRoleOrdreCourant.message, false);
      return;
    }
  }

  // Verrou central "match de football en cours" (chantier "football live", 28 aout 2026) : un
  // titulaire est immobilise pendant l'echauffement + les 20 minutes de jeu + la mi-temps, que son
  // navigateur soit ouvert ou non -- meme principe que le blocus syndical juste en dessous (lecture
  // SYNCHRONE d'un cache pose par tickFootballLive/rafraichirVerrouFootball, jamais un appel reseau
  // ici). Fermer la modale "Soir de match" ou le live ne touche jamais ce cache : seule l'horloge
  // reelle (kickoff/finPrevue, persistee dans championnat.data) le fait expirer. Le joueur garde
  // acces au badge de reouverture du live (hors doOrder) et a toute navigation/consultation qui ne
  // passe pas par un ordre.
  if (typeof state !== 'undefined' && state.matchEnCoursTitulaire) {
    const v = state.matchEnCoursTitulaire;
    const heureFin = v.finPrevue instanceof Date ? v.finPrevue : new Date(v.finPrevue);
    showToast('Vous disputez un match !', 'Vous disputez actuellement un match avec ' + (v.club?.nom || 'votre club') + '. Vous serez de nouveau disponible à ' + heureFin.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) + '.', false);
    return;
  }

  // Blocus syndical : lecture SYNCHRONE d'un cache pose a l'entree dans la piece
  // (verifierBlocusEntree, plateau-organisations-quetes.js) — doOrder ne peut pas attendre
  // un appel reseau, donc on ne consulte jamais Supabase ici directement.
  if (typeof state !== 'undefined' && state.blocusActifIci && state.currentBuilding) {
    const roomBlocus = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const ordreDefBlocus = roomBlocus?.orders?.find(o => o.fn === fn);
    const entreeForceeBlocus = state.blocusEntreeResolueBuildingId === state.currentBuilding;

    if (ordreDefBlocus?.type === 'legal' && !entreeForceeBlocus) {
      showToast('Bloqué', 'Un blocus syndical empêche cette démarche ici. Forcez le passage pour continuer.', false);
      return;
    }
    if (ordreDefBlocus?.type === 'legal' && entreeForceeBlocus) {
      successRate = Math.min(95, successRate + (state.blocusModificateurLegal || 0));
    }
    if (ordreDefBlocus?.type === 'illegal') {
      successRate = Math.min(95, successRate + Math.round((state.blocusActifIci.intensite || 40) / 4));
    }
  }

  // PA check (ignore si mode test)
  if (!TEST_MODE && state.pa < pa) {
    showToast('PA insuffisants', `Il vous manque ${pa - state.pa} PA.`, false);
    return;
  }

  // Argent check — ignore pour les ordres finances par le budget d'une institution (pas le portefeuille personnel)
  // Lot 3 (chantier fiscalite/Helvetia) : verifie desormais les fonds ORDINAIRES (liquide +
  // Banque nationale), jamais arg seul -- garde amont partagee par la quasi-totalite des
  // ordres du jeu (special-cases ET chemin generique), donc a fort effet meme si le debit
  // interne d'un handler dedie individuel n'est pas encore migre lui-meme (voir rapport).
  const ORDRES_BUDGET_INSTITUTION = ['reception_etat', 'banquet_diplo'];
  const fondsOrdinairesDisponibles = typeof getFondsDisponiblesOrdinaires === 'function' ? getFondsDisponiblesOrdinaires() : state.arg;
  if (cost > 0 && !ORDRES_BUDGET_INSTITUTION.includes(fn) && fondsOrdinairesDisponibles < cost) {
    showToast('Fonds insuffisants', `Cette action coute ${cost} ${cur}.`, false);
    return;
  }

  // Ordres speciaux
  // Helvetia H1 : gerer_finances est partage textuellement avec la Banque nationale (meme fn
  // depuis data.js, jamais renomme) mais route desormais vers un parcours reellement distinct
  // selon le batiment ou l'ordre est declenche -- corrige le bug historique ou Helvetia
  // manipulait le compte national. compte_offshore (ancien ordre cosmetique, unique a
  // banque-privee) route vers le meme ecran de gestion Helvetia plutot que de maintenir un
  // second parcours contradictoire.
  if (fn === 'gerer_finances') {
    if (state.currentBuilding === 'banque-privee' && typeof ouvrirGestionHelvetia === 'function') { ouvrirGestionHelvetia(pa, cost); return; }
    openFinancesModal(pa, cost);
    return;
  }
  if (fn === 'compte_offshore') { ouvrirGestionHelvetia(pa, cost); return; }
  // Petites annonces (La Tribune de Republia, 31 aout 2026) : flux dedie (voir
  // ouvrirFormulairePetiteAnnonce, plateau-communication.js) -- jamais le pipeline PA/argent
  // generique ci-dessous, la verification "une annonce active a la fois" doit avoir lieu AVANT
  // tout debit, cost:0 declare dans data.js pour cette raison.
  if (fn === 'deposer_petite_annonce') { ouvrirFormulairePetiteAnnonce(); return; }
  if (fn === 'blanchiment' || fn === 'societe_ecran') {
    showToast('Service à l\'étude', 'Ce service Helvetia n\'est pas encore disponible.', false);
    return;
  }
  if (fn === 'plainte_police') { openPlainteModal(pa, cost); return; }
  if (fn === 'arreter') { doArreter(pa, cost); return; }
  if (fn === 'dossiers_plaintes') { ouvrirDossiersPlaintes(); return; }
  if (fn === 'mener_enquete') { doMenerEnquete(pa, cost); return; }
  if (fn === 'organiser_filature') { doOrganiserFilature(pa, cost); return; }
  if (fn === 'investir') { ouvrirInvestir(pa, cost); return; }
  if (fn === 'organiser_chasse_homme') { doOrganiserChasseHomme(pa, cost); return; }
  if (fn === 'recruter_policier') { doRecruterPolicier(pa, cost); return; }
  if (fn === 'recruter_policier_cynophile') { doRecruterPolicierCynophile(pa, cost); return; }
  if (fn === 'gerer_effectifs_police') { ouvrirGererEffectifsPolice(); return; }
  // 'consulter_caisse_commissariat' : ordre retire le 16 septembre 2026. Le solde s'affiche
  // desormais dans l'en-tete du batiment, pour le seul commissaire (voir enterBuilding).
  // 'cambrioler_caisse_commissariat' : ordre retire du commissariat le 15 septembre 2026
  // (voir plateau-justice-economie.js). Aucune route de compatibilite n'est laissee : un ordre
  // qui n'existe plus dans data.js ne peut plus etre declenche, et payer_ordre le refuserait.
  if (fn === 'se_rebeller') { doSeRebeller(pa, cost); return; }
  if (fn === 'archives_police') { doArchivesPolice(pa, cost); return; }
  if (fn === 'pouls_populaire') { doPoulsPopulaire(); return; }
  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }
  if (fn === 'diner_affaires') { ouvrirModalInvitationSociale('diner_affaires', pa, cost, successRate); return; }
  if (fn === 'boire_verre') { ouvrirModalInvitationSociale('boire_verre', pa, cost, successRate); return; }
  if (fn === 'recruter_informateur_pnj') { doRecruterInformateurPNJ(pa); return; }
  // Comptoir d'embauche d'une agence (5 octobre 2026). Le routeur ne transmet
  // NI pa NI cost : agenceEmploiOuvrir relit l'ordre dans la piece pour y lire
  // `employeur` et `metier`, et c'est le SERVEUR qui lit le tarif. Ajouter un
  // metier recrutable ne demande donc qu'un ordre de plus dans data.js et une
  // ligne ici -- jamais un nouveau handler.
  if (fn === 'embaucher_agent_securite' || fn === 'embaucher_maitre_chien') {
    agenceEmploiOuvrir(fn); return;
  }
  if (fn === 'demander_parler_loge') { doLogePortail(pa, cost); return; }
  if (fn === 'imprimer_tracts_choix') { ouvrirChoixImprimerTracts(); return; }
  // Alias de compatibilite (12 septembre 2026) : les trois imprimeries de Republia partagent
  // desormais un seul moteur d'impression de tracts electoraux. L'ancienne fn imprimer_tracts
  // (moteur propre a la-tribune) n'existe plus dans data.js ; toute definition residuelle ou
  // sauvegarde ancienne aboutit ici, sur le moteur unique.
  if (fn === 'imprimer_tracts') { ouvrirModalImprimerTractsElectoraux(pa, cost); return; }
  if (fn === 'vendre_bois_imprimerie') { ouvrirVendreBoisImprimerie(pa, cost); return; }
  if (fn === 'imprimer_tracts_electoraux') { ouvrirModalImprimerTractsElectoraux(pa, cost); return; }
  if (fn === 'imprimer_tracts_calomnieux') { ouvrirModalImprimerTractsCalomnieux(pa, cost); return; }
  if (fn === 'choisir_arme') { ouvrirModalAcheterArme(); return; }
  if (fn === 'produire_arme') { doProduireArme(); return; }
  if (fn === 'racheter_entreprise') { doRachatEntreprise(); return; }
  if (fn === 'recolter_matiere') { doRecolterMatiere(pa, cost); return; }
  if (fn === 'deposer_demande_permis') { doDeposerDemandePermis(pa, cost); return; }
  if (fn === 'corrompre_fonctionnaire_permis') { doCorrompreFonctionnairePermis(pa, cost); return; }
  if (fn === 'traiter_demandes_permis') { doTraiterDemandesPermis(pa, cost); return; }
  if (fn === 'consulter_dossiers_urbanisme') { doConsulterDossiersUrbanisme(); return; }
  if (fn === 'demander_logement_social') { demanderLogementSocial(pa, cost); return; }
  if (fn === 'gerer_logement_social') { gererLogementSocial(); return; }
  if (fn === 'traiter_demandes_logement_social') { traiterDemandesLogementSocial(pa, cost); return; }
  if (fn === 'consulter_registre_armes') { doConsulterRegistre(); return; }
  if (fn === 'acheter_gilet') { doAcheterGilet(); return; }
  // « Subtiliser des explosifs » (refonte du 13 septembre 2026). Ce n'etait PAS un vol : l'ordre
  // ouvrait le modal du marche noir a 1 200 FR, alors que son libelle et sa description
  // promettaient un vol a 35 % avec pertes de PV. C'est desormais un vrai vol dans le stock reel
  // de l'armurerie militaire. Le marche noir garde sa filiere propre, par l'ordre marche_noir
  // (doMarcheNoir -> doAcheterExplosifs), inchangee et partagee entre les quatre empires.
  if (fn === 'acheter_bombe_illegale') { doSubtiliserExplosifsMilitaires(pa, cost); return; }
  // EFFORT DE GUERRE (13 septembre 2026). acheter_arme_militaire et acheter_bombe_mil ont ete
  // supprimes : ils creaient armes et explosifs ex nihilo. L'armurerie militaire est desormais un
  // lieu de stock, alimente uniquement par la production de l'Effort de guerre.
  if (fn === 'effort_national') { ouvrirEffortNational(); return; }
  if (fn === 'tableau_effort_guerre') { ouvrirTableauEffortMinistre(); return; }
  if (fn === 'retirer_armes_militaires') { doRetirerArmesMilitaires(); return; }
  if (fn === 'retirer_explosifs_militaires') { doRetirerExplosifsMilitaires(); return; }
  if (fn === 'retirer_equipement_militaire') { doRetirerEquipementsMilitaires(); return; }
  if (fn === 'manger_ration') { doMangerRation(); return; }
  if (fn === 'repartir_armement') { ouvrirRepartirArmement(); return; }
  if (fn === 'se_justifier') { doSeJustifier(pa, cost); return; }
  if (fn === 'observer_match') { doObserverMatch(); return; }
  if (fn === 'consulter_palmares') { doConsulterPalmares(); return; }
  if (fn === 'parier_match') { doParierMatch(pa, cost); return; }
  if (fn === 'regarder_live') { doRegarderLiveOuResume(); return; }
  if (fn === 'prendre_licence_sportive') { doPrendreLicenceSportive(pa, cost); return; }
  if (fn === 'demander_non_renouvellement_licence') { doDemanderNonRenouvellementLicence(pa, cost); return; }
  if (fn === 'annuler_non_renouvellement_licence') { doAnnulerNonRenouvellementLicence(); return; }
  if (fn === 'tenue_entrainement') { doTenueEntrainement(pa, cost); return; }
  if (fn === 'tenue_match') { doTenueMatch(); return; }
  if (fn === 'conseil_entraineur_adjoint') { doConseilEntraineurAdjoint(); return; }
  if (fn === 'sponsoriser_club') { doSponsoriserClub(pa, cost); return; }
  if (fn === 'consulter_budget_club') { doConsulterBudgetClub(); return; }
  if (fn === 'gerer_salaires_club') { doGererSalairesClub(); return; }
  if (fn === 'organiser_manifestation') { doOrganiserManifestation(); return; }
  if (fn === 'organiser_boycott') { doOrganiserBoycott(pa, cost); return; }
  if (fn === 'transfert_clinique_privee') { doTransfertCliniquePrivee(pa, cost); return; }
  if (fn === 'centre_anti_poison') { doCentreAntiPoison(pa); return; }
  if (fn === 'soin_public') { doSoinPublic(pa, cost); return; }
  if (fn === 'soins') { doSoinCliniquePrivee(pa, cost); return; }
  if (fn === 'vendre_ressource_medicale') { doVendreRessourceMedicaleGenerique(pa, cost); return; }
  if (fn === 'gerer_visites_chambre') { doGererVisitesChambre(pa, cost); return; }
  if (fn === 'ouvrir_chambres_clinique') { doOuvrirChambresClinique(pa, cost); return; }
  if (fn === 'reserver_chambre_hotel') { doReserverChambreHotel(pa); return; }
  if (fn === 'dormir_chambre') { doDormirChambre(); return; }
  if (fn === 'dormir') { doDormir(); return; }
  if (fn === 'service_etage') { doServiceEtage(pa); return; }
  if (fn === 'consulter_classement_joueurs_club') { doConsulterClassementBookmaker(pa, cost); return; }
  if (fn === 'postuler_president_club') { doPostulerPresidentClub(pa, cost); return; }
  if (fn === 'consulter_bureau_president') { doConsulterBureauPresident(); return; }
  if (fn === 'proposer_transfert') { doProposerTransfert(pa, cost); return; }
  if (fn === 'gerer_offres_transfert') { doGererOffresTransfert(); return; }
  if (fn === 'choisir_accessoire_club') { doChoisirAccessoireClub(pa, cost); return; }
  if (fn === 'acheter_accessoire_personnalise') { doAcheterAccessoirePersonnalise(); return; }
  if (fn === 'rejoindre_club_supporters') { doRejoindreClubSupporters(pa, cost); return; }
  if (fn === 'consulter_organigramme_supporters') { doConsulterOrganigrammeSupporters(); return; }
  if (fn === 'se_syndiquer') { doRejoindreSyndicatDockers(pa, cost); return; }
  if (fn === 'consulter_organigramme_syndicat') { doConsulterOrganigrammeSyndicat(); return; }
  if (fn === 'declencher_election_syndicat') { doDeclencherElectionSyndicat(pa, cost); return; }
  if (fn === 'organiser_manifestation_syndicat') { doOrganiserManifestationSyndicat(); return; }
  if (fn === 'consulter_etat_civil') { doConsulterEtatCivil(); return; }
  if (fn === 'consulter_personnalites_musee') { doConsulterPersonnalitesMusee(); return; }
  if (fn === 'consulter_mandats_maires') { doConsulterResumesMandats(); return; }
  if (fn === 'consulter_archives_notariales') { doConsulterArchivesNotariales(); return; }
  // consulter_succession (Bureau des Successions) retire (refonte notaire, 20 aout 2026 -- audit
  // Ordres) : doublon exact de consulter_archives_notariales, payant pour rien de plus. Le
  // handler partage doConsulterArchivesNotariales() reste utilise par l'ordre restant ci-dessus,
  // non touche.
  if (fn === 'consulter_dossier_notarial') { doConsulterDossierNotarial(); return; }
  if (fn === 'consulter_archives_presse') { doConsulterArchivesPresse(); return; }
  if (fn === 'demander_juge_instruction') { doDemanderJugeInstruction(pa, cost); return; }
  if (fn === 'presenter_autorisation_coffre') { doPresenterAutorisationCoffre(pa, cost); return; }
  if (fn === 'demander_divorce') { doDemanderDivorce(pa, cost); return; }
  // gerer_testament (Bureau des Successions) : acte notarial deterministe (chantier testament/
  // succession, 20 aout 2026) -- special-case obligatoire comme tous les autres actes notariaux
  // reels ci-dessous, sinon le moteur generique de doOrder() lui appliquerait un jet malgre
  // successRate:100 (voir audit prealable : seuls les fn de la liste alwaysSuccess y echappent).
  // pa/cost transmis tels quels : la deduction reelle n'a lieu qu'au moment de soumettreTestament().
  if (fn === 'gerer_testament') { doGererTestament(pa, cost); return; }
  // reclamer_heritage (Bureau des Successions) : meme doctrine que gerer_testament ci-dessus --
  // acte deterministe, special-case obligatoire (0 PA/0 FR, aucun jet malgre le passage par
  // doOrder()). Point d'entree fonctionnel reel des successions (le mail de convocation n'est
  // qu'une notification best-effort, jamais la source de verite -- voir doReclamerHeritage()).
  if (fn === 'reclamer_heritage') { doReclamerHeritage(); return; }
  if (fn === 'acte_vente_terrain') { doActeVenteTerrain(); return; }
  if (fn === 'acte_rachat_entreprise') { doActeRachatEntreprise(pa, cost); return; }
  if (fn === 'officialiser_transaction') { ouvrirMenuOfficialiserTransaction(pa, cost); return; }
  if (fn === 'corrompre_rdv_notaire') { doCorrompreRdvNotaire(pa, cost); return; }
  if (fn === 'transferer_compromis') { doOuvrirTransfertCompromis(pa, cost); return; }
  if (fn === 'valider_transfert_compromis') { doValiderTransfertCompromis(pa, cost); return; }
  if (fn === 'transfert_compromis') { ouvrirMenuTransfertCompromis(pa, cost); return; }
  if (fn === 'payer_versement_chantier') { doPayerVersementChantier(); return; }
  if (fn === 'travailler_chantier')    { doTravaillerChantier(pa, cost); return; }
  if (fn === 'vendre_materiaux_chantier') { doVendreMateriauxChantier(pa, cost); return; }
  if (fn === 'modifier_plan_chantier') { doModifierPlanChantier(pa, cost); return; }
  if (fn === 'reconfigurer_lots') { doOuvrirReconfiguration(pa, cost); return; }
  if (fn === 'gerer_fonds_commerce') { doGererFondsCommerce(pa, cost); return; }
  if (fn === 'corrompre_chantier') { doCorrompreChantier(pa, cost); return; }
  if (fn === 'donner_materiaux_chantier') { return doVendreMateriauxChantier(pa,cost,'don'); }
  if (fn === 'prix_chantier') { ouvrirPrixChantier(); return; }
  if (fn === 'taux_chantier') { ouvrirTauxChantier(); return; }
  if (fn === 'receptionner_chantier') { return receptionnerChantier(); }
  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(pa, cost); return; }
  if (fn === 'acheter_ressources_entrepot') { doOuvrirAchatEntrepot(pa, cost); return; }
  if (fn === 'vente_directe_usine') { doOuvrirVenteDirecteUsine(pa, cost); return; }
  if (fn === 'acheter_sels_ammoniaque') { doAcheterSelsAmmoniaque(pa, cost); return; }
  if (fn === 'vendre_matiere_usine') { doVendreMatierePremiereUsineGenerique(pa, cost); return; }
  if (fn === 'consulter_caisse_usine') { doConsulterCaisseUsine(); return; }
  if (fn === 'consulter_stock_usine') { doConsulterStockUsine(); return; }
  if (fn === 'fabriquer_armoire_souvenirs') { doFabriquerArmoireSouvenirs(); return; }
  if (fn === 'acheter_armoire_souvenirs') { doAcheterArmoireSouvenirs(); return; }
  if (fn === 'produire_medicaments') { doProduireUsine('medicaments'); return; }
  if (fn === 'produire_desinfectant') { doProduireUsine('desinfectant'); return; }
  if (fn === 'produire_alcool') { doProduireUsine('alcool'); return; }
  if (fn === 'produire_tabac') { doProduireUsine('tabac'); return; }
  if (fn === 'produire_carburant') { doProduireUsine('carburant'); return; }
  if (fn === 'nommer_directeur_pharma') { ouvrirModalNommerDirecteurPharma(); return; }
  if (fn === 'nommer_directeur_tabac_alcools') { ouvrirModalNommerDirecteurTabacAlcools(); return; }
  if (fn === 'nommer_directeur_raffinerie') { ouvrirModalNommerDirecteurRaffinerie(); return; }
  if (fn === 'fixer_prix_vente_directe') { doOuvrirFixerPrixVenteDirecte(pa, cost); return; }
  if (fn === 'fixer_repartition_production') { doOuvrirFixerRepartitionProduction(pa, cost); return; }
  if (fn === 'virement_usine_ministere') { doOuvrirVirementUsineMinistere(pa, cost); return; }
  if (fn === 'nommer_directeur_entrepot') { ouvrirModalNommerDirecteurEntrepot(pa, cost); return; }
  if (fn === 'tableau_bord_entrepot')     { ouvrirTableauBordEntrepot(); return; }
  if (fn === 'fixer_prix_achat_entrepot') { doOuvrirFixerPrixAchatEntrepot(pa, cost); return; }
  if (fn === 'emprunter_construction') { ouvrirModalPretBancaire('nationale', 'travaux'); return; }
  if (fn === 'emprunter') {
    const typeBanque = state.currentBuilding === 'banque-privee' ? 'privee' : 'nationale';
    ouvrirModalPretBancaire(typeBanque, null, pa);
    return;
  }
  // emprunter_prive (Banque Privee Helvetia, "sans verification") -- chantier H2A (28 aout
  // 2026) : route desormais vers le parcours dedie creer_pret_helvetia (compte Helvetia requis,
  // 1000-150000, 5-30j, 12% fixe, aucune verification, versement sur le compte Helvetia, arg+=
  // capital, refinancement BNR automatique cote RPC). Ne route plus jamais vers
  // ouvrirModalPretBancaire('privee',...) : ce chemin legacy inserait un pret type_banque='privee'
  // brut (sbCreerPret), totalement hors du systeme Helvetia (compte, contentieux, saisie).
  // ouvrirModalPretBancaire reste utilise tel quel par emprunter_construction (Banque Nationale).
  if (fn === 'emprunter_prive') { ouvrirModalPretHelvetia(pa); return; }
  if (fn === 'diviser_construction') { doOuvrirDivisionTerrain(); return; }
  if (fn === 'louer_lot_ici') { doOuvrirLouerLot(pa, cost); return; }
  if (fn === 'gerer_lot_loue') { doGererLotLoue(); return; }
  if (fn === 'declencher_election_club') { doDeclencherElectionClub(pa, cost); return; }
  if (fn === 'incendier') { doIncendier(); return; }
  if (fn === 'utiliser_explosifs') { doUtiliserExplosifs(); return; }
  if (fn === 'marchander_vote') { ouvrirMarchanderVote(pa, cost); return; }
  // §17 : le terme visible devient "Neutraliser". Le fn 'assassiner' reste inchange -- c'est un
  // identifiant persiste dans data.js et compare par le routeur, jamais montre au joueur.
  if (fn === 'assassiner') { showToast('Cliquez sur la cible', 'Pour neutraliser quelqu\'un, cliquez sur la personne visée dans la liste des personnes présentes.', false); return; }
  if (fn === 'consulter_elections') { ouvrirTableauElectoral(); return; }
  if (fn === 'creer_poste_ministre')    { creerPosteMinistre(pa, cost); return; }
  if (fn === 'creer_comite')            { creerComite(pa, cost); return; }
  if (fn === 'supprimer_poste_custom')  { supprimerPosteCustom(); return; }
  if (fn === 'nommer_ministre')         { ouvrirModalNommerPM(pa, cost); return; }
  if (fn === 'revoquer_pm')             { ouvrirModalRevoquerPM(pa, cost); return; }
  if (fn === 'nommer_pm')               { ouvrirModalCibleRepertoire('nommer_pm_confirm', 'Nommer un Premier Ministre'); return; }
  if (fn === 'nommer_ministre_pm')      { ouvrirNommerMinistresModal(pa, cost); return; }
  if (fn === 'revoquer_ministre_pm')   { ouvrirModalRevoquerMinistre(pa, cost); return; }
  if (fn === 'declencher_vote_confiance') { ouvrirDeclencherVoteConfiance(pa, cost); return; }
  if (fn === 'declarer_guerre_empire' || fn === 'declarer_guerre')  { ouvrirModalGuerreEmpire(pa, cost); return; }
  if (fn === 'gracier_condamne' || fn === 'gracier') { ouvrirModalGracier(pa, cost); return; }
  if (fn === 'decret_referendum')       { ouvrirForumNationalSousForumPresident('referendum', pa, cost); return; }
  if (fn === 'jour_deuil')             { ouvrirForumNationalSousForumPresident('deuil', pa, cost); return; }
  if (fn === 'solliciter_audience_president') { solliciterAudiencePresident(); return; }
  if (fn === 'etat_nation')             { ouvrirEtatNation(); return; }
  if (fn === 'fixer_impots_locaux')    { ouvrirFixerImpotsLocauxReel(pa, cost); return; }
  if (fn === 'consommer_buvette') { doConsommerBuvette(pa, cost); return; }
  // AIGUILLAGE DES TROIS PRIMITIVES COMMERCANTES (30 septembre 2026).
  // Meme vocabulaire d'ordres pour les deux moteurs : voir les produits, produire,
  // ceder des matieres. Ce qui change, c'est QUI tient le commerce. Un local
  // exploite par un fonds PJ est servi par les ecrans du fonds ; partout ailleurs
  // -- les 13 commerces PNJ, les marches, le Republia -- les handlers historiques
  // restent seuls maitres. On teste le fonds AVANT, jamais le metier : c'est
  // precisement pour ne pas ecrire « si armurerie... si boutique Arnie... ».
  //
  // commercePjFondsIci() lit state.locationsActives, deja en memoire : pas d'attente,
  // donc pas de fenetre pendant laquelle le clic resterait sans effet. Elle n'est
  // interrogee que pour ces cinq ordres : doOrder est le passage oblige des 268
  // ordres du jeu, et aucun des 263 autres n'a de raison de payer ce parcours.
  const ORDRES_COMMERCANTS = ['consulter_carte_commerce', 'faire_achats_marche',
                              'produire_commerce', 'vendre_matiere_commerce', 'gerer_commerce'];
  const fondsIci = (ORDRES_COMMERCANTS.indexOf(fn) !== -1 && typeof commercePjFondsIci === 'function')
    ? commercePjFondsIci() : null;
  if (fondsIci) {
    if (fn === 'consulter_carte_commerce' || fn === 'faire_achats_marche') { commercePjEcranBoutique(); return; }
    if (fn === 'produire_commerce')        { commercePjEcranTravail(); return; }
    if (fn === 'vendre_matiere_commerce')  { commercePjEcranMatieresPubliques(); return; }
    if (fn === 'gerer_commerce')           { ouvrirCommercePJ(); return; }
  }
  if (fn === 'produire_commerce') { doProduireCommerceGenerique(pa, cost); return; }
  if (fn === 'consulter_carte_commerce') { doConsulterCarteCommerceGenerique(pa, cost); return; }
  if (fn === 'faire_achats_marche') { doFaireAchatsCommerceGenerique(pa, cost); return; }
  if (fn === 'gerer_commerce') { doGererCommerceGenerique(pa, cost); return; }
  if (fn === 'vendre_matiere_commerce') { doVendreMatiereCommerceGenerique(pa, cost); return; }
  if (fn === 'consommer_boisson') { doConsommerBoissonGenerique(pa, cost); return; }
  if (fn === 'offrir_tournee') { doOffrirTourneeGenerique(pa, cost); return; }
  if (fn === 'prendre_train')          { ouvrirModalTransport('train'); return; }
  if (fn === 'taxi_caserne')           { doTaxiSpecial('caserne', pa, cost); return; }
  if (fn === 'passer_douanes_aeroport'){ doPasserDouanesAeroport(); return; }
  if (fn === 'consulter_organigramme_mairie') { ouvrirOrganigrammeMairie(); return; }
  if (fn === 'louer_local')              { ouvrirModalLouerLocal(pa, cost); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }
  // Point d'entree UNIQUE de la verticale commerce PJ (C5) : l'ecran decide
  // lui-meme s'il montre la gestion, la boutique ou l'installation.
  if (fn === 'commerce_pj')              { ouvrirCommercePJ(); return; }
  if (fn === 'commerce_personnaliser') { commercePjOuvrirAtelier(); return; }
  // EQUIPEMENTS DE BUREAU (4 octobre 2026) : interface d'attente, sans aucune
  // mecanique. Sortie immediate, AVANT tout debit -- l'ordre est a 0 PA / 0 FR
  // et n'a rien a faire savoir au serveur. Voir plateau-equipements.js.
  if (fn === 'installer_equipements')    { ouvrirModalEquipements(); return; }
  // CAMION MILITAIRE (29 septembre 2026). Quatre ordres, tous a 0 PA et 0 FR :
  // monter, descendre, conduire, envoyer a vide. Le seul cout du systeme -- 2 PA
  // par occupant reellement transporte -- est calcule et preleve PAR LE SERVEUR,
  // occupant par occupant, et ne peut donc pas passer par payer_ordre, qui ne
  // sait debiter que l'appelant. Sortie immediate ici, avant tout debit generique.
  if (fn === 'camion_militaire')         { doCamionMilitaire(); return; }
  if (fn === 'camion_descendre')         { doCamionDescendre().catch(function () {}); return; }
  if (fn === 'camion_conduire')          { doCamionConduire(); return; }
  if (fn === 'camion_a_vide')            { doCamionAVide(); return; }
  if (fn === 'louer_box')                { ouvrirModalLouerBox(pa, cost); return; }
  if (fn === 'gerer_box')                { ouvrirModalGererBox(); return; }
  if (fn === 'marchandises_non_reclamees') { ouvrirMarchandisesNonReclamees(); return; }
  if (fn === 'choisir_suite')            { ouvrirModalChoixSuite(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(pa, cost); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'expulsion_legale')        { doExpulsionLegale(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(pa, cost); return; }
  if (fn === 'expulsion_legale')         { doExpulsionLegale(); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'faire_disparaitre_cadavre') { doFaireDisparaitreCadavre(pa, cost); return; }
  if (fn === 'negocier_squatteurs')     { doNegocierSquatteurs(pa, cost); return; }
  if (fn === 'signer_compromis')        { doSignerCompromis(pa, cost); return; }
  if (fn === 'acheter_terrain')         { doAcheterTerrain(); return; }
  // Ajoute le 27 aout 2026 (audit cible, suspicion levee) : ordre defini dans data.js (10
  // parcelles a batir) mais jamais routee -- tombait dans executerOrdreGenerique (aucune entree
  // ORDER_EFFECTS), produisait un toast succes/echec cosmetique sans le moindre effet reel,
  // alors que le mecanisme cible (ouvrirModalConstruire/confirmerConstruction, plateau-justice-
  // economie.js) existe deja, complet et fonctionnel : choix du palier, versement initial 35%
  // reellement preleve, chantier persiste (sbSetTerrainState), progression et livraison
  // (niveau_construction) deja geres cote serveur (avancerChantiersQuotidien, api/cron-minuit.js).
  if (fn === 'construire_sur_terrain')  { ouvrirModalConstruire(); return; }
  if (fn === 'racheter_terrain')        { doRacheterTerrain(pa, cost); return; }
  if (fn === 'decret_inutile')         { signerDecretInutile(pa, cost); return; }
  if (fn === 'elections_tableau')      { ouvrirTableauElectoral(); return; }
  if (fn === 'changer_domicile')       { changerDomicile(state.country, state.currentCity); return; }
  if (fn === 'escort_infos')           { doEscortInfos(); return; }
  if (fn === 'escort_piege')           { doEscortPiege(pa, cost); return; }
  if (fn === 'recruter_informateur_1') { consulterInformateur(1); return; }
  if (fn === 'recruter_informateur_2') { consulterInformateur(2); return; }
  if (fn === 'recruter_informateur_3') { consulterInformateur(3, pa); return; }
  if (fn === 'recruter_informateur_4') { consulterInformateur(4); return; }
  if (fn === 'interroger_informateur_1'){ interrogerInformateur(1); return; }
  if (fn === 'interroger_informateur_2'){ interrogerInformateur(2); return; }
  if (fn === 'interroger_informateur_3'){ interrogerInformateur(3); return; }
  if (fn === 'interroger_informateur_4'){ interrogerInformateur(4); return; }
  if (fn === 'recruter_info')          { ouvrirRecruterInformateur(1); return; }
  if (fn === 'recruter_info_2')        { ouvrirRecruterInformateur(2); return; }
  if (fn === 'recruter_info_3')        { ouvrirRecruterInformateur(3, pa); return; }
  if (fn === 'recruter_info_4')        { ouvrirRecruterInformateur(4, pa); return; }
  if (fn === 'consulter_info')         { consulterInformateur(1); return; }
  if (fn === 'consulter_info_2')       { consulterInformateur(2); return; }
  if (fn === 'consulter_info_3')       { consulterInformateur(3, pa); return; }
  if (fn === 'consulter_info_4')       { consulterInformateur(4); return; }
  if (fn === 'gerer_informateurs')     { ouvrirGestionInformateurs(); return; }
  if (fn === 'taxi_qhs')               { doTaxiSpecial('qhs', pa, cost); return; }
  if (fn === 'renseignement_transport_intl') { ouvrirRenseignementMireilleGuichet(); return; }
  if (fn === 'prendre_bus_taxi')       { ouvrirModalTransport('bus'); return; }
  if (fn === 'prendre_avion')          { ouvrirModalTransport('avion'); return; }
  if (fn === 'aller_douanes_aeroport') { doAllerDouanesAeroport(); return; }
  if (fn === 'prendre_bateau')         { ouvrirModalTransport('bateau'); return; }
  if (fn === 'controle_douanes')       { doControlDouanes(); return; }
  if (fn === 'corrompre_douanier')     { doCorrompreDoanier(pa, cost); return; }
  if (fn === 'expedier_colis')         { ouvrirExpedierColis(pa, cost); return; }
  if (fn === 'receptionner_commande')  { ouvrirReceptionnerCommande(pa, cost); return; }
  if (fn === 'contrebande_port')       { doContrebandePort(pa, cost); return; }
  if (fn === 'blocus_portuaire')       { doBlocusPortuaire(pa, cost); return; }
  if (fn === 'inspecter_cargaisons')   { doInspecterCargaisons(pa, cost); return; }
  if (fn === 'consulter_manifeste')    { doConsulterManifeste(); return; }
  if (fn === 'acheter_parapluie')      { doAcheterPoisonObjet('parapluie'); return; }
  if (fn === 'acheter_ghb')            { doAcheterPoisonObjet('ghb', pa, cost); return; }
  if (fn === 'acheter_polonium')       { doAcheterPoisonObjet('polonium', pa, cost); return; }
  if (fn === 'acheter_vipere')         { doAcheterPoisonObjet('vipere', pa, cost); return; }
  // Doublon supprime (audit du 9 septembre 2026) : cette seconde route 'assassiner' etait
  // INATTEIGNABLE -- le test identique plus haut dans cette meme fonction fait return avant. Elle
  // pointait sur ouvrirModalAssassiner(), implementation legacy elle aussi morte, desormais
  // retiree de plateau-actions-illegales-rumeurs.js.
  if (fn === 'reveiller_depute')       { ouvrirReveillerDepute(pa, cost); return; }
  if (fn === 'se_cacher')              { doSeCacher(); return; }
  if (fn === 'empoisonner')            { ouvrirModalEmpoisonner(); return; }
  if (fn === 'repartition_budget_local'){ doRepartirBudgetMunicipal(pa, cost); return; }
  // La porte des subventions facture ses 2 PA elle-meme : on ne lui passe donc NI pa NI cost, et
  // l'ecran n'appelle pas deduireCoutOrdre. Patron de employeur_embaucher.
  if (fn === 'subvention_proposer'){ doProposerSubvention(); return; }
  if (fn === 'consulter_indices_locaux'){ doConsulterIndicesLocaux(); return; }
  if (fn === 'campagne_securite')      { doCampagneSecurite(); return; }
  if (fn === 'acte_officiel_mairie')   { ouvrirActeOfficielMairie(pa, cost); return; }
  if (fn === 'calendrier_elections')   { ouvrirCalendrierElectoral(); return; }
  // REGROUPEMENTS UX de l'Hotel de Ville (16 septembre 2026) : un bouton par POSTE plutot qu'un
  // bouton par ACTION. Les anciens ordres n'existent plus dans data.js, mais leurs handlers sont
  // intacts -- c'est l'ecran de regroupement qui les appelle, avec leurs couts d'origine.
  if (fn === 'nominations_municipales') { ouvrirNominationsMunicipales(); return; }
  if (fn === 'entrepot_direction')     { ouvrirGestionPosteNomme('directeur_entrepot'); return; }
  if (fn === 'maire_adjoint_gestion')  { ouvrirGestionPosteNomme('maire_adjoint'); return; }
  if (fn === 'commissaire_gestion')    { ouvrirGestionPosteNomme('commissaire'); return; }
  if (fn === 'observer_debats')         { observerDebats(pa, cost); return; }
  if (fn === 'objet_trouve')            { reclamerObjetTrouve(pa, cost); return; }
  // Salle des elections centralisee (chantier "Hotel de Ville / elections", 4 septembre 2026) :
  // remplace l'ancien "Deposer une candidature" (code en dur sur 'maire') et unifie les 2
  // versions incoherentes de contester_resultats -- voir plateau-politique.js.
  if (fn === 'voter_election')          { ouvrirVoterElection(); return; }
  if (fn === 'se_porter_candidat')      { ouvrirSePorterCandidat(); return; }
  if (fn === 'contester_resultats')     { ouvrirContesterResultatsElection(pa, cost); return; }
  if (fn === 'falsifier_listes_electorales') { ouvrirFalsifierListesElectorales(pa, cost); return; }
  if (fn === 'bourrer_urnes')           { ouvrirBourrerUrnes(pa, cost); return; }
  if (fn === 'truquer_depouillement')   { ouvrirTruquerDepouillement(pa, cost); return; }
  // ASSEMBLEE NATIONALE (chantier du 10 septembre 2026) — tout le cycle parlementaire est
  // desormais servi par plateau-assemblee.js, sur les tables assemblee_*. Les anciens handlers
  // (ouvrirVoteLoi/ouvrirDeposerProjet, bases sur state.loisEnCours en memoire) sont supprimes.
  // L'ECRAN DE SEANCE (11 octobre 2026) : parole, discipline, protestation. Ses douze actes
  // ont chacun leur porte serveur ; cet ordre n'ouvre qu'un ecran et ne coute rien.
  if (fn === 'seance_parlementaire')   { ouvrirSeanceParlementaire(); return; }
  if (fn === 'voter_loi')              { ouvrirVoterLoi(pa, cost); return; }
  if (fn === 'projet_loi')             { ouvrirDeposerProposition(pa, cost); return; }
  if (fn === 'amender_projet')         { ouvrirAmenderProposition(); return; }
  // 'proposer_abrogation' n'existe plus comme ordre (30 septembre 2026) : une
  // abrogation se demande au juriste de l'Assemblee, comme toute autre loi. Aucune
  // route de compatibilite n'est laissee -- un ordre retire de data.js ne doit plus
  // pouvoir etre declenche, et le formulaire qu'il ouvrait a ete supprime.
  if (fn === 'registre_assemblee')     { ouvrirRegistreAssemblee(); return; }
  // 'deposer_projet' : ancien fn du bureau presidentiel, sans bouton depuis longtemps (0 appelant
  // constate a l'audit du 9 septembre). Redirige vers le nouveau depot plutot que de laisser une
  // route morte pointant sur une fonction supprimee.
  if (fn === 'deposer_projet')         { ouvrirDeposerProposition(pa, cost); return; }
  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(successRate, pa, cost); return; }
  if (fn === 'consulter_lobbyiste')    { doConsulterLobbyiste(pa, cost); return; }
  if (fn === 'forum_president_conference' || fn === 'conference_presse')  { ouvrirForumNationalSousForumPresident('conference', pa, cost); return; }
  if (fn === 'donner_conf') { doDonnerConference(pa, cost); return; }
  if (fn === 'forum_president_propagande' || fn === 'propagande_etat')  { ouvrirForumNationalSousForumPresident('propagande', pa, cost); return; }
  if (fn === 'forum_president_dementi' || fn === 'dementi')     { doDementiOfficiel(pa, cost); return; }
  // 'consulter_archives_lois' SUPPRIME : l'ordre correspondant de la Salle des Archives est
  // remplace par 'registre_assemblee'. Son handler ouvrirArchivesLois lisait lois_assemblee,
  // table dont l'audit du 9 septembre a montre qu'elle etait vide et dont le champ resultat
  // n'etait jamais renseigne -- toute loi y restait "En cours" indefiniment.
  if (fn === 'consulter_archives_tribunal') { ouvrirArchivesTribunal(); return; }
  // pa/cost etaient omis ici alors que la route jumelle 'plainte' (plus bas) les transmet :
  // deduireCoutOrdre({pa: undefined, cost: undefined}) ne prelevait donc jamais rien.
  // Route 'porter_plainte' SUPPRIMEE le 13 octobre 2026 : AUCUN ordre ne la declarait, dans
  // aucune piece de data.js -- un chemin mort. Porter plainte passe par `plainte_police`, au
  // commissariat, qui appelle la porte serveur `plainte_deposer`.
  // LE JUGE NE VOIT PLUS QUE CE DONT IL EST SAISI (12 octobre 2026). `ouvrirRendreSentence`
  // listait les affaires au statut `deposee` -- celui de l'ancienne chaine, que plus aucune porte
  // ne pose : l'ecran etait devenu structurellement vide. `ouvrirDossiersJuge` lit le role au
  // serveur (`juge_dossiers`), qui ne rend que les affaires regulierement saisies.
  if (fn === 'rendre_sentence')         { ouvrirDossiersJuge(pa, cost); return; }
  // L'ECRAN DU PARQUET. Zero PA : c'est un ecran de decision, pas un acte.
  if (fn === 'parquet')                 { ouvrirParquet(); return; }
  if (fn === 'etat_civil') { ouvrirEtatCivil(); return; }
  if (fn === 'demander_naturalisation') { ouvrirModalNaturalisation(pa, cost); return; }
  if (fn === 'demander_mariage') { ouvrirModalDemandeMariage(pa, cost); return; }
  if (fn === 'marche_noir') { doMarcheNoir(); return; }
  if (fn === 'officialiser_mariage') { ouvrirOfficialiserMariage(pa, cost); return; }
  if (fn === 'gerer_couvre_feu') { ouvrirGererCouvreFeu(pa, cost); return; }
  if (fn === 'subvention_min_int') { ouvrirModalFinancerMinInt(pa, cost); return; }
  // Registre d'execution des lois votees (30 septembre 2026). Le poste est
  // reverifie par la RPC : ce routage n'est qu'une porte.
  if (fn === 'lois_votees_an')     { ouvrirLoisVoteesAN(); return; }
  if (fn === 'demandes_naturalisation') { ouvrirDemandesNaturalisation(); return; }
  if (fn === 'falsifier_document')      { ouvrirFalsifierDocument(pa, cost); return; }
  // ===========================================================================================
  // LES CINQ DOCUMENTS DU GREFFE ET LES DEUX ORDRES DE L'UNIVERSITE (13 octobre 2026)
  // ===========================================================================================
  // CES SEPT ORDRES SONT ROUTES ICI, DONC AVANT `deduireCoutOrdre`, ET C'EST VOULU. Chaque
  // porte serveur appelle `payer_ordre` ELLE-MEME, dans la meme transaction que son effet :
  // le document emis, la caisse creditee, le syndicat ecrit. Un prelevement cote navigateur en
  // plus prelverait deux fois. C'est le meme patron que `plainte_police`.
  if (fn === 'casier_mon_extrait')           { doCasierMonExtrait(); return; }
  if (fn === 'casier_extrait_enquete')       { ouvrirCasierExtraitEnquete(); return; }
  if (fn === 'orga_extrait_duplicata')       { ouvrirExtraitDuplicata(); return; }
  if (fn === 'greffe_corrompre_dossier')     { ouvrirGreffeCorrompreDossier(); return; }
  if (fn === 'greffe_corrompre_faux_casier') { ouvrirGreffeCorrompreFauxCasier(); return; }
  if (fn === 'syndicat_etudiant_creer')      { ouvrirSyndicatEtudiantCreer(); return; }
  if (fn === 'syndicat_etudiant_gerer')      { ouvrirSyndicatsEtudiants(); return; }
  // `suivre_formation` N'A PAS DE ROUTE, ET C'EST LA MOITIE DE SA DESACTIVATION. L'ordre est
  // declare avec `bientot` : son bouton est grise et son clic n'appelle rien. S'il etait
  // malgre tout appele, il tomberait sur le chemin generique -- qui refuserait, l'ordre
  // n'etant pas au miroir des couts (`ordre_inconnu`). Trois verrous, aucun effet.
  if (fn === 'fiscal' || fn === 'gestion_budget') { ouvrirGestionBudget(); return; }
  if (fn === 'proposer_treve')        { ouvrirProposerTreve(pa, cost); return; }
  if (fn === 'prier')                { doPrier(pa, cost); return; }
  if (fn === 'se_confesser')         { doSeConfeser(pa, cost); return; }
  if (fn === 'faire_don')            { doFaireDon(pa, cost); return; }
  if (fn === 'demander_benediction') { doDemanderBenediction(pa, cost); return; }
  if (fn === 'pelerin')              { doPelerin(pa, cost); return; }
  if (fn === 'excommunier')          { ouvrirModalCibleRepertoire('excommunier', 'Excommunier'); return; }
  if (fn === 'benediction_etat')     { doBenedictionEtat(pa, cost); return; }
  if (fn === 'consulter_confessions'){ doConsulterConfessions(pa, cost); return; }
  if (fn === 'acheter_relique')      { doAcheterRelique(pa, cost); return; }
  if (fn === 'scanner_aleatoire')    { declencherScandale(); return; }
  if (fn === 'accord_diplomatique')  { ouvrirModalNegociationDiplomatique(pa, cost); return; }
  if (fn === 'produire_fuite')       { ouvrirProduireFuite(pa, cost); return; }
  if (fn === 'fabriquer_scandale')   { ouvrirFabrquerScandale(pa, cost); return; }
  if (fn === 'etat_nation')          { ouvrirEtatNation(); return; }

  // Handlers complementaires v17
  // corrompre_gardien (QHS, cellules) ajoute le 27 aout 2026 (audit architecture) : defini
  // dans data.js mais jamais routee -- meme mecanique generique que ses homologues (desc
  // "Obtenir des privileges ou informations" = meme resultat generique que doCorruption,
  // aucun effet specifique distinct trouve pour aucun des fn de ce groupe).
  // « Corrompre un journaliste » a desormais sa propre mecanique (12 septembre 2026) : elle porte sur
  // la COUVERTURE d'une affaire judiciaire precise, avec sa formule propre (30 + CHA + INF/4 - ISN).
  // Elle ne passe plus par doCorruption, dont le corps est partage par les cinq autres ordres de
  // corruption (mairie, QHS, gardien, proces-verbal) et ne doit pas bouger.
  if (fn === 'corrompre_journaliste') { ouvrirCorrompreJournaliste(pa, cost); return; }
  if (fn === 'corrompre_fonct' || fn === 'corrompre_police' || fn === 'corrompre_gardien') { doCorruption(fn, pa, cost); return; }
  if (fn === 'se_reposer' || fn === 'se_nourrir') { doSeReposer(fn); return; }
  // Route 'requete_avocat' SUPPRIMEE le 13 octobre 2026 (arbitrage valide). La requete
  // reduisait la peine sur un TIRAGE -- `Math.min(85, 40 + DUP*1.5)` contre un d100 -- donc un
  // de decidait si une plaidoirie etait bonne. Human Gambit ne code pas les reactions
  // humaines. L'ordre, ses trois declarations dans data.js, son entree ORDER_EFFECTS, ses deux
  // handlers et la porte serveur `detention_reduire_peine` sont partis avec elle. La defense
  // par un avocat REEL -- barreau, tarification, defense retenue, dossier, commission d'office
  // -- n'est pas concernee : elle passe par le Tribunal, pas par la cellule.
  if (fn === 'greve_faim') { doGreveFaim(); return; }
  if (fn === 'tentative_evasion') { doTentativeEvasion(pa, cost); return; }
  if (fn === 'visiter_prisonnier') { ouvrirVisiterPrisonnier(pa, cost); return; }
  if (fn === 'se_renseigner') { doSeRenseigner(); return; }
  // Route 'reserver' SUPPRIMEE le 8 septembre 2026 : doReserver() n'existe dans aucun fichier du
  // depot -- le clic aurait leve une ReferenceError. Aucun ordre ne la declarait plus (seul un
  // ORDER_EFFECTS.reserver vide subsiste dans data.js). La reservation reelle passe par
  // 'reserver_chambre_hotel' -> doReserverChambreHotel (plateau-personnage.js).
  if (fn === 'interview') { ouvrirInterviewJodie(pa, cost); return; }
  // Lobbying presse (chantier "lobbying presse", refonte Tribune, 4 septembre 2026) : doArticle()/
  // doEtouffer() n'existaient nulle part avant ce chantier (ReferenceError silencieuse au clic,
  // meme bug de fond que distribuer_tract avant sa propre implementation) -- ouvrirModalLobbyingPresse
  // (plateau-pnj.js) reutilise le composant de selection de cible de lancer_rumeur_cible ci-dessous.
  if (fn === 'article') { ouvrirModalLobbyingPresse('article', pa, cost, successRate); return; }
  if (fn === 'etouffer') { ouvrirModalLobbyingPresse('etouffer', pa, cost, successRate); return; }
  if (fn === 'archives') { ouvrirArchivesTribunal(); return; }
  if (fn === 'consulter_dossiers_gouv') { doConsulterDossiersGouv(pa, cost); return; }
  // Route 'recruter_info' SUPPRIMEE le 8 septembre 2026, meme cas exactement : doRecruterInfo()
  // n'existe nulle part, aucun ordre ne declare ce fn. Le recrutement reel passe par
  // 'recruter_informateur_pnj' -> doRecruterInformateurPNJ (plateau-multijoueur.js).
  if (fn === 'mobiliser_police') { doMobiliserPolice(fn); return; }
  if (fn === 'mobiliser_armee') { doMobiliserArmee(pa, cost); return; }
  if (fn === 'etat_urgence') { doEtatUrgence(pa, cost); return; }
  if (fn === 'inspecter_troupes') { ouvrirInspecterTroupes(); return; }
  if (fn === 'ouvrir_enquete') { ouvrirChoixTypeCibleFiscale('ouvrir_enquete', 'Ouvrir une enquête sur'); return; }
  if (fn === 'proposer_grace') { ouvrirProposerGrace(pa, cost); return; }
  if (fn === 'gestion_qhs') { ouvrirGestionQHS(); return; }
  // LES DEUX ROUTES DU CLASSEMENT MINISTERIEL SONT SUPPRIMEES (12 octobre 2026). L'ordre
  // `annuler_poursuites` permettait au Ministre de la Justice de classer n'importe quelle
  // plainte du pays ; l'opportunite des poursuites appartient desormais au parquet. Les deux
  // routes pointaient la MEME fonction avec le MEME mode, et `annuler_poursuites_cible` n'etait
  // declare par aucun ordre.
  if (fn === 'nommer_juge') { ouvrirModalNommerJuge(); return; }
  if (fn === 'revoquer_juge') { ouvrirModalRevoquerJuge(pa, cost); return; }
  if (fn === 'nommer_chef_douanes') { ouvrirModalNommerChefDouanes(); return; }
  if (fn === 'revoquer_chef_douanes') { ouvrirModalRevoquerChefDouanes(pa, cost); return; }
  if (fn === 'nommer_commandant_port') { ouvrirModalNommerCommandantPort(); return; }
  if (fn === 'revoquer_commandant_port') { ouvrirModalRevoquerCommandantPort(pa, cost); return; }
  if (fn === 'consulter_administration_port') { ouvrirConsulterPort(); return; }
  if (fn === 'gerer_logistique_port') { ouvrirModifierRepartitionPort(); return; }
  if (fn === 'acheter_criee') { ouvrirAcheterCriee(pa, cost); return; }
  if (fn === 'consulter_effectifs_douane') { ouvrirConsulterEffectifsDouane(); return; }
  if (fn === 'recruter_douanier') { doRecruterDouanier(pa, cost); return; }
  if (fn === 'recruter_douanier_cynophile') { doRecruterDouanierCynophile(pa, cost); return; }
  if (fn === 'controler_caisse_douane') { ouvrirControlerCaisseDouane(pa, cost); return; }
  if (fn === 'gerer_effectifs_douane') { ouvrirGererEffectifsDouane(); return; }
  if (fn === 'nommer_commissaire') { ouvrirModalNommerCommissaire(); return; }
  if (fn === 'financer_communal') { ouvrirModalFinancerCommunal(pa, cost); return; }
  if (fn === 'revoquer_commissaire') { ouvrirModalRevoquerCommissaire(pa, cost); return; }
  if (fn === 'gerer_candidatures_directeurs') { ouvrirGestionCandidatures(['directeur_pharma','directeur_tabac_alcools','directeur_raffinerie'], pa, cost); return; }
  if (fn === 'gerer_candidature_commandant') { ouvrirGestionCandidatures(['commandant'], pa, cost); return; }

  // --- LOT 4.3 : PREROGATIVES MINISTERIELLES REGROUPEES -----------------------
  // Chaque entree ouvre un PANNEAU de fonction (plateau-gouvernement.js) qui expose les
  // sous-actions historiques, inchangees. Les anciens fn restent routes ci-dessus et ci-dessous :
  // aucun moteur n'est supprime, seuls les BOUTONS disparaissent des bureaux.
  if (fn === 'mobilisation_nationale')      { ouvrirMobilisationNationale(); return; }
  if (fn === 'diplomatie_bilaterale')       { ouvrirDiplomatieBilaterale(); return; }
  if (fn === 'gerer_chef_douanes')          { ouvrirGestionChefDouanes(pa, cost); return; }
  // Entrees de REGROUPEMENT (8 septembre 2026). Elles n'ouvrent qu'un panneau : aucun cout, aucun
  // effet. Chaque action du panneau appelle son handler historique avec son cout d'origine.
  // Les routes des ordres regroupes restent en place juste au-dessus/en dessous : elles ne sont
  // plus atteintes par un bouton, mais rien ne justifie de les retirer dans un chantier UX.
  if (fn === 'gestion_premier_ministre')    { ouvrirGestionPremierMinistre(); return; }
  if (fn === 'postes_par_decret')           { ouvrirPostesParDecret(); return; }
  if (fn === 'pouvoirs_exceptionnels')      { ouvrirPouvoirsExceptionnels(); return; }
  if (fn === 'adresse_a_la_nation')         { ouvrirAdresseALaNation(); return; }
  if (fn === 'gestion_manifestations')      { ouvrirGestionManifestations(); return; }
  if (fn === 'gerer_juges')                 { ouvrirGestionJuges(pa, cost); return; }
  if (fn === 'gerer_commandement')          { ouvrirGestionCommandement(); return; }
  if (fn === 'gestion_caserne')             { ouvrirGestionCaserne(); return; }
  if (fn === 'demobiliser')                 { doDemobiliser(); return; }
  if (fn === 'pilotage_fiscal_budgetaire')  { ouvrirPilotageFiscalBudgetaire(pa, cost); return; }
  if (fn === 'gestion_industrielle_portuaire') { ouvrirGestionIndustriellePortuaire(pa, cost); return; }
  if (fn === 'gerer_ambassades')            { ouvrirGestionAmbassades(pa, cost); return; }
  if (fn === 'gerer_candidature_directeur_entrepot') { ouvrirGestionCandidatures(['directeur_entrepot'], pa, cost); return; }
  if (fn === 'gerer_candidature_maire_adjoint') { ouvrirGestionCandidatures(['maire_adjoint'], pa, cost); return; }

  // REVOCATIONS MANQUANTES (correctif Lot 4.3). Ces quatre postes etaient nommables mais n'avaient
  // AUCUN chemin de revocation : une fois en place, leur titulaire ne pouvait plus etre demis.
  // On branche simplement le moteur commun -- protection 3 jours et cout 1 PA s'y appliquent
  // automatiquement, aucune logique specifique n'est ecrite.
  if (fn === 'revoquer_directeur_pharma')        { ouvrirRevoquerPosteNomme('directeur_pharma', pa, cost); return; }
  if (fn === 'revoquer_directeur_tabac_alcools') { ouvrirRevoquerPosteNomme('directeur_tabac_alcools', pa, cost); return; }
  if (fn === 'revoquer_directeur_raffinerie')    { ouvrirRevoquerPosteNomme('directeur_raffinerie', pa, cost); return; }
  if (fn === 'revoquer_maire_adjoint')           { ouvrirRevoquerPosteNomme('maire_adjoint', pa, cost); return; }
  if (fn === 'revoquer_directeur_entrepot') { ouvrirModalRevoquerDirecteurEntrepot(pa, cost); return; }
  if (fn === 'censurer_media') { ouvrirModalMedia(pa, cost); return; }
  if (fn === 'commanditer_sondage') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet...'); return; }
  if (fn === 'activer_cessez_le_feu') { ouvrirActiverCessezLeFeu(pa, cost); return; }
  if (fn === 'recruter_compagnie') { doRecruterCompagnie(); return; }
  if (fn === 'nommer_capitaine') { ouvrirNommerCapitaine(pa, cost); return; }
  if (fn === 'nommer_lieutenant') { ouvrirNommerLieutenant(pa, cost); return; }
  if (fn === 'gerer_detachement') { doGererDetachement(); return; }
  if (fn === 'assigner_mission') { doAssignerMission(pa, cost); return; }
  // GRAND TERMINAL DEPUIS LE LOT T. doVoirMaSection rendait une liste en lecture
  // seule sans inventaire et lisait le blob complet des compagnies par REST ;
  // ouvrirTerminalSection passe par militaire_terminal_section(), qui ne rend que
  // la section de l'appelant, et porte les ordres. Repli conserve : si le nouveau
  // fichier n'est pas charge, l'ancien ecran repond encore.
  if (fn === 'voir_ma_section') {
    if (typeof ouvrirTerminalSection === 'function') ouvrirTerminalSection();
    else doVoirMaSection();
    return;
  }
  if (fn === 'entrainer_section') { doEntrainerSection(pa, cost); return; }
  if (fn === 'reposer_section') { doReposerSection(); return; }
  if (fn === 'declencher_mutinerie') { doDeclencherMutinerie(); return; }
  if (fn === 'equiper_section') { doEquiperSection(pa, cost); return; }
  if (fn === 'remonter_renseignement') { ouvrirRemonterRenseignement(pa, cost); return; }
  if (fn === 'demettre_lieutenant') { doDemettreLieutenant(pa, cost); return; }
  // 'recruter_section' : route SUPPRIMEE le 21 septembre 2026 avec l'ordre lui-meme (modele de
  // recompletement a la piece abandonne par le GD le 17 septembre). Plus aucune declaration dans
  // data.js, plus de handler, plus de ligne dans le miroir des couts.
  // RECRUTEMENT MILITAIRE, FILIERE UNIQUE (24 septembre 2026). Ces trois routes remplacent les
  // cinq precedentes -- engager_officier, engager_soldat, candidatures_section,
  // traiter_engagements, affecter_engage -- retirees en meme temps que leurs ordres dans data.js
  // et que leurs lignes du miroir des couts. Les deux anciens chemins d'engagement coexistaient
  // avec des modeles de donnees incompatibles ; les laisser cote a cote aurait donne deux portes
  // vers le meme grade.
  //
  // Les 2 PA de s_engager_armee ne sont PAS preleves ici : militaire_candidature_deposer les
  // prend elle-meme, en dernier, apres avoir verifie l'identite, la presence et le grade. C'est
  // ce qui garantit qu'un refus ne coute jamais un point d'action.
  if (fn === 's_engager_armee') { ouvrirSEngagerArmee(); return; }
  if (fn === 'traiter_candidatures') { ouvrirTraiterCandidatures(); return; }
  if (fn === 'decouvrir_affectation') { doDecouvrirAffectation(); return; }
  if (fn === 'retirer_trousse') { doRetirerTrousse(); return; }
  if (fn === 'retirer_rations') { ouvrirRetraitRations(); return; }
  if (fn === 'calepin_campagne') { ouvrirCalepinCampagne(); return; }
  if (fn === 'decorer_militaire') { ouvrirDecorerMilitaire(); return; }
  if (fn === 'quitter_armee') { ouvrirQuitterArmee(); return; }
  if (fn === 'recherche_militaire') { ouvrirRechercheMilitaire(pa, cost); return; }
  if (fn === 'caisse_caserne') { ouvrirCaisseCaserne(); return; }
  // La Garde republicaine : 0 PA / 0 FR a l'entree, la RPC preleve elle-meme sur la caisse du
  // Ministere de la Defense (11 octobre 2026).
  if (fn === 'garde_republicaine') { ouvrirGardeRepublicaine(); return; }
  if (fn === 'requisition_civile') { ouvrirRequisitionCivile(pa, cost); return; }
  if (fn === 'se_presenter_affectation') { doSePresenterAffectation(pa, cost); return; }
  // 'accepter_incorporation' : ordre retire le 16 septembre 2026. Le transfert vers la caserne
  // est desormais propose par une fenetre contextuelle, une fois par jour de jeu, quand les
  // conditions existantes sont reunies (voir proposerTransfertCaserne).
  if (fn === 'consulter_faits_armes') { ouvrirConsulterFaitsArmes(); return; }
  if (fn === 'gerer_budget_caserne') { ouvrirGererBudgetMilitaire(); return; }
  // ARBITRAGE DU 8 OCTOBRE 2026 : le Ministre de l'Interieur a son tableau de bord
  // budgetaire, servi par le MEME ecran que celui de la Defense. Douanes 35 %, QHS 0 %.
  if (fn === 'gerer_budget_interieur') { ouvrirBudgetInterieur(); return; }
  // ARBITRAGE DU 7 OCTOBRE 2026 : le Ministre de la Justice repartit son budget entre les
  // trois tribunaux territoriaux, a parts egales au demarrage. Meme ecran generique.
  if (fn === 'gerer_budget_justice') { ouvrirBudgetJustice(); return; }
  if (fn === 'signer_traite') { ouvrirModalTraite(pa, cost); return; }
  if (fn === 'ouvrir_ambassade') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans', pa, cost); return; }
  if (fn === 'sanctions_diplo') { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'reponses_diplomatiques') { ouvrirReponsesDiplomatiques(pa, cost); return; }
  if (fn === 'subvention') { ouvrirChoixTypeCibleFiscale('subvention', 'Accorder une subvention à'); return; }
  if (fn === 'virement_ministere_usine') { doOuvrirVirementMinistereUsine(pa, cost); return; }
  if (fn === 'redressement_fiscal') { ouvrirChoixTypeCibleFiscale('redressement_fiscal', 'Redressement fiscal contre'); return; }
  if (fn === 'fixer_impots_nationaux') { ouvrirFixerImpotNational(pa, cost); return; }
  if (fn === 'traiter_manifestations') { doTraiterManifestations(pa, cost); return; }
  if (fn === 'renseignement') { ouvrirModalRenseignement(pa, cost); return; }
  if (fn === 'renseignement_militaire') { ouvrirRenseignementMilitaire(); return; }
  if (fn === 'planifier_operation') { ouvrirModalTexteLibre('planifier_operation', 'Planifier une operation', 'Decrivez l\'operation...'); return; }
  if (fn === 'mobiliser') { doMobiliserPolice(fn); return; }
  if (fn === 'dissoudre_assemblee') { doDissoudreAssemblee(pa, cost); return; }
  if (fn === 'negocier') { showToast('Ordre contact', 'Utilisez les ordres contact en cliquant sur le personnage cible.', false); return; }
  if (fn === 'parler_pnj') { showToast('Ordre contact', 'Cliquez directement sur le personnage pour interagir.', false); return; }
  // Route 'plainte' SUPPRIMEE le 13 octobre 2026 avec son ecran. Elle servait « Consulter les
  // affaires en cours » dans les deux salles d'audience : un doublon du registre public du
  // GREFFE qui disait, lui, le texte de la plainte. Les trois lieux du tribunal sont
  // distincts -- le greffe consulte, le bureau des magistrats exerce, la salle d'audience
  // juge -- et la consultation appartient au greffe : `greffe_affaires` / `greffe_archives`.
  if (fn === 'defense') { doDefense(pa, cost); return; }
  // LE BARREAU, LES TEMOINS ET L'AUDIENCE (12 octobre 2026, soir). Six routes, zero decision :
  // chacune ouvre un ecran qui appelle une porte serveur. Les gardes -- qualification d'avocat,
  // poursuites engagees, audience ouverte, presence au greffe ou au commissariat, titularite du
  // poste de juge -- vivent toutes au serveur, et c'est lui qui refuse.
  if (fn === 'avocat_barreau') { ouvrirAvocatBarreau(); return; }
  if (fn === 'avocat_dossiers') { ouvrirAvocatDossiers(); return; }
  if (fn === 'temoins_mes_convocations') { ouvrirTemoinsConvocations(); return; }
  if (fn === 'temoin_deposition') { ouvrirTemoinDepositionDepuisCommissariat(); return; }
  if (fn === 'audience_juge') { ouvrirAudienceJuge(); return; }
  if (fn === 'audience_salle') { ouvrirAudienceDepuisLaSalle(); return; }
  if (fn === 'greffe_affaires') { ouvrirAffairesPubliques(); return; }
  if (fn === 'greffe_archives') { ouvrirArchivesGreffe(); return; }
  // Doublon 'projet_loi' SUPPRIME (chantier Assemblee, 10 septembre 2026). Cette seconde route
  // etait inatteignable -- le test identique plus haut dans cette meme fonction fait return avant.
  // Elle pointait sur ouvrirDeposerProjet(), desormais retiree de plateau-politique.js. Meme
  // famille de piege que le doublon 'assassiner' corrige plus haut : deux routes pour un meme fn,
  // dont une seule compte, et rien ne le signale.
  // L'ordre 'greve' (greve PNJ d'empire, -5 IE decoratif) a ete retire le 8 septembre 2026 :
  // son handler doGrevePNJ avait disparu lors de l'eclatement de plateau.js du 28 juin 2026 --
  // clic = ReferenceError -- et le moteur syndical complet (greve_lancer/greve_terminer,
  // persistance Supabase, effets quotidiens serveur) l'a rendu obsolete.
  if (fn === 'recruter_etud') { doRecruterMilitants(pa, cost); return; }
  if (fn === 'acte_officiel') { doActeOfficiel(pa, cost); return; }
  if (fn === 'acte_officiel_juge') { ouvrirActeOfficielJuge(pa, cost); return; }
  if (fn === 'acte_officiel_notaire') { ouvrirActeOfficielNotaire(pa, cost); return; }

  if (fn === 'interdire_manif_cible')   { ouvrirModalTexteLibre('interdire_manif', 'Interdire une manifestation', 'Preciser le nom ou sujet de la manifestation a interdire...'); return; }
  if (fn === 'reprimer_manif_cible')    { ouvrirModalTexteLibre('reprimer_manif', 'Ordonner la repression', 'Preciser la manifestation ou le rassemblement cible...'); return; }
  if (fn === 'redressement_cible')      { ouvrirModalCibleRepertoire('redressement_fiscal', 'Redressement fiscal'); return; }
  if (fn === 'subvention_cible')        { ouvrirModalCibleRepertoire('subvention', 'Accorder une subvention'); return; }
  if (fn === 'allegemement_secteur')    { ouvrirModalSecteur(); return; }
  if (fn === 'allegement_fiscal')       { doAllegementFiscalIndisponible(); return; }
  if (fn === 'preempter_entreprise')    { ouvrirPreemptionEntreprise(); return; }
  if (fn === 'stage_caserne')           { doStageCaserne(pa, cost); return; }
  if (fn === 'acte_rachat_entreprise_preemption') { doActeRachatEntreprisePreemption(pa, cost); return; }
  if (fn === 'interdire_manif')         { ouvrirInterdireManif(pa, cost); return; }
  if (fn === 'reprimer_manif')          { ouvrirReprimerManif(pa, cost); return; }
  if (fn === 'ouvrir_enquete_cible')    { ouvrirModalCibleRepertoire('ouvrir_enquete', 'Ouvrir une enquete sur'); return; }
  if (fn === 'nommer_juge_cible')       { ouvrirModalNommerJuge(); return; }
  if (fn === 'cessez_le_feu_empire')    { ouvrirModalEmpireCible('cessez_le_feu', 'Negocier un cessez-le-feu avec'); return; }
  if (fn === 'renseignement_cible')     { ouvrirModalRenseignement(); return; }
  if (fn === 'censurer_media_cible')    { ouvrirModalMedia(); return; }
  if (fn === 'commanditer_sondage_cible') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet du sondage...'); return; }
  if (fn === 'signer_traite_empire')    { ouvrirModalTraite(); return; }
  if (fn === 'ouvrir_ambassade_empire') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans'); return; }
  if (fn === 'nommer_ambassadeur_cible'){ ouvrirModalNommerAmbassadeur(pa, cost); return; }
  if (fn === 'demettre_ambassadeur_cible'){ ouvrirModalDemettreAmbassadeur(pa, cost); return; }
  if (fn === 'expulser_ambassadeur_cible'){ ouvrirModalExpulserAmbassadeur(pa, cost); return; }
  if (fn === 'relations_bilaterales') { ouvrirRelationsBilaterales(); return; }
  if (fn === 'organiser_reception_diplomatique') { doOrganiserReceptionDiplomatique(pa, cost); return; }
  if (fn === 'financer_oeuvre_culturelle') { doFinancerOeuvreCulturelle(pa, cost); return; }
  if (fn === 'demander_audience_ambassadeur') { doDemanderAudienceAmbassadeur(pa, cost); return; }
  if (fn === 'demander_asile_politique') { doDemanderAsilePolitique(pa, cost); return; }
  if (fn === 'reserver_salle_reception') { doReserverSalleReception(pa, cost); return; }
  if (fn === 'bne_caisse_prelever') { ouvrirCaisseBNE(); return; }
  if (fn === 'sanctions_empire')        { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'reception_etat') { doReceptionAvecBonus(fn, cost); return; }
  if (fn === 'banquet_diplo') { ouvrirBanquetDiplomatique(pa, cost); return; }

  // Bureau National de l'Emploi (9 aout 2026)
  if (fn === 'consulter_offres_emploi')    { ouvrirOffresEmploiBNE(); return; }
  if (fn === 'bne_passer_annonce')         { ouvrirFormulaireAnnonceBNE(); return; }
  if (fn === 'virement_joueur')            { ouvrirVirementJoueur(false); return; }
  if (fn === 'virement_automatique')       { ouvrirVirementJoueur(true); return; }

  // Republia — Se nourrir (repas_gastronomique) : lie au stock reel du restaurant (lot
  // finition boucle economique, 21 aout 2026) -- special-case obligatoire comme les autres
  // ordres commerce ci-dessus, sinon le stock/la caisse ne seraient jamais mutes. Le reste du
  // comportement (roll probabiliste inclus, repas_gastronomique n'est pas dans alwaysSuccess
  // ci-dessous) est intentionnellement inchange : delegue a executerOrdreGenerique() apres
  // verification du stock, jamais duplique.
  if (fn === 'repas_gastronomique') { doRepasGastronomiqueGenerique(pa, cost, label, desc, successRate); return; }

  executerOrdreGenerique(fn, pa, cost, label, desc, successRate);
}

// Extrait de doOrder() (lot Le Republica, 21 aout 2026) -- comportement generique (PA/argent,
// roll, effets, toast, journal, detection, temps) partage par doOrder() (chemin par defaut,
// inchange) ET par doRepasGastronomiqueGenerique() ci-dessous (apres verification du stock),
// pour eviter toute duplication/divergence du moteur de jet existant.
async function executerOrdreGenerique(fn, pa, cost, label, desc, successRate) {
  // L'ORDRE GENERIQUE PAR LE SERVEUR (27 octobre 2026, audit « une seule verite » §3.1).
  // Le lieu, le poste, le paiement, le jet de reussite, les effets (sante, moral, influence,
  // popularite, discretion) et le remboursement d'un echec sont decides par
  // ordre_generique_executer, dans une seule transaction ; l'ecran ne fait plus que recopier.
  // Avant, le serveur prelevait le cout mais l'ecran tirait le jet et s'appliquait les effets.
  // Un ordre absent de la table ordres_generiques est refuse.
  const v = (typeof sbRpcVerdict === 'function')
    ? await sbRpcVerdict('ordre_generique_executer', { p_fn: fn, p_pa: pa || 0, p_cost: cost || 0 }).catch(() => null) : null;
  if (!v || v.ok !== true) {
    const motifs = { ordre_indisponible: 'Cet ordre n\'est pas disponible.',
                     pas_sur_place: 'Il faut être sur place pour cela.',
                     poste_requis: 'Cet ordre est réservé à un poste.' };
    if (v && motifs[v.raison]) showToast('Ordre impossible', motifs[v.raison], false);
    else if (typeof signalerRefusCout === 'function') signalerRefusCout(v || {});
    return;
  }
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg, solde_national: v.solde_national });
  if (typeof v.hp === 'number') state.hp = v.hp;
  if (typeof v.moral === 'number') state.moral = v.moral;
  if (typeof adopterJaugeServeur === 'function') { adopterJaugeServeur('pop', v.pop); adopterJaugeServeur('inf', v.inf); }
  if (typeof v.dis === 'number') state.dis = v.dis;
  const resultType = v.resultat;
  const roll = v.jet;

  const msg = buildResultMsg(fn, resultType, desc, label);
  const isGood = ['crit','success','partial'].includes(resultType);
  showToast(buildResultLabel(resultType, roll), msg, isGood, resultType === 'crit');
  addJournalEntry(`${label} — ${buildResultLabel(resultType, roll)}. ${msg}`,
    resultType === 'crit' || resultType === 'success' ? 'event-good' : resultType === 'crit-fail' ? 'event-bad' : '');

  // Verifier detection si acte illegal
  if (ACTES_ILLEGAUX[fn] && resultType !== 'crit-fail') {
    checkDetection(fn, resultType);
  }

  advanceTime(Math.max(0, pa));
  updateUI();
}

// applyEffects A DISPARU (27/10/2026) : les effets d'un ordre generique sont appliques par le
// serveur (ordre_generique_executer). « acheter_terrain » et « repas_gastronomique », ses deux
// effets speciaux, n'arrivaient plus ici (le premier a son propre parcours, le second n'a plus
// de bouton).

function buildResultLabel(type, roll) {
  const labels = {
    'crit':      `Succes critique ! (${roll})`,
    'success':   `Succes (${roll})`,
    'partial':   `Succes partiel (${roll})`,
    'fail':      `Echec (${roll})`,
    'crit-fail': `Echec critique ! (${roll})`
  };
  return labels[type] || `Resultat (${roll})`;
}

function buildResultMsg(fn, type, desc, label) {
  if (type === 'crit') return (desc ? desc + ' ' : '') + 'Resultat exceptionnel !';
  if (type === 'success') return desc || `${label} execute avec succes.`;
  if (type === 'partial') return `${label} partiellement reussi. Effet reduit.`;
  if (type === 'fail') return `${label} a echoue. Ressources partiellement recuperees.`;
  if (type === 'crit-fail') return `${label} s'est retourne contre vous. Consequences negatives.`;
  return desc || '';
}

// =====================
