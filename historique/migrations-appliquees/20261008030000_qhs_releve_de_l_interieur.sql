-- =============================================================================
-- LE QHS RELEVE DU MINISTERE DE L'INTERIEUR, ET SA PART VAUT ZERO
-- Chantier 4F — arbitrage du 8 octobre 2026
--
-- APPLIQUEE le 8 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007181335 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- CE QUI A ETE VERIFIE APRES COUP. La ligne Interieur -> QHS existe avec part_pourcent = 0.00 et
-- NON NULL : la configuration et l'absence d'arbitrage restent distinguables en base (le QHS
-- rend FALSE a `part IS NULL`, un tribunal rend TRUE). Les 35 % des Douanes sont intacts. Aucune
-- source autre que l'Interieur ne finance le QHS. Les cinq invariants de budget_coherence() ne
-- rendent aucune ligne. Eprouve en transaction annulee (outils/bancs/banc-budget-cascade.sql,
-- epreuve 4) : apres une cascade complete, la caisse du QHS ne bouge pas et le journal porte
-- `qhs-prison montant=0 transfere=false` ; un virement ponctuel de 500 FR passe et ne modifie
-- pas la part.
-- =============================================================================
--
-- L'ARBITRAGE. Le Quartier de Haute Securite releve BUDGETAIREMENT du Ministere de l'Interieur,
-- pas du Ministere de la Justice. Le tableau de bord budgetaire du Ministre de l'Interieur
-- presente donc deux beneficiaires : les Douanes a 35 % et le QHS a 0 %.
--
-- ZERO POUR CENT EST UNE CONFIGURATION, PAS UNE ABSENCE. C'est tout l'objet de cette migration,
-- et la distinction est portee par le TYPE de la colonne :
--
--     part_pourcent = 0      le QHS EST un beneficiaire reconnu du ministere. La regle existe,
--                            elle est declaree, elle s'applique chaque nuit -- et elle verse
--                            zero. Le ministre la voit dans son tableau et peut la modifier.
--     part_pourcent = NULL   la part n'est PAS arbitree. C'est le cas des trois tribunaux :
--                            budget_repartir les ignore entierement.
--
-- Les deux ne versent rien aujourd'hui, et c'est la seule chose qu'elles ont en commun. Un
-- `coalesce(part_pourcent, 0)` quelque part dans le code effacerait cette distinction : il n'y
-- en a aucun, et il n'en faut aucun.
--
-- AUCUNE RELATION JUSTICE -> QHS N'EST CREEE, et le quatrieme point de cette migration ajoute un
-- controle qui le prouve en permanence.
--
-- AUCUN CODE SPECIFIQUE AU QHS. La brique generique suffisait : cette migration insere UNE LIGNE
-- dans repartitions_budgetaires. Le virement ponctuel en FR passe par
-- caisse_ministere_mouvement(), qui deduit deja le poste habilite de l'identifiant de la caisse
-- source et credite la destination dans la meme transaction -- elle fonctionnait pour
-- min_def -> caserne sans savoir ce qu'est une caserne, elle fonctionne pour min_int -> qhs sans
-- savoir ce qu'est un QHS.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET C'EST DEMANDE EXPLICITEMENT. Aucun versement
-- retroactif. Aucun solde de betatest touche. Les 35 % des Douanes sont inchanges. Les parts des
-- tribunaux restent NULL. Les budgets municipaux ne sont pas abordes.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. LE QHS DEVIENT BENEFICIAIRE DECLARE DU MINISTERE DE L'INTERIEUR
-- -----------------------------------------------------------------------------
-- L'autorite n'est pas inventee : caisses_autorites declare depuis le 5 octobre 2026 que
-- `qhs-prison` est debitable par {min_int, min_just}. Le Ministre de l'Interieur avait donc deja
-- autorite sur cette caisse ; ce qui lui manquait, c'etait une LIGNE DE FINANCEMENT.
--
-- rang 2 : les Douanes passent devant, parce qu'elles sont financees et que le tableau se lit du
-- plus finance au moins finance.

INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note)
VALUES
  ('republic', 'gouvernement-min_int', 'qhs-prison', 0.00, 'min_int', 2,
   'Quartier de Haute Sécurité',
   'ARBITRAGE DU 8 OCTOBRE 2026 : le QHS releve budgetairement de l''Interieur, pas de la Justice. Part a 0 % PAR DECISION -- beneficiaire reconnu, sans financement recurrent au demarrage. Le ministre peut la modifier, et le virement ponctuel en FR reste possible meme a 0 %.')
