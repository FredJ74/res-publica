-- Banc ANNULÉ du socle fonds et murs (#66). Se joue en concaténant la migration
-- 20261101193000_fonds_murs_commerces_socle.sql AVANT ce fichier, dans la même transaction :
--   BEGIN; <migration>; <ce fichier>; -- se termine TOUJOURS par une exception : rien ne reste.
-- Verdict attendu : « BANC_FONDS_MURS_OK » et la liste des épreuves.
DO $banc$
DECLARE
  r jsonb; c jsonb; v text[] := ARRAY[]::text[];
  jean text := 'Jean Jaaj'; angie text := 'Angie Porcelana'; arnie text := 'Arnie'; may text := 'May';
  u_jean text; u_angie text; u_arnie text; u_may text;
  cafe text := 'cafe-republic-ville_b-cafe-gare-montrouge';
  bar  text := 'bar-republic-ville_a-bar-des-pecheurs-salle_bar';
  rep  text := 'brasserie-republic-capitale-hotel-republica';
  caisse_mtg text; solde_avant numeric; solde_apres numeric;
  a0 numeric; a1 numeric; pa0 integer; pa1 integer; q uuid := gen_random_uuid(); n integer;
BEGIN
  SELECT user_id INTO u_jean  FROM personnages WHERE name = jean;
  SELECT user_id INTO u_angie FROM personnages WHERE name = angie;
  SELECT user_id INTO u_arnie FROM personnages WHERE name = arnie;
  SELECT user_id INTO u_may   FROM personnages WHERE name = may;
  -- Mise en place (serveur) : de quoi payer, des PA, sur place à l'Office notarial.
  UPDATE personnages_donnees SET liquide = 600000, arg = 600000 + coalesce((SELECT solde FROM comptes_bancaires WHERE personnage = name AND banque='nationale'),0), pa = 20
   WHERE name IN (jean, angie, arnie);
  caisse_mtg := salaire_caisse_de('maire', 'republic', 'ville_b');
  SELECT (data->>'solde')::numeric INTO solde_avant FROM caisses_batiments WHERE id = caisse_mtg;

  -- 1. Catalogue (Jean, client authentifié)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_jean, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_catalogue();
  IF jsonb_array_length(r->'titres') <> 14 THEN RAISE EXCEPTION 'E1 catalogue : % titres', jsonb_array_length(r->'titres'); END IF;
  SELECT x INTO c FROM jsonb_array_elements(r->'titres') x WHERE x->>'id' = rep;
  IF (c#>>'{murs,prix}')::numeric <> 180000 OR (c#>>'{fonds,prix}')::numeric <> 380000 OR (c#>>'{ensemble,prix}')::numeric <> 560000 THEN
    RAISE EXCEPTION 'E1 La Républia : %', c; END IF;
  v := v || 'catalogue 14 titres, La Républia 180 000 + 380 000 = 560 000';

  -- 2. Jean achète les murs du Café de la Gare à la commune
  EXECUTE 'RESET ROLE';
  SELECT arg, pa INTO a0, pa0 FROM personnages_donnees WHERE name = jean;
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(jean, cafe, 'murs', 80000, gen_random_uuid());
  IF r->>'raison' <> 'prix_change' OR (r->>'prix')::numeric <> 82500 THEN RAISE EXCEPTION 'E2 prix faux : %', r; END IF;
  r := immobilier_acheter(jean, cafe, 'murs', 82500, q);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E2 achat murs : %', r; END IF;
  r := immobilier_acheter(jean, cafe, 'murs', 82500, q);
  IF (r->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E2 rejeu : %', r; END IF;
  EXECUTE 'RESET ROLE';
  SELECT arg, pa INTO a1, pa1 FROM personnages_donnees WHERE name = jean;
  SELECT (data->>'solde')::numeric INTO solde_apres FROM caisses_batiments WHERE id = caisse_mtg;
  IF a0 - a1 <> 82500 OR pa0 - pa1 <> 1 THEN RAISE EXCEPTION 'E2 débit % PA %', a0 - a1, pa0 - pa1; END IF;
  IF solde_apres - solde_avant <> 82500 THEN RAISE EXCEPTION 'E2 caisse mairie +%', solde_apres - solde_avant; END IF;
  IF (SELECT proprietaire FROM murs_titres WHERE id = cafe) <> jean THEN RAISE EXCEPTION 'E2 titre'; END IF;
  IF (SELECT data->>'proprietaire' FROM entreprises WHERE id = cafe) <> 'PNJ' THEN RAISE EXCEPTION 'E2 le fonds a bougé'; END IF;
  v := v || 'murs communaux : prix annoncé faux refusé, achat 82 500 FR + 1 PA, caisse de Montrouge +82 500, fonds inchangé, rejeu sans double débit';

  -- 3. Fonds PNJ seul : renvoyé au parcours du compromis ; ensemble sur des murs non à vendre : refusé
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_angie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(angie, cafe, 'fonds', 180000, gen_random_uuid());
  IF r->>'raison' <> 'fonds_pnj_par_compromis' THEN RAISE EXCEPTION 'E3 fonds PNJ : %', r; END IF;
  r := immobilier_acheter(angie, cafe, 'ensemble', 262500, gen_random_uuid());
  IF r->>'raison' <> 'murs_pas_en_vente' THEN RAISE EXCEPTION 'E3 ensemble : %', r; END IF;
  v := v || 'fonds PNJ seul renvoyé au compromis ; ensemble refusé si les murs ne sont pas à vendre';

  -- 4. Angie achète l'ensemble du Bar des Pêcheurs (murs commune + fonds PNJ), en un seul acte
  r := immobilier_acheter(angie, bar, 'ensemble', 82500 + 180000, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E4 ensemble : %', r; END IF;
  EXECUTE 'RESET ROLE';
  IF (SELECT proprietaire FROM murs_titres WHERE id = bar) <> angie
     OR (SELECT data->>'proprietaire' FROM entreprises WHERE id = bar) <> angie THEN RAISE EXCEPTION 'E4 titres'; END IF;
  v := v || 'achat conjoint : murs et fonds à Angie dans le même acte (262 500 FR)';

  -- 5. Tout ou rien : May n'a pas les 560 000 FR, rien ne bouge (ni PA, ni titre)
  SELECT arg, pa INTO a0, pa0 FROM personnages_donnees WHERE name = may;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_may, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(may, rep, 'ensemble', 560000, gen_random_uuid());
  EXECUTE 'RESET ROLE';
  SELECT arg, pa INTO a1, pa1 FROM personnages_donnees WHERE name = may;
  IF r->>'raison' <> 'fonds_insuffisants' OR a0 <> a1 OR pa0 <> pa1 THEN RAISE EXCEPTION 'E5 : % (arg % -> %, pa % -> %)', r, a0, a1, pa0, pa1; END IF;
  IF (SELECT proprietaire FROM murs_titres WHERE id = rep) <> 'commune' THEN RAISE EXCEPTION 'E5 titre'; END IF;
  v := v || 'fonds insuffisants : refus nommé, ni argent ni PA ni titre';

  -- 6. Priorité de l'exploitant : Angie exploite le fonds du Café de la Gare, Jean met ses murs en vente
  UPDATE entreprises SET data = data || jsonb_build_object('proprietaire', angie) WHERE id = cafe;
  SELECT count(*) INTO n FROM mails WHERE to_player = angie AND from_player = 'Office notarial';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_mettre_en_vente(arnie, cafe, 'murs', 90000);
  IF r->>'raison' <> 'pas_proprietaire' THEN RAISE EXCEPTION 'E6 non propriétaire : %', r; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_jean, 'role', 'authenticated')::text, true);
  r := immobilier_mettre_en_vente(jean, cafe, 'murs', 90000);
  IF r#>>'{titre,murs,statut}' <> 'priorite' OR r#>>'{titre,murs,prioritaire}' <> angie THEN RAISE EXCEPTION 'E6 priorité : %', r; END IF;
  EXECUTE 'RESET ROLE';
  IF (SELECT count(*) FROM mails WHERE to_player = angie AND from_player = 'Office notarial') <> n + 1 THEN RAISE EXCEPTION 'E6 courrier'; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(arnie, cafe, 'murs', 90000, gen_random_uuid());
  IF r->>'raison' <> 'priorite_exploitant' THEN RAISE EXCEPTION 'E6 tiers pendant la priorité : %', r; END IF;
  r := immobilier_priorite_renoncer(arnie, cafe);
  IF r->>'raison' <> 'pas_prioritaire' THEN RAISE EXCEPTION 'E6 renoncement d''un tiers : %', r; END IF;
  EXECUTE 'RESET ROLE';
  v := v || 'mise en vente par un non-propriétaire refusée ; murs occupés : priorité de 3 jours à l''exploitant, courrier reçu, tiers bloqué';

  -- 7. Délai écoulé (heure du serveur) : la vente s'ouvre à tous, sans cron
  UPDATE murs_titres SET offre = jsonb_set(offre, '{prioriteJusque}', to_jsonb((extract(epoch from now())*1000)::bigint - 1000)) WHERE id = cafe;
  SELECT arg INTO a0 FROM personnages_donnees WHERE name = jean;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(arnie, cafe, 'murs', 90000, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E7 après délai : %', r; END IF;
  EXECUTE 'RESET ROLE';
  SELECT arg INTO a1 FROM personnages_donnees WHERE name = jean;
  IF a1 - a0 <> 90000 THEN RAISE EXCEPTION 'E7 Jean crédité de %', a1 - a0; END IF;
  IF (SELECT data->>'proprietaire' FROM entreprises WHERE id = cafe) <> angie THEN RAISE EXCEPTION 'E7 exploitation affectée'; END IF;
  v := v || 'délai écoulé : Arnie achète au prix libre de 90 000 FR, Jean crédité, l''exploitation d''Angie intacte';

  -- 8. Renoncement explicite : publication immédiate
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_mettre_en_vente(arnie, cafe, 'murs', 95000);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_angie, 'role', 'authenticated')::text, true);
  r := immobilier_priorite_renoncer(angie, cafe);
  IF r#>>'{titre,murs,statut}' <> 'disponible' THEN RAISE EXCEPTION 'E8 renoncement : %', r; END IF;
  v := v || 'renoncement de l''exploitant : vente ouverte aussitôt';

  -- 9. Exercice de la priorité par l'exploitant
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_arnie, 'role', 'authenticated')::text, true);
  r := immobilier_retirer_vente(arnie, cafe, 'murs');
  r := immobilier_mettre_en_vente(arnie, cafe, 'murs', 95000);
  IF r#>>'{titre,murs,statut}' <> 'priorite' THEN RAISE EXCEPTION 'E9 nouvelle priorité : %', r; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_angie, 'role', 'authenticated')::text, true);
  r := immobilier_acheter(angie, cafe, 'murs', 95000, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E9 achat prioritaire : %', r; END IF;
  v := v || 'retrait puis remise en vente : nouvelle priorité ; l''exploitante achète ses murs';

  -- 10. Fonds d'un PJ à prix libre
  r := immobilier_mettre_en_vente(angie, bar, 'fonds', 200000);
  IF (r#>>'{titre,fonds,prix}')::numeric <> 200000 OR r#>>'{titre,fonds,regime}' <> 'libre' THEN RAISE EXCEPTION 'E10 offre : %', r; END IF;
  EXECUTE 'RESET ROLE';
  SELECT arg INTO a0 FROM personnages_donnees WHERE name = angie;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u_jean, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r := immobilier_acheter(jean, bar, 'fonds', 200000, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'E10 achat : %', r; END IF;
  EXECUTE 'RESET ROLE';
  SELECT arg INTO a1 FROM personnages_donnees WHERE name = angie;
  IF a1 - a0 <> 200000 OR (SELECT proprietaire FROM murs_titres WHERE id = bar) <> angie
     OR (SELECT data->>'proprietaire' FROM entreprises WHERE id = bar) <> jean THEN RAISE EXCEPTION 'E10 titres ou crédit'; END IF;
  v := v || 'fonds de PJ à prix libre : Jean achète le fonds, Angie créditée de 200 000 FR et garde les murs';

  -- 11. Le client ne peut ni écrire les titres ni appeler le moteur de lecture
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE murs_titres SET proprietaire = 'May' WHERE id = rep;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n > 0 THEN RAISE EXCEPTION 'E11 écriture client acceptée'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM immobilier_titre_etat_interne(rep, 'May');
    RAISE EXCEPTION 'E11 moteur joignable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  EXECUTE 'RESET ROLE';
  v := v || 'titres en lecture seule pour le client ; moteur injoignable';

  RAISE EXCEPTION 'BANC_FONDS_MURS_OK (% épreuves) : %', array_length(v, 1), array_to_string(v, ' | ');
END $banc$;
