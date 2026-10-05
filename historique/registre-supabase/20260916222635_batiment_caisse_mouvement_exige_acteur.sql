-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916222635
-- Nom original      : batiment_caisse_mouvement_exige_acteur
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-16 22:26:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d70acc5ec65c9c339145c78e3928dd1e
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
-- Audit des frontieres d'autorite, 17 septembre 2026. PROUVE avant correctif, en transaction
-- annulee, sous le seul role anon (aucune session, simple cle publique) :
--   batiment_caisse_mouvement('republic','capitale','la-tribune','imprimerie',50000000,'stockBois',9999)
--   a porte la caisse de l'imprimerie de 178 a 50 000 178 et son stock de bois de 4 a 10 003 ;
--   et un batiment inexistant 'zzpays_zzville_zzbatiment' a ete cree avec 77 777 777 en caisse.
-- Le role anon n'a aucun usage legitime : personnages_donnees n'accorde INSERT/UPDATE qu'a
-- authenticated, donc un client en role anon ne peut pas sauvegarder de personnage, donc pas jouer.
-- Valeurs par defaut des parametres conservees a l'identique.
CREATE OR REPLACE FUNCTION public.batiment_caisse_mouvement(
  p_pays text, p_ville text, p_building text, p_souscle text, p_delta numeric,
  p_stock_cle text DEFAULT NULL::text, p_stock numeric DEFAULT 0,
  p_stock_max numeric DEFAULT NULL::numeric, p_exiger_existant boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_id text; v_brut jsonb; v_d jsonb; v_obj jsonb; v_caisse numeric; v_st numeric; v_existe boolean;
BEGIN
  -- ATTRIBUTION OBLIGATOIRE : soit le serveur (cron, service_role), soit un compte portant
  -- reellement un personnage. Ne dit rien de l'AUTORITE sur le montant : voir le chantier
  -- caisse_institution_mouvement, laisse ouvert.
  IF NOT public.est_appel_serveur() AND public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_ville), '') = ''
     OR COALESCE(btrim(p_building), '') = '' OR COALESCE(btrim(p_souscle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta IS NULL OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_id := p_pays || '_' || p_ville || '_' || p_building;
  SELECT data INTO v_brut FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_existe := FOUND;

  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_brut) = 'string' THEN (v_brut #>> '{}')::jsonb
              WHEN jsonb_typeof(v_brut) = 'object' THEN v_brut
              ELSE '{}'::jsonb END;

  IF p_exiger_existant AND jsonb_typeof(v_d -> p_souscle) IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_obj := CASE WHEN jsonb_typeof(v_d -> p_souscle) = 'object' THEN v_d -> p_souscle ELSE '{}'::jsonb END;
  v_caisse := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;

  IF v_caisse + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  v_obj := v_obj || jsonb_build_object('caisse', v_caisse + p_delta);

  IF p_stock_cle IS NOT NULL AND COALESCE(p_stock, 0) <> 0 THEN
    v_st := CASE WHEN jsonb_typeof(v_obj -> p_stock_cle) = 'number' THEN (v_obj ->> p_stock_cle)::numeric ELSE 0 END;
    IF v_st + p_stock < 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_st, 'caisse', v_caisse);
    END IF;
    IF p_stock_max IS NOT NULL AND v_st + p_stock > p_stock_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plafond', 'stock', v_st,
                                'stock_max', p_stock_max, 'caisse', v_caisse);
    END IF;
    v_obj := v_obj || jsonb_build_object(p_stock_cle, v_st + p_stock);
  END IF;

  v_d := v_d || jsonb_build_object(p_souscle, v_obj);

  IF v_existe THEN
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  ELSE
    INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
    VALUES (v_id, p_pays, p_ville, p_building, to_jsonb(v_d::text), now());
  END IF;

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse + p_delta,
                            'stock', CASE WHEN p_stock_cle IS NULL THEN NULL ELSE v_obj -> p_stock_cle END);
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean) FROM anon;