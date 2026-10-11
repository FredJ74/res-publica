-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011143854 (UTC), nom
-- `assemblee_discipline_par_le_registre_des_causes`.
-- Le registre passe de 651 a 652 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 320c187876cafdad2c68b063e143585d, 26873 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA DISCIPLINE PASSE PAR LE REGISTRE DES CAUSES
--
-- CORRECTIF D'UN DEFAUT TROUVE PAR LE BANC, pas par la relecture. `assemblee_rappeler` appelait
-- la porte de popularite A TROIS ARGUMENTS, qui ecrit par la VUE `personnages` -- et le trigger
-- de cette vue refuse toute ecriture sur la fiche d'AUTRUI hors appel serveur. Or un rappel au
-- reglement est fait par un joueur, sous son propre jeton : en production, le premier rappel de
-- l'histoire aurait leve `personnage_non_possede` et rien ne se serait passe.
-- ET LE JEU AVAIT DEJA LA BONNE PORTE : le REGISTRE DES CAUSES, ou chaque mecanique autorisee a
-- toucher la popularite d'un autre personnage declare son autorite et son amplitude. Trois causes
-- y entrent -- rappel, sanction, suspension volontaire -- avec une amplitude EXACTE et non une
-- fourchette, et une autorite lue dans `postes_attribues` et non sur la fiche.
-- LE DEMI-EFFET DEVIENT IMPOSSIBLE : la popularite est appliquee AVANT l'ecriture de la ligne, et
-- un refus leve une exception qui annule toute la transaction.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA DISCIPLINE PASSE PAR LE REGISTRE DES CAUSES (11 octobre 2026)
-- =================================================================================================
-- LE DEFAUT, TROUVE PAR LE BANC ET NON PAR LA RELECTURE. `assemblee_rappeler` appelait
-- `personnage_ajuster_pop_inf(cible, pop, inf)` -- la porte a trois arguments, qui ecrit par la VUE
-- `personnages`. Le trigger de cette vue refuse toute ecriture sur la fiche d'AUTRUI quand l'appel
-- n'est pas un appel serveur : or un rappel au reglement est fait par un joueur, sous son propre
-- jeton. En production, le premier rappel au reglement de l'histoire aurait leve
-- `personnage_non_possede` et rien ne se serait passe.
--
-- ET LE JEU AVAIT DEJA LA BONNE PORTE. `personnage_ajuster_pop_inf(acteur, cible, pop, inf, cause)`
-- est le REGISTRE DES CAUSES : chaque mecanique autorisee a toucher la popularite d'un autre
-- personnage y declare son autorite et son amplitude -- `rumeur_pj` entre -20 et -5,
-- `excommunication` exactement -15 et reservee au Grand Pretre, `sentence_torture` exactement -100
-- et reservee au juge. Elle ecrit `personnages_donnees` directement, donc sans passer par la vue,
-- et elle verifie que l'acteur est bien celui du jeton.
--
-- TROIS CAUSES NEUVES, ET RIEN DE PLUS :
--   . `assemblee_rappel`             -- President de l'Assemblee, exactement -15 ;
--   . `assemblee_sanction`           -- President de l'Assemblee, exactement -20 ;
--   . `assemblee_suspension_seance`  -- President de l'Assemblee, exactement -20, SUR LUI-MEME.
-- L'amplitude est EXACTE, pas une fourchette : ces trois coups ont un prix fixe, et le registre
-- refusera desormais tout autre montant -- y compris si une version future de la seance se
-- trompait. L'autorite est relue dans `postes_attribues` par `assemblee_president`, le seul point
-- de verite de la presidence.
--
-- ET LE DEMI-EFFET DEVIENT IMPOSSIBLE. Les trois portes appliquent desormais la popularite AVANT
-- d'ecrire leur ligne, et levent une exception si le registre refuse : la transaction entiere est
-- alors annulee. Il ne peut donc plus y avoir de rappel inscrit sans popularite retiree, ni --
-- pour la sanction -- de 100 FR debites sans caisse creditee. Les refus LEGITIMES (pas le
-- President, motif vide, fonds insuffisants) restent des refus propres, prononces avant toute
-- ecriture, et ne coutent rien.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LE REGISTRE DES CAUSES ACCUEILLE LA DISCIPLINE PARLEMENTAIRE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb; v_base jsonb;
  v_poste text; v_pays text;
  v_min integer; v_max integer;
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
    -- registre `postes_attribues`, lu par `assemblee_president`. Une fiche qui porterait
    -- `president_assemblee` sans etre au registre ne donnerait donc rien ici -- et le trigger
    -- d'attestation l'aurait de toute facon annulee.
    IF v_pays IS NULL OR public.assemblee_president(v_pays) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'president_assemblee');
    END IF;
    -- UNE SUSPENSION VOLONTAIRE SE PAIE SOI-MEME. Le President ne peut pas faire porter son cout
    -- a un depute : la cause ne vise que lui.
    IF p_cause = 'assemblee_suspension_seance' AND p_cible IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_doit_etre_l_acteur', 'cause', p_cause);
    END IF;
    -- AMPLITUDE EXACTE, PAS UNE FOURCHETTE. Les trois coups ont un prix fixe arbitre : 15 points
    -- pour un rappel, 20 pour une sanction, 20 pour une suspension volontaire. Le registre
    -- refusera tout autre montant, meme venu d'une future version de la seance qui se tromperait.
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

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf',
                            'cause', p_cause);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 2. LE RAPPEL AU REGLEMENT PASSE PAR LE REGISTRE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_rappeler(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_RAPPEL constant integer := -15;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE. Un rappel rejoue rendait 30 points de popularite au lieu de 15.
  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'rappel', d.id, 'cible', d.cible, 'pop', d.pop_delta);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF p_depute IS NULL OR p_depute = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;
  -- UNIQUEMENT CONTRE UN DEPUTE PHYSIQUEMENT PRESENT. On ne rappelle pas au reglement quelqu'un
  -- qui a quitte l'hemicycle.
  IF NOT public.assemblee_dans_hemicycle(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_l_hemicycle'); END IF;

  -- LA POPULARITE D'ABORD, PAR LE REGISTRE DES CAUSES. Tous les refus legitimes sont derriere
  -- nous : si le registre refuse ici, c'est une incoherence, et on annule TOUT plutot que
  -- d'inscrire un rappel que personne n'a paye.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_RAPPEL, NULL, 'assemblee_rappel');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_rappel_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'rappel-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_rappel-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     chronique_id, requete)
  VALUES (v_id, v_pays, 'rappel', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_RAPPEL, v_chron, p_requete);

  -- LA TRACE PUBLIQUE EST FACTUELLE, ECRITE PAR LE SERVEUR, DANS LA MEME TRANSACTION. Elle dit QUI
  -- a rappele QUI, et rien de plus : aucun adjectif, aucune appreciation. Le motif exact voyage
  -- dans `data`, verbatim, pour que la presse puisse le CITER sans que personne l'ait reecrit.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_rappel', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a rappele ' || p_depute || ' au reglement.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_RAPPEL, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'rappel', v_id, 'cible', p_depute,
                            'pop', POP_RAPPEL, 'pop_cible', v_pop -> 'pop');
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 3. LA SANCTION PASSE PAR LE REGISTRE
-- -------------------------------------------------------------------------------------------------
-- L'ORDRE DES TROIS EFFETS EST RAISONNE. Le debit d'abord, parce qu'un manque de fonds est un
-- refus LEGITIME qui doit ne rien ecrire ; puis le credit de la caisse, dans la meme transaction ;
-- puis la popularite, dont l'echec est une incoherence et leve une exception qui annule le debit
-- ET le credit. Il n'y a donc aucun ordre dans lequel 100 FR partent sans arriver.
CREATE OR REPLACE FUNCTION public.assemblee_sanctionner(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SANCTION constant integer := -20;
  AMENDE       constant integer := 100;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_rappel text;
  v_caisse text; v_debit jsonb; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUT DEBIT. Une sanction rejouee prelevait 200 FR et 40 points.
  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'sanction', d.id, 'cible', d.cible, 'pop', d.pop_delta,
                              'amende', d.amende, 'caisse', d.caisse_creditee,
                              'rappel_consomme', d.rappel_id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  -- LE RAPPEL PREALABLE, NON ENCORE CONSOMME, LE PLUS ANCIEN D'ABORD. Verrouille : deux sanctions
  -- simultanees ne peuvent pas elire le meme rappel.
  SELECT x.id INTO v_rappel FROM public.assemblee_disciplines x
   WHERE x.pays = v_pays AND x.genre = 'rappel' AND x.cible = p_depute
     AND x.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = x.id)
   ORDER BY x.fait_le
   FOR UPDATE
   LIMIT 1;
  IF v_rappel IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_rappel_a_consommer'); END IF;

  -- L'ARGENT D'ABORD, ET SI IL MANQUE, RIEN N'EST ECRIT. `assemblee_debiter_joueur` rend un refus
  -- structure et ne touche a rien quand les fonds manquent.
  v_debit := public.assemblee_debiter_joueur(p_depute, 0, AMENDE);
  IF coalesce((v_debit->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_debit->>'raison', 'debit_impossible'),
                              'detail', v_debit);
  END IF;
  v_caisse := v_pays || '_assemblee';
  PERFORM public.assemblee_crediter_caisse(v_caisse, AMENDE);

  -- PUIS LA POPULARITE. Un refus ici est une incoherence, pas une regle : on annule tout, donc
  -- l'amende repart dans la poche du depute et la caisse ne garde rien.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_SANCTION, NULL, 'assemblee_sanction');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_sanction_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'sanction-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_sanction-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id, requete)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron, p_requete);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_sanction', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a sanctionne ' || p_depute || '.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_SANCTION, 'amende', AMENDE, 'caisse', v_caisse,
                             'rappel', v_rappel, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'sanction', v_id, 'rappel_consomme', v_rappel,
                            'cible', p_depute, 'pop', POP_SANCTION, 'amende', AMENDE,
                            'caisse', v_caisse, 'pop_cible', v_pop -> 'pop');
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 4. LA SUSPENSION VOLONTAIRE PASSE PAR LE REGISTRE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_suspendre_seance(p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SUSPENSION constant integer := -20;
  v_moi text; v_pays text; v_id text; v_m text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_suspensions WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id, 'pop', POP_SUSPENSION,
                              'compte_pour_le_boycott', false);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || left(md5(p_requete), 20);

  -- IL SE PAIE LUI-MEME, et le registre des causes le verifie : `assemblee_suspension_seance`
  -- refuse toute cible autre que l'acteur.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, POP_SUSPENSION, NULL, 'assemblee_suspension_seance');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_suspension_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, close_le, requete)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, now(), p_requete);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false, 'pop_president', v_pop -> 'pop');
