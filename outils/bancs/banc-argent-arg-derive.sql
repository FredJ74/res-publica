-- Banc de 20261104013000_argent_arg_derive (à jouer en production APRÈS le contenu de la
-- migration, dans la même transaction : BEGIN; <migration>; <ce banc>; tout est annulé par
-- l'exception finale « BANC … »).
-- Attendu : toutes les fiches cohérentes (arg = liquide + Banque nationale) ; crédit au compte,
-- débit liquide puis compte, vol limité au liquide ; plus aucune fonction n'écrit arg seul.
DO $banc$
DECLARE r record; n integer; a0 numeric; l0 numeric; s0 numeric; a1 numeric; l1 numeric; s1 numeric;
        pris numeric; cible text; rapport text := '';
BEGIN
  -- 1. Cohérence de toutes les fiches qui ont un compte national.
  SELECT count(*) INTO n FROM public.personnages_donnees p
   WHERE EXISTS (SELECT 1 FROM public.comptes_bancaires c WHERE c.personnage = p.name AND c.banque = 'nationale')
     AND p.arg <> round(coalesce(p.liquide,0) + (SELECT sum(solde) FROM public.comptes_bancaires c
                                                  WHERE c.personnage = p.name AND c.banque = 'nationale'));
  IF n > 0 THEN RAISE EXCEPTION 'BANC ECHEC : % fiches incoherentes', n; END IF;
  FOR r IN SELECT name, arg FROM public.personnages_donnees WHERE name IN ('Jean Jaaj','Angie Porcelana','Arnie') ORDER BY name LOOP
    rapport := rapport || r.name || '=' || r.arg || ' ';
  END LOOP;

  -- 2. Crédit au compte national, puis débit liquide puis compte (Angie Porcelana).
  cible := 'Angie Porcelana';
  SELECT arg, liquide INTO a0, l0 FROM public.personnages_donnees WHERE name = cible;
  SELECT solde INTO s0 FROM public.comptes_bancaires WHERE personnage = cible AND banque = 'nationale';
  PERFORM public.argent_crediter_interne(cible, 100, 'nationale');
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name = cible;
  IF a1 <> a0 + 100 THEN RAISE EXCEPTION 'BANC ECHEC credit : % -> %', a0, a1; END IF;
  pris := public.argent_debiter_interne(cible, l0 + 30, 'liquide_puis_nationale');
  SELECT arg, liquide INTO a1, l1 FROM public.personnages_donnees WHERE name = cible;
  SELECT solde INTO s1 FROM public.comptes_bancaires WHERE personnage = cible AND banque = 'nationale';
  IF pris <> l0 + 30 OR l1 <> 0 OR s1 <> s0 + 70 OR a1 <> s0 + 70 THEN
    RAISE EXCEPTION 'BANC ECHEC debit : pris % liquide % solde % arg %', pris, l1, s1, a1; END IF;
  -- Débit au-delà de tout : ne prend que ce qui existe.
  pris := public.argent_debiter_interne(cible, 1000000, 'liquide_puis_nationale');
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name = cible;
  IF pris <> s0 + 70 OR a1 <> 0 THEN RAISE EXCEPTION 'BANC ECHEC debit borne : pris % arg %', pris, a1; END IF;
  -- Vol : liquide seul.
  PERFORM public.argent_crediter_interne(cible, 40, 'liquide');
  PERFORM public.argent_crediter_interne(cible, 500, 'nationale');
  pris := public.argent_debiter_interne(cible, 100, 'liquide');
  IF pris <> 40 THEN RAISE EXCEPTION 'BANC ECHEC vol : pris %', pris; END IF;
  rapport := rapport || '| moteurs OK ';

  -- 3. Une écriture directe de arg est sans effet.
  UPDATE public.personnages_donnees SET arg = 999999 WHERE name = cible;
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name = cible;
  IF a1 <> 500 THEN RAISE EXCEPTION 'BANC ECHEC arg force : %', a1; END IF;

  -- 4. Plus aucune fonction n'écrit arg seul (hors moteurs de poches qui écrivent aussi liquide/compte).
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public'
     AND p.prosrc ~* 'UPDATE\s+(public\.)?personnages_donnees\s+SET\s+arg\s*=\s*[^=]'
     AND p.proname IN ('cotisation_renouveler','crime_voler','eviction_indemniser','football_pari_engager',
       'football_paris_resoudre','football_primes_match','fraude_electorale_sanctionner','immobilier_acheter',
       'justice_indemnite_naitre','justice_indemnites_payer_depuis_finances','regler_creances_helvetia_quotidien',
       'restituer_reliquats_chantier','subvention_citoyen_verser','succession_regler','taxe_fonciere_prelever',
       'compromis_expire_resoudre');
  IF n > 0 THEN RAISE EXCEPTION 'BANC ECHEC : % fonctions ecrivent encore arg seul', n; END IF;

  -- 5. Droits : seul le rôle service appelle le mouvement ; personne n'appelle les moteurs.
  IF has_function_privilege('authenticated', 'public.argent_crediter_interne(text,numeric,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.argent_mouvement_serveur(text,numeric,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.argent_mouvement_serveur(text,numeric,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.argent_mouvement_serveur(text,numeric,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'BANC ECHEC droits'; END IF;

  RAISE EXCEPTION 'BANC OK : %', rapport;
END;
$banc$;
