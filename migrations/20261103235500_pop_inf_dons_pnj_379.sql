-- #379, lot 3c (Claude, 03/11/2026) : dons d'argent et d'objets aux PNJ décidés par le serveur.
-- Règles existantes de l'écran (confirmerDonPnj, confirmerDonObjetPnj), formules inchangées :
--   argent : refus possible des métiers à risque (commissaire, policier, inspecteur, juge) avec
--     un taux de (ISN national - 30) / 2 % ; l'argent n'est pris que si le don est accepté et il
--     est détruit (aucun personnage en face). Effets : serveur +5 Moral +2 INF ; barman +5 INF ;
--     journaliste +8 INF +5 POP ; médecin +min(25, montant/10) Santé ; commerçant +4 POP +2 INF ;
--     avocat +5 INF ; loge +8 INF ; grand prêtre +5 POP +5 Moral ; escort +6 INF ; métiers à
--     DIS seulement (commissaire, policier, inspecteur, juge, banquier) : aucune jauge ici, leurs
--     jets de DIS restent à l'écran ; tout autre métier : +min(8, montant/50) Moral.
--   objet : kompromat à un journaliste ou rédacteur +8 INF +5 POP, à un autre +3 INF ; tout autre
--     objet +3 Moral +2 INF. Tracts et colis de quête exclus (chemins propres).
-- Le PNJ doit être présent : casting de la pièce (miroir pnj_lieux_metiers, généré depuis data.js
-- par outils/generateurs/generer-pnj-lieux-metiers.cjs) ou PNJ actif du socle qui suit le joueur.
-- ISN national : mêmes valeurs que INDICES_NATIONAUX (data.js). Dépend de 20261103233000.

DO $prevol$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')
     AND position('hg379_lot2_v1' in prosrc)>0) THEN RAISE EXCEPTION '379_lot3c_lot2_absent'; END IF;
 IF to_regprocedure('public.inventaire_remettre(text,integer,jsonb,text)') IS NULL
    OR to_regprocedure('public.inventaire_localiser(jsonb,integer,jsonb)') IS NULL THEN
  RAISE EXCEPTION '379_lot3c_inventaire_absent'; END IF;
END $prevol$;

CREATE TABLE IF NOT EXISTS public.pnj_lieux_metiers(
  pays text NOT NULL, ville text NOT NULL, building_id text NOT NULL, room_id text NOT NULL,
  nom text NOT NULL, job text NOT NULL DEFAULT 'default',
  PRIMARY KEY(pays,ville,building_id,room_id,nom));
ALTER TABLE public.pnj_lieux_metiers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_lieux_metiers FROM PUBLIC,anon,authenticated;

