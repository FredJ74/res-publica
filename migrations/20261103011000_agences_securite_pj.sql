-- APPLIQUEE le 03/11/2026 par Claude (registre agences_securite_pj_20261103011000), apres le banc annule
-- outils/bancs/banc-agences-securite-pj.sql joue en production (tous les cas conformes).
-- 3 novembre 2026 -- #135 : L'AGENCE DE SECURITE PRIVEE D'UN PJ.
--
-- Decisions de Fred (GAME-DESIGN-SECURITE-PRIVEE-135.md, decisions 11 a 14) :
--   . 01/11 : on ne duplique pas Grobras en province ; ce sont les PJ qui ouvrent leur agence.
--   . 03/11 : l'agence a son VIVIER PROPRE de candidats PNJ locaux, comme Grobras ; un vivier par
--     ville (4 agents, 2 maitres-chiens), commun a toutes les agences de PJ de la ville ; noms
--     valides par Fred le 03/11 (accroches ecrites par Claude, a sa relecture).
--   . 03/11 : TOUT PJ peut embaucher dans le vivier, comme chez Grobras : il devient l'employeur ;
--     les frais d'embauche (memes tarifs que Grobras, memes quotas) vont a la CAISSE DU COMMERCE,
--     c'est le revenu du patron. Le patron peut aussi embaucher pour son compte.
--
-- AUCUN MOTEUR NEUF. Le socle d'embauche des agences du 5 octobre (« demain, une agence creee par
-- un joueur devra pouvoir reutiliser exactement le meme socle ») est reutilise tel quel :
--   . pnj_employeurs recoit deux colonnes : `fonds_id` (le commerce du PJ) et `vivier` (le vivier
--     de candidats lu a la place du catalogue propre de l'employeur) ; `proprietaire_pj` existait.
--   . employeur_candidats lit le vivier quand il y en a un (patch en place, 2 fragments).
--   . employeur_embaucher_agence(employeur, candidat) est DERIVEE de la definition de production
--     d'employeur_embaucher par trois patchs verifies : employeur explicite (l'agence) dont le
--     vivier doit contenir le candidat, presence dans le local de l'agence, credit de la caisse du
--     commerce au lieu d'une caisse d'institution. Tout le reste (tarif au referentiel, payer_ordre,
--     quotas, plafond de 10, creation du PNJ) est le code de Grobras, inchange.
--   . agence_securite_ouvrir / _fermer (proprietaire du commerce) et agence_securite_lire (tous).
-- Les viviers sont des employeurs INACTIFS : on n'embauche jamais directement chez eux.
-- Idempotente. Aucun acte de joueur.

ALTER TABLE public.pnj_employeurs ADD COLUMN IF NOT EXISTS fonds_id text;
ALTER TABLE public.pnj_employeurs ADD COLUMN IF NOT EXISTS vivier text;
CREATE UNIQUE INDEX IF NOT EXISTS pnj_employeurs_fonds_unique ON public.pnj_employeurs (fonds_id) WHERE fonds_id IS NOT NULL;

INSERT INTO public.pnj_employeurs (employeur_id, pays, nom, actif, note) VALUES
  ('vivier-securite-capitale', 'republic', 'Vivier des agences de sécurité — Luthécia', false,
   'Vivier commun aux agences de securite ouvertes par des PJ a Luthecia (decision de Fred, 03/11/2026). Inactif : on embauche par une agence, jamais ici.'),
  ('vivier-securite-ville_a', 'republic', 'Vivier des agences de sécurité — Port-Sainte-Marie', false,
   'Vivier commun aux agences de securite ouvertes par des PJ a PSM (decision de Fred, 03/11/2026). Inactif.'),
  ('vivier-securite-ville_b', 'republic', 'Vivier des agences de sécurité — Montrouge', false,
   'Vivier commun aux agences de securite ouvertes par des PJ a Montrouge (decision de Fred, 03/11/2026). Inactif.')
ON CONFLICT (employeur_id) DO NOTHING;

