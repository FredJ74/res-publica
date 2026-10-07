-- =============================================================================
-- BANC D'ESSAI DE LA CASCADE BUDGETAIRE -- chantier 4F, 7 octobre 2026
-- =============================================================================
--
-- POURQUOI CE FICHIER EXISTE. La brique budgetaire deplace de l'argent chaque nuit. On ne la
-- verifie pas en la regardant : on la fait tourner. Mais la seule base joignable depuis cette
-- machine est la PRODUCTION, et la production est interdite en ecriture.
--
-- LA METHODE. Chaque epreuve est un bloc DO qui ecrit pour de vrai, mesure, puis LEVE UNE
-- EXCEPTION dont le message porte le rapport. L'exception annule la transaction : rien n'est
-- ecrit, et le resultat revient quand meme. C'est la meme technique que le dry-run des
-- migrations (voir WORKFLOW-SUPABASE.md).
--
-- COMMENT LE REJOUER. Chaque bloc se colle tel quel dans execute_sql. Le resultat arrive sous
-- forme d'erreur P0001 -- c'est le succes attendu. Apres chaque bloc, verifier que rien n'a
-- bouge :
--     SELECT count(*) FROM public.repartitions_versements;                       -- 0
--     SELECT source, beneficiaire, part_pourcent FROM public.repartitions_budgetaires
--      WHERE source <> 'gouvernement-min_fin' ORDER BY source;                   -- 65.00 / 35.00
--
-- LES RESULTATS MESURES LE 8 OCTOBRE 2026 sont recopies sous chaque bloc. Ce ne sont pas des
-- attentes ecrites a l'avance : ce sont les reponses que la base a donnees.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- EPREUVE 1 -- SOMME, ARRONDIS, CASCADE, ET DOUBLE DISTRIBUTION
-- -----------------------------------------------------------------------------
-- La base choisie est 24 601 FR : un nombre PREMIER, pour qu'aucune part ne tombe juste et que
-- le plus fort reste ait quelque chose a repartir. 24 601 x 9 %% = 2 214,09 et x 19 %% =
-- 4 674,19 : la somme des planchers vaut 24 600, il reste donc exactement 1 FR a placer.

DO $$
DECLARE
  v1 jsonb; v2 jsonb; v_rapport text := E'\n';
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_somme numeric; v_base numeric := 24601;
  v_avant numeric; v_apres numeric;
BEGIN
  SELECT (data->>'solde')::numeric INTO v_avant
    FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_fin';

  v1 := public.budget_cascade_quotidienne('republic', v_base);

  v_rapport := v_rapport || 'parts nationales : ' || (SELECT string_agg(
      beneficiaire || '=' || montant, ' ' ORDER BY beneficiaire)
    FROM public.repartitions_versements
   WHERE pays='republic' AND source='gouvernement-min_fin' AND jour=v_jour) || E'\n';

  SELECT sum(montant) INTO v_somme FROM public.repartitions_versements
   WHERE pays='republic' AND source='gouvernement-min_fin' AND jour=v_jour;
  v_rapport := v_rapport || 'somme = ' || v_somme || ' / base ' || v_base
    || ' -> aucun FR perdu : ' || CASE WHEN v_somme = v_base THEN 'OUI' ELSE 'NON' END || E'\n';

  v_rapport := v_rapport || 'ministeriels : ' || coalesce((SELECT string_agg(
      source || '->' || beneficiaire || '=' || montant, '  ' ORDER BY source, beneficiaire)
    FROM public.repartitions_versements
   WHERE pays='republic' AND source <> 'gouvernement-min_fin' AND jour=v_jour), '(aucun)') || E'\n';

  v2 := public.budget_cascade_quotidienne('republic', v_base);
  v_rapport := v_rapport || '2e passage : ok=' || (v2->>'ok')
    || '  raison=' || coalesce(v2->>'raison','(aucune)')
    || '  verse=' || coalesce(v2->>'verse','?') || E'\n';

  SELECT count(*) INTO v_somme FROM public.repartitions_versements WHERE jour=v_jour;
  v_rapport := v_rapport || 'lignes de journal apres DEUX passages = ' || v_somme || E'\n';

  SELECT (data->>'solde')::numeric INTO v_apres
    FROM public.caisses_batiments WHERE id = 'republic_gouvernement-min_fin';
  v_rapport := v_rapport || 'MEco : ' || v_avant || ' -> ' || v_apres || E'\n';

  RAISE EXCEPTION 'RAPPORT (transaction annulee, rien n''est ecrit) : %', v_rapport;
