-- Banc #267 — caisse d'Helvetia = argent détenu (migration 20261031140000).
-- Production, transaction ANNULÉE (fin par RAISE EXCEPTION). Personnage d'essai : Arnie.
-- Mesure à chaque étape la caisse de la République (C) et l'encours de refinancement BNR (E).
BEGIN;
SELECT set_config('banc.res', '{}', false);
CREATE FUNCTION pg_temp.noter(k text, v jsonb) RETURNS void LANGUAGE sql AS
$f$ SELECT set_config('banc.res', (current_setting('banc.res')::jsonb || jsonb_build_object(k, v))::text, false) $f$;
CREATE FUNCTION pg_temp.etat() RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $f$
 SELECT jsonb_build_object(
  'C', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = 'republic_banque-privee'),
  'E', (SELECT coalesce(sum(montant), 0) FROM public.bnr_refinancements_helvetia WHERE country = 'republic' AND statut = 'actif'),
  'compte', (SELECT solde FROM public.comptes_bancaires WHERE personnage = 'Arnie' AND banque = 'helvetia'),
  'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = 'Arnie')) $f$;
CREATE FUNCTION pg_temp.joueur() RETURNS void LANGUAGE plpgsql AS $f$ BEGIN
 PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"9abef1c4-75ab-4352-b5ca-a219fc37a35c"}', true);
 PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.noter(text, jsonb), pg_temp.etat(), pg_temp.joueur() TO PUBLIC;

-- Contre-épreuve : avant la migration, le prêt vide la caisse (et emprunte à la BNR).
DO $avant$ DECLARE a jsonb; b jsonb; v jsonb; BEGIN
  BEGIN
    PERFORM pg_temp.joueur(); SET LOCAL ROLE authenticated;
    PERFORM public.ouvrir_compte_helvetia('Arnie');
    a := pg_temp.etat();
    PERFORM public.creer_pret_helvetia('Arnie', 20000, 30);
    b := pg_temp.etat();
    v := jsonb_build_object('avant', a, 'apres', b);
    RAISE EXCEPTION 'annuler';
  EXCEPTION WHEN others THEN
    PERFORM pg_temp.noter('00_contre_epreuve_pret', coalesce(v, to_jsonb(SQLERRM)));
  END;
END $avant$;

-- Corps exact de la migration (sans BEGIN/COMMIT)
-- #267 — La caisse d'Helvetia sortait deux fois pour le même argent (Claude, 31/10/2026).
-- Compatible avec l'écran en ligne ; aucune donnée de joueur modifiée.
--
-- Règle retenue (choix technique) : la caisse `<pays>_banque-privee` est l'argent que la banque
-- détient réellement. Un dépôt l'augmente ; un retrait et la restitution à la fermeture d'un
-- compte la diminuent.
--   * creer_pret_helvetia : l'argent prêté reste sur le compte Helvetia du client, rien ne sort
--     de la caisse. Plus de débit ni d'appel à helvetia_assurer_liquidite (le retrait, lui,
--     continue de vérifier la liquidité et de débiter la caisse).
--   * Ce qui passe du compte Helvetia du client à la banque (remboursement intégral, mensualité,
--     saisie sur le compte Helvetia, part appliquée à la dette à la fermeture) était déjà dans la
--     caisse : il ne la crédite plus. Ce qui vient du liquide ou du compte national la crédite
--     toujours.
-- Le refinancement BNR déjà contracté (~150 000 FR de trop pour la République) n'est pas touché :
-- c'est une décision d'économie réservée à Fred.

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


DO $apres$ DECLARE a jsonb; b jsonb; r jsonb; pret text; restant numeric; helv numeric; liq numeric; nat numeric; BEGIN
  PERFORM pg_temp.joueur(); SET LOCAL ROLE authenticated;
  a := pg_temp.etat();
  PERFORM public.ouvrir_compte_helvetia('Arnie');
  b := pg_temp.etat(); PERFORM pg_temp.noter('0_ouverture', jsonb_build_object('avant', a, 'apres', b));
  a := b;
  PERFORM public.creer_pret_helvetia('Arnie', 20000, 30);
  b := pg_temp.etat(); PERFORM pg_temp.noter('1_pret_20000', jsonb_build_object('avant', a, 'apres', b));
  a := b; PERFORM public.retirer_helvetia('Arnie', 8000, 'liquide');
  b := pg_temp.etat(); PERFORM pg_temp.noter('2_retrait_8000', jsonb_build_object('avant', a, 'apres', b));
  RESET ROLE;
  SELECT id INTO pret FROM public.prets WHERE emprunteur = 'Arnie' AND type_banque = 'helvetia' AND statut = 'en_cours';
  UPDATE public.prets SET jour_dernier_prelevement = NULL WHERE id = pret;
  a := pg_temp.etat(); SET LOCAL ROLE service_role;
  PERFORM count(*) FROM public.traiter_prets_helvetia_quotidien();
  RESET ROLE;
  b := pg_temp.etat(); PERFORM pg_temp.noter('3_mensualite_nuit', jsonb_build_object('avant', a, 'apres', b,
    'restant', (SELECT montant_restant FROM public.prets WHERE id = pret)));
  SELECT montant_restant INTO restant FROM public.prets WHERE id = pret;
  -- Remboursement mixte : compte Helvetia (au-dessus du plancher), liquide, puis compte national.
  helv := (b->>'compte')::numeric - 10000 - 100; liq := least((b->>'liquide')::numeric, restant - helv); nat := restant - helv - liq;
  a := b; PERFORM pg_temp.joueur(); SET LOCAL ROLE authenticated;
  PERFORM public.rembourser_pret_helvetia_integral('Arnie', pret,
    jsonb_build_array(jsonb_build_object('type', 'liquide', 'montant', liq), jsonb_build_object('type', 'helvetia', 'montant', helv))
    || CASE WHEN nat > 0 THEN jsonb_build_array(jsonb_build_object('type', 'national', 'montant', nat)) ELSE '[]'::jsonb END);
  b := pg_temp.etat(); PERFORM pg_temp.noter('4_remboursement', jsonb_build_object('avant', a, 'apres', b, 'part_liquide', liq, 'part_national', nat, 'part_helvetia', helv));
  a := b; PERFORM public.fermer_compte_helvetia('Arnie', 'liquide');
  b := pg_temp.etat(); PERFORM pg_temp.noter('5_fermeture', jsonb_build_object('avant', a, 'apres', b));
  RESET ROLE;
  RAISE EXCEPTION 'BANC %', current_setting('banc.res');
END $apres$;
ROLLBACK;
