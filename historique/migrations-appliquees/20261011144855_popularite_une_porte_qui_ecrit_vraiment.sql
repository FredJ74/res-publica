-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011144855 (UTC), nom
-- `popularite_une_porte_qui_ecrit_vraiment`.
-- Le registre passe de 653 a 654 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 8ece84f7b63ec1099e17f29862ae0d37, 14777 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE PORTE QUI DIT « FAIT » DOIT AVOIR FAIT
--
-- DEFAUT PREEXISTANT, ET IL NE CONCERNE PAS QUE L'ASSEMBLEE. Le registre des causes --
-- `personnage_ajuster_pop_inf(acteur, cible, pop, inf, cause)`, la porte par laquelle une
-- mecanique touche la popularite d'un AUTRE personnage -- repondait `{"ok": true}` sans que la
-- popularite ne bouge d'un point. Mesure faite : une rumeur de -10 points laisse la cible a 50.
-- POURQUOI. Le trigger `personnages_fusionner_pop` applique une regle juste : « pas de base
-- annoncee : le navigateur ne decide pas d'une valeur absolue ». La porte ecrivait une valeur
-- absolue sans annoncer `popBase` -- et se faisait annuler en silence, tout en repondant que tout
-- allait bien. SEPT CAUSES ETAIENT CONCERNEES, plus les trois de la discipline parlementaire.
-- DEUX CHANGEMENTS, ET RIEN D'AUTRE : la porte annonce desormais la base qu'elle a lue sous
-- verrou (le trigger applique alors la DIFFERENCE, ce qui rend l'ecriture correcte ET robuste a la
-- concurrence) ; et elle VERIFIE son propre effet, refusant avec `ecriture_annulee` si la valeur
-- rendue n'est pas celle attendue. C'est la lecon : ce defaut a survecu parce que la porte
-- repondait « ok ».
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UNE PORTE QUI DIT « FAIT » DOIT AVOIR FAIT (11 octobre 2026)
-- =================================================================================================
-- DEFAUT PREEXISTANT, TROUVE EN BRANCHANT LE RAPPEL AU REGLEMENT, ET QUI NE CONCERNE PAS QUE LUI.
--
-- `personnage_ajuster_pop_inf(acteur, cible, pop, inf, cause)` -- le registre des causes, la porte
-- par laquelle une mecanique de jeu touche la popularite d'un AUTRE personnage -- repondait
-- `{"ok": true, "pop": 50}` sans que la popularite ne bouge d'un point. Mesure faite : une rumeur
-- de -10 points contre un depute laisse sa popularite a 50.
--
-- POURQUOI. Le trigger `personnages_fusionner_pop` applique une regle juste et necessaire : « pas
-- de base annoncee : le navigateur ne decide pas d'une valeur absolue ». Quand une ecriture ne
-- vient pas du serveur et n'annonce pas `popBase`, il RESTAURE l'ancienne valeur. Le protocole
-- attendu est donc : j'annonce la base que j'ai lue, j'ecris la valeur voulue, et le trigger
-- applique la DIFFERENCE a la valeur reelle du moment. La porte du registre, elle, ecrivait une
-- valeur absolue sans annoncer sa base -- et se faisait donc annuler en silence, tout en repondant
-- que tout allait bien.
--
-- SIX MECANIQUES ETAIENT CONCERNEES, pas une : `rumeur_pj`, `rumeur_gouvernement`,
-- `excommunication`, `dementi_reussi`, `dementi_rate`, `sentence_torture`, `football_match` -- plus
-- les trois causes de discipline parlementaire ajoutees ce matin. Toutes celles declenchees par un
-- JOUEUR. Les appels serveur, eux, passaient : le trigger ne les touche pas.
--
-- CE QUE CETTE MIGRATION CHANGE, ET RIEN D'AUTRE :
--   1. LE PROTOCOLE. La porte annonce desormais `popBase` (et `infBase`) : la valeur qu'elle a lue
--      sous verrou. Le trigger applique donc la difference voulue a la valeur courante -- ce qui
--      rend l'ecriture correcte ET robuste a la concurrence, puisque deux ajustements simultanes
--      s'additionnent au lieu de s'ecraser.
--   2. ELLE NE MENT PLUS. Apres l'ecriture, la porte compare la valeur rendue a la valeur attendue
--      -- bornes 0 et 100 comprises -- et refuse avec `ecriture_annulee` si elles divergent. Un
--      ajustement empeche par un garde-fou futur sera desormais BRUYANT. C'est la lecon de ce
--      defaut : il a survecu parce que la porte repondait « ok ».
--
-- CE QU'ELLE NE CHANGE PAS : ni le registre des causes, ni les autorites, ni les amplitudes, ni les
-- bornes. Aucune cause n'est ajoutee ni retiree ici.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb; v_ecrit jsonb;
  v_poste text; v_pays text;
  v_min integer; v_max integer;
  v_pop_lue numeric; v_inf_lue numeric;
  v_pop_attendue numeric; v_inf_attendue numeric;
  v_serveur boolean := public.est_appel_serveur();