END $$;

-- RESULTAT MESURE LE 8 OCTOBRE 2026
--   parts nationales : assemblee=4675 gouvernement-min_ae=2214 gouvernement-min_def=2214
--                      gouvernement-min_fin=2214 gouvernement-min_info=2214
--                      gouvernement-min_int=2214 gouvernement-min_just=2214
--                      gouvernement-pm=2214 palais-gouvernement=2214 palais-presidentiel=2214
--   somme = 24601 / base 24601 -> aucun FR perdu : OUI
--   ministeriels : gouvernement-min_def->caserne-militaire=1439
--                  gouvernement-min_int->douane=774
--   2e passage : ok=true  raison=cascade_deja_passee_ce_jour  verse=0
--   lignes de journal apres DEUX passages = 12
--   MEco : 69161 -> 71375
--
-- CE QUE CHAQUE LIGNE PROUVE
--   . LES ARRONDIS. Neuf parts a 2 214 et l'Assemblee a 4 675 : le FR orphelin est alle a
--     l'Assemblee, qui avait la plus grosse partie decimale perdue (0,19 contre 0,09). Somme
--     exacte, aucun FR ni cree ni detruit.
--   . LE TRANSIT SANS BOUCLE. Le MEco gagne 2 214 net : il a recu 24 601 et distribue 22 387.
--     Sa part de 9 %% est journalisee -- elle figure bien dans les dix lignes -- mais jamais
--     transferee. C'est ce qui empeche la boucle.
--   . LA HIERARCHIE. La Defense a recu 2 214 et en a verse 65 %% a la caserne, soit 1 439.
--     L'Interieur a recu 2 214 et en a verse 35 %% aux douanes, soit 774. Chaque ministere
--     repartit sur ce qu'il VIENT de recevoir, lu dans le journal.
--   . LA JUSTICE NE VERSE RIEN, et c'est le point. Ses trois tribunaux ont une part NULLE :
--     budget_repartir() les ignore. Aucune repartition n'a ete inventee a la place.
--   . LA DOUBLE DISTRIBUTION EST IMPOSSIBLE. Le second passage rend `ok=true` et
--     `cascade_deja_passee_ce_jour` : il n'echoue pas, il constate. Le journal reste a 12
--     lignes. Ce n'est pas un champ marqueur qu'une ecriture avalee peut perdre -- c'est la
--     cle primaire, qui porte le jour.


-- -----------------------------------------------------------------------------
-- EPREUVE 2 -- L'AUTORITE EST RELUE EN BASE, ET LES BORNES TIENNENT
-- -----------------------------------------------------------------------------
-- L'acteur est un PJ REEL qui tient reellement le poste min_def (ministre de la Defense). Le
-- `sub` du JWT est son user_id ; c'est exactement ce que PostgREST pose quand il sert une
-- requete authentifiee, donc le serveur voit la meme chose qu'en vrai.
--
-- A REMPLACER PAR UN AUTRE PJ si celui-ci perd le poste : la requete qui donne un candidat est
--     SELECT p.name, p.user_id FROM public.personnages p WHERE p.user_id IS NOT NULL;
-- et ses postes se lisent par public.acteur_poste_courant() une fois le claim pose.

