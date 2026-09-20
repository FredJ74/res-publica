-- =====================================================================
-- VERROU DE L'ARGENT PERSONNEL — LOT DU 20 SEPTEMBRE 2026
-- =====================================================================
-- OBJET DU LOT. arg et liquide ne doivent plus pouvoir AUGMENTER depuis le
-- client. Une baisse reste tolerable (au pire le joueur se lese) ; c'est la
-- hausse qui fabrique de la monnaie. Le verrou est ecrit dans le trigger
-- INSTEAD OF de la VUE public.personnages, et pose DESACTIVE derriere un
-- interrupteur rp_transitions ; tant qu'il dort, chaque hausse est JOURNALISEE
-- dans fiche_hausses_observees avec la requete d'origine.
--
-- MIGRATION DE PRODUCTION ABSORBEE :
--   20260920094956  verrou_argent_personnel
--
-- AVERTISSEMENT — ETAT FINAL, PAS HISTORIQUE. Ce fichier reproduit l'etat de la
-- production au 20/09/2026, pas la suite des gestes qui y ont mene.
-- personnages_vue_modifier() est le trigger INSTEAD OF de la vue personnages :
-- c'est une fonction tres sensible, reecrite ici a l'identique depuis pg_proc.
-- Toute divergence de son corps casse l'ecriture de fiche de TOUS les joueurs.
--
-- DEPENDANCES. Aucun fichier *.sql du depot ne cree les objets prerequis.
-- Doivent etre en place AVANT ce fichier :
--   * table public.rp_transitions et fonction public.rp_transition_active(text)
--       -> migration_20260920_mails_systeme_attestes.sql (ce depot), qui les cree
--   * table public.fonds_credits_sources
--       -> 20260917094218 fonds_crediter_atteste (migration de production)
--   * table public.fiche_hausses_observees
--       -> 20260919224319 fiche_colonnes_serveur_lot1 (migration de production)
--   * table public.personnages_donnees, VUE public.personnages et son trigger
--     INSTEAD OF, fonction public.est_appel_serveur()
--       -> 20260913131157 chantier_b_masquage_donnees_privees_personnages,
--          puis les lots qui ont ajoute les colonnes (jusqu'a quete_carriere)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. L'INTERRUPTEUR, POSE DESACTIVE
-- ---------------------------------------------------------------------
-- Commentaire d'origine (20260920094956) :
--
-- POURQUOI UN INTERRUPTEUR. 24 sites de credit client restent a router vers un
-- chemin atteste. Poser le verrou maintenant les ferait echouer EN SILENCE chez
-- les joueurs -- exactement ce que la consigne interdit. Le verrou est donc
-- ecrit, teste dans ses DEUX etats, et pose DESACTIVE. Il s'active d'une ligne
-- au push, quand le client route sera en ligne :
--     UPDATE public.rp_transitions SET actif = true WHERE cle = 'argent_verrou';
--
-- L'observation continue : fiche_hausses_observees enregistre chaque hausse avec
-- la requete d'origine -- la liste REELLE des sites a router, pas une devinette.
--
-- ETAT FINAL CONSTATE : la ligne est toujours a actif = false le 20/09/2026 au
-- soir, avec la note d'origine inchangee.
INSERT INTO public.rp_transitions (cle, actif, note) VALUES
  ('argent_verrou', false,
   'A ACTIVER AU PUSH, une fois les 24 sites de credit routes. Inactif : les hausses d''arg/liquide passent mais sont journalisees.')
ON CONFLICT (cle) DO NOTHING;


-- ---------------------------------------------------------------------
-- 2. LES CAUSES DE CREDIT EN LISTE BLANCHE
-- ---------------------------------------------------------------------
-- Quatre causes de remboursement ajoutees par ce lot. La table
-- fonds_credits_sources contient aussi des lignes venant d'autres lots
-- (remboursement_ordre, remboursement_ordre_echoue, et les sources anterieures) :
-- elles sont volontairement EXCLUES de ce fichier, qui ne versionne que ce que
-- 20260920094956 a pose.
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES
  ('remboursement_kompromat',    300,  1, 'Remboursement — fabrication de kompromat echouee'),
  ('remboursement_recette_lieu', NULL, 1, 'Remboursement — caisse du lieu indisponible'),
  ('remboursement_debauchage',   NULL, 1, 'Remboursement — debauchage refuse par le serveur'),
  ('remboursement_cession',      NULL, 1, 'Remboursement — cession non finalisee')
ON CONFLICT (source) DO UPDATE
  SET montant = EXCLUDED.montant, part = EXCLUDED.part, libelle = EXCLUDED.libelle;


-- ---------------------------------------------------------------------
-- 3. LE TRIGGER INSTEAD OF DE LA VUE public.personnages
-- ---------------------------------------------------------------------
-- FONCTION TRES SENSIBLE. Elle porte a la fois le controle de possession, les
-- colonnes serveur-autoritaires (pa, stats, free_pts_restants, qualifications,
-- banque), le journal des hausses et la reecriture complete de la fiche. Copiee
-- caractere pour caractere depuis pg_proc : ne rien reformater, ne rien corriger.
CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_canon public.personnages_donnees%rowtype;
  v_role  text := coalesce(nullif(current_setting('role', true), ''), session_user);
  v_req   text := left(coalesce(current_query(), ''), 500);
  v_verrou boolean;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF auth.uid() IS NULL
       OR OLD.user_id IS NULL
       OR OLD.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_canon FROM public.personnages_donnees WHERE id = OLD.id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501';
    END IF;

    NEW.user_id := v_canon.user_id;

    IF coalesce(NEW.pa, 0) > coalesce(v_canon.pa, 0) THEN
      NEW.pa := v_canon.pa;
    END IF;

    NEW.stats             := v_canon.stats;
    NEW.free_pts_restants := v_canon.free_pts_restants;
    NEW.qualifications    := v_canon.qualifications;
    NEW.banque            := v_canon.banque;

    v_verrou := public.rp_transition_active('argent_verrou');

    IF coalesce(NEW.arg, 0) > coalesce(v_canon.arg, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'arg', v_canon.arg, NEW.arg, coalesce(NEW.arg,0) - coalesce(v_canon.arg,0), v_role, v_req);
      IF v_verrou THEN NEW.arg := v_canon.arg; END IF;
    END IF;
    IF coalesce(NEW.liquide, 0) > coalesce(v_canon.liquide, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'liquide', v_canon.liquide, NEW.liquide, coalesce(NEW.liquide,0) - coalesce(v_canon.liquide,0), v_role, v_req);
      IF v_verrou THEN NEW.liquide := v_canon.liquide; END IF;
    END IF;
    IF coalesce(NEW.hp, 0) > coalesce(v_canon.hp, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'hp', v_canon.hp, NEW.hp, coalesce(NEW.hp,0) - coalesce(v_canon.hp,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.day, 0) > coalesce(v_canon.day, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'day', v_canon.day, NEW.day, coalesce(NEW.day,0) - coalesce(v_canon.day,0), v_role, v_req);
    END IF;

    NEW.arg       := coalesce(NEW.arg,       v_canon.arg);
    NEW.liquide   := coalesce(NEW.liquide,   v_canon.liquide);
    NEW.inventory := coalesce(NEW.inventory, v_canon.inventory);
  END IF;

  UPDATE public.personnages_donnees SET
    name = NEW.name, country = NEW.country, photo_url = NEW.photo_url, bio = NEW.bio,
    archetype = NEW.archetype, career = NEW.career, origin = NEW.origin, school = NEW.school,
    free_pts_restants = NEW.free_pts_restants, stats = NEW.stats, resources = NEW.resources,
    arg = NEW.arg, liquide = NEW.liquide, banque = NEW.banque,
    hp = NEW.hp, pa = NEW.pa, moral = NEW.moral, poste = NEW.poste, poste_depute = NEW.poste_depute,
    current_city = NEW.current_city, current_building = NEW.current_building, current_room = NEW.current_room,
    inventory = NEW.inventory, informateurs = NEW.informateurs, contacts = NEW.contacts,
    historique_crimes = NEW.historique_crimes, enquetes_en_cours = NEW.enquetes_en_cours,
    domicile = NEW.domicile, employes = NEW.employes, escort_active = NEW.escort_active,
    locations_actives = NEW.locations_actives, poison_actif = NEW.poison_actif, day = NEW.day,
    recherche = NEW.recherche, reputation_criminelle = NEW.reputation_criminelle,
    salutations_du_jour = NEW.salutations_du_jour,
    invitation_sociale_en_attente = NEW.invitation_sociale_en_attente,
    convocations = NEW.convocations, est_emprisonne = NEW.est_emprisonne,
    detention_qhs = NEW.detention_qhs, hospitalisation = NEW.hospitalisation,
    stats_affaiblies = NEW.stats_affaiblies, regen_jour = NEW.regen_jour,
    requisition = NEW.requisition, demandeur_emploi = NEW.demandeur_emploi,
    carte_postale_moral_jour = NEW.carte_postale_moral_jour, motto = NEW.motto,
    licence_sportive = NEW.licence_sportive, performance_sportive = NEW.performance_sportive,
    blessure_sportive = NEW.blessure_sportive, signature_html = NEW.signature_html,
    signature_blocks = NEW.signature_blocks, quete_accueil = NEW.quete_accueil,
    enigme1 = NEW.enigme1, maxence = NEW.maxence, succes_maxence = NEW.succes_maxence,
    journal = NEW.journal, excommunie = NEW.excommunie, reservation_hotel = NEW.reservation_hotel,
    qualifications = NEW.qualifications, effets_actifs = NEW.effets_actifs,
    bonus_lobbyiste = NEW.bonus_lobbyiste, dernier_dormir = NEW.dernier_dormir,
    salaire_touche = NEW.salaire_touche, dernier_objet_trouve_jour = NEW.dernier_objet_trouve_jour,
    photo_pos = NEW.photo_pos, user_id = NEW.user_id, updated_at = NEW.updated_at,
    quete_carriere = NEW.quete_carriere
  WHERE id = OLD.id;
  RETURN NEW;
END;
$function$;


-- =====================================================================
-- REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE
-- =====================================================================
-- NEANT pour ce lot. La migration 20260920094956 ne contient AUCUN UPDATE sur
-- personnages_donnees ni aucun INSERT direct dans fiche_hausses_observees : les
-- seules ecritures dans fiche_hausses_observees sont celles que le trigger
-- ci-dessus emet a l'execution. Rien a recopier ici.
