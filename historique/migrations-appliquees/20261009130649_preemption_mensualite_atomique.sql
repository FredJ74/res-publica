-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009130649 (UTC ; 15h06 a Paris), nom
-- `preemption_mensualite_atomique`. Le registre passe de 566 a 567 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 2bb962186adc398f1ac9500004e476c5, 8 833 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- ELLE VA PAR PAIRE AVEC UNE MODIFICATION DU DEPOT : `api/cron-minuit.js`,
-- `preleverPreemptionsServeur`, qui n'ecrit plus rien lui-meme. Les deux sont dans le meme
-- commit. Et elle suppose la migration 20261009093112, qui installe la brique.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME : DE L'ARGENT QUI DISPARAISSAIT SANS CONTREPARTIE
-- -----------------------------------------------------------------------------
-- `preleverPreemptionsServeur` faisait QUATRE allers-retours par empire : lire le budget, lire
-- la caisse, ECRIRE la caisse, ECRIRE le budget. Les deux ecritures etaient deux transactions.
-- Une interruption entre elles -- un timeout de fonction serverless, une coupure reseau --
-- debitait la caisse du Ministere des Finances SANS reduire la dette de la preemption. Et le
-- marqueur de `tacheQuotidienne`, pose AVANT la passe, interdisait la reprise du jour.
--
-- L'audit du chantier 6 le classait « le pire des sept », et pour une raison qui n'est pas
-- technique : AUCUN JOUEUR NE RECLAME UNE DETTE QUI NE BAISSE PAS ASSEZ VITE. Un double
-- prelevement se voit ; une mensualite payee deux fois a l'Etat sans que la dette bouge ne se
-- voit jamais.
--
-- -----------------------------------------------------------------------------
-- CE QUE FAIT LA RPC, DANS L'ORDRE, ET POURQUOI CET ORDRE
-- -----------------------------------------------------------------------------
--  1. VERROU D'ABORD : `SELECT ... FROM budgets_nationaux WHERE id = pays FOR UPDATE`. Deux
--     passes concurrentes se serialisent ici ; la seconde attend, puis echoue sa revendication.
--  2. Pas de preemption -> `aucune_preemption`, et AUCUNE revendication : on ne remplit pas le
--     journal de lignes qui n'attestent rien (la preuve B7 l'exige).
--  3. Preemption illisible (`montantRestant` ou `mensualite` non numeriques) -> fail-closed :
--     `ok:false, raison:preemption_illisible`, aucun mouvement, et la journee N'EST PAS prise --
--     une donnee qu'on ne comprend pas doit pouvoir etre reparee et reprise (preuve B6).
--  4. REVENDICATION de l'acte nocturne, dans la transaction qui portera l'effet. Deja prise ->
--     `deja_traite`.
--  5. Debit par `caisse_institution_mouvement(caisse, -mensualite, true)` -- la brique generique
--     des caisses d'institution, qui verrouille la ligne, refuse de passer sous zero et rend un
--     verdict. CE VERDICT EST LU. Refus -> `reporte`, et la journee reste revendiquee : le
--     report est une decision prise pour aujourd'hui, pas une perte -- la dette n'a pas bouge
--     d'un centime et l'echeancier reprend demain.
--     AUCUNE ECRITURE DIRECTE DE `caisses_batiments` : la preuve structurelle P2 le verifie par
--     expression reguliere. Dupliquer la brique serait la porte d'un contournement.
--  6. Reduction de la dette, ou retrait de la preemption si elle est soldee. La mensualite est
--     plafonnee au reste du : jamais de trop-percu (preuve B5).
--  7. Le journal recoit ce qui a ete fait : action, montant preleve, reste, caisse.
--
-- -----------------------------------------------------------------------------
-- LA PREUVE QUI VALAIT LE DETOUR : UNE PANNE APRES ACQUISITION
-- -----------------------------------------------------------------------------
-- Au banc, en transaction annulee, la RPC est appelee puis une exception est levee dans la
-- meme transaction. Apres rattrapage : la caisse est revenue a son solde, la dette a son
-- montant, ET LA LIGNE DE REVENDICATION A DISPARU. C'est la propriete que l'ancien code ne
-- pouvait pas avoir : la journee n'est pas « consommee sans effet », elle est simplement
-- restee a prendre. Un etat economique partiel n'est plus representable.
--
-- HUIT PREUVES COMPORTEMENTALES EN TRANSACTION ANNULEE : debit et dette du meme montant en un
-- appel, avec verification de la conservation `caisse_avant - caisse_apres == dette_avant -
-- dette_apres` ; deux rejeux le meme jour sans aucun effet ; la panne ci-dessus ; report sans
-- mouvement sur caisse insuffisante ; derniere mensualite plafonnee au reste du et preemption
-- retiree ; preemption illisible fail-closed sans prendre la journee ; aucun acte journalise
-- sans effet ; pays sans budget national dit au lieu de lever. Verifie annule ensuite.
--
-- SIX PREUVES STRUCTURELLES DANS LA MIGRATION : la revendication est presente et vient AVANT le
-- mouvement de caisse (comparaison des positions dans le corps) ; le verdict du mouvement est
-- consomme et aucune ecriture directe de caisse ne subsiste ; la dette est reduite dans la meme
-- fonction donc la meme transaction ; le mecanisme est declare au registre en sujet unique ;
-- SECURITY DEFINER, `search_path`, et droits -- `service_role` seul, jamais un client ; AUCUNE
-- DONNEE TOUCHEE, les quatre caisses ministerielles comparees a leur valeur exacte d'avant.
--
-- -----------------------------------------------------------------------------
-- CE QUE CE LOT NE CHANGE PAS
-- -----------------------------------------------------------------------------
-- La passe reste enveloppee par `tacheQuotidienne('preemptions_etat', ...)`. Ce n'est plus la
-- protection -- c'est la brique qui l'est -- mais c'est une economie de quatre appels par nuit.
-- A noter pour plus tard : avec la brique, une reprise dans la journee serait desormais SURE,
-- ce que le registre de `tacheQuotidienne` empeche encore. Lever l'enveloppe est une decision
-- distincte, et une migration porte une intention a la fois.
--
-- Aucune regle de jeu n'est touchee : meme mensualite, meme plafonnement au reste du, meme
-- caisse payeuse, memes conditions de report.
-- =============================================================================

