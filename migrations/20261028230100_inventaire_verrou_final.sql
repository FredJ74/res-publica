-- PREPAREE, NON APPLIQUEE (28/10/2026, Claude). ACCORD DE FRED REQUIS, APRES QUELQUES JOURS
-- D'OBSERVATION SANS ECART LEGITIME (20261028230000, table inventaire_ecarts_observes).
-- ============================================================================
-- VERROU DE L'INVENTAIRE, ETAPE 2 : REFUSER
-- ============================================================================
-- La sauvegarde de l'ecran ne peut plus que retirer des objets ou diminuer une pile. Un objet
-- ajoute, ou modifie autrement, est refuse (« objet_non_possede ») : l'ecran recharge alors
-- l'inventaire du serveur, comme pour toute revision perimee.
-- ============================================================================
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.inventaire_sauver_revision(text,bigint,jsonb)'::regprocedure);
  IF position('objet_non_possede' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    INSERT INTO public.inventaire_ecarts_observes (acteur, objet)\n'
      || E'    SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;\n',
      E'    IF jsonb_array_length(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) > 0 THEN\n'
      || E'      INSERT INTO public.inventaire_ecarts_observes (acteur, objet)\n'
      || E'      SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;\n'
      || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''objet_non_possede'',''revision'',v.inventory_revision);\n'
      || E'    END IF;\n');
    IF position('objet_non_possede' IN v_def) = 0 THEN RAISE EXCEPTION 'inventaire_sauver_revision : etape 1 absente'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
