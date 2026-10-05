-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205133
-- Nom original      : entrepots_capacite_et_desiderata
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 20:51:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 362b7eb151dd251e136e75fb380f6ebb
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
-- CAPACITE DISPONIBLE POUR UNE ENTREE PLANIFIEE.
-- capacite = 5000 - stock reel - tout ce qui est deja en route vers cet entrepot.
-- Sans le transit, deux commandes passees le meme jour pourraient chacune "tenir" isolement et
-- faire deborder l'entrepot a la livraison.
CREATE OR REPLACE FUNCTION public.entrepot_capacite_disponible(p_entrepot_id text, p_ressource text)
RETURNS integer LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT greatest(0, public.capacite_entrepot()
    - coalesce((SELECT (public.batiment_etat_lire(data)->'entrepot'->'stock'->>p_ressource)::numeric
                  FROM public.batiments_etat WHERE id = p_entrepot_id), 0)
    - coalesce((SELECT sum(quantite) FROM public.entrepot_transits
                 WHERE destination_id = p_entrepot_id AND ressource = p_ressource), 0))::int;
$$;

-- L'ENTREPOT DU DIRECTEUR. Le poste est local (scope ville) : on resout toujours le batiment
-- depuis la ligne du personnage, jamais depuis un parametre client.
CREATE OR REPLACE FUNCTION public.entrepot_du_directeur(p_acteur text)
RETURNS TABLE (entrepot_id text, ville text, batiment text)
LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT 'republic_' || e.ville || '_' || e.building_id, e.ville, e.building_id
    FROM public.personnages_donnees p
    JOIN public.entrepots_par_ville e ON e.ville = p.poste->>'city'
   WHERE p.name = p_acteur AND p.poste->>'id' = 'directeur_entrepot';
$$;

-- DESIDERATAS : stock cible par ressource, 0 a 5 000.
-- 0 = aucun reapprovisionnement automatique de cette ressource (le stock deja present reste).
-- Ranges dans le blob de l'etablissement, avec le nom du directeur qui les a poses : c'est ce
-- qui permet au cron de les abandonner automatiquement quand il change de titulaire, sans
-- qu'aucun hook de depart n'ait a exister.
CREATE OR REPLACE FUNCTION public.entrepot_fixer_desiderata(p_acteur text, p_desiderata jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_id text; v_etat jsonb; v_ent jsonb; v_d jsonb := '{}'::jsonb;
        v_cle text; v_val numeric; v_cap integer := public.capacite_entrepot();
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT entrepot_id INTO v_id FROM public.entrepot_du_directeur(p_acteur);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_desiderata IS NULL OR jsonb_typeof(p_desiderata) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_absents');
  END IF;

  -- Validation AVANT toute ecriture : une seule valeur invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(p_desiderata) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR NOT (v_val = v_val) OR v_val < 0 OR v_val > v_cap OR v_val <> floor(v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_invalide', 'cle', v_cle,
                                'min', 0, 'max', v_cap);
    END IF;
    v_d := jsonb_set(v_d, ARRAY[v_cle], to_jsonb(v_val::int));
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_ent || jsonb_build_object('desiderata', v_d, 'desiderataPar', p_acteur)))::text),
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'desiderata', v_d, 'entrepot', v_id);
END; $$;

REVOKE ALL ON FUNCTION public.entrepot_capacite_disponible(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.entrepot_du_directeur(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.entrepot_fixer_desiderata(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entrepot_capacite_disponible(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.entrepot_du_directeur(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.entrepot_fixer_desiderata(text, jsonb) TO authenticated;
