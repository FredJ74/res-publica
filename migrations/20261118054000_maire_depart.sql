-- DÉPART D'UN MAIRE (Fred, 18/11/2026, « Décisions du 18/11 », point 5 ; GAME-DESIGN-ELECTIONS.md).
-- Tous motifs (décès, démission, destitution ou changement de poste, emprisonnement, naturalisation), tous
-- les empires, maires joueurs seulement (un PNJ titulaire n'est jamais « parti ») :
--  - le mandat est libéré (eluId vidé, `vacance` noté dans le cycle) ; pas d'élection partielle ;
--  - l'adjoint joueur reçoit une proposition de devenir maire, valable 72 h (courrier à boutons). S'il accepte,
--    il devient maire jusqu'à la fin du mandat et nomme ensuite un nouvel adjoint (nomination existante). S'il
--    refuse ou laisse passer le délai, il reste adjoint ; la mairie reste sans maire jusqu'à la municipale ;
--  - sans adjoint : tutelle du ministre (`tutelle` dans le cycle) — Économie collective (min_fin) en Sovarka,
--    Intérieur (min_int) ailleurs. Dans le bureau du maire de cette ville, le ministre est reconnu comme maire
--    par acteur_poste_courant() et poste_est_atteste() (impôts locaux, budget, subventions) ; jamais adjoint.
--  - la passe de nuit « maires_departs » expire les propositions, rattrape les départs (décès, prison,
--    nationalité) et efface vacance et tutelle dès qu'un maire est élu.
-- Aucune donnée de joueur modifiée à l'application. Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.mairie_successions (
  id text PRIMARY KEY, country text NOT NULL, city text NOT NULL, ancien_maire text NOT NULL, motif text NOT NULL,
  adjoint text NOT NULL, propose_le timestamptz NOT NULL DEFAULT now(), expire_le timestamptz NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'acceptee', 'refusee', 'caduque')),
  traite_le timestamptz);
