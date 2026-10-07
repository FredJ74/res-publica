-- =============================================================================
-- CHANTIER 4F — L'ARCHITECTURE BUDGETAIRE DEVIENT DECLARATIVE
-- 8 octobre 2026
--
-- APPLIQUEE le 8 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007150749 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- CE QUI A ETE VERIFIE APRES COUP. Les quatre invariants de budget_coherence() ne rendent aucune
-- ligne. La cle est celle de l'arbitrage, verifiee en base : total national exactement 100 %,
-- Assemblee 19 %, neuf caisses a 9 %, Defense -> Caserne 65 %, Interieur -> Douanes 35 %, trois
-- parts de Justice a NULL, aucune ligne pour les trois autres empires. La cascade a ete eprouvee
-- en transaction annulee (outils/bancs/banc-budget-cascade.sql) : somme exacte sur une base
-- premiere, aucun FR perdu, aucune boucle du repartiteur, et second passage refuse par la cle
-- primaire du journal.
--
-- MEME DEFAUT DE DROITS que la migration precedente, sur budget_coherence() : corrige par
-- 20261008020000. Les quatre autres fonctions nommaient `authenticated` dans leur REVOKE et
-- etaient donc deja justes -- ce qui prouve que l'omission etait un oubli de redaction, pas
-- une doctrine differente.
-- =============================================================================
--
-- CE QUI EXISTAIT, MESURE LE 7 OCTOBRE 2026 : TROIS DISTRIBUTEURS POUR LES MEMES RECETTES.
--
--   1. api/cron-minuit.js, distribuerFiscaliteServeur -- LE SEUL REEL. Il repartit les recettes
--      du jour sur TREIZE caisses selon une cle qui melange ministeres, commissariats, tribunaux
--      et mairies. La cle appliquee est celle du CODE (REPARTITION_DEFAULT) : verifie en base,
--      `budgets_nationaux.data` ne porte AUCUNE cle `repartition`.
--   2. plateau-justice-economie.js, alimenterBudgets -- UN FANTOME, appele a chaque minuit
--      JOUEUR depuis runMidnightUpdate. Il repartit les MEMES recettes dans `state.budgets`, un
--      objet local au navigateur, jamais persiste, plafonne a 200 000, et remis a
--      BUDGET_DEFAULT a chaque rechargement.
--   3. plateau-justice-economie.js, mettreAJourBudgets -- MORT : zero appelant, et
--      `state.budgetsActuels` n'est jamais initialise.
--
-- LE NOUVEAU MODELE, ARBITRE LE 8 OCTOBRE 2026 POUR REPUBLIA.
--
--   impots nationaux -> MEco -> repartition nationale -> dix caisses
--                                     -> puis chaque ministere finance les institutions de son
--                                        ressort, depuis sa propre caisse.
--
-- UNE SEULE BRIQUE POUR LES DEUX NIVEAUX. Une repartition, c'est toujours la meme chose : une
-- caisse SOURCE, des BENEFICIAIRES, une PART en pourcentage, une AUTORITE habilitee a la
-- modifier. Le niveau national n'est pas un cas special : c'est la repartition dont la source
-- est la caisse du Ministere de l'Economie et des Finances, qui figure parmi ses propres
-- beneficiaires -- parce que c'est exactement sa nature de repartiteur.
--
-- LA BOUCLE EST IMPOSSIBLE PAR CONSTRUCTION : la fonction de repartition saute la ligne dont le
-- beneficiaire EST la source. Le MEco recoit la totalite des recettes, en transfere 91 %, et
-- conserve ses 9 % sans qu'ils soient redistribues.
--
-- LA DOUBLE DISTRIBUTION EST IMPOSSIBLE PAR CONSTRUCTION, elle aussi : chaque versement laisse
-- une ligne dans repartitions_versements, dont la cle primaire porte le JOUR. Un second passage
-- leve une violation d'unicite et ne verse rien. Ce n'est plus un marqueur qu'on peut oublier
-- d'ecrire, c'est la cle de la table.
--
-- CE QUI N'EST PAS INVENTE ICI. Les seules valeurs posees sont celles que le game designer a
-- arbitrees : dix caisses nationales (neuf a 9 %, l'Assemblee a 19 %), Defense -> Caserne 65 %,
-- Interieur -> Douanes 35 %. Les trois tribunaux sont declares avec une part NULLE -- pas zero,
-- NULL : « non arbitre ». La fonction ne verse rien sur une part NULL, et surtout n'invente pas
-- 33/33/34. Les usines nationales n'ont aucune ligne : leur financement recurrent par defaut est
-- 0 %, et l'absence de ligne EST ce zero.
--
-- AUCUN AUTRE EMPIRE N'Y FIGURE. Sovarka, El Estado et Al-Khalija n'ont aucune ligne : ils ne
-- recoivent donc rien, et surtout pas la cle de Republia. L'architecture est generique, les
-- valeurs sont par empire, et l'absence de configuration n'est pas un repli.
--
-- IDEMPOTENTE. Rejouable sans effet de bord.
-- AUCUN DROIT A PUBLIC NI A anon : les trois REVOKE sur chaque objet neuf (lecon du
-- 7 octobre 2026 -- `FROM PUBLIC` ne retire pas les droits que Supabase accorde NOMMEMENT a
-- anon et authenticated sur toute table neuve).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. LA DECLARATION : QUI REPARTIT VERS QUI, QUELLE PART, SOUS QUELLE AUTORITE
-- -----------------------------------------------------------------------------
-- `source` et `beneficiaire` sont des MOTIFS DE CAISSE, au sens de caisses_autorites et de
-- caisse_territoire() : le suffixe qui suit `<pays>_`. On reutilise donc l'identite de caisse
-- deja canonique, sans en inventer une seconde.
--
-- `part_pourcent` NULL signifie NON ARBITRE, et se distingue de 0 qui signifie « rien, et c'est
-- decide ». La fonction de repartition ignore les deux, mais l'interface doit les montrer
-- differemment : une part nulle attend une decision, une part a zero est une decision.

CREATE TABLE IF NOT EXISTS public.repartitions_budgetaires (
  pays           text         NOT NULL,
  source         text         NOT NULL,
  beneficiaire   text         NOT NULL,
  part_pourcent  numeric(5,2),
  poste_autorite text         NOT NULL,
  rang           integer      NOT NULL,
  libelle        text         NOT NULL,
  note           text,
  PRIMARY KEY (pays, source, beneficiaire),
  CONSTRAINT repartitions_budgetaires_part_bornee
    CHECK (part_pourcent IS NULL OR (part_pourcent >= 0 AND part_pourcent <= 100))
);

COMMENT ON TABLE public.repartitions_budgetaires IS
  'Qui repartit son budget vers qui, quelle part, et quel poste peut la modifier. UNE seule table pour les deux niveaux : le national est la repartition dont la source est la caisse du Ministere de l''Economie et des Finances, qui figure parmi ses propres beneficiaires. part_pourcent NULL = non arbitre (la fonction ne verse rien) ; 0 = decide a zero.';
COMMENT ON COLUMN public.repartitions_budgetaires.source IS
  'Motif de caisse source, au sens de caisses_autorites : le suffixe qui suit <pays>_.';
COMMENT ON COLUMN public.repartitions_budgetaires.beneficiaire IS
  'Motif de caisse beneficiaire. Quand il est egal a la source, la ligne est journalisee mais JAMAIS transferee : c''est la part que le repartiteur conserve.';
COMMENT ON COLUMN public.repartitions_budgetaires.part_pourcent IS
  'NULL = non arbitre : rien n''est verse, et aucune valeur par defaut n''est inventee. 0 = decide a zero.';

ALTER TABLE public.repartitions_budgetaires ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.repartitions_budgetaires FROM PUBLIC;
REVOKE ALL ON TABLE public.repartitions_budgetaires FROM anon;
REVOKE ALL ON TABLE public.repartitions_budgetaires FROM authenticated;

-- -----------------------------------------------------------------------------
-- 2. LE JOURNAL, QUI REND LA DOUBLE DISTRIBUTION IMPOSSIBLE
-- -----------------------------------------------------------------------------
-- La cle primaire porte le JOUR. Un second passage du cron, un rejeu, deux appels concurrents :
-- le second INSERT leve une violation d'unicite et la ligne n'est pas versee. Le garde-fou n'est
-- plus un champ `derniereDistribJour` qu'une ecriture avalee peut perdre -- c'est la cle de la
-- table.
--
-- Il sert aussi de BASE DE REFERENCE a l'interface : l'equivalent en FR d'une part se calcule
-- sur ce que la source a REELLEMENT recu la derniere fois, un fait mesure, et non sur une
-- projection inventee.

CREATE TABLE IF NOT EXISTS public.repartitions_versements (
  pays          text        NOT NULL,
  source        text        NOT NULL,
  beneficiaire  text        NOT NULL,
  jour          date        NOT NULL,
  base          numeric     NOT NULL,
  part_pourcent numeric(5,2),
  montant       numeric     NOT NULL,
  transfere     boolean     NOT NULL DEFAULT true,
  verse_le      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, source, beneficiaire, jour)
);

