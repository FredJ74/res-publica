-- Banc annulé : salaires du pouvoir de Sovarka (07/11/2026). Rien ne reste.
BEGIN;
-- Pouvoir en Sovarka, étape 1 (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
-- salaires du président (800 PSK), du Président du Conseil du Peuple (pm, 700 PSK)
-- et des ministres (560 PSK).
--
-- Préalable obligatoire : depuis 20261106060000, le pays payeur d'un poste se déduit
-- d'un barème UNIQUE par clé ; une deuxième ligne (soviet) pour pm/min_*/president
-- ferait refuser le salaire de TOUS les titulaires (« pays_employeur_ambigu »).
-- Le pays employeur vient donc d'abord du registre du poste :
--   1. postes nommés : postes_attribues.country du titulaire ;
--   2. postes élus : cycles_electoraux.country où il est l'élu (eluId) ;
--   3. sinon, l'ancien barème unique ; s'il est ambigu, refus nommé (inchangé).
-- Jamais le pays de présence pour un poste déclaré dans plusieurs pays.
DO $patch$
DECLARE
  v_source text;
  v_avant text := $old$  IF v_poste IS NOT NULL THEN
    SELECT count(DISTINCT s.pays), min(s.pays)$old$;
  v_apres text := $new$  IF v_poste IS NOT NULL THEN
    SELECT a.country INTO v_poste_pays
      FROM public.postes_attribues a
     WHERE a.titulaire = v_moi AND a.poste_id = v_poste
     ORDER BY a.updated_at DESC NULLS LAST LIMIT 1;
    IF v_poste_pays IS NULL THEN
      SELECT c.country INTO v_poste_pays
        FROM public.cycles_electoraux c
       WHERE c.poste_id = v_poste AND c.data::jsonb ->> 'eluId' = v_moi
       ORDER BY c.updated_at DESC NULLS LAST LIMIT 1;
    END IF;
  END IF;
  IF v_poste_pays IS NOT NULL THEN
    v_pays := v_poste_pays;
  ELSIF v_poste IS NOT NULL THEN
    SELECT count(DISTINCT s.pays), min(s.pays)$new$;
BEGIN
  SELECT pg_get_functiondef('public.salaire_civil_percevoir()'::regprocedure) INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_avant) = 0
     OR strpos(v_source, 'cycles_electoraux') > 0
  THEN RAISE EXCEPTION 'salaire_civil_percevoir_version_inattendue'; END IF;
  v_source := replace(v_source, v_avant, v_apres);
  EXECUTE v_source;
  IF NOT EXISTS (SELECT 1 FROM pg_proc
                  WHERE oid = 'public.salaire_civil_percevoir()'::regprocedure
                    AND pg_get_functiondef(oid) LIKE '%cycles_electoraux%')
  THEN RAISE EXCEPTION 'salaire_pays_du_registre_absent'; END IF;
END $patch$;

INSERT INTO public.salaires_civils_declares (pays, categorie, cle, montant)
VALUES ('soviet','poste','president',800), ('soviet','poste','pm',700),
       ('soviet','poste','min_int',560), ('soviet','poste','min_fin',560),
       ('soviet','poste','min_just',560), ('soviet','poste','min_def',560),
       ('soviet','poste','min_info',560), ('soviet','poste','min_ae',560)
ON CONFLICT DO NOTHING;
DO $banc$
DECLARE r1 jsonb; r2 jsonb; r3 jsonb; u_arnie uuid; u_jean uuid; u_angie uuid; j date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT user_id INTO u_arnie FROM personnages_donnees WHERE name='Arnie';
  SELECT user_id INTO u_jean FROM personnages_donnees WHERE name='Jean Jaaj';
  SELECT user_id INTO u_angie FROM personnages_donnees WHERE name='Angie Porcelana';
  DELETE FROM salaires_civils_verses WHERE jour=j AND personnage IN ('Arnie','Jean Jaaj','Angie Porcelana');
  -- Jean Jaaj devient Président du Conseil du Peuple de Sovarka (simulé)
  UPDATE personnages_donnees SET poste = jsonb_build_object('id','pm') WHERE name='Jean Jaaj';
  DELETE FROM postes_attribues WHERE titulaire='Jean Jaaj';
  INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,depuis,source,updated_at)
  VALUES ('banc_soviet_pm','soviet','pm',NULL,'Jean Jaaj',now(),'banc',now());
  -- Angie élue présidente de Sovarka (simulé), sans ligne de registre de poste nommé
  UPDATE personnages_donnees SET poste = jsonb_build_object('id','president') WHERE name='Angie Porcelana';
  DELETE FROM postes_attribues WHERE titulaire='Angie Porcelana';
  INSERT INTO cycles_electoraux(id,country,poste_id,data,updated_at,city)
  VALUES ('banc_soviet_president','soviet','president', jsonb_build_object('eluId','Angie Porcelana')::text, now(), NULL);
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  r1 := salaire_civil_percevoir();
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_jean,'role','authenticated')::text, true);
  r2 := salaire_civil_percevoir();
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_angie,'role','authenticated')::text, true);
  r3 := salaire_civil_percevoir();
  RAISE EXCEPTION 'banc annule | arnie(min_def republic)=% | jean(pm soviet)=% | angie(president soviet)=%',
    jsonb_build_object('du',r1->'du','caisse',r1->'caisse','raison',r1->'raison'),
    jsonb_build_object('du',r2->'du','caisse',r2->'caisse','raison',r2->'raison'),
    jsonb_build_object('du',r3->'du','caisse',r3->'caisse','raison',r3->'raison');
END $banc$;
ROLLBACK;
