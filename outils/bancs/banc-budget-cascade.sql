-- =============================================================================
-- BANC D'ESSAI DE LA CASCADE BUDGETAIRE -- chantier 4F, 8 octobre 2026
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