COMMENT ON TABLE public.repartitions_versements IS
  'Journal des versements de repartition, une ligne par (pays, source, beneficiaire, jour). La cle primaire porte le jour : elle rend la double distribution impossible par construction, et non par un marqueur qu''une ecriture avalee peut perdre. transfere=false marque la part que le repartiteur conserve (beneficiaire = source) : elle est journalisee pour que le circuit soit lisible, mais aucun mouvement n''a lieu.';

ALTER TABLE public.repartitions_versements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.repartitions_versements FROM PUBLIC;
REVOKE ALL ON TABLE public.repartitions_versements FROM anon;
REVOKE ALL ON TABLE public.repartitions_versements FROM authenticated;

-- -----------------------------------------------------------------------------
-- 3. LA CAISSE DES DOUANES, ET SON AUTORITE
-- -----------------------------------------------------------------------------
-- Les Douanes n'avaient PAS de caisse : douane_payer_effectifs debitait directement
-- `<pays>_gouvernement-min_int`, en ouvrant la porte interne de la primitive pour une
-- transaction. La decision du 8 octobre leur en donne une, financee par l'Interieur a 35 %.
--
-- L'AUTORITE N'EST PAS INVENTEE : elle applique la decision deja enregistree (« les douanes
-- doivent disposer de leur propre caisse geree par leur responsable et financee par
-- l'Interieur »). Le Chef des Douanes la gere, le Ministre de l'Interieur la finance et garde
-- autorite dessus -- exactement le couple deja declare pour le commissariat
-- (commissaire + min_int) et pour la caserne (commandant + min_def).

INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note)
VALUES ('douane', false, ARRAY['chef_douanes','min_int'],
        'Caisse du service des douanes. Geree par le Chef des Douanes, financee par le Ministere de l''Interieur qui garde autorite dessus -- meme couple que commissariat et caserne.')