-- 234 PNJ (généré par outils/generateurs/generer-pnj-lieux-metiers.cjs)
INSERT INTO public.pnj_lieux_metiers(pays,ville,building_id,room_id,nom,job) VALUES
('republic','capitale','palais-presidentiel','accueil_elysee','Gérard Tamponneau','protocole'),
('republic','capitale','palais-presidentiel','accueil_elysee','Garde Republicain','garde'),
('republic','capitale','palais-presidentiel','bureau_president','Le Président','president'),
('republic','capitale','palais-presidentiel','bureau_president','Huguette Papier','secretaire_general'),
('republic','capitale','palais-presidentiel','salle_presse_elysee','Porte-parole presidentiel','porteparole'),
('republic','capitale','palais-presidentiel','salle_reception','Gérard Tamponneau','protocole'),
('republic','capitale','hotel-republica','accueil','Nathalie Ondor','hotelier'),
('republic','capitale','hotel-republica','accueil','Isidore Trébien','bagagiste'),
('republic','capitale','hotel-republica','restaurant','Gaston Sauceblanche','serveur'),
('republic','capitale','hotel-republica','restaurant','Régis Gondasse','serveur'),
('republic','capitale','hotel-republica','restaurant','Yvette Gratinée','serveur'),
('republic','capitale','hotel-republica','restaurant','Jean Dupont','commercant'),
('republic','capitale','hotel-republica','restaurant','Marie Leblanc','journaliste'),
('republic','capitale','hotel-republica','bar','Marco (Barman)','barman'),
('republic','capitale','hotel-republica','bar','L''hôtesse de l''agence','escort_agence'),
('republic','capitale','hotel-republica','bar','L''hôte de l''agence','escort_agence'),
('republic','capitale','hotel-republica','bar','Marc Hantile','lobbyiste'),
('republic','capitale','palais-gouvernement','hall','Garde Republicain','garde'),
('republic','capitale','palais-gouvernement','hall','Secretaire Dupuis','secretaire'),
('republic','capitale','palais-gouvernement','bureaux','Éric Stricted','chef_cabinet'),
('republic','capitale','palais-gouvernement','salle_presse','Corinne Tite-Déclaz','porteparole'),
('republic','capitale','palais-gouvernement','salle_presse','Journalistes accrédités','journaliste'),
('republic','capitale','palais-gouvernement','archives_gouv','Archiviste Legrand','archiviste'),
('republic','capitale','palais-gouvernement','bureau_min_int','Yvan Danltat','min_int'),
('republic','capitale','palais-gouvernement','bureau_min_fin','Alain Théret','min_fin'),
('republic','capitale','palais-gouvernement','bureau_min_just','Mathilde Garde','min_just'),
('republic','capitale','palais-gouvernement','bureau_min_def','Martial Bouterin','min_def'),
('republic','capitale','palais-gouvernement','bureau_min_info','Marie-Eve Beaulieu','min_info'),
('republic','capitale','palais-gouvernement','bureau_min_ae','Jean-Jacques Carlin','min_ae'),
('republic','capitale','assemblee','accueil_assemblee','Garde Republicain','garde'),
('republic','capitale','assemblee','accueil_assemblee','Hotesse Accueil','hotesse_accueil'),
('republic','capitale','assemblee','accueil_assemblee','Renée Toitout','femme_menage'),
('republic','capitale','assemblee','couloirs','Lobbyiste Perrin','lobbyiste'),
('republic','capitale','assemblee','couloirs','Journaliste Blanc','journaliste'),
('republic','capitale','assemblee','salle_archives_assemblee','Archiviste Parlementaire','archiviste'),
('republic','capitale','tribunal','salle_audience','Honoré Cozetoujours','juge'),
('republic','capitale','tribunal','salle_audience','Maître Plaidoyer','avocat'),
('republic','capitale','tribunal','salle_audience','Procureur Saad','procureur'),
('republic','capitale','tribunal','greffe','Greffier Petit','greffier'),
('republic','capitale','banque-nationale','accueil_banque','Laurent Barre','directeur'),
('republic','capitale','banque-privee','bureau_prive','Hans Von Discret','banquier'),
('republic','capitale','banque-privee','bureau_prive','Ursula Offshore','conseiller'),
('republic','capitale','clinique-privee','reception_clinique','Docteur Bistouri','medecin'),
('republic','capitale','clinique-privee','reception_clinique','Sophie Stiquay','infirmier'),
('republic','capitale','dispensaire-public','salle_attente','Docteur Aspirine','medecin'),
('republic','capitale','dispensaire-public','salle_attente','Anne Tibiotique','infirmier'),
('republic','capitale','dispensaire-public','ehpad_tilleuls','Jeanine Dubois','pensionnaire_ehpad'),
('republic','capitale','dispensaire-public','ehpad_tilleuls','Louis Chevillard','pensionnaire_ehpad'),
('republic','capitale','dispensaire-public','ehpad_tilleuls','Noël Chauchay','pensionnaire_ehpad'),
('republic','capitale','commissariat','accueil_police','Gardien de la Paix','gardien_paix'),
('republic','capitale','commissariat','prison','Gardien Dubois','gardien'),
('republic','capitale','commissariat','prison','Tristan Cabane','detenu'),
('republic','capitale','commissariat','bureau_commissaire','Raoul Toufaud','commissaire'),
('republic','capitale','commissariat','bureau_commissaire','Brigitte Menottes','inspecteur'),
('republic','capitale','la-tribune','accueil_tribune','Gustave Encre','journaliste'),
('republic','capitale','la-tribune','accueil_tribune','Rosalie Caractère','journaliste'),
('republic','capitale','la-tribune','accueil_tribune','Jodie Moitout','journaliste'),
('republic','capitale','la-tribune','redaction','Romain Castel','redacteur'),
('republic','capitale','la-tribune','redaction','Marie Leblanc','journaliste'),
('republic','capitale','loge-maconnique','portail','Frère Jacques D''Equerre','loge'),
('republic','capitale','loge-maconnique','portail','Frère Maurice Compas','loge'),
('republic','capitale','loge-maconnique','hall_loge','Frere Gardien','membre_loge'),
('republic','capitale','loge-maconnique','bureau_venerable','Venerable Maitre Duval','venerable'),
('republic','capitale','universite','amphi','Professeur Charabia','professeur'),
('republic','capitale','universite','amphi','Assistante Mémoire','professeur'),
('republic','capitale','armurerie','magasin','Roger Détente','commercant'),
('republic','capitale','armurerie','magasin','Simone Calibre','commercant'),
('republic','capitale','marche','marche_ext','Jean-Pierre Bidoche','commercant'),
('republic','capitale','marche','marche_ext','Ginette Légume','commercant'),
('republic','capitale','marche','marche_ext','Jodie Moitout','journaliste'),
('republic','capitale','mairie-capitale','hall_mairie','Secretaire Municipal Petit','secretaire'),
('republic','capitale','mairie-capitale','hall_mairie','Hotesse Objets Trouves','hotesse_objets_trouves'),
('republic','capitale','mairie-capitale','bureau_maire','Le Maire de Luthecia','maire'),
('republic','capitale','mairie-capitale','bureau_maire_adjoint','Le Maire Adjoint de Luthecia','maire_adjoint'),
('republic','capitale','mairie-capitale','salle_elections','Jean Registre','responsable_election'),
('republic','capitale','mairie-capitale','salle_archives','Christophe Bouquin','archiviste'),
('republic','capitale','tabernacle-impots','nef_principale','Père Ception','grand_pretre'),
('republic','capitale','tabernacle-impots','nef_principale','Enfant de chœur Lacroix','clerc'),
('republic','capitale','tabernacle-impots','sacristie','Père Ception','grand_pretre'),
('republic','capitale','centre-multinodal-luthecia','hall_gare','Gaston Retard','chef_gare'),
('republic','capitale','centre-multinodal-luthecia','hall_gare','Mireille Guichet','hotesse'),
('republic','capitale','centre-multinodal-luthecia','hall_douanes','Inspecteur Prosper Tampon','douanier'),
('republic','capitale','centre-commercial','hall','Francisca Brel','criminel'),
('republic','capitale','centre-commercial','hall','Edgar Simore','artiste'),
('republic','capitale','centre-artisanal','travees','Sabri Coledur','commercant'),
('republic','capitale','centre-artisanal','travees','Céd'' Labone','criminel'),
('republic','capitale','centre-artisanal','travees','Henrico Stot','agent_securite'),
('republic','capitale','centre-affaires','hall','Gretta Délieu','hotesse'),
('republic','capitale','centre-affaires','hall','Moshe Maychan','criminel'),
('republic','capitale','centre-affaires','hall','Harry Cover','inspecteur'),
('republic','capitale','centre-affaires','tribune_republia','Correspondant Local','journaliste'),
('republic','capitale','centre-affaires','grobras_securite','Gaston Grobras','directeur'),
('republic','capitale','centre-affaires','grobras_securite','Sandra Pelle','secretaire'),
('republic','capitale','office-notarial','accueil_notaire','Alain Dex','secretaire_notaire'),
('republic','capitale','office-notarial','accueil_notaire','Claire Delhune','clerc_notaire'),
('republic','capitale','office-notarial','bureau_successions','Claire Delhune','clerc_notaire'),
('republic','capitale','office-notarial','bureau_contrats','Notaire Fontenelle','notaire'),
('republic','capitale','office-notarial','archives_notariales','Archiviste Notarial','archiviste_notaire'),
('republic','capitale','stade','terrain','Jean-Pierre Taclojnou','entraineur'),
('republic','capitale','stade','terrain','Michel Parlotte','commentateur'),
('republic','capitale','stade','vestiaires','Alphonse Toudroit','entraineur_adjoint'),
('republic','capitale','stade','buvette','Justin Verre','serveur'),
('republic','capitale','stade','buvette','Jean Fourtout','commercant'),
('republic','capitale','stade','guichet_paris','Ricardo Pif','bookmaker'),
('republic','capitale','stade','siege_supporters','Alfredo Mifassole','meneur_supporters'),
('republic','capitale','quartier-ambassades','accueil_ambassades','Hôtesse d''Accueil','hotesse'),
('republic','capitale','quartier-ambassades','accueil_ambassades','Agent de Sécurité','agent_securite'),
('republic','capitale','quartier-ambassades','bureau_al_khalija','Mohamed Al-Mansoori','ambassadeur'),
('republic','capitale','quartier-ambassades','bureau_sovarka','Valery Antonov','ambassadeur'),
('republic','capitale','quartier-ambassades','bureau_el_estado','Guillermo Vasquez','ambassadeur'),
('republic','capitale','place-formulaire-liberte','place','Pat Hounette','criminel'),
('republic','capitale','musee-ville-luthecia','hall','Gérard Poinçon','gardien_musee'),
('republic','capitale','musee-ville-luthecia','hall','Valérie Loisillon','hotesse'),
('republic','capitale','parc-botanique-national','parc','Florian Grès','jardinier'),
('republic','capitale','parc-botanique-national','serre','Jean-Pierre Ciseaux','conservateur'),
('republic','capitale','entrepot-logistique-luthecia','bureau_direction','Marcel Silo','directeur_entrepot'),
('republic','capitale','usine-pharmaceutique-luthecia','bureau_direction','Bernard Piluler','directeur_pharma'),
('republic','capitale','bureau-national-emploi','accueil','Nathalie Boulot','secretaire'),
('republic','capitale','bureau-national-emploi','accueil','Jean-Lou Zeure','citoyen'),
('republic','ville_a','hotel-port','hall_port','Jeanine Debré','hotelier'),
('republic','ville_a','mairie','accueil_mairie','Secretaire Municipal','secretaire'),
('republic','ville_a','mairie','bureau_maire_local','Le Maire','maire'),
('republic','ville_a','mairie','salle_elections','Loïc Legall','responsable_election'),
('republic','ville_a','banque-locale','guichet','Guichetier','banquier'),
('republic','ville_a','banque-locale','bureau_directeur','Marie Le Roux','directeur'),
('republic','ville_a','dispensaire-public-v','attente','Corinne Titgoute','hotesse'),
('republic','ville_a','dispensaire-public-v','attente','Betty Dine','infirmier'),
('republic','ville_a','commissariat-local','accueil_loc','Brigadier Local','policier'),
('republic','ville_a','commissariat-local','geoles','Loïc Karamel','detenu'),
('republic','ville_a','commissariat-local','bureau_commissaire','Martial Morvan','commissaire'),
('republic','ville_a','tribunal-local','salle_audience_locale','Mireille Sedlex','juge'),
('republic','ville_a','tribunal-local','salle_audience_locale','Maître Ali Bihanbéton','avocat'),
('republic','ville_a','bar-des-pecheurs','salle_bar','Marin Dulac','barman'),
('republic','ville_a','bar-des-pecheurs','salle_bar','René Seigne','default'),
('republic','ville_a','bar-des-pecheurs','salle_bar','Jean-Lou Demer','default'),
('republic','ville_a','imprimerie-librairie','accueil_imprimerie','Annie Talique-Legall','imprimeur'),
('republic','ville_a','imprimerie-librairie','atelier','Ouvrier typographe','typographe'),
('republic','ville_a','centre-multinodal-port-sainte-marie','hall_gare_psm','Chef de Gare Local','chef_gare'),
('republic','ville_a','port-sainte-marie','quai_principal','Alain Bordage','agent_maritime'),
('republic','ville_a','port-sainte-marie','douanes','Pascal Paguevite','chef_douanes'),
('republic','ville_a','port-sainte-marie','bureau_syndical_dockers','Dédé le Docker','docker'),
('republic','ville_a','port-sainte-marie','bureau_syndical_dockers','Étienne Dantafasse','default'),
('republic','ville_a','port-sainte-marie','administration_portuaire','Marcel Ancre','capitaine_port'),
('republic','ville_a','port-sainte-marie','administration_portuaire','Ginette Conteneur','agent_fret'),
('republic','ville_a','port-plaisance-psm','capitainerie','Patrice Lecap','default'),
('republic','ville_a','centre-commercial','hall','Cédric Legoff','agent_securite'),
('republic','ville_a','centre-artisanal','travees','Erwan Kerdan','commercant'),
('republic','ville_a','centre-artisanal','travees','Ronan Lafourgue','criminel'),
('republic','ville_a','centre-artisanal','travees','Maël Strom','agent_securite'),
('republic','ville_a','centre-affaires','hall','Edith Legall','hotesse'),
('republic','ville_a','centre-affaires','tribune_republia','Annie Houininon','journaliste'),
('republic','ville_a','centre-affaires','bureau_emploi_annexe','Edwige Leroux','secretaire'),
('republic','ville_a','stade','terrain','Maurice Éhault','entraineur'),
('republic','ville_a','stade','vestiaires','Thibault Gosse','entraineur_adjoint'),
('republic','ville_a','stade','buvette','Tenancier de Buvette','serveur'),
('republic','ville_a','stade','guichet_paris','Bookmaker Officiel','bookmaker'),
('republic','ville_a','stade','siege_supporters','Pascal Hamar','meneur_supporters'),
('republic','ville_a','zone-production','zone_recolte','Guy Tarembois','proprietaire'),
('republic','ville_a','capitaine-sauvage','salle_principale','Marine Leroux','serveur'),
('republic','ville_a','chasse-peche-psm','boutique','Victor Legall','commercant'),
('republic','ville_a','ecole-marine','hall','Maxime Bonvent','directeur'),
('republic','ville_a','chantier-naval','bureau','Pierrick Le Roux','chef_entreprise'),
('republic','ville_a','notre-dame-mer','nef','Père Iscope','pretre'),
('republic','ville_a','marche-psm','etals','Mireille Legall','commercant'),
('republic','ville_a','marche-psm','etals','Bastien Leroux','commercant'),
('republic','ville_a','musee-port-sainte-marie','hall','Soizic Le Gall','hotesse'),
('republic','ville_a','musee-port-sainte-marie','hall','Yvon Le Gall','conservateur'),
('republic','ville_a','musee-port-sainte-marie','hall','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_criminels','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_maires','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_personnalites','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_entrepreneurs','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_organisations','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_plumes','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_honneur_militaire','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_unions','Marcel Kermeur','guide'),
('republic','ville_a','musee-port-sainte-marie','salle_scandales','Marcel Kermeur','guide'),
('republic','ville_a','pole-tabac-alcools-psm','bureau_direction','Fernand Cendrier','directeur_tabac_alcools'),
('republic','ville_a','entrepot-logistique-psm','bureau_direction','Yvon Paletier','directeur_entrepot'),
('republic','ville_b','hotel-mineur','hall_mineur','Christelle Cazenave','hotelier'),
('republic','ville_b','mairie','accueil_mairie','Secretaire Municipal','secretaire'),
('republic','ville_b','mairie','bureau_maire_local','Le Maire','maire'),
('republic','ville_b','mairie','salle_elections','Patricia Vapeur','responsable_election'),
('republic','ville_b','mairie','salle_archives','Archiviste Municipal','archiviste'),
('republic','ville_b','banque-locale','guichet','Guichetier','banquier'),
('republic','ville_b','dispensaire-public-v','attente','Agnès Thésie','infirmier'),
('republic','ville_b','commissariat-local','accueil_loc','Brigadier Local','policier'),
('republic','ville_b','commissariat-local','bureau_commissaire','Gabriel Pelletier','commissaire'),
('republic','ville_b','tribunal-local','salle_audience_locale','Gérard Bretellewood','juge'),
('republic','ville_b','tribunal-local','salle_audience_locale','Maître Henri Nossant','avocat'),
('republic','ville_b','services-sociaux-montrouge','accueil','Pascale','citoyen'),
('republic','ville_b','services-sociaux-montrouge','bureau_assistante_sociale','Edwige Jacquard','citoyen'),
('republic','ville_b','parking-tribunal-montrouge','accueil','Jean Tarte','agent_securite'),
('republic','ville_b','parking-tribunal-montrouge','accueil','Basile Decoq','criminel'),
('republic','ville_b','siege-syndical','bureau_syndical','Delegue Morel','syndicaliste'),
('republic','ville_b','usine-principale','direction_usine','Directeur Fabre','directeur'),
('republic','ville_b','centre-multinodal-montrouge','hall_gare_montrouge','Chef de Gare Syndiqué','chef_gare'),
('republic','ville_b','centre-multinodal-montrouge','hall_gare_montrouge','Délégué Syndical','syndicaliste'),
('republic','ville_b','centre-commercial','hall','Bastien Jacquemont','agent_securite'),
('republic','ville_b','centre-artisanal','travees','Gilles Bielle','commercant'),
('republic','ville_b','centre-artisanal','travees','Jojo Laferraille','criminel'),
('republic','ville_b','centre-artisanal','travees','Bruno Ducoron','agent_securite'),
('republic','ville_b','centre-affaires','hall','Jeanne Terril','hotesse'),
('republic','ville_b','centre-affaires','tribune_republia','Arthur Lutte','journaliste'),
('republic','ville_b','centre-affaires','bureau_emploi_annexe','Pétra Vaillepas','secretaire'),
('republic','ville_b','stade','terrain','Jean-Philippe Hervitmonfute','entraineur'),
('republic','ville_b','stade','terrain','Émilie Charbon','commentateur'),
('republic','ville_b','stade','vestiaires','Gérard Bricoleau','entraineur_adjoint'),
('republic','ville_b','stade','buvette','Tenancier de Buvette','serveur'),
('republic','ville_b','stade','guichet_paris','Bookmaker Officiel','bookmaker'),
('republic','ville_b','stade','siege_supporters','Lucas Ténaire','meneur_supporters'),
('republic','ville_b','entrepot-logistique-montrouge','bureau_direction','Norbert Charton','directeur_entrepot'),
('republic','ville_b','raffinerie-montrouge','bureau_direction','Gustave Baril','directeur_raffinerie'),
('republic','ville_b','armurerie','magasin','Gerard (Armurier)','armurier'),
('republic','ville_b','loge-maconnique','portail','Le Portier','portier'),
('republic','ville_b','loge-maconnique','hall_loge','Frère Lampiste','membre_loge'),
('republic','ville_b','loge-maconnique','bureau_venerable','Vénérable Maître Augustin Grisou','venerable'),
('republic','ville_b','la-tribune','accueil_tribune','Rédacteur Calame','journaliste'),
('republic','ville_b','marche','marche_ext','Josette Betterave','commercant'),
('republic','ville_b','musee-histoire-montrouge','accueil','Elsa Montbaron','hotesse'),
('republic','ville_b','eglise-montrouge','salle','Abbé Tonnière','pretre'),
('republic','ville_b','jardins-ouvriers-montrouge','salle','Marcel Demine','citoyen'),
('republic','caserne','caserne-militaire','corps_garde','Adjudant Gaspard Ferrière','aide_de_camp'),
('republic','caserne','caserne-militaire','infirmerie','Ève Toahémarch','infirmier_mil'),
('republic','caserne','caserne-militaire','salle_commandement','Commandant Tom Hawak','commandant'),
('republic','caserne','caserne-militaire','armurerie_militaire','Armurier Militaire','armurier_mil'),
('republic','caserne','caserne-militaire','refectoire','Caporal Alouche','cuistot_mil'),
('republic','caserne','caserne-militaire','salle_faits_armes','Archiviste Militaire','archiviste_mil'),
('republic','caserne','caserne-militaire','quartier_troupes','Caporal Lefebvre','soldat'),
('republic','caserne','caserne-militaire','quartier_troupes','Soldat Nguyen','soldat'),
('republic','qhs','qhs-prison','entree_qhs','Dominique Cruel','directeur_qhs'),
('republic','qhs','qhs-prison','entree_qhs','Philippe Cognedur','gardien_qhs'),
('republic','qhs','qhs-prison','cellules_qhs','Jean Terre','gardien_qhs'),
('republic','qhs','qhs-prison','cellules_qhs','Patrick Coule','gardien_qhs')
ON CONFLICT (pays,ville,building_id,room_id,nom) DO UPDATE SET job=EXCLUDED.job;

