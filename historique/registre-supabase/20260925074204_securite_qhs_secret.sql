-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925074204
-- Nom original      : securite_qhs_secret
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:42:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 96bfbf97aedab33d50d48de183f3f6e7
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
-- =============================================================================================
-- LE PLACEMENT AU QHS EST SECRET (25 septembre 2026) — arbitrage GD rendu
-- =============================================================================================
-- REGLE : l'identite des detenus du QHS n'est accessible qu'au Ministre de la Justice, au
-- Ministre de l'Interieur et au personnel du QHS. Se trouver physiquement a l'entree du QHS ne
-- donne AUCUN droit sur cette liste. Le detenu, lui, sait evidemment ou il est.
--
-- CE QUI ETAIT OUVERT :
--   1. `prisonniers_qhs` portait une policy SELECT `USING(true)` pour anon ET authenticated : le
--      registre nominatif complet (nom, motif, photo) etait lisible par n'importe qui, sans compte.
--   2. `detentions.qhs` etait affiche dans les ARCHIVES JUDICIAIRES PUBLIQUES -- l'ordre
--      `archives_police` se decrit lui-meme comme « consultables par tous » et marquait « (QHS) »
--      en rouge a cote du nom. C'est exactement ce que l'arbitrage interdit.
--   3. `geoles_detenus()` rendait le drapeau qhs a tout joueur present dans la salle des geoles.
--
-- « PERSONNEL DU QHS » N'A AUCUN TITULAIRE JOUEUR : directeur_qhs et gardien_qhs n'existent que
-- comme `job:` de PNJ (Dominique Cruel, Philippe Cognedur...), ni dans POSTES_ELECTIFS ni dans
-- POSTES_NOMMES_EXCLUSIFS. La categorie est donc reconnue par la regle mais sans porteur
-- attribuable aujourd'hui : seuls min_just et min_int sont effectivement habilites.
--
-- L'ECRITURE N'EST PAS TOUCHEE : elle etait deja bornee a `(data->>'nom') = mon_personnage()`.

-- ---------------------------------------------------------------- 1. le registre du QHS
DROP POLICY IF EXISTS "prisonniers_qhs_lecture" ON public.prisonniers_qhs;

CREATE POLICY "qhs registre reserve aux habilites et au detenu" ON public.prisonniers_qhs
  FOR SELECT TO authenticated
  USING (
       public.mon_poste_est_dans('min_just', data ->> 'pays')
    OR public.mon_poste_est_dans('min_int',  data ->> 'pays')
    OR (data ->> 'nom') = (SELECT public.mon_personnage())
  );

REVOKE ALL ON public.prisonniers_qhs FROM anon;

-- ---------------------------------------------------------------- 2. le drapeau QHS des detentions
-- Les archives judiciaires restent publiques -- c'est voulu, l'ordre le dit. Seule la colonne qhs
-- sort de portee. Un retrait au niveau COLONNE, pas au niveau ligne : la detention reste lisible,
-- son caractere QHS ne l'est plus. Le client nomme desormais ses colonnes explicitement.
REVOKE SELECT (qhs) ON public.detentions FROM anon, authenticated;

-- ---------------------------------------------------------------- 3. la salle des geoles
-- Meme fonction, meme signature, meme parcours : elle continue d'exiger d'etre physiquement dans
-- la salle des geoles du lieu demande. Seul le drapeau qhs cesse d'etre revele au joueur ; le
-- serveur (est_appel_serveur) continue de le recevoir, le cron en depend.
CREATE OR REPLACE FUNCTION public.geoles_detenus(p_pays text, p_ville text)
 RETURNS TABLE(nom text, photo_url text, qhs boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

  IF v_pays IS DISTINCT FROM p_pays OR v_ville IS DISTINCT FROM p_ville
     OR NOT ( (v_bat = 'commissariat'       AND v_salle = 'prison')
           OR (v_bat = 'commissariat-local' AND v_salle = 'geoles') ) THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
           -- SECRET DU QHS : jamais revele a un joueur, quel que soit l'endroit ou il se tient.
           false
      FROM public.detentions d
     WHERE d.country = p_pays AND d.city = p_ville
       AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
     ORDER BY d.created_at DESC;
END;
$function$;