ON CONFLICT (motif) DO UPDATE
  SET est_prefixe = excluded.est_prefixe,
      postes_debit = excluded.postes_debit,
      note = excluded.note;

INSERT INTO public.caisses_batiments (id, data, updated_at)
VALUES ('republic_douane', jsonb_build_object('solde', 0), now())
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3bis. LE PALAIS DU GOUVERNEMENT CESSE D'ETRE UN VESTIGE
-- -----------------------------------------------------------------------------
-- L'audit fiscal du 5 octobre 2026 avait tranche l'inverse, et il avait raison AVEC LES REGLES
-- DE L'EPOQUE : baseline/DIFFERENCES-DELIBEREES.json le declarait « VESTIGE. Caisse canonique du
-- Premier ministre : gouvernement-pm. Le palais est un batiment dont chaque piece porte la caisse
-- de son ministere ; le batiment lui-meme n'est dans aucune table de caisse et rien ne le
-- credite. » Et dotations-financieres-republia.csv portait « NE PAS DOTER ».
--
-- L'ARBITRAGE DU 8 OCTOBRE 2026 LE RESSUSCITE, et c'est une decision, pas un oubli : la caisse
-- du Palais du Gouvernement devient la DIXIEME caisse nationale, a 9 %, destinee aux actions
-- gouvernementales communes -- communication et autres depenses institutionnelles du
-- gouvernement. Elle est DISTINCTE de la caisse du Premier ministre (gouvernement-pm), qui reste
-- son enveloppe propre et porte son salaire.
--
-- La ligne existe deja en base avec un solde de 0 (mesure du 7 octobre 2026) ; l'INSERT ci-
-- dessous
-- n'est la que pour qu'une base reconstruite depuis zero la porte aussi. Son autorite de debit
-- (caisses_autorites, motif 'palais-gouvernement', postes_debit {pm}) est inchangee : le Premier
-- ministre engage les actions gouvernementales.
INSERT INTO public.caisses_batiments (id, data, updated_at)
VALUES ('republic_palais-gouvernement', jsonb_build_object('solde', 0), now())
ON CONFLICT (id) DO NOTHING;