ON CONFLICT (pays, source, beneficiaire) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. LE JOURNAL CESSE DE PRETENDRE QU'UN VERSEMENT NUL EST UN TRANSFERT
-- -----------------------------------------------------------------------------
-- budget_repartir journalise CHAQUE ligne declaree, puis ne transfere que ce qui est positif.
-- `transfere` valait pourtant `beneficiaire <> source` : une part a 0 % aurait donc inscrit
-- chaque nuit « transfere = true, montant = 0 ». Personne ne l'avait remarque parce qu'aucune
-- part a 0 % n'existait avant aujourd'hui -- c'est la premiere ligne a 0 % qui rend le defaut
-- visible.
--
-- Seule cette expression change. Tout le reste de la fonction est identique a la version
-- appliquee le 8 octobre (20261008010000), y compris le plus fort reste et la garde d'idempotence.
CREATE OR REPLACE FUNCTION public.budget_repartir(p_pays text, p_source text, p_base numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_base numeric := floor(coalesce(p_base, 0));
  v_total_parts numeric := 0;
  v_distribuable numeric;
  v_lignes jsonb := '[]'::jsonb;
  v_verse numeric := 0;
  v_conserve numeric := 0;
  r record; v_rep jsonb; v_cle text;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' OR coalesce(btrim(p_source), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_base <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'base_nulle', 'verse', 0, 'lignes', v_lignes);
  END IF;

  -- Les parts NON ARBITREES (NULL) sont exclues : rien n'est verse, et rien n'est invente.
  SELECT coalesce(sum(part_pourcent), 0) INTO v_total_parts
    FROM public.repartitions_budgetaires
   WHERE pays = p_pays AND source = p_source AND part_pourcent IS NOT NULL;
  IF v_total_parts <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucune_part_arbitree', 'verse', 0,
                              'lignes', v_lignes);
  END IF;

  v_distribuable := floor(v_base * v_total_parts / 100);

  -- PLUS FORT RESTE, EN UNE SEULE REQUETE. Aucune table temporaire : une fonction
  -- SECURITY DEFINER qui cree du DDL a chaque appel est une surprise de plus a maintenir, et le
  -- calcul se dit tres bien en CTE.
  --   parts   : la part exacte et son plancher, par beneficiaire declare ;
  --   classe  : les beneficiaires ordonnes par partie decimale perdue decroissante, egalite
  --             departagee par le rang declare -- donc un resultat identique chaque soir ;
  --   le +1 va aux `distribuable - somme des planchers` premiers de ce classement.
  FOR r IN
    WITH parts AS (
      SELECT b.beneficiaire, b.part_pourcent AS part, b.rang, b.libelle,
             v_base * b.part_pourcent / 100          AS exact,
             floor(v_base * b.part_pourcent / 100)    AS plancher
        FROM public.repartitions_budgetaires b
       WHERE b.pays = p_pays AND b.source = p_source AND b.part_pourcent IS NOT NULL
    ), reliquat AS (
      SELECT v_distribuable - coalesce(sum(plancher), 0) AS n FROM parts
    ), classe AS (
      SELECT p.*, row_number() OVER (ORDER BY (p.exact - p.plancher) DESC, p.rang) AS ordre
        FROM parts p
    )
    SELECT c.beneficiaire, c.part, c.libelle,
           c.plancher + CASE WHEN c.ordre <= (SELECT n FROM reliquat) THEN 1 ELSE 0 END AS montant
      FROM classe c ORDER BY c.rang
  LOOP
    -- LA CLE DU JOURNAL EST LE GARDE-FOU. Un second passage le meme jour leve ici.
    BEGIN
      INSERT INTO public.repartitions_versements
        (pays, source, beneficiaire, jour, base, part_pourcent, montant, transfere)
      VALUES (p_pays, p_source, r.beneficiaire, v_jour, v_base, r.part, r.montant,
              -- transfere DIT LA VERITE : il est faux aussi bien pour la part que le
              -- repartiteur conserve que pour un montant nul. Une part declaree a 0 % est
              -- journalisee -- la regle a bien ete appliquee -- mais rien n'a bouge, et le
              -- journal ne doit pas pretendre le contraire.
              r.beneficiaire <> p_source AND r.montant > 0);
    EXCEPTION WHEN unique_violation THEN
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0, 'raison', 'deja_verse_ce_jour'));
      CONTINUE;
    END;

    -- LA PART DU REPARTITEUR NE SE TRANSFERE PAS. C'est ce qui empeche la boucle : le MEco
    -- recoit tout, en distribue 91 %, et conserve ses 9 % la ou ils sont deja.
    IF r.beneficiaire = p_source THEN
      v_conserve := v_conserve + r.montant;
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', r.montant, 'conserve', true));
      CONTINUE;
    END IF;

    IF r.montant <= 0 THEN
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0));
      CONTINUE;
    END IF;

    -- DEBIT DE LA SOURCE PUIS CREDIT DU BENEFICIAIRE, par les primitives atomiques existantes.
    -- La porte interne est ouverte pour cette transaction : l'autorite de l'operation est celle
    -- du serveur, pas celle d'un poste.
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(p_pays || '_' || p_source, -r.montant, true);
    IF coalesce((v_rep->>'ok')::boolean, false) THEN
      v_rep := public.caisse_institution_mouvement(p_pays || '_' || r.beneficiaire, r.montant, false);
    END IF;
    PERFORM set_config('rp.caisse_interne', '', true);

    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
      -- FAIL CLOSED : rien n'a abouti, on retire la ligne de journal pour que le versement
      -- puisse etre retente, et on le dit.
      DELETE FROM public.repartitions_versements
       WHERE pays = p_pays AND source = p_source AND beneficiaire = r.beneficiaire AND jour = v_jour;
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0,
        'raison', coalesce(v_rep->>'raison','transfert_refuse')));
      CONTINUE;
    END IF;

    v_verse := v_verse + r.montant;
    v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
      'beneficiaire', r.beneficiaire, 'montant', r.montant));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'source', p_source, 'jour', v_jour,
                            'base', v_base, 'total_parts', v_total_parts,
                            'verse', v_verse, 'conserve', v_conserve, 'lignes', v_lignes);