DO $$
DECLARE r jsonb; v text := E'\n'; v_part numeric;
BEGIN
  PERFORM set_config('request.jwt.claims',
    '{"sub":"9abef1c4-75ab-4352-b5ca-a219fc37a35c","role":"authenticated"}', true);
  v := v || 'acteur : ' || coalesce(public.mon_personnage(),'(aucun)') || ', postes : '
    || coalesce((SELECT string_agg(poste_id, ', ') FROM public.acteur_poste_courant()),'(aucun)')
    || E'\n\nSA SOURCE -- gouvernement-min_def\n';

  r := public.budget_repartition_fixer('gouvernement-min_def', 'caserne-militaire', 50);
  SELECT part_pourcent INTO v_part FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_def' AND beneficiaire='caserne-militaire';
  v := v || '  65 -> 50        : ok=' || (r->>'ok') || '  part en base = ' || v_part || E'\n';
  r := public.budget_repartition_fixer('gouvernement-min_def', 'caserne-militaire', 101);
  v := v || '  -> 101 %%        : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';
  r := public.budget_repartition_fixer('gouvernement-min_def', 'caserne-militaire', -5);
  v := v || '  -> -5 %%         : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';

  v := v || E'\nUNE SOURCE QUI N''EST PAS LA SIENNE\n';
  r := public.budget_repartition_fixer('gouvernement-min_fin', 'assemblee', 19);
  v := v || '  budget national  : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';
  r := public.budget_repartition_fixer('gouvernement-min_int', 'douane', 10);
  v := v || '  budget Interieur : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';
  r := public.budget_repartition_fixer('gouvernement-min_just', 'tribunal_capitale', 33);
  v := v || '  budget Justice   : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';

  r := public.budget_repartition_fixer('gouvernement-min_def', 'caisse-inventee', 5);
  v := v || E'\n  beneficiaire inexistant : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';

  v := v || E'\nLA CASCADE, RESERVEE AU SERVEUR\n';
  v := v || '  budget_repartir            / authenticated : '
    || has_function_privilege('authenticated','public.budget_repartir(text,text,numeric)','EXECUTE')::text || E'\n';
  v := v || '  budget_cascade_quotidienne / authenticated : '
    || has_function_privilege('authenticated','public.budget_cascade_quotidienne(text,numeric)','EXECUTE')::text || E'\n';
  v := v || '  budget_repartir            / anon          : '
    || has_function_privilege('anon','public.budget_repartir(text,text,numeric)','EXECUTE')::text || E'\n';

  RAISE EXCEPTION 'TESTS D''AUTORITE ET DE BORNES (transaction annulee) : %', v;
END $$;

-- RESULTAT MESURE LE 8 OCTOBRE 2026
--   acteur : Arnie, postes : min_def
--   SA SOURCE -- gouvernement-min_def
--     65 -> 50        : ok=true  part en base = 50.00
--     -> 101 %%        : ok=false raison=part_hors_bornes
--     -> -5 %%         : ok=false raison=part_hors_bornes
--   UNE SOURCE QUI N'EST PAS LA SIENNE
--     budget national  : ok=false raison=autorite_insuffisante
--     budget Interieur : ok=false raison=autorite_insuffisante
--     budget Justice   : ok=false raison=autorite_insuffisante
--     beneficiaire inexistant : ok=false raison=repartition_non_declaree
--   LA CASCADE, RESERVEE AU SERVEUR
--     budget_repartir            / authenticated : false
--     budget_cascade_quotidienne / authenticated : false
--     budget_repartir            / anon          : false
--
-- UN PIEGE DE LECTURE, RENCONTRE EN ECRIVANT CE BANC. Au premier jet, la ligne « PJ sans le
-- poste min_def » rendait ok=true et j'y ai lu un trou d'autorite. C'etait l'ETIQUETTE qui etait
-- fausse : Arnie tient min_def. La lecon tient en une phrase -- un banc d'autorite doit afficher
-- les postes REELS de l'acteur, sinon il ne prouve rien et peut accuser a tort. C'est pourquoi la
-- premiere ligne du rapport les liste.
--
-- SANS AUCUNE IDENTITE (service_role, sans claim JWT), les quatre appels rendent
-- `acteur_non_authentifie` : la fonction est fail closed au tout premier verrou. Il n'y a
-- deliberement AUCUN chemin serveur dans budget_repartition_fixer -- modifier une cle de
-- repartition est l'acte d'un ministre, jamais celui d'un automate.


-- -----------------------------------------------------------------------------
-- EPREUVE 3 -- LA GARDE DE SOMME, SUR UNE SOURCE A DEUX LIGNES
-- -----------------------------------------------------------------------------
-- Aucune source ministerielle ne porte deux beneficiaires aujourd'hui : la garde de somme
-- n'aurait donc rien a garder. Le serveur declare une seconde ligne de banc pour la duree de la
-- transaction, puis le ministre tente de pousser le total au-dela de 100 %%.