UPDATE public.caisses_autorites
   SET note = 'Caisse des actions gouvernementales communes -- communication et autres depenses institutionnelles du gouvernement. DIXIEME caisse nationale depuis l''arbitrage du 8 octobre 2026, a 9 %. Distincte de gouvernement-pm, enveloppe propre du Premier ministre. Engagee par le pm.'
 WHERE motif = 'palais-gouvernement';

-- -----------------------------------------------------------------------------
-- 4. LES LIGNES DE REPUBLIA
-- -----------------------------------------------------------------------------

DELETE FROM public.repartitions_budgetaires WHERE pays = 'republic';

-- NIVEAU NATIONAL -- source : la caisse du Ministere de l'Economie et des Finances.
-- Neuf caisses a 9 %, l'Assemblee a 19 %. Total exactement 100 %.
-- La ligne `gouvernement-min_fin -> gouvernement-min_fin` est la part que le repartiteur
-- conserve : journalisee, jamais transferee.
INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES
  ('republic','gouvernement-min_fin','palais-presidentiel',   9.00,'min_fin', 1,'Présidence',                       NULL),
  ('republic','gouvernement-min_fin','gouvernement-pm',       9.00,'min_fin', 2,'Premier ministre',                 NULL),
  ('republic','gouvernement-min_fin','gouvernement-min_int',  9.00,'min_fin', 3,'Ministère de l''Intérieur',        NULL),
  ('republic','gouvernement-min_fin','gouvernement-min_fin',  9.00,'min_fin', 4,'Ministère de l''Économie et des Finances',
   'Part conservee par le repartiteur : journalisee, jamais transferee. C''est ce qui empeche la boucle.'),
  ('republic','gouvernement-min_fin','gouvernement-min_just', 9.00,'min_fin', 5,'Ministère de la Justice',          NULL),
  ('republic','gouvernement-min_fin','gouvernement-min_def',  9.00,'min_fin', 6,'Ministère de la Défense',          NULL),
  ('republic','gouvernement-min_fin','gouvernement-min_info', 9.00,'min_fin', 7,'Ministère de l''Information',      NULL),
  ('republic','gouvernement-min_fin','gouvernement-min_ae',   9.00,'min_fin', 8,'Ministère des Affaires étrangères',NULL),
  ('republic','gouvernement-min_fin','palais-gouvernement',   9.00,'min_fin', 9,'Palais du Gouvernement',
   'Actions gouvernementales communes -- communication et autres depenses institutionnelles. DISTINCTE de la caisse du Premier ministre.'),
  ('republic','gouvernement-min_fin','assemblee',            19.00,'min_fin',10,'Assemblée nationale',              NULL);

-- NIVEAU MINISTERIEL -- chaque ministere finance les institutions de son ressort.
INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note) VALUES
  ('republic','gouvernement-min_def','caserne-militaire', 65.00,'min_def', 1,'Caserne militaire',
   'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.'),
  ('republic','gouvernement-min_int','douane',            35.00,'min_int', 1,'Service des douanes',
   'Valeur par defaut arbitree le 8 octobre 2026. Le ministre peut la modifier.'),
  -- LES TROIS TRIBUNAUX : part NULLE, et c'est deliberе. Le mecanisme est valide, les
  -- pourcentages ne sont PAS arbitres. La fonction ne verse rien tant qu'ils le restent, et
  -- surtout n'invente pas 33/33/34. L'argent reste au Ministere de la Justice.
  ('republic','gouvernement-min_just','tribunal_capitale', NULL,'min_just', 1,'Tribunal de Luthécia',
   'Part NON ARBITREE au 8 octobre 2026 : mecanisme valide, pourcentage a decider.'),
  ('republic','gouvernement-min_just','tribunal_ville_a',  NULL,'min_just', 2,'Tribunal de Port-Sainte-Marie',
   'Part NON ARBITREE au 8 octobre 2026.'),
  ('republic','gouvernement-min_just','tribunal_ville_b',  NULL,'min_just', 3,'Tribunal de Montrouge',
   'Part NON ARBITREE au 8 octobre 2026.');