-- Métier d'un PNJ présent auprès de l'acteur, ou NULL s'il n'est pas là.
CREATE OR REPLACE FUNCTION public.pnj_don_metier_interne(p_acteur text,p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
  SELECT coalesce(
    (SELECT l.job FROM public.personnages_donnees a JOIN public.pnj_lieux_metiers l
       ON l.pays=a.country AND l.ville=a.current_city AND l.building_id=a.current_building
      AND l.room_id=a.current_room AND l.nom=p_nom WHERE a.name=p_acteur),
    (SELECT coalesce(em.job,'default') FROM public.pnj_membres m
       LEFT JOIN public.pnj_employes_metier em ON em.pnj_id=m.id
      WHERE m.nom=p_nom AND m.statut='actif' AND (m.proprietaire_pj=p_acteur OR m.leader_pj=p_acteur)
      ORDER BY m.id LIMIT 1));
$f$;
REVOKE ALL ON FUNCTION public.pnj_don_metier_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('don_argent_pnj',0,0),('don_objet_pnj',0,0) ON CONFLICT DO NOTHING;

DO $patch$
DECLARE v_def text; v_ancre text; v_ajout text; v_decl text;
BEGIN
 v_def:=pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure);
 IF position('hg379_lot3c_v1' in v_def)>0 THEN RETURN; END IF;
 v_decl:='  v_int numeric; v_bonus_int numeric; v_taux integer; v_jet integer; v_detecte boolean;';
 IF (length(v_def)-length(replace(v_def,v_decl,'')))/length(v_decl)<>1 THEN RAISE EXCEPTION '379_lot3c_ancre_declarations'; END IF;
 v_def:=replace(v_def,v_decl,v_decl||E'\n  v_job text; v_obj jsonb; v_montant integer; v_moral_gain integer:=0; v_hp_gain integer:=0;');
 v_ancre:=E'  ELSE RETURN jsonb_build_object(''ok'',false,''raison'',''ordre_non_raccorde'');\n  END CASE;';
 v_ajout:=$a$
  -- hg379_lot3c_v1 : dons aux PNJ (formules de confirmerDonPnj / confirmerDonObjetPnj).
  WHEN 'don_argent_pnj' THEN
    IF p_contexte-ARRAY['nom','montant']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'nom') IS DISTINCT FROM 'string'
       OR jsonb_typeof(p_contexte->'montant') IS DISTINCT FROM 'number'
       OR (p_contexte->>'montant')::numeric<>floor((p_contexte->>'montant')::numeric)
       OR (p_contexte->>'montant')::numeric NOT BETWEEN 1 AND 100000000 THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    v_job:=public.pnj_don_metier_interne(a.name,p_contexte->>'nom');
    IF v_job IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pnj_non_present');END IF;
    v_montant:=(p_contexte->>'montant')::integer;
    -- Refus des métiers à risque : l'argent reste en poche (règle d'origine).
    v_taux:=CASE WHEN v_job IN('commissaire','policier','inspecteur','juge')
      THEN greatest(0,(CASE a.country WHEN 'narco' THEN 15 WHEN 'soviet' THEN 70 WHEN 'khalija' THEN 60 ELSE 30 END)-30)/2 ELSE 0 END;
    v_detecte:=v_taux>0 AND floor(random()*100)::integer+1<=v_taux;
    IF NOT v_detecte THEN
      paiement:=public.debiter_fonds_ordinaires(a.name,v_montant);
      IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
      CASE v_job
        WHEN 'serveur' THEN v_moral_gain:=5; inf_gain:=2;
        WHEN 'barman' THEN inf_gain:=5;
        WHEN 'journaliste' THEN inf_gain:=8; pop_gain:=5;
        WHEN 'medecin' THEN v_hp_gain:=least(25,v_montant/10);
        WHEN 'commercant' THEN pop_gain:=4; inf_gain:=2;
        WHEN 'avocat' THEN inf_gain:=5;
        WHEN 'loge' THEN inf_gain:=8;
        WHEN 'grand_pretre' THEN pop_gain:=5; v_moral_gain:=5;
        WHEN 'escort' THEN inf_gain:=6;
        WHEN 'commissaire' THEN NULL; WHEN 'policier' THEN NULL; WHEN 'inspecteur' THEN NULL;
        WHEN 'juge' THEN NULL; WHEN 'banquier' THEN NULL;
        ELSE v_moral_gain:=least(8,v_montant/50);
      END CASE;
    END IF;
    pa_cout:=NULL;
    publication:=jsonb_build_object('job',v_job,'refuse',v_detecte,'montant',CASE WHEN v_detecte THEN 0 ELSE v_montant END,
      'gain_moral',v_moral_gain,'gain_hp',v_hp_gain);
  WHEN 'don_objet_pnj' THEN
    IF p_contexte-ARRAY['nom','index','signature']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'nom') IS DISTINCT FROM 'string'
       OR jsonb_typeof(p_contexte->'index') IS DISTINCT FROM 'number' OR jsonb_typeof(p_contexte->'signature') IS DISTINCT FROM 'object' THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    v_job:=public.pnj_don_metier_interne(a.name,p_contexte->>'nom');
    IF v_job IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pnj_non_present');END IF;
    v_jet:=public.inventaire_localiser(coalesce(a.inventory,'[]'::jsonb),(p_contexte->>'index')::integer,p_contexte->'signature');
    IF v_jet<0 THEN RETURN jsonb_build_object('ok',false,'raison','objet_absent');END IF;
    v_obj:=a.inventory->v_jet;
    IF v_obj->>'type' IN('tract','colis_secret_pat','acte_officiel') THEN RETURN jsonb_build_object('ok',false,'raison','objet_non_donnable');END IF;
    paiement:=public.inventaire_remettre(a.name,(p_contexte->>'index')::integer,p_contexte->'signature',p_contexte->>'nom');
    IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
    IF v_obj->>'type'='kompromat' THEN
      IF v_job IN('journaliste','redacteur') THEN inf_gain:=8; pop_gain:=5; ELSE inf_gain:=3; END IF;
    ELSE v_moral_gain:=3; inf_gain:=2; END IF;
    pa_cout:=NULL;
    publication:=jsonb_build_object('job',v_job,'objet',v_obj,'gain_moral',v_moral_gain,'gain_hp',0,
      'scandale',v_obj->>'type'='kompromat' AND v_job IN('journaliste','redacteur'));
