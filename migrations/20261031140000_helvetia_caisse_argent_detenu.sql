-- #267 — La caisse d'Helvetia sortait deux fois pour le même argent (Claude, 31/10/2026).
-- Compatible avec l'écran en ligne ; aucune donnée de joueur modifiée.
--
-- Règle retenue (choix technique) : la caisse `<pays>_banque-privee` est l'argent que la banque
-- détient réellement. Un dépôt l'augmente ; un retrait et la restitution à la fermeture d'un
-- compte la diminuent.
--   * ouvrir_compte_helvetia : le dépôt d'ouverture (10 000 FR) n'entrait pas dans la caisse ;
--     il y entre désormais, comme tout dépôt.
--   * creer_pret_helvetia : l'argent prêté reste sur le compte Helvetia du client, rien ne sort
--     de la caisse. Plus de débit ni d'appel à helvetia_assurer_liquidite (le retrait, lui,
--     continue de vérifier la liquidité et de débiter la caisse).
--   * Ce qui passe du compte Helvetia du client à la banque (remboursement intégral, mensualité,
--     saisie sur le compte Helvetia, part appliquée à la dette à la fermeture) était déjà dans la
--     caisse : il ne la crédite plus. Ce qui vient du liquide ou du compte national la crédite
--     toujours.
-- Le refinancement BNR déjà contracté (~150 000 FR de trop pour la République) n'est pas touché :
-- c'est une décision d'économie réservée à Fred.
BEGIN;

CREATE FUNCTION pg_temp.helvetia_corriger(p_sig text, p_avant text, p_apres text,
  p_regles text[]) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE h text; d text; i integer; n integer;
BEGIN
  SELECT md5(prosrc), pg_get_functiondef(oid) INTO h, d FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  IF h = p_apres THEN RETURN; END IF;
  IF h IS DISTINCT FROM p_avant THEN RAISE EXCEPTION 'definition_non_examinee: % (%)', p_sig, h; END IF;
  -- p_regles : motif, remplacement, motif, remplacement… (expressions régulières, une seule occurrence exigée)
  FOR i IN 1 .. array_length(p_regles, 1) BY 2 LOOP
    SELECT count(*) INTO n FROM regexp_matches(d, p_regles[i], 'g');
    IF n <> 1 THEN RAISE EXCEPTION '%: motif % trouvé % fois', p_sig, (i + 1) / 2, n; END IF;
    d := regexp_replace(d, p_regles[i], p_regles[i + 1]);
  END LOOP;
  EXECUTE d;
  SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  IF h IS DISTINCT FROM p_apres THEN RAISE EXCEPTION '%: empreinte après correction inattendue (%)', p_sig, h; END IF;
END $f$;

-- 1. Le prêt ne sort plus de la caisse.
SELECT pg_temp.helvetia_corriger('public.creer_pret_helvetia(text,numeric,integer)',
  '7096fa86fc27f13d18c83bb2edc48e0b', '034009e8182932f69ab0b27a55dc5555', ARRAY[
  $m$\n\s*IF NOT public\.helvetia_assurer_liquidite\(v_perso\.country, p_montant, 'pret_client'\) THEN\s+RAISE EXCEPTION 'Helvetia ne peut pas financer ce pret actuellement';\s+END IF;\s+UPDATE public\.caisses_batiments\s+SET data = jsonb_set\(data, '\{solde\}', to_jsonb\(COALESCE\(\(data->>'solde'\)::numeric,0\) - p_montant\)\), updated_at = now\(\)\s+WHERE id = v_caisse_id;$m$,
  E'\n  -- #267 : l''argent prêté reste sur le compte Helvetia du client ; la caisse ne bouge qu''au retrait.'
]);

-- 2. Remboursement intégral : la part prise sur le compte Helvetia ne crédite plus la caisse.
SELECT pg_temp.helvetia_corriger('public.rembourser_pret_helvetia_integral(text,text,jsonb)',
  'e9b8e2f9489564f0e4a0496729604c47', '976bf2fc79ed77f1649848a522b99459', ARRAY[
  $m$\+v_total\)\), updated_at = now\(\)$m$, $r$+v_total-v_helvetia_requis)), updated_at = now()$r$,
  $m$jsonb_build_object\('solde', v_total\)$m$, $r$jsonb_build_object('solde', v_total-v_helvetia_requis)$r$
]);

-- 3. Nuit : mensualité et saisie prélevées sur le compte Helvetia ne créditent plus la caisse.
SELECT pg_temp.helvetia_corriger('public.traiter_prets_helvetia_quotidien()',
  '4d80d4e3a329c2d575d80eacb9311b3d', '88920c938fc3a8da8af506b07ed5224c', ARRAY[
  $m$(banque = 'helvetia';\s+UPDATE public\.caisses_batiments\s+SET data = jsonb_set\(data,'\{solde\}', to_jsonb\(COALESCE\(\(data->>'solde'\)::numeric,0\))\+v_a_prelever(\)\), updated_at = now\(\)\s+WHERE id = v_caisse_id;\s+IF NOT FOUND THEN\s+INSERT INTO public\.caisses_batiments \(id, data, updated_at\) VALUES \(v_caisse_id, jsonb_build_object\('solde', )v_a_prelever\)$m$,
  $r$\1\20)$r$,
  $m$(banque = 'helvetia';\s+UPDATE public\.caisses_batiments\s+SET data = jsonb_set\(data,'\{solde\}', to_jsonb\(COALESCE\(\(data->>'solde'\)::numeric,0\))\+v_seize(\)\), updated_at = now\(\)\s+WHERE id = v_caisse_id;\s+IF NOT FOUND THEN\s+INSERT INTO public\.caisses_batiments \(id, data, updated_at\) VALUES \(v_caisse_id, jsonb_build_object\('solde', )v_seize\)$m$,
  $r$\1\20)$r$
]);

-- 4. Fermeture : seule la restitution sort de la caisse ; la part appliquée à la dette y était déjà.
SELECT pg_temp.helvetia_corriger('public.fermer_compte_helvetia(text,text)',
  '782884435ecfa5561ae720636a27eee8', '515464a1ccdc0a9d65117c6aba5e5cd4', ARRAY[
  $m$COALESCE\(\(data->>'solde'\)::numeric,0\) \+ v_applique_a_la_dette - v_restitution$m$,
  $r$COALESCE((data->>'solde')::numeric,0) - v_restitution$r$,
  $m$GREATEST\(0, v_applique_a_la_dette - v_restitution\)$m$, $r$0$r$
]);

-- 5. Ouverture de compte : le dépôt initial de 10 000 FR entre dans la caisse (il n'y entrait pas).
SELECT pg_temp.helvetia_corriger('public.ouvrir_compte_helvetia(text)',
  'b4c8cb26121db02836ef1e6a28611c02', 'cafabbef5b777a1cf6c8d7dcb967a3c4', ARRAY[
  $m$returning \* into v_nouveau_compte;$m$,
  $r$returning * into v_nouveau_compte;

  -- #267 : le dépôt d'ouverture entre dans la caisse d'Helvetia (argent détenu par la banque).
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) + 10000)), updated_at = now()
    WHERE id = v_perso.country || '_banque-privee';
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_perso.country || '_banque-privee', jsonb_build_object('solde', 10000), now());
  END IF;$r$
]);

COMMIT;
