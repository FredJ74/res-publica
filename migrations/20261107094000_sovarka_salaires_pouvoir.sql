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