ALTER TABLE public.mairie_successions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mairie_successions FROM PUBLIC, anon;
GRANT SELECT ON public.mairie_successions TO authenticated;
DROP POLICY IF EXISTS mairie_successions_lecture ON public.mairie_successions;
CREATE POLICY mairie_successions_lecture ON public.mairie_successions FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.maire_tutelle_ministre(p_pays text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT CASE WHEN p_pays = 'soviet' THEN 'min_fin' ELSE 'min_int' END $$;

CREATE OR REPLACE FUNCTION public.maire_ville_nom(p_pays text, p_city text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_pays = 'soviet' THEN CASE p_city WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' ELSE p_city END
              WHEN p_pays = 'republic' THEN CASE p_city WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' WHEN 'ville_b' THEN 'Montrouge' ELSE p_city END
              ELSE p_city END $$;

-- Ville dont le personnage exerce la tutelle là où il se trouve (bureau du maire), sinon NULL.
CREATE OR REPLACE FUNCTION public.maire_tutelle_ici_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p.current_city FROM public.personnages_donnees p
    JOIN public.cycles_electoraux c ON c.country = p.country AND c.poste_id = 'maire' AND c.city = p.current_city
   WHERE p.name = p_nom AND p.current_room IN ('bureau_maire', 'bureau_maire_local')
     AND p.poste->>'id' = public.maire_tutelle_ministre(p.country)
     AND EXISTS (SELECT 1 FROM public.postes_attribues a WHERE a.titulaire = p.name AND a.country = p.country
                  AND a.poste_id = public.maire_tutelle_ministre(p.country) AND a.city IS NULL)
     AND left(btrim(c.data), 1) = '{' AND coalesce(c.data::jsonb->>'eluId', '') = '' AND (c.data::jsonb ? 'tutelle')
   LIMIT 1 $$;
REVOKE ALL ON FUNCTION public.maire_tutelle_ici_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.maire_depart_ouvrir_interne(p_pays text, p_city text, p_nom text, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE c record; d jsonb; v_adj text; v_min text; v_id text; v_ville text := public.maire_ville_nom(p_pays, p_city);
        v_ms bigint := floor(extract(epoch FROM now()) * 1000);
BEGIN
  SELECT id, data INTO c FROM public.cycles_electoraux WHERE country = p_pays AND poste_id = 'maire' AND city = p_city FOR UPDATE;
  IF NOT FOUND OR left(btrim(c.data), 1) <> '{' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cycle_absent'); END IF;
  d := c.data::jsonb;
  IF d->>'eluId' IS DISTINCT FROM p_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_maire'); END IF;
  d := jsonb_set(d, '{eluId}', 'null'::jsonb) - 'tutelle'
       || jsonb_build_object('vacance', jsonb_build_object('depuis', v_ms, 'motif', p_motif, 'ancienMaire', p_nom));
  SELECT a.titulaire INTO v_adj FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = 'maire_adjoint' AND a.city = p_city AND a.titulaire IS DISTINCT FROM p_nom
     AND EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = a.titulaire)
   ORDER BY a.updated_at DESC NULLS LAST LIMIT 1;
  IF v_adj IS NULL THEN
    v_min := public.maire_tutelle_ministre(p_pays);
    d := d || jsonb_build_object('tutelle', jsonb_build_object('poste', v_min, 'depuis', v_ms));
  END IF;
  UPDATE public.cycles_electoraux SET data = d::text WHERE id = c.id;
  -- L'ancien maire n'est plus maire (après le cycle : le déclencheur ne relance rien).
  UPDATE public.personnages_donnees SET poste = NULL, updated_at = now()
   WHERE name = p_nom AND poste->>'id' = 'maire' AND poste->>'city' IS NOT DISTINCT FROM p_city;
  IF v_adj IS NOT NULL THEN
    v_id := 'succ-' || p_pays || '-' || p_city || '-' || v_ms;
    INSERT INTO public.mairie_successions (id, country, city, ancien_maire, motif, adjoint, expire_le)
    VALUES (v_id, p_pays, p_city, p_nom, p_motif, v_adj, now() + interval '72 hours');
    PERFORM public.mail_systeme_poser_interne('Mairie de ' || v_ville, v_adj, 'Proposition : devenir maire',
      'Le maire de ' || v_ville || ' a quitté ses fonctions. En tant qu''adjoint, vous pouvez devenir maire jusqu''à la fin du mandat en cours ; vous nommerez ensuite un nouvel adjoint. Sans réponse sous 72 h, vous restez adjoint et la mairie reste sans maire jusqu''à la prochaine municipale. '
      || '[[act:maire_oui|' || v_id || ']] [[act:maire_non|' || v_id || ']]', NULL);
  ELSE
    PERFORM public.mail_systeme_poser_interne('Mairie de ' || v_ville, a.titulaire, 'Tutelle de la mairie de ' || v_ville,
      'Le maire de ' || v_ville || ' a quitté ses fonctions et la ville n''a pas d''adjoint : la mairie passe sous votre tutelle jusqu''à la prochaine municipale. Les boutons du bureau du maire vous sont ouverts.', NULL)
      FROM public.postes_attribues a WHERE a.country = p_pays AND a.poste_id = v_min AND a.city IS NULL
       AND EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = a.titulaire);
  END IF;
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (p_pays, p_city, '🏛️ Le maire de ' || v_ville || ' a quitté ses fonctions. '
    || CASE WHEN v_adj IS NOT NULL THEN 'L''adjoint a 72 heures pour accepter la mairie.' ELSE 'La mairie passe sous la tutelle du ministre.' END, NULL);
  RETURN jsonb_build_object('ok', true, 'adjoint', v_adj, 'tutelle', v_adj IS NULL, 'proposition', v_id);
END $function$;
REVOKE ALL ON FUNCTION public.maire_depart_ouvrir_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- Le personnage est-il maire élu quelque part, et doit-il quitter la mairie ? p_motif imposé ou constaté.
CREATE OR REPLACE FUNCTION public.maire_depart_verifier_interne(p_nom text, p_motif text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE c record; p record; v_motif text; n integer := 0;
BEGIN
  FOR c IN SELECT country, city FROM public.cycles_electoraux
            WHERE poste_id = 'maire' AND left(btrim(data), 1) = '{' AND data::jsonb->>'eluId' = p_nom LOOP
    SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
    IF NOT FOUND THEN CONTINUE; END IF;   -- PNJ titulaire : jamais « parti »
    v_motif := coalesce(p_motif,
      CASE WHEN EXISTS (SELECT 1 FROM public.successions s WHERE s.defunt = p_nom) THEN 'deces'
           WHEN coalesce(p.est_emprisonne, 'null'::jsonb) <> 'null'::jsonb OR coalesce(p.detention_qhs, 'null'::jsonb) NOT IN ('null'::jsonb, '{}'::jsonb) THEN 'emprisonnement'
           WHEN coalesce(p.nationalite, p.country) IS DISTINCT FROM c.country THEN 'naturalisation' END);
    IF v_motif IS NULL THEN CONTINUE; END IF;
    IF coalesce((public.maire_depart_ouvrir_interne(c.country, c.city, p_nom, v_motif)->>'ok')::boolean, false) THEN n := n + 1; END IF;
  END LOOP;
  RETURN n;
END $function$;
REVOKE ALL ON FUNCTION public.maire_depart_verifier_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Déclencheurs : démission ou changement de poste (maire → autre chose), prison, naturalisation ; décès.
CREATE OR REPLACE FUNCTION public.maire_depart_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
BEGIN
  IF TG_TABLE_NAME = 'successions' THEN
    PERFORM public.maire_depart_verifier_interne(NEW.defunt, 'deces');
    RETURN NEW;
  END IF;
  IF OLD.poste->>'id' = 'maire' AND NEW.poste->>'id' IS DISTINCT FROM 'maire' THEN
    PERFORM public.maire_depart_verifier_interne(NEW.name, 'demission');
  ELSIF NEW.est_emprisonne IS DISTINCT FROM OLD.est_emprisonne OR NEW.detention_qhs IS DISTINCT FROM OLD.detention_qhs
        OR NEW.nationalite IS DISTINCT FROM OLD.nationalite THEN
    PERFORM public.maire_depart_verifier_interne(NEW.name, NULL);
  END IF;
  RETURN NEW;
END $function$;
DROP TRIGGER IF EXISTS personnages_maire_depart ON public.personnages_donnees;
CREATE TRIGGER personnages_maire_depart AFTER UPDATE OF poste, est_emprisonne, detention_qhs, nationalite ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.maire_depart_declencheur();
DROP TRIGGER IF EXISTS successions_maire_depart ON public.successions;
CREATE TRIGGER successions_maire_depart AFTER INSERT ON public.successions
  FOR EACH ROW EXECUTE FUNCTION public.maire_depart_declencheur();

-- Réponse de l'adjoint (boutons du courrier).
CREATE OR REPLACE FUNCTION public.maire_succession_repondre(p_id text, p_accepte boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); s public.mairie_successions; c record; d jsonb; v_ville text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO s FROM public.mairie_successions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;
  IF s.adjoint IS DISTINCT FROM a THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_a_l_adjoint'); END IF;
  IF s.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'proposition_close', 'statut', s.statut); END IF;
  IF s.expire_le <= now() THEN
    UPDATE public.mairie_successions SET statut = 'caduque', traite_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_expiree');
  END IF;
  v_ville := public.maire_ville_nom(s.country, s.city);
  IF NOT coalesce(p_accepte, false) THEN
    UPDATE public.mairie_successions SET statut = 'refusee', traite_le = now() WHERE id = p_id;
    INSERT INTO public.evenements_globaux (country, city, texte, jour)
    VALUES (s.country, s.city, '🏛️ L''adjoint décline la mairie de ' || v_ville || ' : la ville reste sans maire jusqu''à la prochaine municipale.', NULL);
    RETURN jsonb_build_object('ok', true, 'accepte', false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.postes_attribues WHERE country = s.country AND poste_id = 'maire_adjoint' AND city = s.city AND titulaire = a) THEN
    UPDATE public.mairie_successions SET statut = 'caduque', traite_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'plus_adjoint');
  END IF;
  SELECT id, data INTO c FROM public.cycles_electoraux WHERE country = s.country AND poste_id = 'maire' AND city = s.city FOR UPDATE;
  d := c.data::jsonb;
  IF coalesce(d->>'eluId', '') <> '' THEN
    UPDATE public.mairie_successions SET statut = 'caduque', traite_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_pourvue');
  END IF;
  d := (d - 'vacance' - 'tutelle') || jsonb_build_object('eluId', a,
         'successionAdjoint', jsonb_build_object('de', s.ancien_maire, 'le', floor(extract(epoch FROM now()) * 1000)));
  UPDATE public.cycles_electoraux SET data = d::text WHERE id = c.id;
  DELETE FROM public.postes_attribues WHERE country = s.country AND poste_id = 'maire_adjoint' AND city = s.city AND titulaire = a;
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id', 'maire', 'city', s.city, 'name', 'Maire'), updated_at = now() WHERE name = a;
  UPDATE public.mairie_successions SET statut = 'acceptee', traite_le = now() WHERE id = p_id;
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (s.country, s.city, '🏛️ ' || a || ', adjoint, devient maire de ' || v_ville || ' jusqu''à la fin du mandat.', NULL);
  RETURN jsonb_build_object('ok', true, 'accepte', true, 'ville', s.city, 'poste', jsonb_build_object('id', 'maire', 'city', s.city, 'name', 'Maire'));