DO $$
DECLARE r jsonb; v text := E'\n'; v_tot numeric;
BEGIN
  INSERT INTO public.repartitions_budgetaires
    (pays, source, beneficiaire, part_pourcent, poste_autorite, rang, libelle, note)
  VALUES ('republic','gouvernement-min_def','qhs-prison', 20, 'min_def', 2, 'Banc d''essai', 'banc');

  PERFORM set_config('request.jwt.claims',
    '{"sub":"9abef1c4-75ab-4352-b5ca-a219fc37a35c","role":"authenticated"}', true);

  SELECT sum(part_pourcent) INTO v_tot FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_def';
  v := v || 'total de depart : ' || v_tot || ' %% (caserne 65 + banc 20)' || E'\n';

  r := public.budget_repartition_fixer('gouvernement-min_def', 'qhs-prison', 35);
  v := v || 'banc 20 -> 35 (total 100) : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';
  r := public.budget_repartition_fixer('gouvernement-min_def', 'qhs-prison', 36);
  v := v || 'banc 35 -> 36 (total 101) : ok=' || (r->>'ok') || ' raison=' || coalesce(r->>'raison','-') || E'\n';

  SELECT sum(part_pourcent) INTO v_tot FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_def';
  v := v || 'total apres le refus      : ' || v_tot || ' %%' || E'\n';
  RAISE EXCEPTION 'GARDE DE SOMME (transaction annulee) : %', v;
END $$;

-- RESULTAT MESURE LE 8 OCTOBRE 2026
--   total de depart : 85.00 %% (caserne 65 + banc 20)
--   banc 20 -> 35 (total 100) : ok=true raison=-
--   banc 35 -> 36 (total 101) : ok=false raison=somme_depasse_cent
--   total apres le refus      : 100.00 %%
--
-- CE QUE CELA PROUVE. Exactement 100 %% passe ; 101 %% est refuse ; et le refus ne laisse rien
-- derriere lui -- le total reste a 100, pas a un etat intermediaire. Le navigateur ne peut donc
-- pas ecrire une cle a 110 %% en contournant l'ecran : la garde est en base, pas dans le
-- formulaire.


-- -----------------------------------------------------------------------------
-- EPREUVE 4 -- UNE PART A 0 % EST UNE CONFIGURATION, PAS UNE ABSENCE DE REGLE
-- -----------------------------------------------------------------------------
-- Arbitrage du 7 octobre 2026 : le QHS releve budgetairement de l'Interieur, a 0 % par defaut.
-- Les sept preuves demandees, dans l'ordre.