-- Chantier 6 -- PREMIER CONSOMMATEUR DE actes_nocturnes : la mensualite de preemption d'Etat.
-- preleverPreemptionsServeur faisait quatre allers-retours par pays ; une interruption entre
-- l'ecriture de la caisse et celle du budget debitait sans reduire la dette, et le marqueur de
-- tacheQuotidienne, deja pose, interdisait la reprise. Argent perdu sans contrepartie, et
-- personne ne reclame une dette qui ne baisse pas assez vite. Debit et reduction sont desormais
-- UNE SEULE transaction, ouverte par une revendication d'acte nocturne. Banc annule : 8 preuves
-- vertes, dont une panne apres acquisition qui annule les deux ecritures ET la revendication.
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
VALUES ('preemption_mensualite', true,
        'Mensualite de la preemption d''Etat : debit de la caisse du Ministere des Finances et reduction de la dette. Un rejeu debiterait une seconde mensualite. Un sujet par pays : une seule preemption a la fois.')
ON CONFLICT (mecanisme) DO NOTHING;

CREATE OR REPLACE FUNCTION public.preemption_mensualite_prelever(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pays text := lower(btrim(coalesce(p_pays, '')));
  v_data jsonb; v_pre jsonb; v_mensualite numeric; v_restant numeric;
  v_caisse text; v_mouvement jsonb; v_neuf jsonb; v_action text;
BEGIN
  IF v_pays = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  -- VERROU D'ABORD : deux passes concurrentes se serialisent ici, et la seconde echouera sa
  -- revendication.
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'action', 'aucun_budget'); END IF;

  v_pre := v_data -> 'preemption';
  IF v_pre IS NULL OR jsonb_typeof(v_pre) <> 'object' THEN
    -- Aucun effet a produire : on ne revendique pas, pour ne pas remplir le journal de lignes
    -- qui n'attestent rien.
    RETURN jsonb_build_object('ok', true, 'action', 'aucune_preemption'); END IF;

  v_restant    := CASE WHEN jsonb_typeof(v_pre->'montantRestant') = 'number'
                       THEN (v_pre->>'montantRestant')::numeric ELSE NULL END;
  v_mensualite := CASE WHEN jsonb_typeof(v_pre->'mensualite') = 'number'
                       THEN (v_pre->>'mensualite')::numeric ELSE NULL END;
  IF v_restant IS NULL OR v_mensualite IS NULL OR v_mensualite <= 0 OR v_restant <= 0 THEN
    -- FAIL-CLOSED : une preemption illisible ne se devine pas, et sa journee n'est pas prise.
    RETURN jsonb_build_object('ok', false, 'raison', 'preemption_illisible',
                              'montantRestant', v_pre->'montantRestant', 'mensualite', v_pre->'mensualite'); END IF;

  -- REVENDICATION, dans la transaction qui portera l'effet.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'preemption_mensualite', '-') THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_traite'); END IF;

  v_mensualite := LEAST(v_mensualite, v_restant);
  v_caisse     := v_pays || '_gouvernement-min_fin';

  -- Le debit passe par la brique generique des caisses d'institution : elle verrouille, refuse
  -- de passer sous zero et rend un verdict. On le LIT.
  v_mouvement := public.caisse_institution_mouvement(v_caisse, -v_mensualite, true);
  IF NOT coalesce((v_mouvement->>'ok')::boolean, false) THEN
    -- La journee reste revendiquee : le report est une decision prise pour aujourd'hui, pas une
    -- perte -- la dette n'a pas bouge d'un centime et l'echeancier reprend demain.
    RETURN jsonb_build_object('ok', true, 'action', 'reporte', 'raison', v_mouvement->>'raison',
                              'mensualite', v_mensualite, 'caisse', v_caisse); END IF;

  v_restant := v_restant - v_mensualite;
  IF v_restant <= 0 THEN v_neuf := v_data - 'preemption'; v_action := 'solde';
  ELSE v_neuf := v_data || jsonb_build_object('preemption',
         v_pre || jsonb_build_object('montantRestant', v_restant)); v_action := 'preleve'; END IF;

  UPDATE public.budgets_nationaux SET data = v_neuf, updated_at = now() WHERE id = v_pays;

  -- Le journal dit ce qui a ete fait, pas seulement que ce fut fait.
  UPDATE public.actes_nocturnes
     SET details = jsonb_build_object('action', v_action, 'preleve', v_mensualite,
                                      'restant', v_restant, 'caisse', v_caisse)
   WHERE pays = v_pays AND mecanisme = 'preemption_mensualite' AND sujet = '-'
     AND jour = (now() AT TIME ZONE 'Europe/Paris')::date;

  RETURN jsonb_build_object('ok', true, 'action', v_action, 'preleve', v_mensualite, 'restant', v_restant);