END $function$;
REVOKE ALL ON FUNCTION public.maire_succession_repondre(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maire_succession_repondre(text, boolean) TO authenticated;

-- Passe de nuit : propositions expirées, départs constatés, vacance et tutelle closes par l'élection.
CREATE OR REPLACE FUNCTION public.maires_departs_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE n_exp integer; n_dep integer := 0; n_clos integer; r record;
BEGIN
  UPDATE public.mairie_successions SET statut = 'caduque', traite_le = now() WHERE statut = 'en_attente' AND expire_le <= now();
  GET DIAGNOSTICS n_exp = ROW_COUNT;
  FOR r IN SELECT DISTINCT data::jsonb->>'eluId' AS elu FROM public.cycles_electoraux
            WHERE poste_id = 'maire' AND left(btrim(data), 1) = '{' AND coalesce(data::jsonb->>'eluId', '') <> '' LOOP
    n_dep := n_dep + public.maire_depart_verifier_interne(r.elu, NULL);
  END LOOP;
  UPDATE public.cycles_electoraux SET data = (data::jsonb - 'vacance' - 'tutelle')::text
   WHERE poste_id = 'maire' AND left(btrim(data), 1) = '{' AND coalesce(data::jsonb->>'eluId', '') <> ''
     AND (data::jsonb ? 'vacance' OR data::jsonb ? 'tutelle');
  GET DIAGNOSTICS n_clos = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'propositions_expirees', n_exp, 'departs', n_dep, 'vacances_closes', n_clos);