INSERT INTO public.pnj_candidats_catalogue (candidat_id, employeur_id, metier, nom, genre, accroche, rang) VALUES
  -- Port-Sainte-Marie
  ('vivier-psm-as-01', 'vivier-securite-ville_a', 'agent_securite', 'Gwen Darm', 'F', 'Ancienne gardienne du phare. Voit venir les ennuis de très loin.', 1),
  ('vivier-psm-as-02', 'vivier-securite-ville_a', 'agent_securite', 'Loïc Adenas', 'H', 'Ferme tout à double tour, y compris sa bouche.', 2),
  ('vivier-psm-as-03', 'vivier-securite-ville_a', 'agent_securite', 'Tanguy Ronde', 'H', 'Ancien docker. Fait sa tournée par tous les temps, ciré compris.', 3),
  ('vivier-psm-as-04', 'vivier-securite-ville_a', 'agent_securite', 'Maëlle Arm', 'F', 'Réagit au moindre bruit. Dort, paraît-il, un œil ouvert.', 4),
  ('vivier-psm-mc-01', 'vivier-securite-ville_a', 'maitre_chien', 'Corentin Kerbrat', 'H', 'Avec Bosco, terre-neuve qui a déjà repêché deux voleurs dans le port.', 1),
  ('vivier-psm-mc-02', 'vivier-securite-ville_a', 'maitre_chien', 'Soizic Lemolosse', 'F', 'Avec Taïga, malinoise qui flaire la contrebande sous le poisson.', 2),
  -- Montrouge
  ('vivier-mtr-as-01', 'vivier-securite-ville_b', 'agent_securite', 'Alain Terdit', 'H', 'Connaît par cœur tous les panneaux d''interdiction de la ville.', 1),
  ('vivier-mtr-as-02', 'vivier-securite-ville_b', 'agent_securite', 'Ginette Planton', 'F', 'Ancienne garde-barrière. Peut rester debout douze heures sans broncher.', 2),
  ('vivier-mtr-as-03', 'vivier-securite-ville_b', 'agent_securite', 'Dédé Fensive', 'H', 'Ancien mineur de fond. Large d''épaules, court de patience.', 3),
  ('vivier-mtr-as-04', 'vivier-securite-ville_b', 'agent_securite', 'Marcel Rondier', 'H', 'A fait les rondes de nuit au dépôt ferroviaire pendant vingt ans.', 4),
  ('vivier-mtr-mc-01', 'vivier-securite-ville_b', 'maitre_chien', 'Josiane Croquette', 'F', 'Avec Sultan, rottweiler qui n''aboie qu''une fois, mais au bon moment.', 1),
  ('vivier-mtr-mc-02', 'vivier-securite-ville_b', 'maitre_chien', 'Raymond Collier', 'H', 'Avec Coron, bâtard du carreau de mine qui connaît chaque galerie.', 2),
  -- Luthecia
  ('vivier-lut-as-01', 'vivier-securite-capitale', 'agent_securite', 'Paul Icier', 'H', 'Recalé trois fois au concours de police. Ne l''a pas digéré.', 1),
  ('vivier-lut-as-02', 'vivier-securite-capitale', 'agent_securite', 'Sandrine Terdiction', 'F', 'Ancienne huissière du ministère. Personne ne passe sans formulaire.', 2),
  ('vivier-lut-as-03', 'vivier-securite-capitale', 'agent_securite', 'Bruno Ssard', 'H', 'Videur des meilleures boîtes de la capitale. Physionomiste redoutable.', 3),
  ('vivier-lut-as-04', 'vivier-securite-capitale', 'agent_securite', 'Nadia Lerte', 'F', 'Toujours sur le qui-vive. Repère un pickpocket à trente mètres.', 4),
  ('vivier-lut-mc-01', 'vivier-securite-capitale', 'maitre_chien', 'Hugo Zeille', 'H', 'Avec Brutus, dogue allemand plus haut qu''un comptoir.', 1),
  ('vivier-lut-mc-02', 'vivier-securite-capitale', 'maitre_chien', 'Fanny Mordant', 'F', 'Avec Pepsi, jack russell minuscule et parfaitement terrifiante.', 2)
ON CONFLICT (candidat_id) DO NOTHING;

-- Le catalogue d'une agence de PJ est celui de son vivier.
DO $$
DECLARE f text; n integer;
BEGIN
  f := pg_get_functiondef('public.employeur_candidats(text)'::regprocedure);
  IF position('agences_securite_pj' IN f) > 0 THEN RETURN; END IF;
  n := (length(f) - length(replace(f, 'c.employeur_id = v_emp.employeur_id', ''))) / length('c.employeur_id = v_emp.employeur_id');
  IF n <> 2 THEN RAISE EXCEPTION 'employeur_candidats_definition_non_examinee (%)', n; END IF;
  f := replace(f, 'c.employeur_id = v_emp.employeur_id',
               'c.employeur_id = coalesce(v_emp.vivier, v_emp.employeur_id) /* agences_securite_pj */');
  EXECUTE f;
END $$;

-- Embaucher par l'agence d'un PJ : derivee d'employeur_embaucher (production), trois patchs.
DO $$
DECLARE f text;
  a_entete text := 'public.employeur_embaucher(p_candidat_id text)';
  a_emp text := 'where employeur_id = v_cand.employeur_id and actif;';
  a_caisse text := '  if v_emp.caisse_id is not null and v_cost > 0 then';
  a_prof text := '  select * into v_prof from public.pnj_metiers_profils where metier = v_cand.metier;';
