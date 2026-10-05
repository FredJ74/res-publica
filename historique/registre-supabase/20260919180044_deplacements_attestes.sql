-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919180044
-- Nom original      : deplacements_attestes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 18:00:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : aa5cba32667aa0614e8815ff6b2b1a4d
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
-- historique_deplacements : fermeture du chemin minimal AVANT qu'il ne devienne
-- une source de renseignement pour le Coordinateur.
--
-- DEUX DEFAUTS MESURES A L'AUDIT :
--   1. RLS desactivee et anon en ecriture : n'importe qui pouvait forger le
--      deplacement de n'importe qui, ou en effacer.
--   2. Ce n'etait pas un journal de deplacements mais un BATTEMENT DE PRESENCE :
--      setInterval de 30 s, et 98,0 % des 9 541 lignes etaient la repetition
--      exacte de la precedente. 96 changements reels de batiment au total.
--      Compter les lignes revenait a compter des minutes de stationnement.
--
-- CE QUI EST FERME : l'ecriture directe, pour tout le monde. Elle passe
-- desormais par cette RPC, qui
--   * derive le PERSONNAGE de mon_personnage() -- on ne peut plus ecrire le
--     deplacement d'autrui ;
--   * derive le PAYS et le JOUR de personnages_donnees -- cela corrige au
--     passage les couples (pays, batiment) incoherents observes, ou le
--     battement tombait entre le changement de pays et celui de batiment ;
--   * N'INSERE QUE SI LA POSITION A REELLEMENT CHANGE. Les battements
--     disparaissent : une ligne = un passage.
--
-- LIMITE ASSUMEE ET DOCUMENTEE : la position reste DECLAREE par le client,
-- comme pour presences -- personnages_donnees n'est pas mis a jour de facon
-- synchrone au changement de piece (l'autosave est debounce), la deriver ici
-- enregistrerait donc la piece precedente. Le niveau de confiance est
-- exactement celui de presences, et il est tres superieur a l'etat anterieur
-- ou l'identite elle-meme etait forgeable.
--
-- SELECT est laisse INCHANGE : decider qui peut lire les deplacements d'autrui
-- releve du brouillard d'information, et n'est pas tranche ici.

ALTER TABLE public.historique_deplacements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "deplacements lecture" ON public.historique_deplacements;
CREATE POLICY "deplacements lecture" ON public.historique_deplacements
  FOR SELECT TO authenticated, anon USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.historique_deplacements FROM PUBLIC, anon, authenticated;
GRANT  SELECT                  ON public.historique_deplacements TO authenticated, anon;

-- Index indispensables des que la synthese quotidienne existe : l'audit avait
-- mesure un Seq Scan (9 542 lignes ecartees pour en retenir 1) faute d'index
-- autre que la cle primaire.
CREATE INDEX IF NOT EXISTS idx_deplacements_lieu
  ON public.historique_deplacements (country, city, building_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deplacements_personne
  ON public.historique_deplacements (name, created_at DESC);

CREATE OR REPLACE FUNCTION public.deplacement_enregistrer(
  p_city text, p_building text, p_room text, p_heure text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_building IS NULL OR p_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_incomplete'); END IF;

  SELECT coalesce(country, 'republic'), coalesce(day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- Dedoublonnage : un battement au meme endroit n'ecrit RIEN.
  SELECT h.city, h.building_id, h.room_id INTO d
    FROM public.historique_deplacements h
   WHERE h.name = v_moi ORDER BY h.created_at DESC LIMIT 1;
  IF FOUND AND d.city IS NOT DISTINCT FROM p_city
           AND d.building_id IS NOT DISTINCT FROM p_building
           AND d.room_id IS NOT DISTINCT FROM p_room THEN
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'position_inchangee');
  END IF;

  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (v_moi, v_pays, p_city, p_building, p_room, v_jour, p_heure);
  RETURN jsonb_build_object('ok', true, 'enregistre', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.deplacement_enregistrer(text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deplacement_enregistrer(text,text,text,text) TO authenticated, service_role;
