-- Équipes de renseignement par empire et par ministère (Fred, 13/11/2026, 21 h 53 – 22 h 14 ;
-- GAME-DESIGN-NOVOMIRSK.md, « Équipes de renseignement par empire »).
-- Avant : un seul vivier de 4 identités réelles (renseignement_identites_reelles, clé = rôle) et
-- 4 PNJ uniques (agent-<rôle>) partagés par tous les pays : un même agent pouvait servir deux empires.
-- Après : chaque identité appartient à une équipe « <pays>-<poste> ». La Républia garde son équipe
-- (republic-min_def, mêmes PNJ, mêmes identifiants) ; Sovarka reçoit soviet-min_int et soviet-min_def.
-- Partie 1/4 (structure). Les fonctions de la chaîne sont adaptées en partie 2.

ALTER TABLE public.renseignement_identites_reelles
  ADD COLUMN IF NOT EXISTS equipe text NOT NULL DEFAULT 'republic-min_def';
ALTER TABLE public.agents_renseignement ADD COLUMN IF NOT EXISTS equipe text;
ALTER TABLE public.cellules_renseignement ADD COLUMN IF NOT EXISTS ministere text;
UPDATE public.agents_renseignement SET equipe = 'republic-min_def' WHERE equipe IS NULL;
UPDATE public.cellules_renseignement SET ministere = 'min_def' WHERE ministere IS NULL;

-- Clé : (équipe, rôle) au lieu du seul rôle.
DO $cle$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_index i JOIN pg_class t ON t.oid = i.indrelid
     WHERE t.relname = 'renseignement_identites_reelles' AND i.indisprimary
       AND array_length(i.indkey::int2[], 1) = 2) THEN
    ALTER TABLE public.renseignement_identites_reelles DROP CONSTRAINT renseignement_identites_reelles_pkey;
    ALTER TABLE public.renseignement_identites_reelles ADD PRIMARY KEY (equipe, role);
  END IF;
END $cle$;

-- Noms validés par Fred (13/11/2026, 21 h 54). Même composition et même DUP (13) que le socle.
INSERT INTO public.renseignement_identites_reelles (equipe, role, vrai_nom, dup, sexe) VALUES
  ('soviet-min_int', 'coordinateur', 'Arkadi Moltchanov',   13, 'H'),
  ('soviet-min_int', 'conseiller',   'Vera Taïnova',        13, 'F'),
  ('soviet-min_int', 'garde',        'Kirill Ouchakov',     13, 'H'),
  ('soviet-min_int', 'traducteur',   'Rodion Chepotov',     13, 'H'),
  ('soviet-min_def', 'coordinateur', 'Iouri Glazov',        13, 'H'),
  ('soviet-min_def', 'conseiller',   'Nadejda Tenkova',     13, 'F'),
  ('soviet-min_def', 'garde',        'Timofeï Bronine',     13, 'H'),
  ('soviet-min_def', 'traducteur',   'Iakov Perevodtchikov', 13, 'H')
ON CONFLICT (equipe, role) DO NOTHING;