-- -----------------------------------------------------------------------------
-- 5. LA REPARTITION, EXECUTEE PAR LE SERVEUR ET PAR LUI SEUL
-- -----------------------------------------------------------------------------
-- METHODE DU PLUS FORT RESTE (Hamilton), la meme que la repartition territoriale : chaque
-- beneficiaire recoit le plancher de sa part exacte, puis le reliquat va 1 FR a la fois a ceux
-- dont la part decimale perdue est la plus grande, egalite departagee par le rang declare. La
-- somme versee est donc exactement egale a la part distribuable -- aucun FR perdu par arrondi,
-- et un resultat identique quel que soit le soir.
--
-- RESERVEE AU SERVEUR. Aucun role client n'a EXECUTE : le montant de base ne doit jamais venir
-- d'un navigateur. C'est le cron qui l'appelle, et lui seul.

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
              r.beneficiaire <> p_source);
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
  'Execute la repartition declaree pour (pays, source) sur une base donnee. Plus fort reste, aucun FR perdu. Les parts NULL sont ignorees : rien n''est invente. La ligne dont le beneficiaire est la source est journalisee mais jamais transferee -- c''est ce qui empeche la boucle du repartiteur. La cle primaire du journal porte le jour : la double distribution est impossible par construction. RESERVEE AU SERVEUR : la base ne doit jamais venir d''un navigateur.';

REVOKE ALL ON FUNCTION public.budget_repartir(text, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_repartir(text, text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 5bis. LA CASCADE COMPLETE, EN UNE SEULE TRANSACTION
-- -----------------------------------------------------------------------------
-- Le cron n'orchestre rien : il dit « voici les recettes du jour » et le serveur fait le reste,
-- atomiquement. S'il echoue a mi-chemin, rien n'est verse -- au lieu d'un budget national
-- distribue et de ministeres qui n'ont pas reparti.
--
-- L'ORDRE EST CELUI DE L'ARBITRAGE :
--   1. les recettes entrent dans la caisse du MEco -- la totalite, parce qu'il est le
--      repartiteur et que l'argent doit VISIBLEMENT y transiter ;
--   2. le MEco repartit vers les dix caisses nationales, en conservant sa propre part ;
--   3. chaque ministere repartit a son tour vers les institutions de son ressort, sur la base
--      de ce qu'il VIENT de recevoir -- lu dans le journal, pas recalcule.
--
-- POURQUOI LA BASE D'UN MINISTERE EST SA PART RECUE, ET NON SON SOLDE. Un pourcentage du SOLDE
-- ferait croitre le versement chaque nuit ou le ministre ne depense rien, et le rendrait
-- imprevisible. « 65 % du budget du ministere » designe 65 % de ce que le ministere RECOIT :
-- c'est la lecture budgetaire, elle est stable, et elle se compose proprement avec le niveau
-- national. Le transfert reste plafonne par le solde reel, ce qui traite le cas ou le ministere
-- a deja depense.
CREATE OR REPLACE FUNCTION public.budget_cascade_quotidienne(p_pays text, p_recettes numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_repartiteur constant text := 'gouvernement-min_fin';
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_base numeric := floor(coalesce(p_recettes, 0));
  v_national jsonb; v_etapes jsonb := '[]'::jsonb;
  v_rep jsonb; r record; v_recu numeric;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUCUNE LIGNE DECLAREE = AUCUNE DISTRIBUTION. C'est le cas des trois autres empires : ils ne
  -- recoivent rien, et surtout pas la cle de Republia.
  IF NOT EXISTS (SELECT 1 FROM public.repartitions_budgetaires
                  WHERE pays = p_pays AND source = c_repartiteur) THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucune_repartition_declaree',
                              'pays', p_pays, 'verse', 0);
  END IF;

  IF v_base <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'recettes_nulles', 'verse', 0);
  END IF;

  -- 1. LES RECETTES ENTRENT CHEZ LE REPARTITEUR. Garde d'idempotence : si le journal porte deja
  -- une ligne du jour pour cette source, la cascade a tourne -- on ne credite pas une seconde
  -- fois.
  IF EXISTS (SELECT 1 FROM public.repartitions_versements
              WHERE pays = p_pays AND source = c_repartiteur AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'cascade_deja_passee_ce_jour',
                              'jour', v_jour, 'verse', 0);
  END IF;

  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(p_pays || '_' || c_repartiteur, v_base, false);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_recettes_refusee',
                              'detail', v_rep);
  END IF;

  -- 2. LE NIVEAU NATIONAL.
  v_national := public.budget_repartir(p_pays, c_repartiteur, v_base);
  v_etapes := v_etapes || jsonb_build_array(v_national);

  -- 3. LES NIVEAUX MINISTERIELS, sur la base de ce que chacun vient de recevoir.
  FOR r IN SELECT DISTINCT b.source
             FROM public.repartitions_budgetaires b
            WHERE b.pays = p_pays AND b.source <> c_repartiteur
            ORDER BY b.source
  LOOP
    SELECT v.montant INTO v_recu
      FROM public.repartitions_versements v
     WHERE v.pays = p_pays AND v.source = c_repartiteur
       AND v.beneficiaire = r.source AND v.jour = v_jour;
    -- Un ministere qui n'est pas beneficiaire du niveau national n'a pas de base : on ne
    -- devine pas, on ne repartit pas.
    IF v_recu IS NULL OR v_recu <= 0 THEN
      v_etapes := v_etapes || jsonb_build_array(jsonb_build_object(
        'source', r.source, 'ok', true, 'raison', 'aucune_part_recue_ce_jour'));
      CONTINUE;
    END IF;
    v_etapes := v_etapes || jsonb_build_array(public.budget_repartir(p_pays, r.source, v_recu));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'jour', v_jour,
                            'recettes', v_base, 'etapes', v_etapes);