DO $$
DECLARE
  v jsonb; r jsonb; t text := E'\n';
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_qhs_avant numeric; v_qhs_apres numeric; v_lig record;
BEGIN
  -- (1) et (2) LES DEUX PARTS DECLAREES DE L'INTERIEUR.
  t := t || 'parts declarees de gouvernement-min_int :' || E'\n';
  FOR v_lig IN SELECT beneficiaire, part_pourcent, rang FROM public.repartitions_budgetaires
                WHERE pays='republic' AND source='gouvernement-min_int' ORDER BY rang LOOP
    t := t || '  ' || v_lig.beneficiaire || ' = '
      || coalesce(v_lig.part_pourcent::text, 'NULL') || E'\n';
  END LOOP;

  -- (3) ZERO N'EST PAS NULL. La distinction est portee par le type, et c'est tout l'arbitrage.
  t := t || E'\n' || 'QHS : part NULL ? '
    || (SELECT (part_pourcent IS NULL)::text FROM public.repartitions_budgetaires
         WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='qhs-prison')
    || '   tribunal_capitale : part NULL ? '
    || (SELECT (part_pourcent IS NULL)::text FROM public.repartitions_budgetaires
         WHERE pays='republic' AND source='gouvernement-min_just' AND beneficiaire='tribunal_capitale')
    || E'\n';

  -- (6) JUSTICE N'A AUCUNE RELATION VERS LE QHS.
  t := t || 'sources qui financent le QHS : '
    || coalesce((SELECT string_agg(source, ', ' ORDER BY source)
                   FROM public.repartitions_budgetaires WHERE beneficiaire='qhs-prison'),
                '(aucune)') || E'\n';

  -- (4) AUCUN VERSEMENT RECURRENT AU QHS TANT QUE LA PART VAUT 0 %.
  SELECT (data->>'solde')::numeric INTO v_qhs_avant
    FROM public.caisses_batiments WHERE id='republic_qhs-prison';
  v := public.budget_cascade_quotidienne('republic', 24601);
  SELECT (data->>'solde')::numeric INTO v_qhs_apres
    FROM public.caisses_batiments WHERE id='republic_qhs-prison';
  t := t || E'\n' || 'apres une cascade complete :' || E'\n';
  t := t || '  caisse du QHS : ' || v_qhs_avant || ' -> ' || v_qhs_apres || E'\n';
  t := t || '  journal Interieur : ' || coalesce((SELECT string_agg(
        beneficiaire || ' montant=' || montant || ' transfere=' || transfere, '  ' ORDER BY beneficiaire)
      FROM public.repartitions_versements
     WHERE pays='republic' AND source='gouvernement-min_int' AND jour=v_jour), '(rien)') || E'\n';
  t := t || '  journal Justice   : ' || coalesce((SELECT string_agg(
        beneficiaire || '=' || montant, ' ' ORDER BY beneficiaire)
      FROM public.repartitions_versements
     WHERE pays='republic' AND source='gouvernement-min_just' AND jour=v_jour), '(rien)') || E'\n';

  -- (5) LE VIREMENT PONCTUEL RESTE POSSIBLE, PART A 0 % COMPRISE.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  r := public.caisse_institution_mouvement('republic_gouvernement-min_int', -500, true);
  IF coalesce((r->>'ok')::boolean,false) THEN
    r := public.caisse_institution_mouvement('republic_qhs-prison', 500, false);
  END IF;
  PERFORM set_config('rp.caisse_interne', '', true);
  SELECT (data->>'solde')::numeric INTO v_qhs_apres
    FROM public.caisses_batiments WHERE id='republic_qhs-prison';
  t := t || E'\n' || 'virement ponctuel de 500 FR : ok=' || coalesce(r->>'ok','?')
    || '  caisse du QHS = ' || v_qhs_apres || E'\n';
  t := t || 'part du QHS apres le virement ponctuel : '
    || (SELECT part_pourcent FROM public.repartitions_budgetaires
         WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='qhs-prison')
    || ' %% -- un acte ne modifie pas une regle' || E'\n';

  -- (7) LES CINQ INVARIANTS, LE NOUVEAU COMPRIS.
  t := t || E'\n' || 'budget_coherence() : '
    || coalesce((SELECT string_agg(probleme, ' | ') FROM public.budget_coherence()),
                'aucun probleme') || E'\n';

  RAISE EXCEPTION 'ARBITRAGE QHS (transaction annulee) : %', t;
END $$;

-- RESULTAT MESURE LE 8 OCTOBRE 2026
--   parts declarees de gouvernement-min_int :
--     douane = 35.00
--     qhs-prison = 0.00
--   QHS : part NULL ? false   tribunal_capitale : part NULL ? true
--   sources qui financent le QHS : gouvernement-min_int
--   apres une cascade complete :
--     caisse du QHS : 200 -> 200
--     journal Interieur : douane montant=774 transfere=true  qhs-prison montant=0 transfere=false
--     journal Justice   : (rien)
--   virement ponctuel de 500 FR : ok=true  caisse du QHS = 700
--   part du QHS apres le virement ponctuel : 0.00 % -- un acte ne modifie pas une regle
--   budget_coherence() : aucun probleme
--
-- LES SEPT PREUVES, LIGNE PAR LIGNE
--   (1) MInt -> Douanes = 35 %, inchange par cet arbitrage.
--   (2) MInt -> QHS = 0 %.
--   (3) ZERO N'EST PAS NULL, et c'est la preuve centrale. `part NULL ?` rend FALSE pour le QHS et
--       TRUE pour un tribunal. Les deux ne versent rien, et c'est tout ce qu'ils ont en commun :
--       le QHS est un beneficiaire RECONNU dont la part a ete DECIDEE a zero, le tribunal attend
--       encore un arbitrage. budget_repartir applique la premiere et ignore la seconde.
--   (4) AUCUN VERSEMENT RECURRENT. La caisse du QHS ne bouge pas (200 -> 200), et pourtant le
--       journal porte une ligne `qhs-prison montant=0 transfere=false`. C'est exactement ce qu'on
--       veut : la regle a ete APPLIQUEE -- la trace le prouve -- et elle a donne zero. Une
--       absence de ligne, elle, ne distinguerait pas « regle a zero » de « pas de regle ».
--       `transfere=false` est l'apport de la migration 20261008030000 : avant elle, cette ligne
--       aurait affirme chaque nuit qu'un transfert avait eu lieu.
--   (5) LE VIREMENT PONCTUEL FONCTIONNE A 0 %. 500 FR passent, la caisse monte a 700, et la part
--       reste a 0,00 %. L'acte et la regle ne se touchent pas.
--   (6) JUSTICE N'A AUCUNE RELATION VERS LE QHS : une seule source le finance, et le journal de
--       la Justice est vide (ses trois parts sont NULL).
--   (7) LES CINQ INVARIANTS TIENNENT, y compris le nouveau -- aucune caisse financee par deux
--       sources.
--
-- APRES CE BLOC, verifie le 7 octobre 2026 : 0 versement en base, caisse du QHS a 200,
-- Interieur a 86 424, Douanes a 0, parts a 0,00 et 35,00. Rien n'a persiste.