-- Identifiant du PNJ d'une identité : inchangé pour la Républia (agent-<rôle>).
CREATE OR REPLACE FUNCTION public.renseignement_pnj_id(p_equipe text, p_role text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN coalesce(p_equipe, 'republic-min_def') = 'republic-min_def'
              THEN 'agent-' || p_role
              ELSE 'agent-' || p_equipe || '-' || p_role END;
$$;

-- Les 8 PNJ de Sovarka, copiés du profil des agents du socle (classe, PA, caractéristiques).
INSERT INTO public.pnj_membres (id, famille, nom, pays, pa, liquide, statut, classe,
       car_ent, car_cha, car_dup, car_int, car_per, car_vol,
       proprietaire_institution, proprietaire_perimetre, cree_le, maj_le)
SELECT public.renseignement_pnj_id(i.equipe, i.role), s.famille, i.vrai_nom, 'soviet', s.pa, 0, s.statut, s.classe,
       s.car_ent, s.car_cha, s.car_dup, s.car_int, s.car_per, s.car_vol,
       s.proprietaire_institution, 'soviet', now(), now()
  FROM public.renseignement_identites_reelles i
  JOIN public.pnj_membres s ON s.id = 'agent-' || i.role
 WHERE i.equipe LIKE 'soviet-%'
ON CONFLICT (id) DO NOTHING;

-- Le raccordement d'une mission à son PNJ lit désormais l'équipe.
DO $trg$
DECLARE f oid; code text;
  ancien text := 'v_pnj := public.renseignement_pnj_id(NEW.role);';
  nouveau text := 'v_pnj := public.renseignement_pnj_id(coalesce(NEW.equipe, ''republic-min_def''), NEW.role);';
BEGIN
  SELECT t.tgfoid INTO f FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'agents_renseignement' AND t.tgname = 'trg_renseignement_mission_raccorder';
  code := pg_get_functiondef(f);
  IF position(nouveau IN code) > 0 THEN RETURN; END IF;
  IF position(ancien IN code) = 0 THEN RAISE EXCEPTION 'raccordement des missions : fragment introuvable'; END IF;
  EXECUTE replace(code, ancien, nouveau);
END $trg$;

-- Un agent rentré au bureau de son ministre : Défense ou Sécurité du Peuple (Intérieur).
CREATE OR REPLACE FUNCTION public.agent_au_bureau_min_def(p_bat text, p_piece text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_bat = 'palais-gouvernement' AND p_piece IN ('bureau_min_def', 'bureau_min_int');
$$;

-- Diagnostic du socle des agents : une identité attendue par équipe et par rôle.
CREATE OR REPLACE FUNCTION public.pnj_comparer_agents()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_prof jsonb; v_nb integer; v_att integer; v_div jsonb;
BEGIN
  v_prof := public.pnj_metier_profil('agent');
  SELECT count(*) INTO v_nb FROM public.pnj_membres WHERE famille = 'agent' AND statut = 'actif';
  SELECT count(*) INTO v_att FROM public.renseignement_identites_reelles;
  WITH attendu AS (SELECT i.equipe, i.role, i.vrai_nom, public.renseignement_pnj_id(i.equipe, i.role) AS pnj
                     FROM public.renseignement_identites_reelles i),
  socle AS (SELECT m.* FROM public.pnj_membres m WHERE m.famille = 'agent'),
  cmp AS (
    SELECT coalesce(a.pnj, s.id) AS role,
      CASE
        WHEN s.id IS NULL THEN 'identite_absente_du_socle'
        WHEN a.role IS NULL THEN 'surnumeraire_au_socle'
        WHEN s.nom IS DISTINCT FROM a.vrai_nom THEN 'nom_reel'
        WHEN s.classe IS DISTINCT FROM 'beta' THEN 'classe'
        WHEN public.pnj_caracteristiques_base(s.id) IS DISTINCT FROM v_prof THEN 'profil'
        WHEN s.proprietaire_institution IS DISTINCT FROM 'renseignement' THEN 'institution'
        WHEN s.pa IS DISTINCT FROM 12 THEN 'pa'
        ELSE NULL END AS divergence
      FROM attendu a FULL OUTER JOIN socle s ON s.id = a.pnj)
  SELECT coalesce(jsonb_agg(jsonb_build_object('role', role, 'divergence', divergence)
           ORDER BY role) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_div FROM cmp;
  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb = v_att
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement WHERE pnj_id IS NULL)
          AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                            JOIN public.pnj_membres m ON m.id = a.pnj_id
                           WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'identites_au_socle', v_nb, 'attendues', v_att,
    'profil', v_prof, 'divergences', v_div,
    'occurrences_de_mission', (SELECT count(*) FROM public.agents_renseignement),
    'missions_non_raccordees', (SELECT count(*) FROM public.agents_renseignement WHERE pnj_id IS NULL),
    'missions_actives', (SELECT count(*) FROM public.agents_renseignement WHERE statut = 'actif'),
    'dup_active_desalignee', (SELECT count(*) FROM public.agents_renseignement a
                                JOIN public.pnj_membres m ON m.id = a.pnj_id
                               WHERE a.statut = 'actif' AND a.dup IS DISTINCT FROM m.car_dup),
    'observation_axe_position', (SELECT autorite FROM public.pnj_axes_autorite
                                  WHERE famille = 'agent' AND axe = 'position_leader'));
END; $$;

-- Preuves structurelles.
DO $preuve$
BEGIN
  IF (SELECT count(*) FROM public.renseignement_identites_reelles WHERE equipe LIKE 'soviet-%') <> 8 THEN
    RAISE EXCEPTION 'équipes de Sovarka incomplètes'; END IF;
  IF (SELECT count(*) FROM public.pnj_membres WHERE id LIKE 'agent-soviet-%') <> 8 THEN
    RAISE EXCEPTION 'PNJ de Sovarka absents'; END IF;
  IF EXISTS (SELECT 1 FROM public.renseignement_identites_reelles WHERE equipe = 'republic-min_def'
              AND public.renseignement_pnj_id(equipe, role) <> 'agent-' || role) THEN
    RAISE EXCEPTION 'identifiants des agents de la Républia modifiés'; END IF;
END $preuve$;
