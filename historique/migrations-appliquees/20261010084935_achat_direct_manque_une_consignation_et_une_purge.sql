-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010084935 (UTC), nom `achat_direct_manque_une_consignation_et_une_purge`.
-- Le registre passe de 601 a 602 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4b025686d52678b7a953b4896fcf54bf, 5843 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5/6 : LE RENDEZ-VOUS NOTARIAL MANQUE
--
-- `nettoyerAchatsDirectsManques` (api/cron-minuit.js) etait le SECOND ecrivain de
-- `compromis_historique`, avec un `Date.now()` dans l'identifiant, un INSERT avale et aucune
-- verification. La porte fait de la consignation de la perte et de la purge du rendez-vous une
-- seule transaction sous verrou du terrain, avec un identifiant date. Aucune regle de jeu modifiee.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5/6 -- LE RENDEZ-VOUS NOTARIAL MANQUE (10 octobre 2026)
--
-- DEFAUT TROUVE EN POSANT LA CONTRAINTE UNIQUE DU §5, ET QU'AUCUN DES DEUX INVENTAIRES NE
-- NOMMAIT. `nettoyerAchatsDirectsManques` (api/cron-minuit.js) est le SECOND ecrivain de
-- `compromis_historique`, et il porte trois defauts :
--
--   1. UN `Date.now()` DANS L'IDENTIFIANT : `'achatdirect-' + row.id + '-' + Date.now()`. Deux
--      passes la meme nuit ecrivent DEUX lignes d'historique pour le meme depot perdu. C'est
--      exactement le defaut que la migration 575 avait ferme sur l'autre ecrivain, et qui
--      n'avait pas ete propage jusqu'ici.
--   2. SON INSERT EST AVALE, et l'ecriture du terrain qui suit l'est aussi : le depot pouvait
--      etre consigne perdu sans que le rendez-vous soit purge -- donc reconsigne la nuit
--      suivante -- ou l'inverse, le terrain libere sans trace publique de la perte.
--   3. AUCUNE DES DEUX ECRITURES N'EST VERIFIEE : la passe comptait `manques++` dans tous les cas.
--
-- CE QUE LA PORTE FAIT. Une transaction : la consignation publique de la perte et la purge du
-- rendez-vous, sous verrou du terrain. L'identifiant devient DATE (`achatdirect-<terrain>-<jour>`,
-- heure de Paris) et l'insertion porte un ON CONFLICT -- deux gardes pour le meme rejeu, la cle
-- primaire et l'index unique pose le meme jour.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Meme condition d'echeance (`dateLimite` depassee), meme
-- resultat 'perdu', meme texte de detail avec le montant de l'acompte, meme purge de la seule
-- cle `achatDirect`. L'acompte etait deja preleve au moment de la reservation : AUCUN ARGENT NE
-- BOUGE ICI, et c'est pour cela qu'aucune brique financiere n'intervient.

CREATE OR REPLACE FUNCTION public.achat_direct_manque_resoudre(p_terrain_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_cle text; v_pays text; v_bat text; v_data jsonb; v_ad jsonb;
  v_jour text := to_char((now() AT TIME ZONE 'Europe/Paris')::date, 'YYYY-MM-DD');
  v_n integer;
BEGIN
  SELECT t.id, t.country, t.building_id, t.data::jsonb
    INTO v_cle, v_pays, v_bat, v_data
    FROM public.terrains_etat t WHERE t.id = p_terrain_id FOR UPDATE;
  IF v_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable');
  END IF;
  v_data := coalesce(v_data, '{}'::jsonb);
  v_ad := v_data -> 'achatDirect';
  IF v_ad IS NULL OR jsonb_typeof(v_ad) <> 'object' OR (v_ad ->> 'dateLimite') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_achat_direct');
  END IF;

  -- MEME CONDITION D'ECHEANCE QU'AVANT : dateLimite est un horodatage en millisecondes.
  IF (v_ad ->> 'dateLimite')::numeric >= (extract(epoch from now()) * 1000) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_echu');
  END IF;

  -- L'IDENTIFIANT EST DATE, PLUS HORODATE A LA MILLISECONDE. Deux gardes pour le meme rejeu :
  -- la cle primaire, et l'index unique (pays, bien, resultat, journee).
  INSERT INTO public.compromis_historique (id, country, building_id, demandeur, resultat, detail)
  VALUES ('achatdirect-' || v_cle || '-' || v_jour, v_pays, v_bat,
          coalesce(nullif(v_ad ->> 'demandeur', ''), 'inconnu'), 'perdu',
          'Rendez-vous notarial manqué (dépôt de '
            || coalesce(v_ad ->> 'acompte', '0') || ' FR perdu)')
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- LA PURGE, DANS LA MEME TRANSACTION QUE LA CONSIGNATION.
  UPDATE public.terrains_etat
     SET data = (v_data - 'achatDirect')::text, updated_at = now()
   WHERE id = v_cle;

  RETURN jsonb_build_object('ok', true, 'consigne', v_n = 1, 'jour', v_jour,
                            'demandeur', v_ad ->> 'demandeur');
END; $fn$;

REVOKE ALL ON FUNCTION public.achat_direct_manque_resoudre(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.achat_direct_manque_resoudre(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.achat_direct_manque_resoudre(text) TO service_role;

DO $$
DECLARE v_def text; v_acl text;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='achat_direct_manque_resoudre';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_acl <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P2 : la porte n''est pas reservee au serveur -- %', v_acl; END IF;
  IF v_def NOT LIKE '%FOR UPDATE%' THEN RAISE EXCEPTION 'P3 : le terrain n''est pas verrouille'; END IF;
  -- P4 : l'identifiant est DATE, et jamais horodate a la milliseconde.
  IF v_def NOT LIKE '%''achatdirect-'' || v_cle || ''-'' || v_jour%' THEN
    RAISE EXCEPTION 'P4a : l''identifiant n''est pas date'; END IF;
  IF v_def LIKE '%epoch from now()) * 1000)%' AND v_def NOT LIKE '%dateLimite%' THEN
    RAISE EXCEPTION 'P4b : l''echeance ne porte plus sur dateLimite'; END IF;
  IF v_def NOT LIKE '%ON CONFLICT DO NOTHING%' THEN
    RAISE EXCEPTION 'P4c : l''insertion n''est pas protegee'; END IF;
  -- P5 : aucun argent ne bouge -- la porte ne touche ni personnages ni caisse.
  IF v_def LIKE '%public.personnages%' OR v_def LIKE '%caisses_batiments%'
     OR v_def LIKE '%budgets_%' THEN
    RAISE EXCEPTION 'P5 : la porte touche a de l''argent, ce qu''elle ne doit pas faire'; END IF;
  -- P6 : l'index unique pose le meme jour est bien la, c'est la seconde garde.
  IF NOT EXISTS (SELECT 1 FROM pg_class
                  WHERE relname = 'compromis_historique_un_resultat_par_bien_et_par_jour') THEN
    RAISE EXCEPTION 'P6 : la seconde garde (index unique) a disparu'; END IF;
  RAISE NOTICE 'achat_direct_manque_resoudre : 6 preuves structurelles conformes.';
END $$;