-- -----------------------------------------------------------------------------
-- EPREUVE 5 -- TROIS PARTS RIGOUREUSEMENT EGALES, ET UN RELIQUAT QUI TOURNE
-- -----------------------------------------------------------------------------
-- Arbitrage du 7 octobre 2026 : le budget du Ministere de la Justice se repartit a PARTS EGALES
-- entre les trois tribunaux territoriaux. Pas 33,33 -- qui ne fait pas 100 a trois. Pas
-- 33,33 / 33,33 / 33,34 -- qui privilegie un tribunal pour toujours. UN TIERS EXACT.

DO $$
DECLARE
  v text := E'\n'; r jsonb; v_lig record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_num numeric; v_den numeric; v_dec integer := ((now() AT TIME ZONE 'Europe/Paris')::date - DATE '2026-01-01');
BEGIN
  SELECT numerateur, denominateur INTO v_num, v_den
    FROM public.budget_part_totale('republic','gouvernement-min_just');
  v := v || 'somme des parts Justice = ' || trim_scale(v_num)::text || '/' || trim_scale(v_den)::text
         || '  -> le tout : ' || (v_num = v_den)::text || E'\n';
  v := v || 'parts : ' || (SELECT string_agg(beneficiaire || '=' || trim_scale(part_numerateur)::text
         || '/' || trim_scale(part_denominateur)::text, '  ' ORDER BY rang)
         FROM public.repartitions_budgetaires
        WHERE pays='republic' AND source='gouvernement-min_just') || E'\n';
  v := v || 'valeurs distinctes = ' || (SELECT count(DISTINCT part_numerateur/part_denominateur)
         FROM public.repartitions_budgetaires
        WHERE pays='republic' AND source='gouvernement-min_just')::text
         || ' (1 = aucune preference structurelle)' || E'\n';

  r := public.budget_repartir('republic','gouvernement-min_just', 2215);
  v := v || E'\n' || 'base 2215 : distribuable=' || (r->>'distribuable')
         || '  verse=' || (r->>'verse') || '  parts=' || (r->>'parts_totales') || E'\n';
  v := v || '  ' || (SELECT string_agg(beneficiaire || '=' || montant, ' ' ORDER BY beneficiaire)
         FROM public.repartitions_versements
        WHERE source='gouvernement-min_just' AND jour=v_jour) || E'\n';
  v := v || '  somme versee = ' || (SELECT sum(montant) FROM public.repartitions_versements
        WHERE source='gouvernement-min_just' AND jour=v_jour)::text
         || ' / base 2215  -> aucun FR perdu : '
         || ((SELECT sum(montant) FROM public.repartitions_versements
              WHERE source='gouvernement-min_just' AND jour=v_jour) = 2215)::text || E'\n';

  -- LE RELIQUAT TOURNE AVEC LE JOUR. La cascade ne peut pas etre rejouee pour trois journees
  -- dans une seule transaction -- la cle du journal l'interdit, et c'est voulu. On rejoue donc
  -- l'EXPRESSION DE DEPARTAGE pour quatre decalages consecutifs. Deux niveaux de CTE sont
  -- necessaires : PostgreSQL refuse une fonction de fenetrage dans la definition d'une autre,
  -- et c'est pourquoi budget_repartir a lui aussi une etape `denses` separee.
  v := v || E'\n' || 'departage du reliquat, decalage du jour = ' || v_dec || ' :' || E'\n';
  FOR v_lig IN
    WITH d AS (SELECT v_dec + g AS dec FROM generate_series(0,3) g),
    denses AS (
      SELECT d.dec, b.beneficiaire, b.rang,
             row_number() OVER (PARTITION BY d.dec ORDER BY b.rang) AS position,
             count(*) OVER (PARTITION BY d.dec) AS combien
        FROM d CROSS JOIN public.repartitions_budgetaires b
       WHERE b.pays='republic' AND b.source='gouvernement-min_just'),
    classe AS (
      SELECT x.dec, x.beneficiaire,
             row_number() OVER (PARTITION BY x.dec
               ORDER BY ((x.position - 1 + x.dec) % x.combien), x.rang) AS ordre
        FROM denses x)
    SELECT dec, beneficiaire FROM classe WHERE ordre = 1 ORDER BY dec
  LOOP
    v := v || '  decalage ' || v_lig.dec || ' -> le FR orphelin va a ' || v_lig.beneficiaire || E'\n';
  END LOOP;

  RAISE EXCEPTION 'JUSTICE EN TIERS (transaction annulee) : %', v;
