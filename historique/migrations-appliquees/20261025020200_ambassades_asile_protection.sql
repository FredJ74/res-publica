-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025005227.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025005227.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- ASILE POLITIQUE -- 3/3 : un refugie present au Quartier des Ambassades ne peut pas etre
-- arrete (decision de Fred, 25/10/2026). Des qu'il en sort, il redevient arretable.
-- ============================================================================
-- TROIS POINTS, du plus courant au filet de securite :
--   1. police_detection_verifier : la police ne detecte pas un refugie protege -- pas
--      d'interception, donc pas de tentative d'arrestation. Refus NOMME 'refugie_protege'.
--   2. detention_ouvrir_interne, porte unique d'ouverture des detentions : elle refuse
--      l'arrestation d'un refugie protege, avec le meme motif nomme, comme elle refuse deja
--      une cible introuvable ou deja detenue -- ses appelants savent lire ce refus.
--   3. Un declencheur sur personnages_donnees refuse toute ecriture d'une detention pour un
--      refugie protege, par quelque chemin que ce soit (filet : il ne doit jamais servir).
--
-- PATCH EN PLACE, JAMAIS RETAPE (WORKFLOW-SUPABASE.md) : les deux fonctions existantes ne
-- recoivent qu'une ligne, inseree apres un fragment exact. Un fragment introuvable fait
-- echouer la migration bruyamment ; un fragment deja patche est reconnu et laisse tel quel.
-- Depend de 20261025020000_ambassades_asile.sql. Idempotente. Aucun acte de joueur.
-- ============================================================================

DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  SELECT coalesce(d.day,1), d.est_emprisonne INTO v_jour_cible, v_deja\n    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;\n';
  v_ajout text := E'  -- Asile politique (25/10/2026) : un refugie au Quartier des Ambassades n''est pas arretable.\n  IF FOUND AND public.ambassade_refugie_protege(p_nom) THEN\n    RETURN jsonb_build_object(''ok'',false,''raison'',''refugie_protege'');\n  END IF;\n';
BEGIN
  v_def := pg_get_functiondef('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure);
  IF position('ambassade_refugie_protege' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_frag || v_ajout);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique : fragment de detention_ouvrir_interne introuvable';
  END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E' IF NOT EXISTS(SELECT 1 FROM public.justice_recherches(v_nom) r WHERE r.country=v_pj.country) THEN\n RETURN jsonb_build_object(''ok'',false,''raison'',''non_recherche''); END IF;\n';
  v_ajout text := E' -- Asile politique (25/10/2026) : la police ne detecte pas un refugie au Quartier des Ambassades.\n IF public.ambassade_refugie_protege(v_nom) THEN\n RETURN jsonb_build_object(''ok'',false,''raison'',''refugie_protege''); END IF;\n';
BEGIN
  v_def := pg_get_functiondef('public.police_detection_verifier(text,text,text)'::regprocedure);
  IF position('ambassade_refugie_protege' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_frag || v_ajout);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique : fragment de police_detection_verifier introuvable';
  END IF;
  EXECUTE v_new;
END $mig$;

-- LE FILET : aucune detention ne s'ecrit sur un refugie protege, quel que soit le chemin.
CREATE OR REPLACE FUNCTION public.personnages_proteger_refugie()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.est_emprisonne IS NOT NULL AND NEW.est_emprisonne <> 'null'::jsonb
     AND (OLD.est_emprisonne IS NULL OR OLD.est_emprisonne = 'null'::jsonb)
     AND NEW.current_building = 'quartier-ambassades'
     AND public.ambassade_refuge_de(NEW.name) IS NOT NULL THEN
    RAISE EXCEPTION 'refugie_protege: % beneficie de l''asile politique au Quartier des Ambassades', NEW.name
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END; $function$;
REVOKE ALL ON FUNCTION public.personnages_proteger_refugie() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_personnages_proteger_refugie ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_proteger_refugie
  BEFORE UPDATE OF est_emprisonne ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_proteger_refugie();