END;
$function$;
COMMENT ON FUNCTION public.budget_repartir(text, text, numeric) IS
  'Execute la repartition declaree pour (pays, source) sur une base donnee. Plus fort reste, aucun FR perdu. Les parts NULL sont ignorees -- rien n''est invente ; les parts a 0 sont APPLIQUEES et journalisees a montant nul -- la regle existe et donne zero. La ligne dont le beneficiaire est la source est journalisee mais jamais transferee : c''est ce qui empeche la boucle du repartiteur. transfere=false des que rien n''a bouge, part conservee comme montant nul. La cle primaire du journal porte le jour : la double distribution est impossible par construction. RESERVEE AU SERVEUR : la base ne doit jamais venir d''un navigateur.';

REVOKE ALL ON FUNCTION public.budget_repartir(text, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_repartir(text, text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 3. UN CINQUIEME INVARIANT : DEUX MINISTERES NE FINANCENT PAS LA MEME CAISSE
-- -----------------------------------------------------------------------------
-- « Ne cree surtout aucune relation Justice -> QHS. » On pourrait verifier exactement cela, et
-- ce serait un controle qui nomme un objet -- donc le symptome d'une regle manquante. La regle
-- est plus large et se dit en une phrase : UNE CAISSE, UN FINANCEUR RECURRENT. Deux ministeres
-- qui alimentent la meme caisse, c'est un double financement que personne n'a decide, et le
-- probleme n'a rien de propre au QHS.
--
-- C'est un RAPPORT, pas une contrainte : budget_coherence() decrit, elle n'interdit pas. Si un
-- co-financement devait un jour etre arbitre, il apparaitrait ici et on saurait qu'il est
-- delibere -- au lieu d'etre decouvert six mois plus tard dans un solde qui monte trop vite.
-- La ligne dont le beneficiaire est sa propre source est exclue : ce n'est pas un financement,
-- c'est la part conservee par le repartiteur.

CREATE OR REPLACE FUNCTION public.budget_coherence()
RETURNS TABLE(probleme text, detail text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  -- La somme des parts d'une source ne doit jamais depasser 100 %.
  SELECT 'somme des parts superieure a 100 %',
         string_agg(x.pays || '/' || x.source || ' = ' || x.somme::text, ', ' ORDER BY x.source)
    FROM (SELECT pays, source, sum(part_pourcent) AS somme
            FROM public.repartitions_budgetaires WHERE part_pourcent IS NOT NULL
           GROUP BY pays, source) x
   WHERE x.somme > 100
  HAVING count(*) > 0
  UNION ALL
  -- Un beneficiaire declare doit avoir une caisse qui existe, sinon le versement sera refuse
  -- chaque nuit en silence. Les parts NULL sont exclues : elles ne versent rien. Les parts a
  -- ZERO, elles, sont incluses -- la regle existe, elle s'appliquera le jour ou le ministre
  -- relevera la part, et la caisse doit donc etre la des maintenant.
  SELECT 'beneficiaire sans caisse en base',
         string_agg(b.pays || '_' || b.beneficiaire, ', ' ORDER BY b.beneficiaire)
    FROM public.repartitions_budgetaires b
   WHERE b.part_pourcent IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.caisses_batiments c
                      WHERE c.id = b.pays || '_' || b.beneficiaire)
  HAVING count(*) > 0
  UNION ALL
  -- Le poste d'autorite doit exister comme poste du jeu.
  SELECT 'poste d''autorite inconnu',
         string_agg(DISTINCT b.poste_autorite, ', ')
    FROM public.repartitions_budgetaires b
   WHERE NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles p WHERE p.poste_id = b.poste_autorite)
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses s WHERE s.poste_id = b.poste_autorite)
  HAVING count(*) > 0
  UNION ALL
  -- Deux versements le meme jour pour le meme couple : impossible par la cle primaire, mais on
  -- le verifie quand meme -- c'est l'invariant le plus couteux s'il tombe.
  SELECT 'double versement le meme jour',
         string_agg(v.source || '->' || v.beneficiaire || ' le ' || v.jour::text, ', ')
    FROM (SELECT pays, source, beneficiaire, jour, count(*) AS n
            FROM public.repartitions_versements
           GROUP BY pays, source, beneficiaire, jour) v
   WHERE v.n > 1
  HAVING count(*) > 0
  UNION ALL
  -- UNE CAISSE, UN FINANCEUR RECURRENT.
  SELECT 'caisse financee par deux sources',
         string_agg(y.pays || '_' || y.beneficiaire || ' <- ' || y.sources, ', ' ORDER BY y.beneficiaire)
    FROM (SELECT pays, beneficiaire, string_agg(source, ' et ' ORDER BY source) AS sources
            FROM public.repartitions_budgetaires
           WHERE beneficiaire <> source
           GROUP BY pays, beneficiaire
          HAVING count(*) > 1) y
  HAVING count(*) > 0;
