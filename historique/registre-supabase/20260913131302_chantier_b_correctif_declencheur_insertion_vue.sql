-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913131302
-- Nom original      : chantier_b_correctif_declencheur_insertion_vue
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:13:02 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 493fd236d276a31a42e737ed0fd1aba4
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
-- CORRECTIF. Le declencheur d'insertion faisait « INSERT ... VALUES (NEW.*) »,
-- c'est-a-dire une insertion POSITIONNELLE : elle supposait que la vue enumere
-- ses colonnes dans l'ordre exact de la table, ce qui n'etait pas le cas. Les
-- valeurs se decalaient et Postgres refusait (42804, « stats est de type jsonb
-- mais l'expression est de type text »). On nomme donc chaque colonne.
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

  INSERT INTO public.personnages_donnees (
    id, name, country, photo_url, bio, archetype, career, origin, school,
    free_pts_restants, stats, resources, arg, liquide, banque, hp, pa, moral,
    poste, poste_depute, current_city, current_building, current_room, inventory,
    informateurs, contacts, historique_crimes, enquetes_en_cours, domicile,
    employes, escort_active, locations_actives, poison_actif, day, recherche,
    reputation_criminelle, salutations_du_jour, invitation_sociale_en_attente,
    convocations, est_emprisonne, detention_qhs, hospitalisation, stats_affaiblies,
    regen_jour, requisition, demandeur_emploi, carte_postale_moral_jour, motto,
    licence_sportive, performance_sportive, blessure_sportive, signature_html,
    signature_blocks, quete_accueil, enigme1, maxence, succes_maxence, journal,
    excommunie, reservation_hotel, qualifications, effets_actifs, bonus_lobbyiste,
    dernier_dormir, salaire_touche, dernier_objet_trouve_jour, photo_pos,
    user_id, created_at, updated_at
  ) VALUES (
    coalesce(NEW.id, gen_random_uuid()), NEW.name, NEW.country, NEW.photo_url, NEW.bio,
    NEW.archetype, NEW.career, NEW.origin, NEW.school,
    coalesce(NEW.free_pts_restants, 0), NEW.stats, NEW.resources, NEW.arg, NEW.liquide,
    NEW.banque, NEW.hp, NEW.pa, NEW.moral, NEW.poste, NEW.poste_depute,
    NEW.current_city, NEW.current_building, NEW.current_room, NEW.inventory,
    NEW.informateurs, NEW.contacts, NEW.historique_crimes, NEW.enquetes_en_cours, NEW.domicile,
    NEW.employes, NEW.escort_active, NEW.locations_actives, NEW.poison_actif, NEW.day,
    NEW.recherche, NEW.reputation_criminelle, NEW.salutations_du_jour,
    NEW.invitation_sociale_en_attente, NEW.convocations, NEW.est_emprisonne,
    NEW.detention_qhs, NEW.hospitalisation, coalesce(NEW.stats_affaiblies, '{}'::jsonb),
    NEW.regen_jour, NEW.requisition, coalesce(NEW.demandeur_emploi, false),
    NEW.carte_postale_moral_jour, NEW.motto, NEW.licence_sportive, NEW.performance_sportive,
    NEW.blessure_sportive, NEW.signature_html, NEW.signature_blocks, NEW.quete_accueil,
    NEW.enigme1, NEW.maxence, NEW.succes_maxence, NEW.journal, NEW.excommunie,
    NEW.reservation_hotel, coalesce(NEW.qualifications, '[]'::jsonb),
    coalesce(NEW.effets_actifs, '[]'::jsonb), coalesce(NEW.bonus_lobbyiste, 0),
    NEW.dernier_dormir, NEW.salaire_touche, NEW.dernier_objet_trouve_jour, NEW.photo_pos,
    NEW.user_id, coalesce(NEW.created_at, now()), coalesce(NEW.updated_at, now())
  );
  RETURN NEW;
END; $$;