// =====================
// PLATEAU-ROUTER.JS
// Routeur central des ordres (doOrder) — appelle des fonctions de TOUS les autres
// fichiers thematiques. DOIT ETRE CHARGE EN DERNIER dans plateau.html.
// =====================

// ORDERS SYSTEM
// =====================
function doOrder(fn, pa, cost, label, desc, successRate) {
  if (typeof queteAccueilNotifierOrdre === 'function') queteAccueilNotifierOrdre(fn);
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

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
  const ORDRES_BUDGET_INSTITUTION = ['reception_etat', 'banquet_diplo'];
  if (cost > 0 && !ORDRES_BUDGET_INSTITUTION.includes(fn) && state.arg < cost) {
    showToast('Fonds insuffisants', `Cette action coute ${cost} ${cur}.`, false);
    return;
  }

  // Ordres speciaux
  if (fn === 'gerer_finances') { openFinancesModal(pa, cost); return; }
  if (fn === 'plainte_police') { openPlainteModal(pa, cost); return; }
  if (fn === 'arreter') { doArreter(pa, cost); return; }
  if (fn === 'mener_enquete') { doMenerEnquete(pa, cost); return; }
  if (fn === 'organiser_filature') { doOrganiserFilature(pa, cost); return; }
  if (fn === 'investir') { ouvrirInvestir(pa, cost); return; }
  if (fn === 'organiser_chasse_homme') { doOrganiserChasseHomme(pa, cost); return; }
  if (fn === 'recruter_policier') { doRecruterPolicier(pa, cost); return; }
  if (fn === 'gerer_effectifs_police') { ouvrirGererEffectifsPolice(); return; }
  if (fn === 'consulter_caisse_commissariat') { doConsulterCaisseCommissariat(); return; }
  if (fn === 'cambrioler_caisse_commissariat') { doCambriolerCaisseCommissariat(); return; }
  if (fn === 'se_rebeller') { doSeRebeller(pa, cost); return; }
  if (fn === 'archives_police') { doArchivesPolice(pa, cost); return; }
  if (fn === 'pouls_populaire') { doPoulsPopulaire(); return; }
  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }
  if (fn === 'diner_affaires') { ouvrirModalInvitationSociale('diner_affaires', pa, cost, successRate); return; }
  if (fn === 'boire_verre') { ouvrirModalInvitationSociale('boire_verre', pa, cost, successRate); return; }
  if (fn === 'recruter_informateur_pnj') { doRecruterInformateurPNJ(pa); return; }
  if (fn === 'distribuer_tract') { doDistribuerTract(pa, cost); return; }
  if (fn === 'demander_parler_loge') { doLogePortail(pa, cost); return; }
  if (fn === 'imprimer_tracts') { ouvrirModalImprimerTracts(pa, cost); return; }
  if (fn === 'vendre_bois_imprimerie') { ouvrirVendreBoisImprimerie(pa, cost); return; }
  if (fn === 'imprimer_tracts_electoraux') { ouvrirModalImprimerTractsElectoraux(pa, cost); return; }
  if (fn === 'imprimer_tracts_calomnieux') { ouvrirModalImprimerTractsCalomnieux(pa, cost); return; }
  if (fn === 'choisir_arme') { ouvrirModalAcheterArme(); return; }
  if (fn === 'produire_arme') { doProduireArme(); return; }
  if (fn === 'racheter_entreprise') { doRachatEntreprise(); return; }
  if (fn === 'recolter_matiere') { doRecolterMatiere(pa, cost); return; }
  if (fn === 'deposer_demande_permis') { doDeposerDemandePermis(pa, cost); return; }
  if (fn === 'corrompre_fonctionnaire_permis') { doCorrompreFonctionnairePermis(pa, cost); return; }
  if (fn === 'plainte_obstruction_permis') { doPlainteObstruction(pa, cost); return; }
  if (fn === 'traiter_demandes_permis') { doTraiterDemandesPermis(pa, cost); return; }
  if (fn === 'demander_logement_social') { demanderLogementSocial(pa, cost); return; }
  if (fn === 'gerer_logement_social') { gererLogementSocial(); return; }
  if (fn === 'traiter_demandes_logement_social') { traiterDemandesLogementSocial(pa, cost); return; }
  if (fn === 'consulter_registre_armes') { doConsulterRegistre(); return; }
  if (fn === 'acheter_gilet') { doAcheterGilet(); return; }
  if (fn === 'acheter_bombe_illegale') { doAcheterExplosifs(pa, cost); return; }
  if (fn === 'acheter_bombe_mil') { doObtenirExplosifsMilitaires(pa, cost); return; }
  if (fn === 'se_justifier') { doSeJustifier(pa, cost); return; }
  if (fn === 'observer_match') { doObserverMatch(); return; }
  if (fn === 'consulter_palmares') { doConsulterPalmares(); return; }
  if (fn === 'parier_match') { doParierMatch(pa, cost); return; }
  if (fn === 'regarder_live') { doRegarderLive(); return; }
  if (fn === 'prendre_licence_sportive') { doPrendreLicenceSportive(pa, cost); return; }
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
  if (fn === 'corrompre_rdv_notaire') { doCorrompreRdvNotaire(pa, cost); return; }
  if (fn === 'transferer_compromis') { doOuvrirTransfertCompromis(pa, cost); return; }
  if (fn === 'valider_transfert_compromis') { doValiderTransfertCompromis(pa, cost); return; }
  if (fn === 'payer_versement_chantier') { doPayerVersementChantier(); return; }
  if (fn === 'corrompre_chantier') { doCorrompreChantier(pa, cost); return; }
  if (fn === 'voler_materiel_chantier') { doVolerMaterielChantier(pa, cost); return; }
  if (fn === 'acheter_ressources_entrepot') { doOuvrirAchatEntrepot(pa, cost); return; }
  if (fn === 'vente_directe_usine') { doOuvrirVenteDirecteUsine(pa, cost); return; }
  if (fn === 'vendre_matiere_usine') { doVendreMatierePremiereUsineGenerique(pa, cost); return; }
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
  if (fn === 'fixer_prix_achat_entrepot') { doOuvrirFixerPrixAchatEntrepot(pa, cost); return; }
  if (fn === 'emprunter_construction') { ouvrirModalPretBancaire('nationale', 'travaux'); return; }
  if (fn === 'emprunter') {
    const typeBanque = state.currentBuilding === 'banque-privee' ? 'privee' : 'nationale';
    ouvrirModalPretBancaire(typeBanque, null, pa);
    return;
  }
  // emprunter_prive (Banque Privee, "sans verification, taux eleve") n'avait aucun handler —
  // corrige le 9 aout 2026 (audit Ordres) en le routant directement vers le type de pret
  // 'consommation' deja existant (meme profil : petite somme, remboursement rapide, taux eleve).
  if (fn === 'emprunter_prive') { ouvrirModalPretBancaire('privee', 'consommation', pa); return; }
  if (fn === 'diviser_construction') { doOuvrirDivisionTerrain(); return; }
  if (fn === 'louer_lot_ici') { doOuvrirLouerLot(pa, cost); return; }
  if (fn === 'gerer_lot_loue') { doGererLotLoue(); return; }
  if (fn === 'declencher_election_club') { doDeclencherElectionClub(pa, cost); return; }
  if (fn === 'incendier') { doIncendier(); return; }
  if (fn === 'utiliser_explosifs') { doUtiliserExplosifs(); return; }
  if (fn === 'marchander_vote') { openMarchanderVoteModal(); return; }
  if (fn === 'assassiner') { showToast('Cliquez sur la cible', 'Pour assassiner, cliquez sur le personnage cible dans la liste des personnes presentes.', false); return; }
  if (fn === 'consulter_elections') { ouvrirTableauElectoral(); return; }
  if (fn === 'creer_poste_ministre')    { creerPosteMinistre(pa, cost); return; }
  if (fn === 'creer_comite')            { creerComite(pa, cost); return; }
  if (fn === 'supprimer_poste_custom')  { supprimerPosteCustom(); return; }
  if (fn === 'nommer_ministre')         { ouvrirModalNommerPM(); return; }
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
  if (fn === 'organigramme')           { ouvrirOrganigramme(); return; }
  if (fn === 'consulter_organigramme_mairie') { ouvrirOrganigrammeMairie(); return; }
  if (fn === 'louer_local')              { ouvrirModalLouerLocal(pa, cost); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }
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
  if (fn === 'racheter_terrain')        { doRacheterTerrain(pa, cost); return; }
  if (fn === 'decret_inutile')         { signerDecretInutile(pa, cost); return; }
  if (fn === 'elections_tableau')      { ouvrirTableauElectoral(); return; }
  if (fn === 'changer_domicile')       { changerDomicile(state.country, state.currentCity); return; }
  if (fn === 'deposer_candidature')    { deposerCandidature('maire', state.country, state.currentCity); return; }
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
  if (fn === 'assassiner')             { ouvrirModalAssassiner(); return; }
  if (fn === 'se_cacher')              { doSeCacher(); return; }
  if (fn === 'empoisonner')            { ouvrirModalEmpoisonner(); return; }
  if (fn === 'repartition_budget_local'){ doRepartirBudgetMunicipal(pa, cost); return; }
  if (fn === 'consulter_indices_locaux'){ doConsulterIndicesLocaux(); return; }
  if (fn === 'campagne_securite')      { doCampagneSecurite(); return; }
  if (fn === 'acte_officiel_mairie')   { ouvrirActeOfficielMairie(pa, cost); return; }
  if (fn === 'contester_resultats')    { ouvrirContesterResultats(pa, cost); return; }
  if (fn === 'calendrier_elections')   { ouvrirCalendrierElectoral(); return; }
  if (fn === 'observer_debats')         { observerDebats(pa, cost); return; }
  if (fn === 'consulter_annuaire_deputes') { consulterAnnuaireDeputes(); return; }
  if (fn === 'objet_trouve')            { reclamerObjetTrouve(pa, cost); return; }
  if (fn === 'voter_loi')              { ouvrirVoteLoi(pa, cost); return; }
  if (fn === 'deposer_projet')         { ouvrirDeposerProjet(); return; }
  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(successRate, pa, cost); return; }
  if (fn === 'consulter_lobbyiste')    { doConsulterLobbyiste(pa, cost); return; }
  if (fn === 'forum_president_conference' || fn === 'conference_presse')  { ouvrirForumNationalSousForumPresident('conference', pa, cost); return; }
  if (fn === 'donner_conf') { doDonnerConference(pa, cost); return; }
  if (fn === 'forum_president_propagande' || fn === 'propagande_etat')  { ouvrirForumNationalSousForumPresident('propagande', pa, cost); return; }
  if (fn === 'forum_president_dementi' || fn === 'dementi')     { doDementiOfficiel(pa, cost); return; }
  if (fn === 'consulter_archives_lois') { ouvrirArchivesLois(); return; }
  if (fn === 'consulter_archives_tribunal') { ouvrirArchivesTribunal(); return; }
  if (fn === 'porter_plainte')          { ouvrirPorterPlainte(); return; }
  if (fn === 'rendre_sentence')         { ouvrirRendreSentence(pa, cost); return; }
  if (fn === 'demander_naturalisation') { ouvrirModalNaturalisation(pa, cost); return; }
  if (fn === 'demander_mariage') { ouvrirModalDemandeMariage(pa, cost); return; }
  if (fn === 'marche_noir') { doMarcheNoir(); return; }
  if (fn === 'officialiser_mariage') { ouvrirOfficialiserMariage(pa, cost); return; }
  if (fn === 'gerer_couvre_feu') { ouvrirGererCouvreFeu(pa, cost); return; }
  if (fn === 'subvention_min_int') { ouvrirModalFinancerMinInt(pa, cost); return; }
  if (fn === 'demandes_naturalisation') { ouvrirDemandesNaturalisation(); return; }
  if (fn === 'falsifier_document')      { ouvrirFalsifierDocument(pa, cost); return; }
  if (fn === 'fiscal' || fn === 'gestion_budget') { ouvrirGestionBudget(); return; }
  if (fn === 'proposer_treve')        { ouvrirProposerTreve(pa, cost); return; }
  if (fn === 'prier')                { doPrier(pa, cost); return; }
  if (fn === 'se_confesser')         { doSeConfeser(pa, cost); return; }
  if (fn === 'faire_don')            { doFaireDon(cost); return; }
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
  if (fn === 'corrompre_fonct' || fn === 'corrompre_police' || fn === 'corrompre_journaliste') { doCorruption(fn, cost); return; }
  if (fn === 'se_reposer' || fn === 'se_nourrir') { doSeReposer(fn); return; }
  if (fn === 'requete_avocat') { doRequeteAvocat(pa, cost); return; }
  if (fn === 'greve_faim') { doGreveFaim(); return; }
  if (fn === 'tentative_evasion') { doTentativeEvasion(pa, cost); return; }
  if (fn === 'visiter_prisonnier') { ouvrirVisiterPrisonnier(pa, cost); return; }
  if (fn === 'se_renseigner') { doSeRenseigner(); return; }
  if (fn === 'reserver') { doReserver(); return; }
  if (fn === 'interview') { doInterview(); return; }
  if (fn === 'article') { doArticle(); return; }
  if (fn === 'etouffer') { doEtouffer(); return; }
  if (fn === 'archives') { ouvrirArchivesTribunal(); return; }
  if (fn === 'consulter_dossiers_gouv') { doConsulterDossiersGouv(pa, cost); return; }
  if (fn === 'demander_info_loge') { doLogeInfo(); return; }
  if (fn === 'se_former') { doSeFormer(pa, cost); return; }
  if (fn === 'recruter_info') { doRecruterInfo(); return; }
  if (fn === 'mobiliser_police') { doMobiliserPolice(fn); return; }
  if (fn === 'mobiliser_armee') { doMobiliserArmee(pa, cost); return; }
  if (fn === 'etat_urgence') { doEtatUrgence(pa, cost); return; }
  if (fn === 'inspecter_troupes') { doInspecterTroupes(); return; }
  if (fn === 'ouvrir_enquete') { ouvrirChoixTypeCibleFiscale('ouvrir_enquete', 'Ouvrir une enquête sur'); return; }
  if (fn === 'proposer_grace') { ouvrirProposerGrace(pa, cost); return; }
  if (fn === 'gestion_qhs') { ouvrirGestionQHS(); return; }
  if (fn === 'annuler_poursuites') { ouvrirModalAffaires('annuler', pa, cost); return; }
  if (fn === 'nommer_juge') { ouvrirModalNommerJuge(); return; }
  if (fn === 'revoquer_juge') { ouvrirModalRevoquerJuge(pa, cost); return; }
  if (fn === 'nommer_chef_douanes') { ouvrirModalNommerChefDouanes(); return; }
  if (fn === 'revoquer_chef_douanes') { ouvrirModalRevoquerChefDouanes(pa, cost); return; }
  if (fn === 'nommer_commandant_port') { ouvrirModalNommerCommandantPort(); return; }
  if (fn === 'revoquer_commandant_port') { ouvrirModalRevoquerCommandantPort(pa, cost); return; }
  if (fn === 'consulter_administration_port') { ouvrirConsulterPort(); return; }
  if (fn === 'acheter_criee') { ouvrirAcheterCriee(pa, cost); return; }
  if (fn === 'affecter_criee') { ouvrirAffecterCriee(); return; }
  if (fn === 'consulter_effectifs_douane') { ouvrirConsulterEffectifsDouane(); return; }
  if (fn === 'recruter_douanier') { doRecruterDouanier(pa, cost); return; }
  if (fn === 'gerer_effectifs_douane') { ouvrirGererEffectifsDouane(); return; }
  if (fn === 'nommer_commissaire') { ouvrirModalNommerCommissaire(); return; }
  if (fn === 'financer_communal') { ouvrirModalFinancerCommunal(pa, cost); return; }
  if (fn === 'revoquer_commissaire') { ouvrirModalRevoquerCommissaire(pa, cost); return; }
  if (fn === 'gerer_candidatures_directeurs') { ouvrirGestionCandidatures(['directeur_pharma','directeur_tabac_alcools','directeur_raffinerie'], pa, cost); return; }
  if (fn === 'gerer_candidature_commandant') { ouvrirGestionCandidatures(['commandant'], pa, cost); return; }
  if (fn === 'gerer_candidature_directeur_entrepot') { ouvrirGestionCandidatures(['directeur_entrepot'], pa, cost); return; }
  if (fn === 'gerer_candidature_maire_adjoint') { ouvrirGestionCandidatures(['maire_adjoint'], pa, cost); return; }
  if (fn === 'revoquer_directeur_entrepot') { ouvrirModalRevoquerDirecteurEntrepot(pa, cost); return; }
  if (fn === 'censurer_media') { ouvrirModalMedia(pa, cost); return; }
  if (fn === 'commanditer_sondage') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet...'); return; }
  if (fn === 'activer_cessez_le_feu') { ouvrirActiverCessezLeFeu(pa, cost); return; }
  if (fn === 'nommer_commandant') { ouvrirNommerCommandant(pa, cost); return; }
  if (fn === 'recruter_compagnie') { doRecruterCompagnie(); return; }
  if (fn === 'nommer_capitaine') { ouvrirNommerCapitaine(pa, cost); return; }
  if (fn === 'nommer_lieutenant') { ouvrirNommerLieutenant(pa, cost); return; }
  if (fn === 'gerer_detachement') { doGererDetachement(); return; }
  if (fn === 'assigner_mission') { doAssignerMission(pa, cost); return; }
  if (fn === 'voir_ma_section') { doVoirMaSection(); return; }
  if (fn === 'entrainer_section') { doEntrainerSection(pa, cost); return; }
  if (fn === 'equiper_section') { doEquiperSection(pa, cost); return; }
  if (fn === 'remonter_renseignement') { ouvrirRemonterRenseignement(pa, cost); return; }
  if (fn === 'demettre_lieutenant') { doDemettreLieutenant(pa, cost); return; }
  if (fn === 'recruter_section') { ouvrirRecruterSection(pa, cost); return; }
  if (fn === 'engager_officier') { doEngagerOfficier(pa, cost); return; }
  if (fn === 'traiter_engagements') { ouvrirTraiterEngagements(pa, cost); return; }
  if (fn === 'affecter_engage') { ouvrirAffecterEngage(pa, cost); return; }
  if (fn === 'recherche_militaire') { ouvrirRechercheMilitaire(pa, cost); return; }
  if (fn === 'requisition_civile') { ouvrirRequisitionCivile(pa, cost); return; }
  if (fn === 'se_presenter_affectation') { doSePresenterAffectation(pa, cost); return; }
  if (fn === 'consulter_faits_armes') { ouvrirConsulterFaitsArmes(); return; }
  if (fn === 'gerer_budget_caserne') { ouvrirGererBudgetMilitaire(); return; }
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
  if (fn === 'planifier_operation') { ouvrirModalTexteLibre('planifier_operation', 'Planifier une operation', 'Decrivez l\'operation...'); return; }
  if (fn === 'mobiliser') { doMobiliserPolice(fn); return; }
  if (fn === 'dissoudre_assemblee') { doDissoudreAssemblee(); return; }
  if (fn === 'negocier') { showToast('Ordre contact', 'Utilisez les ordres contact en cliquant sur le personnage cible.', false); return; }
  if (fn === 'parler_pnj') { showToast('Ordre contact', 'Cliquez directement sur le personnage pour interagir.', false); return; }
  if (fn === 'plainte') { ouvrirPorterPlainte(pa, cost); return; }
  if (fn === 'defense') { doDefense(pa, cost); return; }
  if (fn === 'projet_loi') { ouvrirDeposerProjet(pa, cost); return; }
  if (fn === 'greve') { doGrevePNJ(); return; }
  if (fn === 'recruter_etud') { doRecruterMilitants(pa, cost); return; }
  if (fn === 'acte_officiel') { doActeOfficiel(); return; }

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
  if (fn === 'annuler_poursuites_cible'){ ouvrirModalAffaires('annuler', pa, cost); return; }
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
  if (fn === 'corrompre_homologue_local') { doCorrompreHomologueLocal(pa, cost); return; }
  if (fn === 'organiser_reception_diplomatique') { doOrganiserReceptionDiplomatique(pa, cost); return; }
  if (fn === 'financer_oeuvre_culturelle') { doFinancerOeuvreCulturelle(pa, cost); return; }
  if (fn === 'demander_audience_ambassadeur') { doDemanderAudienceAmbassadeur(pa, cost); return; }
  if (fn === 'demander_asile_politique') { doDemanderAsilePolitique(pa, cost); return; }
  if (fn === 'reserver_salle_reception') { doReserverSalleReception(pa, cost); return; }
  if (fn === 'sanctions_empire')        { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'reception_etat') { doReceptionAvecBonus(fn, cost); return; }
  if (fn === 'banquet_diplo') { ouvrirBanquetDiplomatique(pa, cost); return; }

  // Bureau National de l'Emploi (9 aout 2026)
  if (fn === 'sinscrire_demandeur_emploi') { doInscrireDemandeurEmploi(pa, cost); return; }
  if (fn === 'consulter_offres_emploi')    { ouvrirOffresEmploiBNE(); return; }
  if (fn === 'demissionner_emploi_bne')    { demissionnerEmploiBNE(); return; }

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
function executerOrdreGenerique(fn, pa, cost, label, desc, successRate) {
  // Deduire PA et argent
  if (!TEST_MODE) state.pa = Math.max(0, state.pa - pa);
  if (cost > 0) state.arg = Math.max(0, state.arg - cost);

  // Roll
  // Ajuster le taux selon le groupe pour le blocus
  if (fn === 'organiser_blocus') {
    const groupBonus = getGroupSize ? getGroupSize() - 1 : 0;
    successRate = Math.min(90, 25 + groupBonus);
  }

  const roll = Math.floor(Math.random() * 100) + 1;
  const malusSecurite = state.malusSecuriteMilitaire || 0;
  const effectiveRate = Math.max(5, (successRate >= 98 ? 99 : successRate) - malusSecurite);
  let resultType;
  if (roll <= 100 - effectiveRate) { resultType = 'crit-fail'; }
  else if (roll <= 100 - (effectiveRate * 0.7)) { resultType = 'fail'; }
  else if (roll <= 100 - (effectiveRate * 0.4)) { resultType = 'partial'; }
  else if (roll >= 95) { resultType = 'crit'; }
  else { resultType = 'success'; }

  // Ordres a succes garanti
  // soins/soin_public/soins_basiques retires (20 aout 2026) : desormais des fn dediees
  // (special-casees plus haut, doSoinCliniquePrivee/doSoinPublic), doOrder() ne les atteint plus
  // jamais -- entree ici devenue inutile/trompeuse. soins_basiques n'est plus reference par aucun
  // batiment (dispensaire-public-v est desormais branche sur soin_public comme les 2 autres).
  // repas_gastronomique ajoute (lot carte gastronomique Le Republica, 21 aout 2026) : bug
  // preexistant corrige (successRate:100 declare mais jamais garanti faute d'etre dans cette
  // liste). Sans effet observable a ce jour -- le bouton qui l'exposait a ete retire de la salle
  // du restaurant au meme lot (remplace par "Consulter la carte") -- mais le fn reste une
  // infrastructure partagee (ORDER_EFFECTS, applyEffects, doRepasGastronomiqueGenerique) : garde
  // deterministe si jamais rebranche ailleurs.
  const alwaysSuccess = ['se_nourrir','dormir','se_reposer','soins_urgence','deplacer','gerer_finances','reserver','parler_pnj','se_renseigner','assister_session','voter_loi','plainte','plainte_police','archives','archives_police','acheter_terrain','se_presenter','rencontrer','se_former','repas_gastronomique'];
  if (alwaysSuccess.includes(fn)) resultType = roll >= 95 ? 'crit' : 'success';

  applyEffects(fn, resultType, cost);
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

function applyEffects(fn, resultType, cost) {
  const ef = ORDER_EFFECTS[fn] || {};
  const mult = resultType === 'crit' ? 1.5 : resultType === 'success' ? 1 :
               resultType === 'partial' ? 0.5 : resultType === 'fail' ? 0 : -0.5;

  // Remboursement partiel si echec
  if (resultType === 'fail' && cost > 0) state.arg += Math.floor(cost * 0.3);
  if (resultType === 'crit-fail' && cost > 0) { /* Pas de remboursement */ }

  // Appliquer effets
  if (ef.hp)    state.hp    = Math.min(100, Math.max(0, state.hp    + Math.round(ef.hp    * mult)));
  if (ef.moral) state.moral = Math.min(100, Math.max(0, state.moral + Math.round(ef.moral * mult)));
  if (ef.inf)   state.inf   = Math.min(100, Math.max(0, state.inf   + Math.round(ef.inf   * mult)));
  if (ef.pop)   state.pop   = Math.min(100, Math.max(0, state.pop   + Math.round(ef.pop   * (resultType === 'crit-fail' ? -1 : mult))));
  if (ef.dis)   state.dis   = Math.min(100, Math.max(0, state.dis   + Math.round(ef.dis   * (ef.dis < 0 ? 1 : mult))));
  if (ef.arg)   state.arg   = Math.min(9999999, Math.max(0, state.arg + Math.round(ef.arg * mult)));

  // Effets speciaux
  // Blocus : 1 PA quoi qu'il arrive + bonus groupe
  if (fn === 'organiser_blocus') {
    if (!TEST_MODE) state.pa = Math.max(0, state.pa - 1);
  }
  if (fn === 'acheter_terrain') addToInventory({name:'Terrain (terrain en jeu)', icon:'ti-fence', type:'bien'});
  if (fn === 'repas_gastronomique' && resultType !== 'fail' && resultType !== 'crit-fail') {
    state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + 1;
  }
}

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