END;
$function$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'assemblee_rappeler(text,text,text)',
    'assemblee_sanctionner(text,text,text)',
    'assemblee_suspendre_seance(text,text)',
    'personnage_ajuster_pop_inf(text,text,integer,integer,text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC', f);
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', f);
  END LOOP;
END $$;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_src text; v_reg text; v_n integer;
BEGIN
  SELECT p.prosrc INTO v_reg FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'personnage_ajuster_pop_inf' AND p.pronargs = 5;

  -- P1 : LES TROIS CAUSES SONT DECLAREES, AVEC UNE AMPLITUDE EXACTE. Une fourchette large aurait
  -- rendu le registre decoratif : c'est son etroitesse qui protege.
  IF v_reg NOT LIKE '%assemblee_rappel%' OR v_reg NOT LIKE '%assemblee_sanction%'
     OR v_reg NOT LIKE '%assemblee_suspension_seance%' THEN
    RAISE EXCEPTION 'P1a : une cause de discipline manque au registre';
  END IF;
  IF v_reg NOT LIKE '%v_min := -15; v_max := -15%' OR v_reg NOT LIKE '%v_min := -20; v_max := -20%' THEN
    RAISE EXCEPTION 'P1b : les amplitudes de la discipline ne sont pas exactes';
  END IF;

  -- P2 : L'AUTORITE EST LUE AU REGISTRE DES POSTES, pas sur la fiche. Une fiche ne doit jamais
  -- pouvoir se declarer presidente de l'Assemblee.
  IF v_reg NOT LIKE '%assemblee_president(v_pays)%' THEN
    RAISE EXCEPTION 'P2 : l autorite de la discipline n est pas lue au registre des postes';
  END IF;

  -- P3 : LES ANCIENNES CAUSES SONT INTACTES. Cette migration en AJOUTE trois ; elle n'en retire
  -- aucune. Si une disparaissait, une mecanique du jeu tomberait en silence.
  SELECT count(*) INTO v_n FROM (VALUES
    ('rumeur_pj'), ('rumeur_gouvernement'), ('excommunication'), ('dementi_reussi'),
    ('dementi_rate'), ('sentence_torture'), ('football_match')) AS c(cause)
   WHERE v_reg LIKE '%' || c.cause || '%';
  IF v_n <> 7 THEN RAISE EXCEPTION 'P3 : % cause(s) historique(s) sur 7 survivent', v_n; END IF;

  -- P4 : LES TROIS PORTES N'APPELLENT PLUS LA VERSION A TROIS ARGUMENTS. C'etait le defaut :
  -- elle ecrit par la vue `personnages`, dont le trigger refuse la fiche d'autrui.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_rappeler','assemblee_sanctionner','assemblee_suspendre_seance')
     AND p.prosrc LIKE '%personnage_ajuster_pop_inf(v_moi,%';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P4 : % porte(s) sur 3 passent par le registre des causes', v_n; END IF;

  -- P5 : AUCUN DEMI-EFFET. Dans les trois portes, la popularite est appliquee AVANT l'inscription
  -- de la ligne, et son echec leve une exception -- donc la transaction entiere est annulee.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_rappeler','assemblee_sanctionner','assemblee_suspendre_seance')
     AND p.prosrc LIKE '%RAISE EXCEPTION%popularite_refusee%'
     AND position('personnage_ajuster_pop_inf' in p.prosrc)
         < position('INSERT INTO public.assemblee_' in p.prosrc);
  IF v_n <> 3 THEN RAISE EXCEPTION 'P5 : % porte(s) sur 3 appliquent la popularite avant d ecrire', v_n; END IF;

  -- P6 : LA SANCTION DEBITE AVANT D'APPLIQUER LA POPULARITE. Un manque de fonds est un refus
  -- LEGITIME : il doit ne rien ecrire du tout, pas annuler un effet deja applique.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_sanctionner';
  IF position('assemblee_debiter_joueur' in v_src) > position('personnage_ajuster_pop_inf' in v_src) THEN
    RAISE EXCEPTION 'P6 : la sanction applique la popularite avant de verifier les fonds';
  END IF;

  -- P7 : LA PORTE A TROIS ARGUMENTS RESTE RESERVEE AU SERVEUR, et celle du registre reste ouverte
  -- aux joueurs. On n'a ni ouvert l'une, ni ferme l'autre.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'personnage_ajuster_pop_inf'
     AND ((p.pronargs = 3 AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE'))
       OR (p.pronargs = 5 AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
                          AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')));
  IF v_n <> 2 THEN RAISE EXCEPTION 'P7 : les droits des portes de popularite ont change'; END IF;

  RAISE NOTICE 'Discipline par le registre des causes : les 7 preuves structurelles passent.';
END $$;
