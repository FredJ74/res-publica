-- =====================================================================================
-- INCENDIE ET EXPLOSIFS : BÂTIMENTS SENSIBLES DANS TOUTES LES VILLES (29/10/2026, Claude).
-- NON APPLIQUÉE — application par ChatGPT. Compatible avec l'écran en ligne.
--
-- Le malus de 30 points (bâtiment gardé) visait le commissariat, le tribunal et les banques de
-- Luthécia, mais pas leurs équivalents de Montrouge et de Port-Sainte-Marie
-- (`commissariat-local`, `tribunal-local`, `banque-locale`). Ces bâtiments y étaient donc plus
-- faciles à incendier ou à faire sauter. Même règle partout, comme les pouvoirs des
-- commissaires (décision de Fred du 29/10).
-- Correction en place : seule la liste change, le reste des deux fonctions est conservé.
-- =====================================================================================
DO $$
DECLARE f text; d text;
  ancien text := '''banque-nationale'',''banque-privee'',''mairie-capitale'',''mairie'')';
  nouveau text := '''banque-nationale'',''banque-privee'',''mairie-capitale'',''mairie'',''commissariat-local'',''tribunal-local'',''banque-locale'')';
BEGIN
  FOREACH f IN ARRAY ARRAY['crime_incendier', 'crime_explosifs'] LOOP
    SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.proname = f;
    IF d IS NULL THEN RAISE EXCEPTION 'fonction_absente %', f; END IF;
    IF position('''commissariat-local'',''tribunal-local'',''banque-locale''' IN d) > 0 THEN CONTINUE; END IF;
    IF (length(d) - length(replace(d, ancien, ''))) / length(ancien) <> 1 THEN
      RAISE EXCEPTION 'fragment_introuvable %', f; END IF;
    EXECUTE replace(d, ancien, nouveau);
  END LOOP;
END $$;
