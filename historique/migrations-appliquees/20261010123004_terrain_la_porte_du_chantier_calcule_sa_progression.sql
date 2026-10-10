-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010123004 (UTC), nom `terrain_la_porte_du_chantier_calcule_sa_progression`.
-- Le registre passe de 616 a 617 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4d892ac074f60aaf9dfb133d46855169, 10003 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- L'ETAT D'UN TERRAIN -- 3/4 : LE CHANTIER (ACCELERATION PAR CORRUPTION, VOL DE MATERIAUX)
--
-- Chantier 5, les 19 `sbSetTerrainState` avales. Les deux actes les plus autoritaires du mecanisme
-- ecrivaient l'objet `chantier` entier depuis le cache du navigateur : l'acceleration calculait
-- elle-meme la nouvelle progression, et le vol de materiaux etait plafonne par le stock que le
-- CLIENT avait lu. La porte calcule desormais la progression a partir de l'etat reel, et replafonne
-- le vol sur le stock reel sous verrou ; les trois seuils de financement sont generes, pas recopies.
--
-- AVERTISSEMENT DE LECTURE : l'en-tete du corps archive affirme que l'arithmetique en
-- `double precision` est NECESSAIRE. La migration 618 (registre 618) rectifie ce point : la
-- contre-epreuve en `numeric` exact donne le meme resultat sur les 184 cas de la grille, donc c'est
-- une PRECAUTION et non une necessite mesuree. Le corps reste celui qui a ete applique.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ETAT D'UN TERRAIN -- 3/4 : LE CHANTIER (acceleration par corruption, vol de materiaux)
-- Chantier 5, les 19 `sbSetTerrainState` avales (10 octobre 2026).
--
-- CES DEUX ACTES SONT LES PLUS AUTORITAIRES DU MECANISME, et les deux ecrivaient l'objet
-- `chantier` ENTIER depuis le cache du navigateur -- dans la ligne que le cron de minuit fait
-- avancer chaque nuit (`progressionJours`, `heuresFaites`, `tresorerie`, `stockMateriaux`,
-- `evenements`, `jourTraite`).
--
--   ACCELERATION. Le navigateur calculait lui-meme la nouvelle progression
--   (`progressionAutorisee`, `appliquerVerrouPlan`) et l'envoyait. Un chiffre que le client dicte
--   et qui BORNE un avancement est une faille, meme derriere une RPC. La porte le calcule
--   desormais ELLE-MEME, a partir de l'etat reel -- le navigateur n'envoie plus aucun nombre.
--
--   VOL DE MATERIAUX. La quantite derobee etait plafonnee par le stock que le CLIENT avait lu.
--   Deux voleurs simultanes emportaient donc chacun tout le stock, et un cache perime pouvait
--   RESSUSCITER un stock que le cron avait consomme. La porte replafonne sur le stock reel, sous
--   verrou, et rend la quantite REELLEMENT emportee -- c'est elle que l'inventaire credite.
--
-- LES TROIS SEUILS DE FINANCEMENT SONT GENERES, PAS RECOPIES. `progressionMaxFinancee` depend de
-- `SEUILS_FINANCEMENT_CONSTRUCTION` (plateau-chantiers.js). `outils/generateurs/generer_miroirs_chantiers.py`
-- les extrait du VRAI fichier sous JavaScriptCore et les seme ici -- il n'en mirroitait qu'un
-- seul jusqu'a aujourd'hui. Rejouer le generateur apres toute modification de ces seuils.
--
-- ET L'ARITHMETIQUE EST CELLE DE JAVASCRIPT, DELIBEREMENT. Les comparaisons de tiers se font en
-- `double precision` et non en `numeric` : le client compare des flottants binaires, et deux
-- arithmetiques differentes peuvent basculer un seuil dans des sens opposes. Le banc compare les
-- deux implementations sur une grille de valeurs -- c'est la preuve ancien-contre-nouveau.

INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('seuil_premier_tiers_pct', 70),
  ('seuil_deux_tiers_pct', 100)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