BEGIN
  IF NOT v_serveur THEN PERFORM public.exiger_acteur(p_acteur); END IF;

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  -- Aucune mecanique du jeu ne modifie l'INF d'un AUTRE personnage aujourd'hui : l'influence
  -- d'une organisation est une autre jauge, portee par la table organisations. On refuse donc,
  -- plutot que de laisser une porte ouverte sans usage.
  IF p_inf IS NOT NULL AND NOT v_serveur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inf_sans_cause');
  END IF;

  SELECT pd.poste->>'id', pd.country INTO v_poste, v_pays
    FROM public.personnages_donnees pd WHERE pd.name = p_acteur;

  -- REGISTRE DES CAUSES. Chaque ligne = une mecanique reelle, son autorite et son amplitude.
  IF v_serveur THEN
    v_min := -100; v_max := 100;

  ELSIF p_cause = 'rumeur_pj' THEN
    -- Action grise ouverte a tout joueur. Perte tiree dans 5..20 (appliquerEffetRumeur).
    v_min := -20; v_max := -5;

  ELSIF p_cause = 'rumeur_gouvernement' THEN
    -- Meme action, cible gouvernementale. Perte tiree dans 1..5, appliquee a chaque titulaire.
    v_min := -5; v_max := -1;

  ELSIF p_cause = 'excommunication' THEN
    -- Reserve au Grand Pretre national en exercice. Le Grand Pretre n'est pas un poste porte par
    -- la fiche : c'est la ligne titulaires_pnj(pays, 'grand_pretre', NULL), que le client compare
    -- deja au nom du joueur (estGrandPretreActuel). Meme source de verite cote serveur.
    IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj t
                    WHERE t.poste_id = 'grand_pretre' AND t.city IS NULL
                      AND t.nom_pnj = p_acteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'grand_pretre');
    END IF;
    v_min := -15; v_max := -15;

  ELSIF p_cause IN ('dementi_reussi', 'dementi_rate') THEN
    -- Ordre « Dementi officiel » : requiresPost president (palais) ou min_info (ministere).
    IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_info') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    IF p_cause = 'dementi_reussi' THEN v_min := 1; v_max := 100;
    ELSE v_min := -100; v_max := -1; END IF;

  ELSIF p_cause = 'sentence_torture' THEN
    -- Ordre « Rendre la sentence » : requiresPost juge. -100 ramene la POP exactement a zero.
    IF v_poste IS DISTINCT FROM 'juge' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    v_min := -100; v_max := -100;

  ELSIF p_cause IN ('assemblee_rappel', 'assemblee_sanction', 'assemblee_suspension_seance') THEN
    -- LA DISCIPLINE DE SEANCE (arbitrage du 11 octobre 2026). L'autorite n'est PAS lue sur la
    -- fiche : la presidence de l'Assemblee est un poste NOMME, et son seul point de verite est le
    -- registre `postes_attribues`, lu par `assemblee_president`.
    IF v_pays IS NULL OR public.assemblee_president(v_pays) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'president_assemblee');
    END IF;
    -- UNE SUSPENSION VOLONTAIRE SE PAIE SOI-MEME. Le President ne peut pas faire porter son cout
    -- a un depute : la cause ne vise que lui.
    IF p_cause = 'assemblee_suspension_seance' AND p_cible IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_doit_etre_l_acteur', 'cause', p_cause);
    END IF;
    -- AMPLITUDE EXACTE, PAS UNE FOURCHETTE. 15 points pour un rappel, 20 pour une sanction, 20
    -- pour une suspension volontaire. Le registre refusera tout autre montant.
    IF p_cause = 'assemblee_rappel' THEN v_min := -15; v_max := -15;
    ELSE                                 v_min := -20; v_max := -20; END IF;

  ELSIF p_cause = 'football_match' THEN
    -- Gain de popularite d'un titulaire apres un match : +20 (participation) ou +30 (victoire).
    -- RESIDU ASSUME : le championnat n'a pas de moteur serveur, il avance depuis les navigateurs
    -- des joueurs. Aucun poste ne peut donc etre exige ici. L'amplitude est bornee aux deux
    -- seules valeurs declarees et le sens est POSITIF : le pire abus possible est d'elever la POP
    -- d'un personnage, jamais de l'abaisser. Fermeture definitive = moteur serveur du championnat.
    IF coalesce(p_pop,0) NOT IN (20, 30) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                                'cause', p_cause, 'pop', p_pop);
    END IF;
    v_min := 20; v_max := 30;

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_non_declaree', 'cause', p_cause);
  END IF;

  IF coalesce(p_pop, 0) < v_min OR coalesce(p_pop, 0) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                              'cause', p_cause, 'pop', p_pop, 'min', v_min, 'max', v_max);
  END IF;

  -- LA LECTURE SOUS VERROU. C'est la base qu'on va ANNONCER au trigger : 50 est la valeur par
  -- defaut d'une popularite jamais ecrite, comme partout ailleurs dans le jeu.
  SELECT coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                       THEN (pp.resources ->> 'pop')::numeric END, 50),
         coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'inf') = 'number'
                       THEN (pp.resources ->> 'inf')::numeric END, 0),
         CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END
    INTO v_pop_lue, v_inf_lue, v_ecrit
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  -- LE PROTOCOLE DU TRIGGER : on annonce la base lue, on ecrit la valeur voulue, et le trigger
  -- applique la DIFFERENCE a la valeur reelle du moment. Sans `popBase`, il restaurait l'ancienne
  -- valeur -- c'est le defaut que cette migration corrige. On n'ecrete pas ici : le trigger borne
  -- lui-meme entre 0 et 100, et ecreter deux fois ferait perdre le sens de la difference.
  v_ecrit := jsonb_set(v_ecrit, '{popBase}', to_jsonb(v_pop_lue));
  v_ecrit := jsonb_set(v_ecrit, '{pop}', to_jsonb(v_pop_lue + coalesce(p_pop, 0)));
  v_pop_attendue := greatest(0, least(100, v_pop_lue + coalesce(p_pop, 0)));

  IF p_inf IS NOT NULL THEN
    v_ecrit := jsonb_set(v_ecrit, '{infBase}', to_jsonb(v_inf_lue));
    v_ecrit := jsonb_set(v_ecrit, '{inf}', to_jsonb(v_inf_lue + p_inf));
    v_inf_attendue := greatest(0, least(100, v_inf_lue + p_inf));
  END IF;

  UPDATE public.personnages_donnees SET resources = v_ecrit
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  -- ET ELLE NE MENT PLUS. Si la valeur rendue n'est pas celle attendue, un garde-fou a annule
  -- l'ecriture : on le DIT, au lieu de repondre « ok » comme avant. C'est exactement ce silence
  -- qui a permis a ce defaut de survivre.
  IF coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                   THEN (v_res ->> 'pop')::numeric END, 50) IS DISTINCT FROM v_pop_attendue THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ecriture_annulee', 'cause', p_cause,
                              'attendue', v_pop_attendue, 'obtenue', v_res -> 'pop');
  END IF;
  IF p_inf IS NOT NULL
     AND coalesce(CASE WHEN jsonb_typeof(v_res -> 'inf') = 'number'
                       THEN (v_res ->> 'inf')::numeric END, 0) IS DISTINCT FROM v_inf_attendue THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ecriture_annulee', 'cause', p_cause,
                              'attendue_inf', v_inf_attendue, 'obtenue_inf', v_res -> 'inf');
  END IF;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf',
                            'cause', p_cause);