BEGIN
  IF to_regprocedure('public.employeur_embaucher_agence(text,text)') IS NOT NULL THEN RETURN; END IF;
  f := pg_get_functiondef('public.employeur_embaucher(text)'::regprocedure);
  IF position(a_entete IN f) = 0 OR position(a_emp IN f) = 0 OR position(a_caisse IN f) = 0 OR position(a_prof IN f) = 0 THEN
    RAISE EXCEPTION 'employeur_embaucher_definition_non_examinee';
  END IF;
  f := replace(f, a_entete, 'public.employeur_embaucher_agence(p_employeur_id text, p_candidat_id text)');
  f := replace(f, a_emp, 'where employeur_id = p_employeur_id and actif and fonds_id is not null and vivier = v_cand.employeur_id; /* agences_securite_pj */');
  f := replace(f, a_prof,
    '  if not exists (select 1 from public.entreprises en where en.id = v_emp.fonds_id and coalesce(en.data->>''statut'',''actif'') = ''actif'') then' || E'\n' ||
    '    return jsonb_build_object(''ok'', false, ''raison'', ''agence_fermee''); end if;' || E'\n' ||
    '  if not public.fonds_acteur_present(v_moi, (select en.data->''implantation'' from public.entreprises en where en.id = v_emp.fonds_id)) then' || E'\n' ||
    '    return jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place''); end if;' || E'\n' || a_prof);
  f := replace(f, a_caisse,
    '  if v_emp.fonds_id is not null and v_cost > 0 then' || E'\n' ||
    '    update public.entreprises set data = jsonb_set(data, ''{caisse}'', to_jsonb(greatest(0, coalesce((data->>''caisse'')::numeric, 0)) + v_cost)), updated_at = now()' || E'\n' ||
    '     where id = v_emp.fonds_id returning jsonb_build_object(''fonds_id'', id, ''caisse'', data->''caisse'') into v_caisse;' || E'\n' ||
    '  end if;' || E'\n' || a_caisse);
  EXECUTE f;
END $$;

CREATE OR REPLACE FUNCTION public.agence_securite_lire(p_fonds_id text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT jsonb_build_object('ok', true, 'agence', e.actif, 'employeur_id', e.employeur_id,
                                             'nom', e.nom, 'proprietaire', e.proprietaire_pj)
                     FROM public.pnj_employeurs e WHERE e.fonds_id = p_fonds_id),
                  jsonb_build_object('ok', true, 'agence', false));
$function$;

CREATE OR REPLACE FUNCTION public.agence_securite_ouvrir(p_fonds_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_data jsonb; v_ville text; v_vivier text; v_id text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce(v_data->>'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM v_moi AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ville := v_data->'implantation'->>'city';
  v_vivier := 'vivier-securite-' || coalesce(v_ville, '');
  IF NOT EXISTS (SELECT 1 FROM public.pnj_employeurs WHERE employeur_id = v_vivier
                   AND pays = coalesce(v_data->'implantation'->>'country', 'republic')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_vivier_ici'); END IF;
  v_id := 'agence-pj-' || p_fonds_id;
  v_nom := coalesce(nullif(trim(v_data->>'enseigne'), ''), 'Agence de sécurité');
  INSERT INTO public.pnj_employeurs (employeur_id, pays, nom, actif, proprietaire_pj, fonds_id, vivier, note)
  VALUES (v_id, coalesce(v_data->'implantation'->>'country', 'republic'), v_nom, true, v_moi, p_fonds_id, v_vivier,
          'Agence de securite privee ouverte par un PJ (#135, decision de Fred du 03/11/2026).')
  ON CONFLICT (employeur_id) DO UPDATE SET actif = true, nom = excluded.nom, proprietaire_pj = excluded.proprietaire_pj;
  RETURN jsonb_build_object('ok', true, 'agence', true, 'employeur_id', v_id, 'nom', v_nom);
END; $function$;

CREATE OR REPLACE FUNCTION public.agence_securite_fermer(p_fonds_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM v_moi AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  -- Les agents deja embauches restent au service de leurs employeurs : seul le guichet ferme.
  UPDATE public.pnj_employeurs SET actif = false WHERE fonds_id = p_fonds_id;
  RETURN jsonb_build_object('ok', true, 'agence', false);
END; $function$;

REVOKE ALL ON FUNCTION public.employeur_embaucher_agence(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agence_securite_lire(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agence_securite_ouvrir(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agence_securite_fermer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.employeur_embaucher_agence(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agence_securite_lire(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agence_securite_ouvrir(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agence_securite_fermer(text) TO authenticated;