END $$;

-- RESULTAT MESURE LE 7 OCTOBRE 2026
--   somme des parts Justice = 3/3  -> le tout : true
--   parts : tribunal_capitale=1/3  tribunal_ville_a=1/3  tribunal_ville_b=1/3
--   valeurs distinctes = 1 (1 = aucune preference structurelle)
--   base 2215 : distribuable=2215  verse=2215  parts=3.00000000000000000000/3
--     tribunal_capitale=739 tribunal_ville_a=738 tribunal_ville_b=738
--     somme versee = 2215 / base 2215  -> aucun FR perdu : true
--   departage du reliquat, decalage du jour = 279 :
--     decalage 279 -> le FR orphelin va a tribunal_capitale
--     decalage 280 -> le FR orphelin va a tribunal_ville_b
--     decalage 281 -> le FR orphelin va a tribunal_ville_a
--     decalage 282 -> le FR orphelin va a tribunal_capitale
--
-- CE QUE CELA PROUVE
--   . TROIS PARTS EXACTEMENT EGALES. 1/3 chacune, UNE seule valeur distincte. Aucune hierarchie,
--     pas meme d'un centieme de point -- ce que 33,33 / 33,33 / 33,34 n'aurait pas permis.
--   . LA SOMME EST LE TOUT. 3/3, verifie en FRACTIONS : la somme des parts n'est pas comparee a
--     1 apres division, elle est comparee numerateur a denominateur. Le premier jet de la
--     migration divisait d'abord et obtenait 0,99999999999999999999 ; son propre controle l'a
--     refusee, et rien n'avait ete applique.
--   . AUCUN FR PERDU SUR UNE BASE NON DIVISIBLE PAR TROIS. 2215 = 739 + 738 + 738. Le
--     distribuable vaut 2215, pas 2214 : la division est ENTIERE (div), jamais un floor sur un
--     quotient decimal tronque.
--   . LE RELIQUAT NE VA PAS TOUJOURS AU MEME. Sur quatre jours consecutifs : capitale, ville_b,
--     ville_a, capitale. Chacun l'obtient une fois sur trois, et la meme journee rend toujours
--     le meme resultat -- deterministe sans etre partial. Avant ce lot, le departage se faisait
--     par le RANG : Luthecia aurait ramasse le FR orphelin chaque nuit, pour toujours. Le defaut
--     n'etait pas propre a la Justice -- les neuf caisses nationales a 9 % sont elles aussi a
--     egalite entre elles.
--
-- UNE COSMETIQUE NON CORRIGEE : `parts=3.00000000000000000000/3` dans le JSON de retour. La
-- valeur est juste, son echelle est bruyante. C'est une chaine de journal lue par le cron
-- seulement ; un trim_scale() a cet endroit ne valait pas une migration de plus.