END;
$function$;

COMMENT ON FUNCTION public.budget_cascade_quotidienne(text, numeric) IS
  'La cascade budgetaire quotidienne, en UNE transaction : les recettes entrent chez le repartiteur (MEco), qui repartit vers les dix caisses nationales en conservant sa part, puis chaque ministere repartit vers les institutions de son ressort sur la base de ce qu''il vient de recevoir (lu dans le journal). Un empire sans ligne declaree ne recoit rien. RESERVEE AU SERVEUR.';

REVOKE ALL ON FUNCTION public.budget_cascade_quotidienne(text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_cascade_quotidienne(text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 6. MODIFIER UNE PART -- l'autorite est relue en base, jamais annoncee par le client
-- -----------------------------------------------------------------------------
-- Le navigateur saisit une decision ; il ne decide ni de la caisse source, ni du beneficiaire,
-- ni de son propre droit. La ligne doit EXISTER : on ne cree pas un beneficiaire depuis un
-- navigateur.

CREATE OR REPLACE FUNCTION public.budget_repartition_fixer(p_source text, p_beneficiaire text, p_part numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; r record;
  v_part numeric; v_somme numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country,'republic'), poste->>'id' INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO r FROM public.repartitions_budgetaires
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_non_declaree',
                              'source', p_source, 'beneficiaire', p_beneficiaire);
  END IF;
  IF v_poste IS DISTINCT FROM r.poste_autorite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', r.poste_autorite);
  END IF;

  v_part := round(coalesce(p_part, 0)::numeric, 2);
  IF v_part < 0 OR v_part > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'part_hors_bornes');
  END IF;

  -- LA SOMME NE DEPASSE JAMAIS 100 %. Verifiee ICI, au serveur : une somme a 110 % versee par
  -- un client modifie distribuerait plus que les recettes.
  SELECT coalesce(sum(part_pourcent), 0) + v_part INTO v_somme
    FROM public.repartitions_budgetaires
   WHERE pays = v_pays AND source = p_source AND part_pourcent IS NOT NULL
     AND beneficiaire <> p_beneficiaire;
  IF v_somme > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'somme_depasse_cent',
                              'somme_obtenue', v_somme);
  END IF;

  UPDATE public.repartitions_budgetaires SET part_pourcent = v_part
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'source', p_source,
                            'beneficiaire', p_beneficiaire, 'part', v_part, 'somme', v_somme);
