-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917221639
-- Nom original      : militaire_entrainement_quatre_domaines
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:16:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2f169c9721677032b6215aa8700deeee
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
-- ==========================================================================================
-- ENTRAINEMENT : QUATRE DOMAINES, ET DES PA REELLEMENT DEBITES
--
-- L'ANCIEN MODELE ABANDONNE. militaire_entrainer_section n'acceptait que force / endurance / tir,
-- et surtout n'avait AUCUN controle de PA : une section pouvait s'entrainer indefiniment sans
-- rien depenser. L'arbitrage du GD est precisement inverse -- une troupe qui s'entraine devient
-- meilleure mais reduit fortement son potentiel operationnel immediat.
--
-- LES QUATRE DOMAINES : combat_rapproche, tir, reconnaissance, secourisme. Echelle 0..100.
-- « endurance » disparait : les PA remplissent deja ce role. Pas de competence radio ni tente :
-- ce sont des outils, pas des savoir-faire.
--
-- COUT, constantes serveur : 6 PA pour CHAQUE soldat participant ET 6 PA pour le Lieutenant qui
-- conduit la seance. Les PA sont INDIVIDUELS et reellement debites. Ils ne sont JAMAIS remis a
-- une valeur pleine apres l'entrainement.
--
-- PAS DE RESOLUTION PARTIELLE INCOHERENTE. Ne participent que les soldats qui ont reellement
-- leurs 6 PA : on debite exactement ceux qui progressent, et on fait progresser exactement ceux
-- qu'on debite. Si aucun soldat n'est en etat, ou si le Lieutenant n'a pas ses 6 PA, la seance
-- n'a pas lieu du tout et rien n'est ecrit.
--
-- L'ENTRAINEMENT NE CONCERNE QUE LES SOLDATS PNJ. Un soldat PJ n'a pas de `formation` : ses
-- caracteristiques sont son capital, et le GD precise que les domaines ne sont pas des doublons
-- des caracteristiques PJ. Le capital d'entrainement appartient donc a l'individu PNJ et voyage
-- avec lui entre section et reserve -- un mort l'emporte definitivement.
-- Ce que gagne un soldat PJ a une seance reste un point de game design ouvert.
-- ==========================================================================================

CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(
  p_compagnie_id text, p_section_id text, p_stat text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_max_soldats constant integer := 12;
  c_pa_soldat   constant integer := 6;
  c_pa_chef     constant integer := 6;
  c_gain        constant integer := 3;
  c_plafond     constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_pa_chef integer; v_elus jsonb; v_n integer;
BEGIN
  IF p_stat NOT IN ('combat_rapproche','tir','reconnaissance','secourisme') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'domaine_invalide', 'domaine', p_stat);
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- Le Lieutenant paie sa seance. Verifie AVANT toute ecriture : un RETURN ne defait rien.
  SELECT coalesce(pa, 0) INTO v_pa_chef FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;
  IF v_pa_chef < c_pa_chef THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_chef_insuffisants',
                              'requis', c_pa_chef, 'pa_reel', v_pa_chef);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- Les elus : soldats PNJ ayant reellement 6 PA, les MOINS formes d'abord dans ce domaine,
  -- jusqu'a 12. On retient leur matricule, seule identite stable d'un soldat PNJ.
  SELECT coalesce(jsonb_agg(m ORDER BY ord), '[]'::jsonb) INTO v_elus
    FROM (SELECT sol->>'matricule' AS m,
                 row_number() OVER (ORDER BY coalesce((sol->'formation'->>p_stat)::numeric, 0),
                                             sol->>'matricule') AS ord
            FROM jsonb_array_elements(v_sols) sol
           WHERE NOT coalesce((sol->>'pj')::boolean, false)
             AND coalesce((sol->>'pa')::numeric, 0) >= c_pa_soldat
             AND coalesce(sol->>'matricule', '') <> '') x
   WHERE ord <= c_max_soldats;
  v_n := jsonb_array_length(v_elus);

  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_en_etat',
                              'pa_requis_par_soldat', c_pa_soldat);
  END IF;

  -- Debit ET gain sur les MEMES soldats, dans la meme ecriture : jamais l'un sans l'autre.
  SELECT coalesce(jsonb_agg(
           CASE WHEN v_elus ? (sol->>'matricule')
                THEN sol
                     || jsonb_build_object('pa', coalesce((sol->>'pa')::numeric, 0) - c_pa_soldat)
                     || jsonb_build_object('formation',
                          coalesce(CASE WHEN jsonb_typeof(sol->'formation') = 'object'
                                        THEN sol->'formation' END, '{}'::jsonb)
                          || jsonb_build_object(p_stat,
                               least(c_plafond,
                                     coalesce((sol->'formation'->>p_stat)::numeric, 0) + c_gain)))
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- Les PA du Lieutenant : un debit, jamais une remise a une valeur pleine.
  UPDATE public.personnages_donnees SET pa = v_pa_chef - c_pa_chef WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'domaine', p_stat, 'progresses', v_n,
    'gain', c_gain, 'plafond', c_plafond,
    'pa_soldat', c_pa_soldat, 'pa_chef', c_pa_chef, 'pa_restants_chef', v_pa_chef - c_pa_chef,
    'matricules', v_elus);
END;
$fn$;

-- ---- Les nouveaux soldats naissent avec les quatre domaines a zero ----
-- Ecrivain et lecteur doivent toujours s'accorder sur la forme des donnees : le changement de
-- domaines et celui de la creation se font donc dans la meme migration.
CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_contingent constant integer := 96;
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  c_pa         constant integer := 3;
  v_moi text; v_pays text; v_pa integer; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb; v_sections jsonb; v_reserve jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic'), coalesce(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_compagnie_creer: paiement des PA refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('combat_rapproche', 0, 'tir', 0,
                                           'reconnaissance', 0, 'secourisme', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent, 'reserve', v_reserve, 'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$fn$;