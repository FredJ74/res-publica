// =====================
// PLATEAU-ROUTER.JS
// Routeur central des ordres (doOrder) — appelle des fonctions de TOUS les autres
// fichiers thematiques. DOIT ETRE CHARGE EN DERNIER dans plateau.html.
// =====================

// ORDERS SYSTEM
// =====================
function doOrder(fn, pa, cost, label, desc, successRate) {
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

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
  if (fn === 'postuler') { ouvrirPostulerPoste(); return; }
  if (fn === 'gerer_finances') { openFinancesModal(); return; }
  if (fn === 'plainte_police') { openPlainteModal(); return; }
  if (fn === 'archives_police') { doArchivesPolice(); return; }
  if (fn === 'pouls_populaire') { doPoulsPopulaire(); return; }
  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }
  if (fn === 'diner_affaires') { ouvrirModalInvitationSociale('diner_affaires', pa, cost, successRate); return; }
  if (fn === 'boire_verre') { ouvrirModalInvitationSociale('boire_verre', pa, cost, successRate); return; }
  if (fn === 'recruter_informateur_pnj') { doRecruterInformateurPNJ(); return; }
  if (fn === 'distribuer_tract') { doDistribuerTract(); return; }
  if (fn === 'demander_parler_loge') { doLogePortail(); return; }
  if (fn === 'imprimer_tracts') { ouvrirModalImprimerTracts(); return; }
  if (fn === 'choisir_arme') { ouvrirModalAcheterArme(); return; }
  if (fn === 'produire_arme') { doProduireArme(); return; }
  if (fn === 'acheter_produit_stock') { doAcheterProduitStock(); return; }
  if (fn === 'vendre_matiere_armurerie') { doVendreMatiereArmurerie(); return; }
  if (fn === 'racheter_armurerie') { doRachatArmurerie(); return; }
  if (fn === 'gerer_armurerie') { doGererArmurerie(); return; }
  if (fn === 'recolter_matiere') { doRecolterMatiere(); return; }
  if (fn === 'deposer_demande_permis') { doDeposerDemandePermis(); return; }
  if (fn === 'corrompre_fonctionnaire_permis') { doCorrompreFonctionnairePermis(); return; }
  if (fn === 'plainte_obstruction_permis') { doPlainteObstruction(); return; }
  if (fn === 'traiter_demandes_permis') { doTraiterDemandesPermis(); return; }
  if (fn === 'consulter_registre_armes') { doConsulterRegistre(); return; }
  if (fn === 'acheter_gilet') { doAcheterGilet(); return; }
  if (fn === 'acheter_bombe_illegale') { doAcheterExplosifs(); return; }
  if (fn === 'se_justifier') { doSeJustifier(); return; }
  if (fn === 'observer_match') { doObserverMatch(); return; }
  if (fn === 'consulter_palmares') { doConsulterPalmares(); return; }
  if (fn === 'parier_match') { doParierMatch(); return; }
  if (fn === 'regarder_live') { doRegarderLive(); return; }
  if (fn === 'prendre_licence_sportive') { doPrendreLicenceSportive(); return; }
  if (fn === 'tenue_entrainement') { doTenueEntrainement(); return; }
  if (fn === 'tenue_match') { doTenueMatch(); return; }
  if (fn === 'conseil_entraineur_adjoint') { doConseilEntraineurAdjoint(); return; }
  if (fn === 'sponsoriser_club') { doSponsoriserClub(); return; }
  if (fn === 'consulter_budget_club') { doConsulterBudgetClub(); return; }
  if (fn === 'gerer_salaires_club') { doGererSalairesClub(); return; }
  if (fn === 'imprimer_tracts_sportifs') { doImprimerTractsSportifs(); return; }
  if (fn === 'distribuer_tracts_match') { doDistribuerTractsMatch(); return; }
  if (fn === 'organiser_manifestation') { doOrganiserManifestation(); return; }
  if (fn === 'organiser_boycott') { doOrganiserBoycott(); return; }
  if (fn === 'transfert_clinique_privee') { doTransfertCliniquePrivee(); return; }
  if (fn === 'centre_anti_poison') { doCentreAntiPoison(); return; }
  if (fn === 'reserver_chambre_hotel') { doReserverChambreHotel(); return; }
  if (fn === 'dormir_chambre') { doDormirChambre(); return; }
  if (fn === 'dormir') { doDormir(); return; }
  if (fn === 'service_etage') { doServiceEtage(); return; }
  if (fn === 'consulter_classement_joueurs_club') { doConsulterClassementBookmaker(); return; }
  if (fn === 'postuler_president_club') { doPostulerPresidentClub(); return; }
  if (fn === 'consulter_bureau_president') { doConsulterBureauPresident(); return; }
  if (fn === 'proposer_transfert') { doProposerTransfert(); return; }
  if (fn === 'gerer_offres_transfert') { doGererOffresTransfert(); return; }
  if (fn === 'choisir_accessoire_club') { doChoisirAccessoireClub(); return; }
  if (fn === 'acheter_accessoire_personnalise') { doAcheterAccessoirePersonnalise(); return; }
  if (fn === 'rejoindre_club_supporters') { doRejoindreClubSupporters(); return; }
  if (fn === 'consulter_organigramme_supporters') { doConsulterOrganigrammeSupporters(); return; }
  if (fn === 'declencher_election_club') { doDeclencherElectionClub(); return; }
  if (fn === 'incendier') { doIncendier(); return; }
  if (fn === 'utiliser_explosifs') { doUtiliserExplosifs(); return; }
  if (fn === 'marchander_vote') { openMarchanderVoteModal(); return; }
  if (fn === 'assassiner') { showToast('Cliquez sur la cible', 'Pour assassiner, cliquez sur le personnage cible dans la liste des personnes presentes.', false); return; }
  if (fn === 'consulter_elections') { ouvrirTableauElectoral(); return; }
  if (fn === 'creer_poste_ministre')    { creerPosteMinistre(); return; }
  if (fn === 'creer_comite')            { creerComite(); return; }
  if (fn === 'supprimer_poste_custom')  { supprimerPosteCustom(); return; }
  if (fn === 'nommer_ministre')         { openNominerModal(); return; }
  if (fn === 'nommer_pm')               { ouvrirModalCibleRepertoire('nommer_pm_confirm', 'Nommer un Premier Ministre'); return; }
  if (fn === 'nommer_ministre_pm')      { ouvrirNommerMinistresModal(); return; }
  if (fn === 'declencher_vote_confiance') { ouvrirDeclencherVoteConfiance(); return; }
  if (fn === 'declarer_guerre_empire' || fn === 'declarer_guerre')  { ouvrirModalGuerreEmpire(); return; }
  if (fn === 'gracier_condamne' || fn === 'gracier') { ouvrirModalGracier(); return; }
  if (fn === 'decret_referendum')       { ouvrirForumNationalSousForumPresident('referendum'); return; }
  if (fn === 'jour_deuil')             { ouvrirForumNationalSousForumPresident('deuil'); return; }
  if (fn === 'solliciter_audience_president') { solliciterAudiencePresident(); return; }
  if (fn === 'etat_nation')             { ouvrirEtatNation(); return; }
  if (fn === 'fixer_impots_locaux')    { ouvrirFixerImpotsLocauxReel(); return; }
  if (fn === 'consommer_buvette') { doConsommerBuvette(); return; }
  if (fn === 'prendre_train')          { ouvrirModalTransport('train'); return; }
  if (fn === 'taxi_caserne')           { doTaxiSpecial('caserne'); return; }
  if (fn === 'passer_douanes_aeroport'){ doPasserDouanesAeroport(); return; }
  if (fn === 'organigramme')           { ouvrirOrganigramme(); return; }
  if (fn === 'louer_local')              { ouvrirModalLouerLocal(); return; }
  if (fn === 'gerer_local')              { ouvrirModalGererLocal(); return; }
  if (fn === 'choisir_suite')            { ouvrirModalChoixSuite(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'expulsion_legale')        { doExpulsionLegale(); return; }
  if (fn === 'donner_argent_pnj')       { doDonnerArgentPnj(); return; }
  if (fn === 'expulsion_legale')         { doExpulsionLegale(); return; }
  if (fn === 'appeler_police_terrain')  { doAppelerPoliceTerrain(); return; }
  if (fn === 'faire_disparaitre_cadavre') { doFaireDisparaitreCadavre(); return; }
  if (fn === 'negocier_squatteurs')     { doNegocierSquatteurs(); return; }
  if (fn === 'signer_compromis')        { doSignerCompromis(); return; }
  if (fn === 'acheter_terrain')         { doAcheterTerrain(); return; }
  if (fn === 'racheter_terrain')        { doRacheterTerrain(); return; }
  if (fn === 'decret_inutile')         { signerDecretInutile(); return; }
  if (fn === 'elections_tableau')      { ouvrirTableauElectoral(); return; }
  if (fn === 'changer_domicile')       { changerDomicile(state.country, state.currentCity); return; }
  if (fn === 'deposer_candidature')    { deposerCandidature(buildingId, state.country, state.currentCity); return; }
  if (fn === 'escort_infos')           { doEscortInfos(); return; }
  if (fn === 'escort_piege')           { doEscortPiege(); return; }
  if (fn === 'recruter_informateur_1') { consulterInformateur(1); return; }
  if (fn === 'recruter_informateur_2') { consulterInformateur(2); return; }
  if (fn === 'recruter_informateur_3') { consulterInformateur(3); return; }
  if (fn === 'recruter_informateur_4') { consulterInformateur(4); return; }
  if (fn === 'interroger_informateur_1'){ interrogerInformateur(1); return; }
  if (fn === 'interroger_informateur_2'){ interrogerInformateur(2); return; }
  if (fn === 'interroger_informateur_3'){ interrogerInformateur(3); return; }
  if (fn === 'interroger_informateur_4'){ interrogerInformateur(4); return; }
  if (fn === 'recruter_info')          { ouvrirRecruterInformateur(1); return; }
  if (fn === 'recruter_info_2')        { ouvrirRecruterInformateur(2); return; }
  if (fn === 'recruter_info_3')        { ouvrirRecruterInformateur(3); return; }
  if (fn === 'recruter_info_4')        { ouvrirRecruterInformateur(4); return; }
  if (fn === 'consulter_info')         { consulterInformateur(1); return; }
  if (fn === 'consulter_info_2')       { consulterInformateur(2); return; }
  if (fn === 'consulter_info_3')       { consulterInformateur(3); return; }
  if (fn === 'consulter_info_4')       { consulterInformateur(4); return; }
  if (fn === 'gerer_informateurs')     { ouvrirGestionInformateurs(); return; }
  if (fn === 'taxi_qhs')               { doTaxiSpecial('qhs'); return; }
  if (fn === 'prendre_bus_taxi')       { ouvrirModalTransport('bus'); return; }
  if (fn === 'prendre_avion')          { ouvrirModalTransport('avion'); return; }
  if (fn === 'prendre_bateau')         { ouvrirModalTransport('bateau'); return; }
  if (fn === 'controle_douanes')       { doControlDouanes(); return; }
  if (fn === 'corrompre_douanier')     { doCorrompreDoanier(); return; }
  if (fn === 'expedier_colis')         { ouvrirExpedierColis(); return; }
  if (fn === 'receptionner_commande')  { ouvrirReceptionnerCommande(); return; }
  if (fn === 'contrebande_port')       { doContrebandePort(); return; }
  if (fn === 'blocus_portuaire')       { doBlocusPortuaire(); return; }
  if (fn === 'inspecter_cargaisons')   { doInspecterCargaisons(); return; }
  if (fn === 'consulter_manifeste')    { doConsulterManifeste(); return; }
  if (fn === 'falsifier_manifeste')    { doFalsifierManifeste(); return; }
  if (fn === 'acheter_parapluie')      { doAcheterPoisonObjet('parapluie'); return; }
  if (fn === 'acheter_ghb')            { doAcheterPoisonObjet('ghb'); return; }
  if (fn === 'acheter_polonium')       { doAcheterPoisonObjet('polonium'); return; }
  if (fn === 'acheter_vipere')         { doAcheterPoisonObjet('vipere'); return; }
  if (fn === 'assassiner')             { ouvrirModalAssassiner(); return; }
  if (fn === 'se_cacher')              { doSeCacher(); return; }
  if (fn === 'empoisonner')            { ouvrirModalEmpoisonner(); return; }
  if (fn === 'repartition_budget_local'){ doRepartirBudgetMunicipal(); return; }
  if (fn === 'consulter_indices_locaux'){ doConsulterIndicesLocaux(); return; }
  if (fn === 'campagne_securite')      { doCampagneSecurite(); return; }
  if (fn === 'acte_officiel_mairie')   { ouvrirActeOfficielMairie(); return; }
  if (fn === 'contester_resultats')    { ouvrirContesterResultats(); return; }
  if (fn === 'calendrier_elections')   { ouvrirCalendrierElectoral(); return; }
  if (fn === 'observer_debats')         { observerDebats(); return; }
  if (fn === 'consulter_annuaire_deputes') { consulterAnnuaireDeputes(); return; }
  if (fn === 'objet_trouve')            { reclamerObjetTrouve(); return; }
  if (fn === 'voter_loi')              { ouvrirVoteLoi(); return; }
  if (fn === 'deposer_projet')         { ouvrirDeposerProjet(); return; }
  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(successRate); return; }
  if (fn === 'consulter_lobbyiste')    { doConsulterLobbyiste(); return; }
  if (fn === 'forum_president_conference' || fn === 'conference_presse')  { ouvrirForumNationalSousForumPresident('conference'); return; }
  if (fn === 'donner_conf') { doDonnerConference(); return; }
  if (fn === 'forum_president_propagande' || fn === 'propagande_etat')  { ouvrirForumNationalSousForumPresident('propagande'); return; }
  if (fn === 'forum_president_dementi' || fn === 'dementi')     { doDementiOfficiel(); return; }
  if (fn === 'consulter_archives_lois') { ouvrirArchivesLois(); return; }
  if (fn === 'consulter_archives_tribunal') { ouvrirArchivesTribunal(); return; }
  if (fn === 'porter_plainte')          { ouvrirPorterPlainte(); return; }
  if (fn === 'rendre_sentence')         { ouvrirRendreSentence(); return; }
  if (fn === 'demander_naturalisation') { ouvrirModalNaturalisation(); return; }
  if (fn === 'demander_mariage') { ouvrirModalDemandeMariage(); return; }
  if (fn === 'acheter_poison_parapluie') { doAcheterPoisonObjet('parapluie'); return; }
  if (fn === 'acheter_poison_ghb')       { doAcheterPoisonObjet('ghb'); return; }
  if (fn === 'acheter_poison_polonium')  { doAcheterPoisonObjet('polonium'); return; }
  if (fn === 'acheter_poison_vipere')    { doAcheterPoisonObjet('vipere'); return; }
  if (fn === 'officialiser_mariage') { ouvrirOfficialiserMariage(); return; }
  if (fn === 'gerer_couvre_feu') { ouvrirGererCouvreFeu(); return; }
  if (fn === 'demandes_naturalisation') { ouvrirDemandesNaturalisation(); return; }
  if (fn === 'falsifier_document')      { ouvrirFalsifierDocument(); return; }
  if (fn === 'fiscal' || fn === 'gestion_budget') { ouvrirGestionBudget(); return; }
  if (fn === 'proposer_treve')        { ouvrirProposerTreve(); return; }
  if (fn === 'prier')                { doPrier(); return; }
  if (fn === 'se_confesser')         { doSeConfeser(); return; }
  if (fn === 'faire_don')            { doFaireDon(cost); return; }
  if (fn === 'demander_benediction') { doDemanderBenediction(); return; }
  if (fn === 'pelerin')              { doPelerin(); return; }
  if (fn === 'excommunier')          { ouvrirModalCibleRepertoire('excommunier', 'Excommunier'); return; }
  if (fn === 'benediction_etat')     { doBenedictionEtat(); return; }
  if (fn === 'consulter_confessions'){ doConsulterConfessions(); return; }
  if (fn === 'acheter_relique')      { doAcheterRelique(); return; }
  if (fn === 'scanner_aleatoire')    { declencherScandale(); return; }
  if (fn === 'accord_diplomatique')  { ouvrirModalNegociationDiplomatique(); return; }
  if (fn === 'produire_fuite')       { ouvrirProduireFuite(); return; }
  if (fn === 'fabriquer_scandale')   { ouvrirFabrquerScandale(); return; }
  if (fn === 'etat_nation')          { ouvrirEtatNation(); return; }

  // Handlers complementaires v17
  if (fn === 'corrompre_fonct' || fn === 'corrompre_police' || fn === 'corrompre_journaliste') { doCorruption(fn, cost); return; }
  if (fn === 'se_reposer' || fn === 'se_nourrir') { doSeReposer(fn); return; }
  if (fn === 'requete_avocat') { doRequeteAvocat(); return; }
  if (fn === 'greve_faim') { doGreveFaim(); return; }
  if (fn === 'tentative_evasion') { doTentativeEvasion(); return; }
  if (fn === 'visiter_prisonnier') { doVisiterPrisonnier(); return; }
  if (fn === 'se_renseigner') { doSeRenseigner(); return; }
  if (fn === 'reserver') { doReserver(); return; }
  if (fn === 'interview') { doInterview(); return; }
  if (fn === 'article') { doArticle(); return; }
  if (fn === 'etouffer') { doEtouffer(); return; }
  if (fn === 'archives') { ouvrirArchivesTribunal(); return; }
  if (fn === 'consulter_dossiers_gouv') { doConsulterDossiersGouv(); return; }
  if (fn === 'demander_info_loge') { doLogeInfo(); return; }
  if (fn === 'se_former') { doSeFormer(); return; }
  if (fn === 'recruter_info') { doRecruterInfo(); return; }
  if (fn === 'mobiliser_police') { doMobiliserPolice(); return; }
  if (fn === 'mobiliser_armee') { doMobiliserArmee(); return; }
  if (fn === 'etat_urgence') { doEtatUrgence(); return; }
  if (fn === 'inspecter_troupes') { doInspecterTroupes(); return; }
  if (fn === 'ouvrir_enquete') { ouvrirChoixTypeCibleFiscale('ouvrir_enquete', 'Ouvrir une enquête sur'); return; }
  if (fn === 'proposer_grace') { ouvrirProposerGrace(); return; }
  if (fn === 'gestion_qhs') { ouvrirGestionQHS(); return; }
  if (fn === 'annuler_poursuites') { ouvrirModalAffaires('annuler'); return; }
  if (fn === 'nommer_juge') { ouvrirModalNommerJuge(); return; }
  if (fn === 'nommer_commissaire') { ouvrirModalNommerCommissaire(); return; }
  if (fn === 'censurer_media') { ouvrirModalMedia(); return; }
  if (fn === 'commanditer_sondage') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet...'); return; }
  if (fn === 'activer_cessez_le_feu') { ouvrirActiverCessezLeFeu(); return; }
  if (fn === 'nommer_commandant') { ouvrirNommerCommandant(); return; }
  if (fn === 'recruter_compagnie') { doRecruterCompagnie(); return; }
  if (fn === 'nommer_capitaine') { ouvrirNommerCapitaine(); return; }
  if (fn === 'nommer_lieutenant') { ouvrirNommerLieutenant(); return; }
  if (fn === 'gerer_detachement') { doGererDetachement(); return; }
  if (fn === 'assigner_mission') { doAssignerMission(); return; }
  if (fn === 'voir_ma_section') { doVoirMaSection(); return; }
  if (fn === 'entrainer_section') { doEntrainerSection(); return; }
  if (fn === 'equiper_section') { doEquiperSection(); return; }
  if (fn === 'remonter_renseignement') { ouvrirRemonterRenseignement(); return; }
  if (fn === 'demettre_lieutenant') { doDemettreLieutenant(); return; }
  if (fn === 'recruter_section') { ouvrirRecruterSection(); return; }
  if (fn === 'engager_officier') { doEngagerOfficier(); return; }
  if (fn === 'traiter_engagements') { ouvrirTraiterEngagements(); return; }
  if (fn === 'affecter_engage') { ouvrirAffecterEngage(); return; }
  if (fn === 'recherche_militaire') { ouvrirRechercheMilitaire(); return; }
  if (fn === 'requisition_civile') { ouvrirRequisitionCivile(); return; }
  if (fn === 'se_presenter_affectation') { doSePresenterAffectation(); return; }
  if (fn === 'consulter_faits_armes') { ouvrirConsulterFaitsArmes(); return; }
  if (fn === 'gerer_budget_caserne') { ouvrirGererBudgetMilitaire(); return; }
  if (fn === 'signer_traite') { ouvrirModalTraite(); return; }
  if (fn === 'ouvrir_ambassade') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans'); return; }
  if (fn === 'sanctions_diplo') { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'reponses_diplomatiques') { ouvrirReponsesDiplomatiques(); return; }
  if (fn === 'subvention') { ouvrirChoixTypeCibleFiscale('subvention', 'Accorder une subvention à'); return; }
  if (fn === 'redressement_fiscal') { ouvrirChoixTypeCibleFiscale('redressement_fiscal', 'Redressement fiscal contre'); return; }
  if (fn === 'fixer_impots_nationaux') { ouvrirFixerImpotNational(); return; }
  if (fn === 'traiter_manifestations') { doTraiterManifestations(); return; }
  if (fn === 'renseignement') { ouvrirModalRenseignement(); return; }
  if (fn === 'planifier_operation') { ouvrirModalTexteLibre('planifier_operation', 'Planifier une operation', 'Decrivez l\'operation...'); return; }
  if (fn === 'mobiliser') { doMobiliserPolice(); return; }
  if (fn === 'dissoudre_assemblee') { doDissoudreAssemblee(); return; }
  if (fn === 'negocier') { showToast('Ordre contact', 'Utilisez les ordres contact en cliquant sur le personnage cible.', false); return; }
  if (fn === 'parler_pnj') { showToast('Ordre contact', 'Cliquez directement sur le personnage pour interagir.', false); return; }
  if (fn === 'plainte') { ouvrirPorterPlainte(); return; }
  if (fn === 'defense') { doDefense(); return; }
  if (fn === 'projet_loi') { ouvrirDeposerProjet(); return; }
  if (fn === 'greve') { doGrevePNJ(); return; }
  if (fn === 'recruter_etud') { doRecruterMilitants(); return; }
  if (fn === 'acte_officiel') { doActeOfficiel(); return; }

  if (fn === 'interdire_manif_cible')   { ouvrirModalTexteLibre('interdire_manif', 'Interdire une manifestation', 'Preciser le nom ou sujet de la manifestation a interdire...'); return; }
  if (fn === 'reprimer_manif_cible')    { ouvrirModalTexteLibre('reprimer_manif', 'Ordonner la repression', 'Preciser la manifestation ou le rassemblement cible...'); return; }
  if (fn === 'redressement_cible')      { ouvrirModalCibleRepertoire('redressement_fiscal', 'Redressement fiscal'); return; }
  if (fn === 'subvention_cible')        { ouvrirModalCibleRepertoire('subvention', 'Accorder une subvention'); return; }
  if (fn === 'allegemement_secteur')    { ouvrirModalSecteur(); return; }
  if (fn === 'annuler_poursuites_cible'){ ouvrirModalAffaires('annuler'); return; }
  if (fn === 'ouvrir_enquete_cible')    { ouvrirModalCibleRepertoire('ouvrir_enquete', 'Ouvrir une enquete sur'); return; }
  if (fn === 'nommer_juge_cible')       { ouvrirModalNommerJuge(); return; }
  if (fn === 'cessez_le_feu_empire')    { ouvrirModalEmpireCible('cessez_le_feu', 'Negocier un cessez-le-feu avec'); return; }
  if (fn === 'renseignement_cible')     { ouvrirModalRenseignement(); return; }
  if (fn === 'censurer_media_cible')    { ouvrirModalMedia(); return; }
  if (fn === 'commanditer_sondage_cible') { ouvrirModalTexteLibre('commanditer_sondage', 'Commanditer un sondage', 'Preciser le sujet du sondage...'); return; }
  if (fn === 'signer_traite_empire')    { ouvrirModalTraite(); return; }
  if (fn === 'ouvrir_ambassade_empire') { ouvrirModalEmpireCible('ouvrir_ambassade', 'Ouvrir une ambassade dans'); return; }
  if (fn === 'nommer_ambassadeur_cible'){ ouvrirModalNommerAmbassadeur(); return; }
  if (fn === 'demettre_ambassadeur_cible'){ ouvrirModalDemettreAmbassadeur(); return; }
  if (fn === 'expulser_ambassadeur_cible'){ ouvrirModalExpulserAmbassadeur(); return; }
  if (fn === 'relations_bilaterales') { ouvrirRelationsBilaterales(); return; }
  if (fn === 'corrompre_homologue_local') { doCorrompreHomologueLocal(); return; }
  if (fn === 'organiser_reception_diplomatique') { doOrganiserReceptionDiplomatique(); return; }
  if (fn === 'financer_oeuvre_culturelle') { doFinancerOeuvreCulturelle(); return; }
  if (fn === 'demander_audience_ambassadeur') { doDemanderAudienceAmbassadeur(); return; }
  if (fn === 'demander_asile_politique') { doDemanderAsilePolitique(); return; }
  if (fn === 'reserver_salle_reception') { doReserverSalleReception(); return; }
  if (fn === 'sanctions_empire')        { ouvrirModalEmpireCible('sanctions', 'Imposer des sanctions a'); return; }
  if (fn === 'reception_etat') { doReceptionAvecBonus(fn, cost); return; }
  if (fn === 'banquet_diplo') { ouvrirBanquetDiplomatique(); return; }

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
  const alwaysSuccess = ['se_nourrir','dormir','se_reposer','soins','soins_urgence','soins_basiques','deplacer','gerer_finances','reserver','parler_pnj','se_renseigner','assister_session','voter_loi','plainte','plainte_police','archives','archives_police','acheter_terrain','se_presenter','rencontrer','se_former'];
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