END $function$;
REVOKE ALL ON FUNCTION public.maires_departs_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.maires_departs_passe() TO service_role;

-- Tutelle : dans le bureau du maire d'une ville sous tutelle, le ministre est reconnu comme maire de cette ville.
DO $tutelle$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.acteur_poste_courant()'::regprocedure);
  IF position('maire_tutelle_ici_interne' IN d) = 0 THEN
    a := $a$  SELECT p.name, p.poste->>'id', p.poste->>'city',$a$;
    b := $b$  SELECT p.name,
         CASE WHEN public.maire_tutelle_ici_interne(p.name) IS NOT NULL THEN 'maire' ELSE p.poste->>'id' END,
         coalesce(public.maire_tutelle_ici_interne(p.name), p.poste->>'city'),$b$;
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'acteur_poste_courant : ancrage'; END IF;
    EXECUTE replace(d, a, b);
  END IF;
  d := pg_get_functiondef('public.poste_est_atteste(text,jsonb,text)'::regprocedure);
  IF position('maire_tutelle_ici_interne' IN d) = 0 THEN
    a := E'    RETURN (v_cycle::jsonb ->> ''eluId'') = p_nom;\n';
    b := E'    RETURN (v_cycle::jsonb ->> ''eluId'') = p_nom\n'
      || E'        OR (v_id = ''maire'' AND public.maire_tutelle_ici_interne(p_nom) IS NOT DISTINCT FROM v_city AND v_city IS NOT NULL);\n';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'poste_est_atteste : ancrage'; END IF;
    EXECUTE replace(d, a, b);
  END IF;
END $tutelle$;

DO $$ BEGIN
  IF position('maire_tutelle_ici_interne' IN pg_get_functiondef('public.acteur_poste_courant()'::regprocedure)) = 0
     OR position('maire_tutelle_ici_interne' IN pg_get_functiondef('public.poste_est_atteste(text,jsonb,text)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'personnages_maire_depart')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'successions_maire_depart')
  THEN RAISE EXCEPTION 'maire_depart : controle structurel en echec'; END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