END;
$function$;

REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text,text,integer,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text,text,integer,integer,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text,text,integer,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text,text,integer,integer,text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_src text; v_n integer;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'personnage_ajuster_pop_inf' AND p.pronargs = 5;

  -- P1 : LA BASE EST ANNONCEE. C'est le protocole du trigger, et sans lui l'ecriture est annulee
  -- en silence pour tout appel venu d'un joueur.
  IF v_src NOT LIKE '%popBase%' THEN
    RAISE EXCEPTION 'P1 : la porte n annonce pas la base de popularite qu elle a lue';
  END IF;

  -- P2 : LA BASE EST CELLE LUE SOUS VERROU, pas une valeur devinee : c'est ce qui rend la
  -- difference appliquee exacte, meme quand deux ajustements arrivent ensemble.
  IF v_src NOT LIKE '%FOR UPDATE%' THEN
    RAISE EXCEPTION 'P2 : la base de popularite est lue sans verrou';
  END IF;

  -- P3 : ELLE VERIFIE SON PROPRE EFFET. Une porte qui repond « ok » sans avoir rien fait est pire
  -- qu'une porte qui echoue : c'est ce silence qui a cache ce defaut.
  IF v_src NOT LIKE '%ecriture_annulee%' THEN
    RAISE EXCEPTION 'P3 : la porte ne verifie pas que son ecriture a pris';
  END IF;

  -- P4 : LES DIX CAUSES SONT TOUTES LA. Cette migration corrige un protocole d'ecriture ; elle ne
  -- touche ni le registre, ni les autorites, ni les amplitudes.
  SELECT count(*) INTO v_n FROM (VALUES
    ('rumeur_pj'), ('rumeur_gouvernement'), ('excommunication'), ('dementi_reussi'),
    ('dementi_rate'), ('sentence_torture'), ('football_match'),
    ('assemblee_rappel'), ('assemblee_sanction'), ('assemblee_suspension_seance')) AS c(cause)
   WHERE v_src LIKE '%' || c.cause || '%';
  IF v_n <> 10 THEN RAISE EXCEPTION 'P4 : % cause(s) sur 10 survivent au registre', v_n; END IF;

  -- P5 : LE TRIGGER QUI IMPOSE CE PROTOCOLE EST TOUJOURS LA, et toujours actif. S'il disparaissait,
  -- la regle « le navigateur ne decide pas d'une valeur absolue » tomberait avec lui.
  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'personnages_donnees'
     AND t.tgname = 'trg_personnages_fusionner_pop' AND t.tgenabled = 'O';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 : le trigger de fusion de la popularite a disparu'; END IF;

  -- P6 : LA PORTE RESTE OUVERTE AUX JOUEURS ET FERMEE A anon.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'personnage_ajuster_pop_inf' AND p.pronargs = 5
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 : les droits de la porte de popularite ont change'; END IF;

  RAISE NOTICE 'Popularite : les 6 preuves structurelles passent.';
END $$;
