-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913213136
-- Nom original      : chantier_c_phase3_assurer_existence_imprimerie
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 21:31:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b4edee15f79f0efd59cbb2c266c9025b
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
-- Les imprimeries rachetables passent par le meme chargement generique que les commerces. Leur
-- ligne 'entreprises' ne porte QUE l'identite de propriete : ni caisse ni stock (ils vivent dans
-- batiments_etat, sous-cle 'imprimerie' -- une seule source de verite, deja fermee en phase 2).
-- Elles sont donc creables sans risque economique, mais leur emplacement doit etre declare.
CREATE TABLE IF NOT EXISTS public.imprimeries_declarees (
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL,
  PRIMARY KEY (pays, ville, batiment));
ALTER TABLE public.imprimeries_declarees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "imprimeries lecture" ON public.imprimeries_declarees;
CREATE POLICY "imprimeries lecture" ON public.imprimeries_declarees FOR SELECT USING (true);
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.imprimeries_declarees FROM anon, authenticated;
GRANT SELECT ON public.imprimeries_declarees TO anon, authenticated;

DELETE FROM public.imprimeries_declarees;
INSERT INTO public.imprimeries_declarees (pays, ville, batiment) VALUES
  ('republic','capitale','la-tribune'),
  ('republic','ville_b','la-tribune'),
  ('republic','ville_a','imprimerie-librairie');

CREATE OR REPLACE FUNCTION public.entreprise_assurer_existence(
  p_id text, p_type text, p_pays text, p_ville text, p_batiment text, p_room text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_data jsonb; v_dot record; v_arm record; v_cle text; v_type_attendu text;
  v_id_attendu text; v_param jsonb; v_modifie boolean := false;
  v_k text; v_v jsonb;
BEGIN
  IF COALESCE(p_id,'') = '' OR COALESCE(p_pays,'') = '' OR COALESCE(p_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT public.est_appel_serveur()
     AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id FOR UPDATE;

  IF FOUND THEN
    IF COALESCE((v_data->>'version')::integer, 0) >= 2 THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;
    END IF;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;

    FOR v_v IN SELECT value FROM jsonb_array_elements(v_dot.carte) LOOP
      IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(v_v)) THEN
        v_data := jsonb_set(v_data, '{carte}', COALESCE(v_data->'carte','[]'::jsonb) || jsonb_build_array(v_v), true);
        v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.stock_matieres) LOOP
      IF NOT (COALESCE(v_data->'stockMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['stockMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.cout_moyen_matieres) LOOP
      IF NOT (COALESCE(v_data->'coutMoyenMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['coutMoyenMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    v_param := COALESCE(v_data->'parametres', '{}'::jsonb);
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'stockMax','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'stockMax','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['stockMax', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'prixVente','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'prixVente','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    IF v_modifie THEN
      v_data := jsonb_set(v_data, '{parametres}', v_param, true);
      UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_id;
    END IF;
    RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false, 'rattrapee', v_modifie);
  END IF;

  IF p_type = 'armurerie' THEN
    v_id_attendu := 'armurerie-' || p_pays || '-' || p_ville;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    SELECT * INTO v_arm FROM public.armureries_dotations WHERE pays = p_pays;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_inconnue');
    END IF;
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'armurerie', 'country', p_pays, 'city', p_ville,
      'buildingId', 'armurerie', 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisse', v_arm.caisse, 'stockMatieres', v_arm.stock_matieres,
      'coutMoyenMatieres', '{}'::jsonb, 'stockProduits', '{}'::jsonb,
      'carte', '[]'::jsonb, 'parametres', v_arm.parametres, 'historique', '[]'::jsonb);

  ELSIF p_type = 'imprimerie' THEN
    v_id_attendu := 'imprimerie-' || p_pays || '-' || p_ville || '-' || p_batiment;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.imprimeries_declarees
                    WHERE pays = p_pays AND ville = p_ville AND batiment = p_batiment) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'imprimerie_non_declaree');
    END IF;
    -- Identite de propriete SEULE : la caisse et le stock de bois vivent dans batiments_etat.
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'imprimerie', 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisseExterne', jsonb_build_object('table','batiments_etat','sousCle','imprimerie'),
      'historique', '[]'::jsonb);

  ELSE
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = p_batiment;
      v_cle := p_batiment;
    END IF;
    IF v_type_attendu IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'batiment_sans_commerce');
    END IF;
    IF p_type IS DISTINCT FROM v_type_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_non_conforme', 'attendu', v_type_attendu);
    END IF;
    v_id_attendu := p_type || '-' || p_pays || '-' || p_ville || '-' || p_batiment
                    || CASE WHEN COALESCE(p_room,'') <> '' THEN '-' || p_room ELSE '' END;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme', 'attendu', v_id_attendu);
    END IF;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    v_data := jsonb_build_object(
      'id', p_id, 'type', p_type, 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULLIF(COALESCE(p_room,''), ''),
      'proprietaire', 'PNJ',
      'caisse', COALESCE(v_dot.caisse, 0),
      'stockMatieres', COALESCE(v_dot.stock_matieres, '{}'::jsonb),
      'coutMoyenMatieres', COALESCE(v_dot.cout_moyen_matieres, '{}'::jsonb),
      'stockProduits', '{}'::jsonb,
      'carte', COALESCE(v_dot.carte, '[]'::jsonb),
      'parametres', COALESCE(v_dot.parametres, jsonb_build_object('prixVente','{}'::jsonb,'stockMax','{}'::jsonb)),
      'historique', '[]'::jsonb);
  END IF;

  INSERT INTO public.entreprises (id, data, updated_at) VALUES (p_id, v_data, now())
  ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', true);
END; $$;

REVOKE EXECUTE ON FUNCTION public.entreprise_assurer_existence(text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.entreprise_assurer_existence(text,text,text,text,text,text) TO authenticated, service_role;
