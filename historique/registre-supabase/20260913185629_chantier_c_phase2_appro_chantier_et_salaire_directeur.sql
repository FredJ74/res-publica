-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913185629
-- Nom original      : chantier_c_phase2_appro_chantier_et_salaire_directeur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 18:56:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b50cec3607f96fc68f23344b72d278ad
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
-- ============================================================================
-- CHANTIER C / PHASE 2 — F8 APPROVISIONNEMENT DE CHANTIER, F9 SALAIRE DIRECTEUR
-- 13 septembre 2026.
-- ============================================================================

-- --- F8 : APPROVISIONNEMENT AUTOMATIQUE D'UN CHANTIER -----------------------
-- planifierApprovisionnement (plateau-chantiers.js) calculait TOUT cote client --
-- achats, depense, et LES DEUX STOCKS RESULTANTS -- puis ecrivait le stock et la
-- caisse de l'entrepot national tels quels. Le serveur refait le plan a partir du
-- stock reel et des prix reels, et n'applique que ce qu'il a lui-meme calcule.
--
-- LIMITE ASSUMEE ET DOCUMENTEE : le chantier lui-meme (son stock de materiaux et
-- sa tresorerie) vit dans terrains_etat, que ce lot ne migre pas -- et il n'est
-- meme pas encore ecrit en base au moment de l'appel, le client le construisant
-- juste avant. Ces deux valeurs restent donc fournies par l'appelant. Ce qui est
-- acquis : le cote ENTREPOT est entierement autoritaire -- prix reels, stock reel,
-- reserve militaire opposable, et l'on ne peut plus vider un entrepot en
-- annoncant un plan fabrique. Le cote chantier suivra avec terrains_etat.
CREATE OR REPLACE FUNCTION public.approvisionner_chantier(
  p_acteur text, p_pays text, p_ville text, p_entrepot text,
  p_besoin jsonb, p_stock_chantier jsonb, p_tresorerie numeric)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_entrepot;
  v_etat jsonb; v_entrepot jsonb; v_stock jsonb; v_reserve jsonb;
  v_cle text; v_en_chantier numeric; v_manque numeric; v_prix numeric;
  v_present numeric; v_reserve_m numeric; v_dispo numeric; v_abordable numeric; v_qte numeric;
  v_achats jsonb := '{}'::jsonb; v_nouveau_chantier jsonb := '{}'::jsonb;
  v_depense numeric := 0;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'depense', 0, 'achats', '{}'::jsonb,
                              'stockChantier', coalesce(p_stock_chantier,'{}'::jsonb));
  END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_stock := coalesce(v_entrepot->'stock', '{}'::jsonb);
  v_reserve := coalesce(v_entrepot->'reserveMilitaire', '{}'::jsonb);

  -- Meme boucle, dans le meme ordre, sur les memes trois materiaux.
  FOREACH v_cle IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    v_en_chantier := greatest(0, coalesce((p_stock_chantier->>v_cle)::numeric, 0));
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier));
    v_manque := greatest(0, greatest(0, coalesce((p_besoin->>v_cle)::numeric, 0)) - v_en_chantier);
    CONTINUE WHEN v_manque <= 0;
    -- Le PRIX vient du miroir, jamais du client.
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    CONTINUE WHEN v_prix IS NULL OR v_prix <= 0;
    v_present := greatest(0, floor(coalesce((v_stock->>v_cle)::numeric, 0)));
    v_reserve_m := greatest(0, floor(coalesce((v_reserve->>v_cle)::numeric, 0)));
    v_dispo := greatest(0, v_present - v_reserve_m);     -- reserve militaire opposable
    v_abordable := floor(greatest(0, coalesce(p_tresorerie,0) - v_depense) / v_prix);
    v_qte := least(v_manque, v_dispo, v_abordable);
    CONTINUE WHEN v_qte <= 0;
    v_achats := jsonb_set(v_achats, ARRAY[v_cle], to_jsonb(v_qte));
    v_depense := v_depense + v_qte * v_prix;
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier + v_qte));
    -- On debite le stock PHYSIQUE, jamais la vue « disponible ».
    v_stock := jsonb_set(v_stock, ARRAY[v_cle], to_jsonb(v_present - v_qte));
  END LOOP;

  IF v_depense > 0 THEN
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
             v_entrepot || jsonb_build_object('stock', v_stock,
               'caisse', coalesce((v_entrepot->>'caisse')::numeric,0) + v_depense)))::text),
           updated_at = now()
     WHERE id = v_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'depense', v_depense,
                            'stockChantier', v_nouveau_chantier);
END; $$;
REVOKE ALL ON FUNCTION public.approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric) TO authenticated;

-- --- F9 : SALAIRE QUOTIDIEN D'UN DIRECTEUR ----------------------------------
-- Les deux fonctions …Plafonne ne servaient qu'a cela : un directeur se versait
-- son salaire depuis la caisse de son etablissement, en reecrivant cette caisse.
-- Le serveur verifie qu'il occupe REELLEMENT le poste, plafonne au solde reel
-- (versement partiel conserve, c'est la regle existante) et pose le marqueur du
-- jour. p_souscle vaut 'entrepot' ou 'usine'.
--
-- AU PASSAGE, UN DEFAUT CORRIGE : le marqueur du jour vivait sur state.char
-- (dernierSalaireDirecteurEntrepotJour), qui n'est PAS persiste -- un simple
-- rechargement permettait donc de toucher son salaire plusieurs fois. Il vit
-- desormais dans personnages.stats, comme les marqueurs de soin.
CREATE OR REPLACE FUNCTION public.percevoir_salaire_directeur(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_souscle text,
  p_poste_attendu text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_poste text; v_jour int; v_stats jsonb; v_marqueur text;
  v_etat jsonb; v_sous jsonb; v_solde numeric; v_verse numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_souscle NOT IN ('entrepot','usine') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'souscle_invalide');
  END IF;
  v_marqueur := 'salaireDirecteur_' || p_souscle || '_' || p_batiment;

  SELECT poste->>'id', coalesce(day,1), coalesce(stats,'{}'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_poste, v_jour, v_stats, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_jour IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_poste IS DISTINCT FROM p_poste_attendu THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'etablissement_introuvable'); END IF;
  v_sous := coalesce(v_etat->p_souscle, '{}'::jsonb);
  v_solde := coalesce((v_sous->>'caisse')::numeric, 0);
  v_verse := least(v_solde, greatest(0, coalesce(p_montant,0)));   -- versement partiel conserve

  IF v_verse > 0 THEN
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object(p_souscle,
             v_sous || jsonb_build_object('caisse', v_solde - v_verse)))::text), updated_at = now()
     WHERE id = v_id;
  END IF;
  UPDATE public.personnages_donnees
     SET arg = v_arg + v_verse, liquide = v_liquide + v_verse,
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'complet', v_verse >= coalesce(p_montant,0),
    'arg', v_arg + v_verse, 'liquide', v_liquide + v_verse, 'caisse', v_solde - v_verse);
END; $$;
REVOKE ALL ON FUNCTION public.percevoir_salaire_directeur(text,text,text,text,text,text,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.percevoir_salaire_directeur(text,text,text,text,text,text,numeric) TO authenticated;