-- -----------------------------------------------------------------------------
-- EPREUVE 6 -- LE CIRCUIT MINISTERE DE LA JUSTICE -> LES TROIS TRIBUNAUX
-- -----------------------------------------------------------------------------
-- UNE PRECAUTION DE LECTURE, PAYEE COMPTANT. Un premier jet de cette epreuve appelait
-- caisse_ministere_mouvement() depuis cette session et concluait, devant trois
-- `acteur_non_authentifie`, que budget_repartition_fixer et caisse_ministere_mouvement lisaient
-- l'autorite a deux endroits differents. C'ETAIT FAUX, et la verification l'a montre : les deux
-- lisent personnages_donnees.poste->>'id' filtre par user_id = auth.uid(). La vraie raison est
-- que exiger_poste() rend NULL quand est_appel_serveur() est vrai -- ce qui est le cas d'une
-- session service_role -- et que caisse_ministere_mouvement traite ce NULL comme un refus.
--
-- CONSEQUENCE : le virement ponctuel N'EST PAS exercable depuis une session serveur, par
-- construction. C'est un acte de ministre, et seule une session de navigateur authentifiee
-- l'obtient. Ce qui SE verifie ici, c'est la plomberie : les trois caisses de tribunal
-- acceptent le credit, la caisse du ministere est debitee d'autant, et la REGLE ne bouge pas.

DO $$
DECLARE v text := E'\n'; r jsonb; b text; v_avant numeric; v_apres numeric;
BEGIN
  v := v || 'est_appel_serveur() dans cette session : ' || public.est_appel_serveur()::text || E'\n\n';
  FOREACH b IN ARRAY ARRAY['tribunal_capitale','tribunal_ville_a','tribunal_ville_b'] LOOP
    SELECT (data->>'solde')::numeric INTO v_avant
      FROM public.caisses_batiments WHERE id = 'republic_' || b;
    PERFORM set_config('rp.caisse_interne', 'on', true);
    r := public.caisse_institution_mouvement('republic_gouvernement-min_just', -500, true);
    IF coalesce((r->>'ok')::boolean,false) THEN
      r := public.caisse_institution_mouvement('republic_' || b, 500, false);
    END IF;
    PERFORM set_config('rp.caisse_interne', '', true);
    SELECT (data->>'solde')::numeric INTO v_apres
      FROM public.caisses_batiments WHERE id = 'republic_' || b;
    v := v || '  ' || b || ' : ok=' || coalesce(r->>'ok','?')
           || '  ' || v_avant || ' -> ' || v_apres || E'\n';
  END LOOP;
  v := v || '  caisse de la Justice : '
         || (SELECT (data->>'solde') FROM public.caisses_batiments
              WHERE id='republic_gouvernement-min_just') || E'\n';
  v := v || E'\n' || 'LES PARTS N''ONT PAS BOUGE : ' || (SELECT string_agg(
         trim_scale(part_numerateur)::text || '/' || trim_scale(part_denominateur)::text, ' '
         ORDER BY rang) FROM public.repartitions_budgetaires
        WHERE pays='republic' AND source='gouvernement-min_just')
         || '  -- un acte ne modifie pas une regle' || E'\n';
  RAISE EXCEPTION 'PLOMBERIE DU PONCTUEL (transaction annulee) : %', v;
END $$;

-- RESULTAT MESURE LE 7 OCTOBRE 2026
--   est_appel_serveur() dans cette session : true
--     tribunal_capitale : ok=true  56921 -> 57421
--     tribunal_ville_a : ok=true  3224 -> 3724
--     tribunal_ville_b : ok=true  2344 -> 2844
--     caisse de la Justice : 67629   (69129 - 3 x 500)
--   LES PARTS N'ONT PAS BOUGE : 1/3 1/3 1/3  -- un acte ne modifie pas une regle
--
-- ET LE CHEMIN D'AUTORITE, mesure a part depuis une identite de PJ reelle (voir epreuve 2 pour
-- la methode) : un acteur qui ne tient pas min_just recoit `autorite_insuffisante` de
-- budget_repartition_fixer, avec `poste_requis: min_just`. Porter une part de la Justice a 50 %
-- sans baisser les autres d'abord est refuse pour `somme_depasse_cent` (116,6667 %), et le refus
-- RESTAURE l'ancienne valeur : les trois parts restent a 1/3 apres l'echec. C'est pourquoi
-- l'ecran ecrit les baisses avant les hausses.