$function$;

COMMENT ON FUNCTION public.budget_coherence() IS
  'Cinq invariants de l''architecture budgetaire : aucune somme de parts au-dela de 100 %, aucun beneficiaire a part NON NULLE sans caisse en base (les parts a 0 comptent -- la regle existe), aucun poste d''autorite inconnu, aucun double versement le meme jour, et aucune caisse financee par deux sources differentes (une caisse, un financeur recurrent).';

REVOKE ALL ON FUNCTION public.budget_coherence() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_coherence() TO service_role;

-- -----------------------------------------------------------------------------
-- 4. LE CONTROLE, DANS LA TRANSACTION
-- -----------------------------------------------------------------------------
-- Sept assertions, une par preuve demandee. Si l'une tombe, la migration echoue plutot que de
-- laisser croire qu'elle a fait ce qu'elle annonce.

DO $$
DECLARE v_douane numeric; v_qhs numeric; v_nulle boolean; v_justice integer; v_pbs text;
BEGIN
  -- (1) MInt -> Douanes = 35 %, inchange.
  SELECT part_pourcent INTO v_douane FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='douane';
  IF v_douane IS DISTINCT FROM 35.00 THEN
    RAISE EXCEPTION 'Douanes attendues a 35 %%, trouvees : %', coalesce(v_douane::text,'(aucune ligne)');
  END IF;

  -- (2) MInt -> QHS = 0 %, et (3) la ligne EXISTE avec une part NON NULLE : une configuration,
  -- pas une absence de regle.
  SELECT part_pourcent, part_pourcent IS NULL INTO v_qhs, v_nulle
    FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='qhs-prison';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'la ligne Interieur -> QHS n''existe pas : 0 %% serait confondu avec une absence de regle';
  END IF;
  IF v_nulle THEN
    RAISE EXCEPTION 'la part du QHS est NULL, donc NON ARBITREE -- l''arbitrage dit 0 %%, ce qui n''est pas la meme chose';
  END IF;
  IF v_qhs <> 0.00 THEN
    RAISE EXCEPTION 'QHS attendu a 0 %%, trouve : %', v_qhs;
  END IF;

  -- (6) Justice n'a AUCUNE relation budgetaire vers le QHS.
  SELECT count(*) INTO v_justice FROM public.repartitions_budgetaires
   WHERE beneficiaire = 'qhs-prison' AND source <> 'gouvernement-min_int';
  IF v_justice > 0 THEN
    RAISE EXCEPTION 'le QHS est finance par % source(s) autre(s) que l''Interieur', v_justice;
  END IF;

  -- Les cinq invariants generiques tiennent, le nouveau compris.
  SELECT string_agg(probleme || ' (' || detail || ')', ' | ') INTO v_pbs FROM public.budget_coherence();
  IF v_pbs IS NOT NULL THEN
    RAISE EXCEPTION 'budget_coherence() signale : %', v_pbs;
  END IF;
END $$;

COMMIT;
