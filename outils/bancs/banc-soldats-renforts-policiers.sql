-- Banc annulé de 20261103163000_soldats_renforts_policiers : à jouer APRÈS la migration, dans la
-- même transaction ; l'exception finale annule tout. Soldats de Vince Kubrick, salle de commandement.
DO $banc$
DECLARE v jsonb; n_tiers integer; n_vince integer; m_tiers integer;
BEGIN
  v := public.securite_agents_prives_presents_interne('republic', 'caserne', 'caserne-militaire', 'salle_commandement', NULL, 'Angie Porcelana');
  SELECT count(*) INTO n_tiers FROM jsonb_array_elements(v) x WHERE x ->> 'pnj_prive_id' LIKE 'compagnie-%';
  v := public.securite_agents_prives_presents_interne('republic', 'caserne', 'caserne-militaire', 'salle_commandement', NULL, 'Vince Kubrick');
  SELECT count(*) INTO n_vince FROM jsonb_array_elements(v) x WHERE x ->> 'pnj_prive_id' LIKE 'compagnie-%';
  IF n_tiers = 0 THEN RAISE EXCEPTION 'banc 1: soldats postés absents des forces de police'; END IF;
  IF n_vince <> 0 THEN RAISE EXCEPTION 'banc 2: l''escorte compte contre son propre chef (%)', n_vince; END IF;
  -- Dissuasion : un tiers dans la pièce subit le malus des soldats.
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'caserne', current_building = 'caserne-militaire',
         current_room = 'salle_commandement', current_street = NULL WHERE name = 'Angie Porcelana';
  m_tiers := public.securite_malus_lieu_interne('Angie Porcelana');
  IF m_tiers <> least(40, 10 + n_tiers) THEN RAISE EXCEPTION 'banc 3: malus % pour % soldats', m_tiers, n_tiers; END IF;
  IF to_regprocedure('public.controle_detachement_interne(text)') IS NOT NULL
     OR has_function_privilege('authenticated', 'public.militaire_assigner_mission(text,text,text,text)', 'execute')
     OR EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'assigner_mission') THEN
    RAISE EXCEPTION 'banc 4: mission encore présente';
  END IF;
  RAISE EXCEPTION 'BANC OK : % soldats renforts policiers, escorte exclue, malus %, missions retirées', n_tiers, m_tiers;
END $banc$;
