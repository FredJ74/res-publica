-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913131157
-- Nom original      : chantier_b_masquage_donnees_privees_personnages
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:11:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 18fda5ceda543cf52f3c61f7f868b179
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ============================================================================
-- CHANTIER B — LES DONNEES PRIVEES D'UN JOUEUR NE SONT PLUS PUBLIQUES
-- 13 septembre 2026.
-- ============================================================================
-- LE PROBLEME. RLS est ROW-level : il sait cacher des lignes, pas des colonnes.
-- Or le jeu a besoin que la ligne d'autrui reste lisible -- repertoire, presences
-- en salle, elections, forum, geoles s'en nourrissent : 81 lectures clientes
-- portent sur personnages, dont 4 seulement sur soi-meme. Fermer la table
-- casserait le jeu ; la laisser ouverte publie la fortune et l'inventaire de
-- chacun, ce qui vide de son sens le systeme de renseignements, dont tout le
-- propos est justement de faire payer ce genre d'information.
--
-- LA SOLUTION, SANS TOUCHER UNE LIGNE DU CLIENT. La table passe en
-- personnages_donnees, fermee a anon et authenticated. Une VUE reprend son nom :
-- PostgREST continue de servir /rest/v1/personnages exactement comme avant, mais
-- les colonnes privees n'y sont visibles que par leur proprietaire.
--
-- PERIMETRE VOLONTAIREMENT ETROIT : arg, liquide, banque, inventory. Ce sont les
-- quatre qui sont sans ambiguite prives. Tout le reste -- poste, ville, detention,
-- recherche, domicile, statistiques -- reste visible, parce que le jeu s'en sert
-- reellement a propos d'autrui et qu'un masquage trop large casserait en silence
-- des ecrans que je ne peux pas tester un par un.
--
-- LE PIEGE EVITE. Le serveur (cron, endpoints /api/*) n'a pas d'auth.uid() : sans
-- precaution, le masquage l'aurait vu comme un tiers, et sa prochaine ecriture
-- aurait REMPLACE PAR NULL l'argent et l'inventaire de tout le monde. D'ou
-- est_appel_serveur() dans chaque condition de masquage ET dans le declencheur.

ALTER TABLE public.personnages RENAME TO personnages_donnees;

-- Plus personne n'atteint la table directement : sans ca, il suffirait
-- d'interroger /rest/v1/personnages_donnees pour contourner la vue.
REVOKE ALL ON TABLE public.personnages_donnees FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE VIEW public.personnages AS
SELECT
  d.id, d.name, d.country, d.photo_url, d.bio, d.archetype, d.career, d.origin, d.school,
  d.free_pts_restants, d.stats, d.resources,
  CASE WHEN d.user_id = auth.uid() OR public.est_appel_serveur() THEN d.arg     END AS arg,
  CASE WHEN d.user_id = auth.uid() OR public.est_appel_serveur() THEN d.liquide END AS liquide,
  CASE WHEN d.user_id = auth.uid() OR public.est_appel_serveur() THEN d.banque  END AS banque,
  d.hp, d.pa, d.moral, d.poste, d.poste_depute,
  d.current_city, d.current_building, d.current_room,
  CASE WHEN d.user_id = auth.uid() OR public.est_appel_serveur() THEN d.inventory END AS inventory,
  d.informateurs, d.contacts, d.historique_crimes, d.enquetes_en_cours, d.domicile,
  d.employes, d.escort_active, d.locations_actives, d.poison_actif, d.day, d.recherche,
  d.reputation_criminelle, d.salutations_du_jour, d.invitation_sociale_en_attente,
  d.convocations, d.est_emprisonne, d.detention_qhs, d.hospitalisation, d.stats_affaiblies,
  d.regen_jour, d.requisition, d.demandeur_emploi, d.carte_postale_moral_jour, d.motto,
  d.licence_sportive, d.performance_sportive, d.blessure_sportive, d.signature_html,
  d.signature_blocks, d.quete_accueil, d.enigme1, d.maxence, d.succes_maxence, d.journal,
  d.excommunie, d.reservation_hotel, d.qualifications, d.effets_actifs, d.bonus_lobbyiste,
  d.dernier_dormir, d.salaire_touche, d.dernier_objet_trouve_jour, d.photo_pos,
  d.user_id, d.created_at, d.updated_at
FROM public.personnages_donnees d;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.personnages TO anon, authenticated;

-- --- Ecritures : la vue n'est pas auto-modifiable (expressions CASE), on pose
-- --- donc des declencheurs INSTEAD OF qui portent AUSSI le controle de propriete.
CREATE OR REPLACE FUNCTION public.personnages_vue_inserer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'creation_sans_compte' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
  END IF;
  INSERT INTO public.personnages_donnees VALUES (NEW.*);
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := OLD.user_id;   -- un personnage ne change pas de proprietaire
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
    photo_pos = NEW.photo_pos, user_id = NEW.user_id, updated_at = NEW.updated_at
  WHERE id = OLD.id;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.personnages_vue_supprimer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
  END IF;
  DELETE FROM public.personnages_donnees WHERE id = OLD.id;
  RETURN OLD;
END; $$;

CREATE TRIGGER trg_personnages_vue_inserer  INSTEAD OF INSERT ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_vue_inserer();
CREATE TRIGGER trg_personnages_vue_modifier INSTEAD OF UPDATE ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_vue_modifier();
CREATE TRIGGER trg_personnages_vue_supprimer INSTEAD OF DELETE ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_vue_supprimer();