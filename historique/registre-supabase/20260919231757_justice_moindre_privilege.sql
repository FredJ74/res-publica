-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919231757
-- Nom original      : justice_moindre_privilege
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 23:17:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 815d5195f9886f392b19890867ca8478
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
-- =====================================================================
-- §6 — JUSTICE : FERMETURE DES FUITES TECHNIQUES
-- =====================================================================
-- DECISION GD RAPPELEE : il n'existe AUCUNE mecanique publique donnant a un
-- joueur ordinaire la liste des personnes recherchees ou detenues. L'exposition
-- actuelle a `anon` est donc une fuite, pas un registre voulu. On ne cree pas de
-- registre public ; on rend a chaque fonction la portee que sa mecanique a deja.
--
-- geoles_detenus : sa vraie mecanique est l'AFFICHAGE D'UNE SALLE. Le client ne
--   l'appelle que lorsque le joueur ENTRE dans les geoles (plateau-navigation.js
--   :800, salle 'prison' du commissariat de Luthecia ou 'geoles' du
--   commissariat-local). Voir qui est en cellule quand on est dans la piece est
--   une observation de jeu ; lire la liste depuis l'exterieur n'en est pas une.
--   La regle devient donc la PRESENCE REELLE, relue en base -- jamais un
--   parametre du client. C'est la meme position canonique que le chantier des
--   presences vient de securiser.
--
-- justice_recherches : sa mecanique est la chasse a l'homme, deja reservee au
--   commissaire (data.js:2787, requiresPost:'commissaire'). On porte cette
--   exigence cote serveur, en y ajoutant les autorites judiciaires superieures
--   et le cas ou l'on s'interroge sur SOI-MEME (un joueur a le droit de savoir
--   qu'il est recherche : c'est deja ce que son propre dossier lui montre).

CREATE OR REPLACE FUNCTION public.geoles_detenus(p_pays text, p_ville text)
RETURNS TABLE(nom text, photo_url text, qhs boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_salle text;
BEGIN
  IF public.est_appel_serveur() THEN
    RETURN QUERY
      SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
             coalesce(d.qhs, false)
        FROM public.detentions d
       WHERE d.country = p_pays AND d.city = p_ville
         AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
       ORDER BY d.created_at DESC;
    RETURN;
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_salle
    FROM public.personnages_donnees WHERE name = v_moi;

  -- Il faut etre reellement dans la salle des geoles du lieu demande.
  IF v_pays IS DISTINCT FROM p_pays OR v_ville IS DISTINCT FROM p_ville
     OR NOT ( (v_bat = 'commissariat'       AND v_salle = 'prison')
           OR (v_bat = 'commissariat-local' AND v_salle = 'geoles') ) THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
           coalesce(d.qhs, false)
      FROM public.detentions d
     WHERE d.country = p_pays AND d.city = p_ville
       AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
     ORDER BY d.created_at DESC;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_moi text; v_autorise boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN
    v_autorise := true;
  ELSE
    v_moi := public.mon_personnage();
    IF v_moi IS NOT NULL THEN
      -- Soi-meme : un joueur peut savoir qu'il est recherche.
      IF v_moi = p_nom THEN
        v_autorise := true;
      ELSE
        -- Autorite judiciaire, dans son propre pays.
        SELECT true INTO v_autorise
          FROM public.acteur_poste_courant() a
          JOIN public.personnages_donnees c ON c.name = p_nom
         WHERE a.poste_id IN ('commissaire','juge','min_just','min_int','president')
           AND a.pays = c.country
         LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF NOT coalesce(v_autorise, false) THEN RETURN; END IF;

  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           coalesce((SELECT sum((m->>'jours')::int)
                       FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
           j.data
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$fn$;

-- anon n'a aucune mecanique judiciaire : il perd l'acces aux deux.
REVOKE EXECUTE ON FUNCTION public.geoles_detenus(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.justice_recherches(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.geoles_detenus(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO authenticated, service_role;