END; $fn$;

REVOKE ALL ON FUNCTION public.preemption_mensualite_prelever(text) FROM anon;
REVOKE ALL ON FUNCTION public.preemption_mensualite_prelever(text) FROM authenticated;

COMMENT ON FUNCTION public.preemption_mensualite_prelever(text) IS
'Preleve la mensualite de la preemption d''Etat d''un pays : debit de la caisse du Ministere des
Finances ET reduction de la dette, dans UNE SEULE transaction ouverte par une revendication
d''acte nocturne. Appelable par service_role seulement (le cron).
VERDICTS : aucun_budget, aucune_preemption, preemption_illisible (fail-closed, aucun mouvement,
journee non prise), deja_traite, reporte (caisse insuffisante -- dette intacte), preleve, solde.';

DO $$
DECLARE v_def text; v_n int; v_droits text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'preemption_mensualite_prelever';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la fonction n''existe pas'; END IF;

  -- P1 : elle revendique l'acte, et AVANT de toucher a l'argent.
  IF position('acte_nocturne_revendiquer' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucune revendication d''acte nocturne';
  END IF;
  IF position('acte_nocturne_revendiquer' in v_def)
     > position('caisse_institution_mouvement' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la revendication vient APRES le mouvement de caisse';
  END IF;

  -- P2 : le debit passe par la brique generique, et son verdict est LU.
  IF position('coalesce((v_mouvement->>''ok'')::boolean, false)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le verdict du mouvement de caisse n''est pas consomme';
  END IF;
  -- Aucune ecriture directe de caisses_batiments : la duplication serait la porte d'un
  -- contournement de la brique.
  IF v_def ~ 'UPDATE\s+(public\.)?caisses_batiments' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la fonction ecrit caisses_batiments en direct';
  END IF;

  -- P3 : la reduction de la dette est dans la MEME fonction, donc la meme transaction.
  IF v_def !~ 'UPDATE public\.budgets_nationaux SET data = v_neuf' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la dette n''est pas reduite dans cette transaction';
  END IF;

  -- P4 : le mecanisme est declare au registre, et il est le seul de ce lot.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes_mecanismes
   WHERE mecanisme = 'preemption_mensualite' AND sujet_singleton;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- mecanisme non declare ou mal declare'; END IF;

  -- P5 : autorite, search_path, et droits -- service_role seulement.
  IF v_def !~ 'SECURITY DEFINER' OR v_def !~ 'search_path TO ''public'', ''pg_temp''' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- autorite ou search_path incorrects';
  END IF;
  IF has_function_privilege('anon', 'public.preemption_mensualite_prelever(text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.preemption_mensualite_prelever(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la RPC est appelable par un client';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.preemption_mensualite_prelever(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le cron ne pourrait pas l''appeler';
  END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE par cette migration.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % acte(s) journalise(s) par la migration', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.budgets_nationaux WHERE data ? 'preemption';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % preemption(s) apparue(s)', v_n; END IF;
  SELECT string_agg(id || '=' || (data->>'solde'), ' ' ORDER BY id) INTO v_droits
    FROM public.caisses_batiments WHERE id LIKE '%\_gouvernement-min\_fin';
  IF v_droits IS DISTINCT FROM 'khalija_gouvernement-min_fin=200 narco_gouvernement-min_fin=3996 republic_gouvernement-min_fin=71375 soviet_gouvernement-min_fin=6426' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les caisses ministerielles ont bouge : %', v_droits;
  END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;