-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011203102 (UTC), nom
-- `candidature_estampille_du_scrutin_fail_closed`.
-- Le registre passe de 667 a 668 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 7e2d2f868944e6a5ac274680febd506b, 4163 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'ESTAMPILLE DU SCRUTIN NE VIENT JAMAIS DU CLIENT (5/5)
--
-- CELLE-LA VIENT D'UNE MESURE FAITE APRES COUP, et elle corrige la migration 1/5.
-- `candidatures.cle_scrutin` est posee par le declencheur, qui RELIT la valeur sur le cycle --
-- c'est le bon principe. Mais la pose etait CONDITIONNELLE : cycle absent, ou cycle sans
-- `dateDebutCandidatures` numerique, et le declencheur sortait sans toucher la colonne. La valeur
-- annoncee par l'appelant survivait alors.
--
-- OR LE DROIT D'INSERT DE `authenticated` SUR `candidatures` N'EST PAS ENCORE REVOQUE -- dette
-- nommee du chantier 5, et volontairement non refermee tant que le code deploye en depend. Un
-- client pouvait donc placer une estampille arbitraire et faire apparaitre sa ligne dans le
-- scrutin EN COURS a l'affichage. La portee restait limitee (le depouillement ne lit que
-- `cycle.candidats`, que seules les deux portes ecrivent, donc une telle ligne n'atteignait aucun
-- resultat) mais une valeur d'autorite qui peut venir du client n'a pas a exister.
--
-- LA REGLE DEVIENT FAIL-CLOSED, EN UNE LIGNE ET DANS LE BON ORDRE : `NEW.cle_scrutin := NULL`
-- AVANT toute lecture. L'estampille vaut ensuite ce que le cycle dit, et NULL quand le cycle ne
-- dit rien -- et NULL ne remonte dans aucun scrutin, puisque le navigateur refuse de lire sans
-- clef numerique connue. Une preuve verifie l'ORDRE des deux instructions : poser NULL apres la
-- lecture effacerait l'estampille legitime.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ESTAMPILLE DU SCRUTIN NE VIENT JAMAIS DU CLIENT, MEME QUAND LE CYCLE EST MUET
-- 11 octobre 2026
--
-- CE QUI MANQUAIT, MESURE APRES COUP. `candidatures.cle_scrutin` est posee par ce declencheur,
-- qui RELIT la valeur sur le cycle -- c'est le bon principe. Mais la pose etait CONDITIONNELLE :
-- si le cycle n'existait pas encore, ou ne portait pas de `dateDebutCandidatures` numerique, le
-- declencheur sortait sans toucher la colonne, et la valeur annoncee par l'appelant survivait.
--
-- OR LE DROIT D'INSERT DE `authenticated` SUR `candidatures` N'EST PAS ENCORE REVOQUE (dette
-- nommee du chantier 5) : un client pouvait donc placer une estampille arbitraire et faire
-- apparaitre sa ligne dans le scrutin EN COURS a l'affichage. La portee reste limitee -- le
-- depouillement ne lit que `cycle.candidats`, que seules les deux portes ecrivent, donc une telle
-- ligne n'atteint aucun resultat -- mais une valeur d'autorite qui peut venir du client n'a pas a
-- exister.
--
-- LA REGLE DEVIENT FAIL-CLOSED : l'estampille vaut ce que le cycle dit, et NULL quand le cycle ne
-- dit rien. NULL ne remonte dans aucun scrutin, puisque le navigateur filtre sur une valeur
-- numerique et ne lit RIEN sans clef connue.
CREATE OR REPLACE FUNCTION public.candidatures_cloture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data text;
  v_d    jsonb;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  -- L'ESTAMPILLE EST REMISE A ZERO D'ABORD, ET C'EST LE POINT : ce que l'appelant a annonce dans
  -- cette colonne est jete AVANT toute lecture. Elle ne pourra valoir que ce que le cycle dit.
  NEW.cle_scrutin := NULL;

  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (gel du lundi 00:01 de la derniere semaine du mandat).';
  END IF;
  -- ET LA CANDIDATURE EST ESTAMPILLEE DU SCRUTIN VISE, PAR LE SERVEUR (11 octobre 2026).
  -- Un cycle n'etant plus detruit entre deux scrutins, la table `candidatures` n'est plus
  -- distinguable par (pays, poste, ville) : sans cette colonne, les candidats d'un scrutin passe
  -- seraient reinjectes dans le suivant par syncCyclesDepuisSupabase. La valeur n'est pas celle
  -- que le client annonce : elle est RELUE sur le cycle, ici meme, dans la transaction.
  IF jsonb_typeof(v_d -> 'dateDebutCandidatures') = 'number' THEN
    NEW.cle_scrutin := (v_d ->> 'dateDebutCandidatures')::numeric::bigint;
  END IF;
  RETURN NEW;
END;
$function$;

DO $preuve$
DECLARE v_txt text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'candidatures_cloture';
  -- P1 : la remise a zero precede la lecture du cycle. L'ordre EST la regle : poser NULL apres
  --      la lecture effacerait l'estampille legitime.
  IF position('NEW.cle_scrutin := NULL;' IN v_txt) = 0
     OR position('NEW.cle_scrutin := NULL;' IN v_txt) > position('FROM public.cycles_electoraux' IN v_txt) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''estampille n''est pas jetee avant la lecture du cycle';
  END IF;
  -- P2 : la seule valeur non nulle vient du cycle.
  IF position('(v_d ->> ''dateDebutCandidatures'')::numeric::bigint' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''estampille ne vient plus du cycle';
  END IF;
  -- P3 : le gel n'a pas bouge.
  IF position('dateDebutCampagne' IN v_txt) = 0 OR position('candidatures_closes' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le gel du lundi 00:01 a disparu';
  END IF;
  RAISE NOTICE 'LES 3 PREUVES SONT VERTES.';
END
$preuve$;