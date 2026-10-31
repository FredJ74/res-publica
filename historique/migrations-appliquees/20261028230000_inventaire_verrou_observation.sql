-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029210356.
-- Archivage documentaire seulement ; ne pas rejouer.
-- PREPAREE, NON APPLIQUEE (28/10/2026, Claude). A APPLIQUER APRES LA LIVRAISON DE LA PR #213.
-- ============================================================================
-- VERROU DE L'INVENTAIRE, ETAPE 1 : OBSERVER SANS RIEN REFUSER
-- ============================================================================
-- Depuis la PR #213, tout objet qui ENTRE dans un inventaire est depose par le serveur. La
-- sauvegarde de l'ecran (inventaire_sauver_revision) ne devrait donc plus que RETIRER : jeter,
-- consommer, utiliser, diminuer une pile. La regle du verrou : chaque objet envoye par l'ecran doit
-- correspondre a un objet deja possede, identique, ou dont seule la quantite (qty / quantite) a
-- baisse.
-- Etape 1 (ce fichier) : la regle est evaluee a chaque sauvegarde, et un ecart est INSCRIT dans
-- inventaire_ecarts_observes, sans rien refuser. Quelques jours de beta diront si un usage
-- legitime de l'ecran modifie encore un objet autrement (il faudra alors le passer au serveur).
-- Etape 2 (20261028230100, accord de Fred requis) : le meme ecart est refuse.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.inventaire_ecarts_observes (
  id bigserial PRIMARY KEY, acteur text NOT NULL, objet jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.inventaire_ecarts_observes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventaire_ecarts_observes FROM anon, authenticated;

-- Rend les objets de p_nouveau qui ne correspondent a aucun objet de p_ancien (correspondance un a
-- un ; seules qty et quantite peuvent avoir baisse, et rester positives).
CREATE OR REPLACE FUNCTION public.inventaire_ajouts_interdits(p_ancien jsonb, p_nouveau jsonb)
 RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pris boolean[]; v_anc jsonb[]; n jsonb; i integer; v_trouve boolean; v_hors jsonb := '[]'::jsonb;
BEGIN
  SELECT coalesce(array_agg(e ORDER BY o), ARRAY[]::jsonb[]) INTO v_anc
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_ancien) = 'array' THEN p_ancien ELSE '[]'::jsonb END) WITH ORDINALITY x(e, o);
  v_pris := array_fill(false, ARRAY[greatest(1, coalesce(array_length(v_anc, 1), 0))]);
  FOR n IN SELECT e FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_nouveau) = 'array' THEN p_nouveau ELSE '[]'::jsonb END) e LOOP
    v_trouve := false;
    FOR i IN 1..coalesce(array_length(v_anc, 1), 0) LOOP
      CONTINUE WHEN v_pris[i];
      IF (v_anc[i] - 'qty' - 'quantite') = (n - 'qty' - 'quantite')
         AND (NOT (n ? 'qty') OR (jsonb_typeof(n -> 'qty') = 'number' AND (n ->> 'qty')::numeric > 0
              AND (n ->> 'qty')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'qty') = 'number' THEN (v_anc[i] ->> 'qty')::numeric END, 1)))
         AND (NOT (n ? 'quantite') OR (jsonb_typeof(n -> 'quantite') = 'number' AND (n ->> 'quantite')::numeric > 0
              AND (n ->> 'quantite')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'quantite') = 'number' THEN (v_anc[i] ->> 'quantite')::numeric END, 0)))
      THEN v_pris[i] := true; v_trouve := true; EXIT; END IF;
    END LOOP;
    IF NOT v_trouve THEN v_hors := v_hors || jsonb_build_array(n); END IF;
  END LOOP;
  RETURN v_hors;
END; $function$;
REVOKE ALL ON FUNCTION public.inventaire_ajouts_interdits(jsonb, jsonb) FROM PUBLIC, anon, authenticated;

DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.inventaire_sauver_revision(text,bigint,jsonb)'::regprocedure);
  IF position('inventaire_ecarts_observes' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur\n',
      E'    -- VERROU, ETAPE 1 (observation) : un objet qui n''etait pas deja possede est inscrit.\n'
      || E'    INSERT INTO public.inventaire_ecarts_observes (acteur, objet)\n'
      || E'    SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;\n'
      || E'    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur\n');
    IF position('inventaire_ecarts_observes' IN v_def) = 0 THEN RAISE EXCEPTION 'inventaire_sauver_revision : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