$a$;
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_lot3c_ancre_dispatcher'; END IF;
 v_def:=replace(v_def,v_ancre,v_ajout||v_ancre);
 -- Moral et santé des dons, dans la même écriture finale que POP/INF ; inventaire rendu pour adoption.
 v_ancre:=E'    hp=CASE WHEN p_ordre=''greve_faim'' THEN greatest(1,hp-5) ELSE hp END\n';
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_lot3c_ancre_ecriture'; END IF;
 v_def:=replace(v_def,v_ancre,
   E'    hp=CASE WHEN p_ordre=''greve_faim'' THEN greatest(1,hp-5) WHEN v_hp_gain<>0 THEN least(100,greatest(0,coalesce(hp,100)+v_hp_gain)) ELSE hp END,\n'
 ||E'    moral=CASE WHEN v_moral_gain<>0 THEN least(100,greatest(0,coalesce(moral,50)+v_moral_gain)) ELSE moral END\n');
 v_ancre:=E'  sortie:=coalesce(publication,''{}''::jsonb)||jsonb_build_object(';
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_lot3c_ancre_sortie'; END IF;
 v_def:=replace(v_def,v_ancre,
   E'  IF p_ordre=''don_objet_pnj'' THEN publication:=publication||jsonb_build_object(''inventory'',a.inventory,''revision'',a.inventory_revision); END IF;\n'||v_ancre);
 EXECUTE v_def;
END $patch$;
NOTIFY pgrst,'reload schema';