END;
$function$;

COMMENT ON FUNCTION public.budget_repartition_fixer(text, text, numeric) IS
  'Fixe la part d''un beneficiaire declare. L''acteur vient de mon_personnage(), son pays et son poste de sa fiche : le navigateur n''annonce jamais son droit. La ligne doit exister -- on ne cree pas un beneficiaire depuis un navigateur -- et la somme des parts d''une source ne peut jamais depasser 100 %.';

REVOKE ALL ON FUNCTION public.budget_repartition_fixer(text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_repartition_fixer(text, text, numeric) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. LIRE UNE REPARTITION -- une regle, deux representations
-- -----------------------------------------------------------------------------
-- LE POURCENTAGE EST LA REGLE. Le montant en FR est une REPRESENTATION, calculee sur la base du
-- DERNIER VERSEMENT REELLEMENT RECU par la caisse source -- un fait mesure, lu dans le journal,
-- et non une projection. Les deux ne peuvent donc pas diverger : il n'y a qu'une regle.
--
-- Quand la source n'a encore rien recu, `base_reference` est NULL et l'interface doit le dire
-- plutot que d'afficher un montant invente.

CREATE OR REPLACE FUNCTION public.budget_repartition_lire(p_source text)
RETURNS TABLE (
  beneficiaire text, libelle text, part_pourcent numeric, rang integer,
  poste_autorite text, est_la_source boolean,
  solde_beneficiaire numeric, base_reference numeric, equivalent_fr numeric,
  dernier_versement numeric, dernier_jour date, note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_base numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;
  SELECT coalesce(country,'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- La base de reference : ce que la SOURCE a recu lors du dernier versement la concernant.
  SELECT v.montant INTO v_base
    FROM public.repartitions_versements v
   WHERE v.pays = v_pays AND v.beneficiaire = p_source
   ORDER BY v.jour DESC LIMIT 1;

  RETURN QUERY
  SELECT b.beneficiaire, b.libelle, b.part_pourcent, b.rang, b.poste_autorite,
         (b.beneficiaire = b.source) AS est_la_source,
         (SELECT CASE WHEN jsonb_typeof(c.data->'solde') = 'number'
                      THEN (c.data->>'solde')::numeric ELSE 0 END
            FROM public.caisses_batiments c WHERE c.id = v_pays || '_' || b.beneficiaire),
         v_base,
         CASE WHEN v_base IS NULL OR b.part_pourcent IS NULL THEN NULL
              ELSE floor(v_base * b.part_pourcent / 100) END,
         (SELECT v.montant FROM public.repartitions_versements v
           WHERE v.pays = b.pays AND v.source = b.source AND v.beneficiaire = b.beneficiaire
           ORDER BY v.jour DESC LIMIT 1),
         (SELECT v.jour FROM public.repartitions_versements v
           WHERE v.pays = b.pays AND v.source = b.source AND v.beneficiaire = b.beneficiaire
           ORDER BY v.jour DESC LIMIT 1),
         b.note
    FROM public.repartitions_budgetaires b
   WHERE b.pays = v_pays AND b.source = p_source
   ORDER BY b.rang;
END;
$function$;

COMMENT ON FUNCTION public.budget_repartition_lire(text) IS
  'Lit la repartition declaree d''une source, pour l''interface. UNE regle -- le pourcentage -- et DEUX representations : la part, et son equivalent en FR calcule sur le dernier versement REELLEMENT recu par la source (lu dans le journal, jamais projete). base_reference NULL = la source n''a encore rien recu, et l''interface doit le dire plutot qu''inventer un montant.';

REVOKE ALL ON FUNCTION public.budget_repartition_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_repartition_lire(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. LES DOUANES SE PAIENT SUR LEUR PROPRE CAISSE
-- -----------------------------------------------------------------------------
-- Seule la caisse change : `<pays>_douane` au lieu de `<pays>_gouvernement-min_int`. Tout le
-- reste -- l'autorite du Chef des Douanes, le marqueur de journee, le depart des derniers
-- recrutes quand le versement ne couvre pas tout -- est repris a l'identique.

CREATE OR REPLACE FUNCTION public.douane_payer_effectifs(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_cout_standard  constant integer := 50;
  c_cout_cynophile constant integer := 100;
  c_ville    constant text := 'ville_a';
  c_batiment constant text := 'port-sainte-marie';
  v_serveur boolean; v_moi text; v_poste text;
  v_id text; v_data jsonb; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_jour date; v_deja text;
  v_du numeric := 0; v_verse numeric; v_r jsonb;
  v_n integer; v_gardes integer := 0; v_cumul numeric := 0; v_el jsonb;
  v_caisse text;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'chef_douanes' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND country = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  v_jour   := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_id     := p_pays || '_' || c_ville || '_' || c_batiment;
  -- LA CAISSE DES DOUANES, depuis le 8 octobre 2026. C'etait gouvernement-min_int : le service
  -- n'avait pas de caisse propre, et son personnel etait paye directement par le ministere.
  v_caisse := p_pays || '_douane';

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;
  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_eff  := v_etat -> 'effectifsDouane';
  IF v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;

  v_deja := v_eff ->> 'dernierPaiementJour';
  IF v_deja = v_jour::text THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_paye', 'jour', v_jour, 'verse', 0);
  END IF;

  v_liste := COALESCE(v_eff -> 'douaniers', '[]'::jsonb);
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_n := jsonb_array_length(v_liste);
  IF v_n = 0 THEN
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'raison', 'effectif_vide', 'jour', v_jour, 'verse', 0);
  END IF;

  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                        THEN c_cout_cynophile ELSE c_cout_standard END;
  END LOOP;

  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_r := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','debit_refuse'));
  END IF;
  v_verse := COALESCE((v_r->>'verse')::numeric, 0);

  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                              THEN c_cout_cynophile ELSE c_cout_standard END;
    EXIT WHEN v_cumul > v_verse;
    v_gardes := v_gardes + 1;
  END LOOP;

  IF v_gardes < v_n THEN
    SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
      FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
     WHERE o <= v_gardes;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','douaniers'], v_liste, true);
  END IF;
  v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                      to_jsonb(v_jour::text), true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'du', v_du, 'verse', v_verse,
                            'effectif_avant', v_n, 'effectif_apres', v_gardes,
                            'partis', v_n - v_gardes, 'caisse', v_caisse);
END;
$function$;

COMMENT ON FUNCTION public.douane_payer_effectifs(text) IS
  'Paie les douaniers PNJ du port. Depuis le 8 octobre 2026, la caisse payeuse est <pays>_douane -- le service a sa propre caisse, financee par le Ministere de l''Interieur a 35 % (repartitions_budgetaires). Autorite : chef_douanes, ou le serveur.';

REVOKE ALL ON FUNCTION public.douane_payer_effectifs(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.douane_payer_effectifs(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 9. LE CONTROLE DE COHERENCE BUDGETAIRE
-- -----------------------------------------------------------------------------
-- Les invariants que le game designer a nommes, verifiables a la demande.

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
  -- chaque nuit en silence. Les parts NULL sont exclues : elles ne versent rien.
  SELECT 'beneficiaire sans caisse en base',
         string_agg(b.pays || '_' || b.beneficiaire, ', ' ORDER BY b.beneficiaire)
    FROM public.repartitions_budgetaires b
   WHERE b.part_pourcent IS NOT NULL AND b.part_pourcent > 0
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
  HAVING count(*) > 0;
$function$;

COMMENT ON FUNCTION public.budget_coherence() IS
  'Quatre invariants de l''architecture budgetaire : aucune somme de parts au-dela de 100 %, aucun beneficiaire a part non nulle sans caisse en base, aucun poste d''autorite inconnu, aucun double versement le meme jour.';

REVOKE ALL ON FUNCTION public.budget_coherence() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_coherence() TO service_role;

COMMIT;