CREATE OR REPLACE FUNCTION public.terrain_chantier_acte(
  p_terrain_id text, p_acte text, p_matiere text DEFAULT NULL,
  p_quantite integer DEFAULT NULL, p_jour integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_ch jsonb; v_final jsonb;
  v_d double precision; v_total double precision; v_verse double precision; v_prog double precision;
  v_s1 double precision; v_s2 double precision; v_s3 double precision;
  v_requis double precision; v_plafond double precision; v_gain double precision; v_neuf double precision;
  v_stock jsonb; v_dispo integer; v_qte integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  IF p_acte = 'chantier_accelerer' THEN
    SELECT valeur::double precision INTO v_s1 FROM public.entreprises_constantes WHERE cle = 'seuil_demarrage_pct';
    SELECT valeur::double precision INTO v_s2 FROM public.entreprises_constantes WHERE cle = 'seuil_premier_tiers_pct';
    SELECT valeur::double precision INTO v_s3 FROM public.entreprises_constantes WHERE cle = 'seuil_deux_tiers_pct';
    IF v_s1 IS NULL OR v_s2 IS NULL OR v_s3 IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'seuils_indisponibles');
    END IF;
    v_d     := greatest(0, coalesce((v_ch ->> 'dureeJours')::double precision, 0));
    v_total := greatest(0, coalesce((v_ch ->> 'coutTotal')::double precision, 0));
    v_verse := greatest(0, coalesce((v_ch ->> 'totalVerse')::double precision, 0));
    v_prog  := greatest(0, coalesce((v_ch ->> 'progressionJours')::double precision, 0));

    -- peutProgresser : montantManquant(...) <= 0, avec seuilFinancementRequis par palier de tiers.
    v_requis := ceil(v_total * (CASE WHEN v_d <= 0 THEN v_s3
                                     WHEN v_prog < v_d * 1 / 3 THEN v_s1
                                     WHEN v_prog < v_d * 2 / 3 THEN v_s2
                                     ELSE v_s3 END) / 100);
    IF greatest(0, v_requis - v_verse) > 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'financement_insuffisant',
                                'manquant', greatest(0, v_requis - v_verse));
    END IF;
    IF greatest(0, v_d - v_prog) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'chantier_a_son_terme');
    END IF;

    -- progressionMaxFinancee, puis progressionAutorisee avec un gain de la MOITIE du travail
    -- restant -- la regle exacte de `doCorrompreChantier`, inchangee.
    v_plafond := CASE WHEN v_d <= 0 THEN 0
                      WHEN v_total <= 0 THEN v_d
                      WHEN v_verse * 100 >= v_s3 * v_total THEN v_d
                      WHEN v_verse * 100 >= v_s2 * v_total THEN v_d * 2 / 3
                      WHEN v_verse * 100 >= v_s1 * v_total THEN v_d * 1 / 3
                      ELSE 0 END;
    v_gain := greatest(0, least(v_prog + greatest(0, (v_d - v_prog) / 2), v_plafond) - v_prog);
    IF v_gain <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'progression_plafonnee', 'plafond', v_plafond);
    END IF;
    v_neuf := least(v_d, v_prog + v_gain);
    v_ch := v_ch || jsonb_build_object('progressionJours', v_neuf);
    -- appliquerVerrouPlan : le plan se fige aux deux tiers, et une seule fois.
    IF coalesce((v_ch ->> 'planVerrouille')::boolean, false) IS NOT TRUE
       AND v_d > 0 AND v_neuf >= v_d * 2 / 3 THEN
      v_ch := v_ch || jsonb_build_object('planVerrouille', true, 'jourVerrouPlan', p_jour);
    END IF;
    v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
                 jsonb_build_object('chantier', v_ch), v_pays);
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
      'progression', v_neuf, 'reste', greatest(0, v_d - v_neuf), 'gain', v_gain);
  END IF;

  -- VOL DE MATERIAUX
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue');
  END IF;
  IF coalesce(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  v_stock := coalesce(v_ch -> 'stockMateriaux', '{}'::jsonb);
  v_dispo := greatest(0, coalesce((v_stock ->> p_matiere)::numeric, 0))::integer;
  IF v_dispo <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide', 'matiere', p_matiere);
  END IF;
  -- LE PLAFOND EST LE STOCK REEL, PAS CELUI QUE LE CLIENT AVAIT LU.
  v_qte := least(p_quantite, v_dispo);
  v_ch := v_ch
    || jsonb_build_object('stockMateriaux', v_stock || jsonb_build_object(p_matiere, v_dispo - v_qte))
    || jsonb_build_object('evenements', coalesce(v_ch -> 'evenements', '[]'::jsonb)
         || jsonb_build_array(jsonb_build_object('cle', 'vol_materiaux', 'jour', p_jour,
              'matiere', p_matiere, 'quantite', v_qte)));
  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('chantier', v_ch), v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
    'matiere', p_matiere, 'quantite', v_qte, 'stock_restant', v_dispo - v_qte);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_chantier_acte(text, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_chantier_acte(text, text, text, integer, integer)
  TO authenticated, service_role;

DO $p$
DECLARE v_def text; v integer;
BEGIN
  IF NOT has_function_privilege('authenticated',
        'public.terrain_chantier_acte(text,text,text,integer,integer)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon',
        'public.terrain_chantier_acte(text,text,text,integer,integer)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'les droits de la porte du chantier sont faux';
  END IF;
  SELECT count(*) INTO v FROM public.entreprises_constantes
   WHERE cle IN ('seuil_demarrage_pct', 'seuil_premier_tiers_pct', 'seuil_deux_tiers_pct');
  IF v <> 3 THEN RAISE EXCEPTION 'les trois seuils de financement ne sont pas semes : %', v; END IF;

  v_def := pg_get_functiondef(
    'public.terrain_chantier_acte(text,text,text,integer,integer)'::regprocedure);
  -- AUCUN NOMBRE DE PROGRESSION NE VIENT DU CLIENT : la signature n'en a pas, et la porte lit les
  -- seuils en base.
  IF v_def LIKE '%p_progression%' THEN
    RAISE EXCEPTION 'la porte accepte une progression dictee par le client';
  END IF;
  IF v_def NOT LIKE '%entreprises_constantes%' THEN
    RAISE EXCEPTION 'la porte ne lit pas les seuils de financement en base';
  END IF;
  IF v_def NOT LIKE '%double precision%' THEN
    RAISE EXCEPTION 'l''arithmetique n''est pas celle du client';
  END IF;
  IF v_def NOT LIKE '%least(p_quantite, v_dispo)%' THEN
    RAISE EXCEPTION 'le vol n''est pas replafonne sur le stock reel';
  END IF;
  IF v_def LIKE '%UPDATE public.terrains_etat%' OR v_def LIKE '%INSERT INTO public.terrains_etat%' THEN
    RAISE EXCEPTION 'la porte du chantier ecrit la table directement';
  END IF;
  RAISE NOTICE 'Les 7 preuves structurelles de la porte du chantier sont vertes.';
END $p$;
