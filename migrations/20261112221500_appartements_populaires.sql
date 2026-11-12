-- Appartements populaires : sommeil, option premium, colocation, époux, emplacements, serrures.
-- Décisions de Fred du 12/11/2026 au soir (GAME-DESIGN-APPARTEMENTS.md), feu vert de codage le 12/11 à 23 h.
--
-- Logement populaire = toute pièce qui a une ligne dans logements_sociaux_historiques (Montrouge,
-- Novomirsk V14/V16, Starovka, immeubles collectifs des mairies de Sovarka) ou dont le bail est
-- marqué logementSocial (lots sociaux des terrains communaux de Montrouge).
-- Chambres premium : pièces « <appartement>_chambre_1 » et « _chambre_2 », seulement pour les
-- immeubles dessinés dans le jeu (logement_premium_possible_interne).
--
-- Correctif au passage : la clé de logements_sociaux_historiques était (pays, batiment, piece), sans
-- la ville ; les 8 logements du Baraquement Sibirsk-9 (Starovka, même bâtiment socle que Novomirsk)
-- avaient été écartés en silence par ON CONFLICT DO NOTHING. Clé portée à (pays, ville, batiment, piece).
BEGIN;

-- ===================================================================== 1. Starovka et la clé
ALTER TABLE public.logements_sociaux_historiques DROP CONSTRAINT IF EXISTS logements_sociaux_historiques_pkey;
ALTER TABLE public.logements_sociaux_historiques ADD CONSTRAINT logements_sociaux_historiques_pkey PRIMARY KEY (pays, ville, batiment, piece);

INSERT INTO public.logements_sociaux_historiques (pays, ville, batiment, piece, label, type_logement, loyer, bonus_moral, bonus_sante) VALUES
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_1', 'Petit appartement n°1', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_2', 'Petit appartement n°2', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_3', 'Petit appartement n°3', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_4', 'Petit appartement n°4', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_1', 'Grand appartement n°1', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_2', 'Grand appartement n°2', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_3', 'Grand appartement n°3', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_4', 'Grand appartement n°4', 'grand', 20, 5, 7)
ON CONFLICT DO NOTHING;

-- Les deux fonctions qui lisaient un logement sans sa ville la lisent désormais avec.
DO $$
DECLARE f text;
BEGIN
  SELECT pg_get_functiondef('public.logement_historique_attribuer_interne(text,text,text,text,text)'::regprocedure) INTO f;
  IF position('x.ville = p_ville AND x.batiment = p_batiment' IN f) = 0 THEN
    IF position('WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE' IN f) = 0 THEN
      RAISE EXCEPTION 'attribuer_interne_non_examinee'; END IF;
    f := replace(f, 'WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE',
                    'WHERE x.pays = v_pays AND x.ville = p_ville AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE');
  END IF;
  -- Reprise du bail par un colocataire en cours : le logement n'est pas libre.
  IF position('reprise_en_cours' IN f) = 0 THEN
    IF position('RETURN jsonb_build_object(''ok'',false,''raison'',''local_occupe''); END IF;' IN f) = 0 THEN
      RAISE EXCEPTION 'attribuer_interne_occupe_non_examine'; END IF;
    f := replace(f, 'RETURN jsonb_build_object(''ok'',false,''raison'',''local_occupe''); END IF;',
      'RETURN jsonb_build_object(''ok'',false,''raison'',''local_occupe''); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_reprises rp WHERE rp.bail_id = idb AND rp.statut = ''en_attente'' AND rp.expire_le > now()) THEN
    RETURN jsonb_build_object(''ok'',false,''raison'',''reprise_en_cours''); END IF;');
  END IF;
  -- La table des reprises est créée plus bas : on diffère l'exécution à la fin du bloc 4.
  PERFORM set_config('appartements.attribuer', f, true);

  SELECT pg_get_functiondef('public.logement_historique_loyer_fixer_interne(text,text,text,text,integer)'::regprocedure) INTO f;
  IF position('x.ville = p_ville AND x.batiment = p_batiment' IN f) = 0 THEN
    IF position('WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE' IN f) = 0
       OR position('WHERE x.pays = h.pays AND x.batiment = h.batiment AND x.piece = h.piece' IN f) = 0 THEN
      RAISE EXCEPTION 'loyer_fixer_interne_non_examinee'; END IF;
    f := replace(f, 'WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE',
                    'WHERE x.pays = v_pays AND x.ville = p_ville AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE');
    f := replace(f, 'WHERE x.pays = h.pays AND x.batiment = h.batiment AND x.piece = h.piece',
                    'WHERE x.pays = h.pays AND x.ville = h.ville AND x.batiment = h.batiment AND x.piece = h.piece');
    EXECUTE f;
  END IF;
END $$;

-- ===================================================================== 2. Tables
CREATE TABLE IF NOT EXISTS public.logements_premium (
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  active_par text NOT NULL, active_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, ville, batiment, piece));

CREATE TABLE IF NOT EXISTS public.logements_colocations (
  bail_id text PRIMARY KEY,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  titulaire text NOT NULL, colocataire text NOT NULL UNIQUE,
  depuis timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS public.logements_reprises (
  bail_id text PRIMARY KEY,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  colocataire text NOT NULL, ancien_titulaire text, bail jsonb NOT NULL,
  offerte_le timestamptz NOT NULL DEFAULT now(), expire_le timestamptz NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'acceptee', 'refusee', 'caduque')));

CREATE TABLE IF NOT EXISTS public.logements_decors (
  cle text PRIMARY KEY,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  owner_user_id uuid REFERENCES auth.users(id),
  image_path text, preview_path text,
  retouches integer NOT NULL DEFAULT 0, generations integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  retiree_le timestamptz, motif_retrait text);

ALTER TABLE public.logements_premium ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logements_colocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logements_reprises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logements_decors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_premium, public.logements_colocations, public.logements_reprises, public.logements_decors FROM anon, authenticated;
-- Lecture publique : quels appartements ont leurs chambres (onglets), et les décors (images publiques).
GRANT SELECT ON public.logements_premium, public.logements_decors TO anon, authenticated;
DROP POLICY IF EXISTS "Lecture publique des appartements premium" ON public.logements_premium;
CREATE POLICY "Lecture publique des appartements premium" ON public.logements_premium FOR SELECT USING (true);
DROP POLICY IF EXISTS "Lecture publique des decors d'appartement" ON public.logements_decors;
CREATE POLICY "Lecture publique des decors d'appartement" ON public.logements_decors FOR SELECT USING (true);

ALTER TABLE public.visuels_versions DROP CONSTRAINT IF EXISTS visuels_versions_type_visuel_check;
ALTER TABLE public.visuels_versions ADD CONSTRAINT visuels_versions_type_visuel_check
  CHECK (type_visuel = ANY (ARRAY['publicite'::text, 'commerce'::text, 'logement'::text]));

-- Ordres facturés par le serveur (2 PA, décision de Fred).
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('logement_coloc_designer', 2, 0), ('logement_coloc_retirer', 2, 0)
ON CONFLICT DO NOTHING;

-- ===================================================================== 3. Lecture d'un logement
-- Immeubles dessinés dans le jeu : seuls à pouvoir recevoir des chambres premium.
CREATE OR REPLACE FUNCTION public.logement_premium_possible_interne(p_batiment text)
 RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT p_batiment IN ('logements-montrouge', 'logements-novomirsk', 'logements-novomirsk-marche', 'logements-novomirsk-quais') $function$;

CREATE OR REPLACE FUNCTION public.conjoint_actif_interne(p_nom text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN m.conjoint1 = p_nom THEN m.conjoint2 ELSE m.conjoint1 END
    FROM public.mariages m
   WHERE m.statut = 'actif' AND p_nom IN (m.conjoint1, m.conjoint2)
   ORDER BY m.created_at DESC LIMIT 1;
$function$;

-- Tout ce qu'il faut savoir d'une pièce de logement populaire (salon/pièce unique ou chambre), ou NULL.
CREATE OR REPLACE FUNCTION public.logement_info_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_base text := p_piece; v_ch integer := 0; m text[]; h public.logements_sociaux_historiques;
  v_bail jsonb; v_id text; v_coloc text; v_reprise text; v_type text;
BEGIN
  IF p_pays IS NULL OR p_ville IS NULL OR p_batiment IS NULL OR p_piece IS NULL THEN RETURN NULL; END IF;
  m := regexp_match(p_piece, '^(.+)_chambre_([12])$');
  IF m IS NOT NULL THEN v_base := m[1]; v_ch := m[2]::integer; END IF;
  SELECT * INTO h FROM public.logements_sociaux_historiques x
   WHERE x.pays = p_pays AND x.ville = p_ville AND x.batiment = p_batiment AND x.piece = v_base;
  v_id := p_pays || ':' || p_batiment || ':' || v_base || ':' || p_ville;
  SELECT l.data INTO v_bail FROM public.locations_actives l WHERE l.id = v_id;
  IF h.piece IS NULL AND coalesce(v_bail->>'logementSocial', '') <> 'true' THEN RETURN NULL; END IF;
  -- Les chambres n'existent que dans les immeubles dessinés.
  IF v_ch > 0 AND (h.piece IS NULL OR NOT public.logement_premium_possible_interne(p_batiment)) THEN RETURN NULL; END IF;
  v_type := coalesce(nullif(v_bail->>'typeLogement', ''), h.type_logement, nullif(v_bail->>'type', ''), 'petit');
  IF v_ch > (CASE WHEN v_type = 'grand' THEN 2 ELSE 1 END) THEN RETURN NULL; END IF;
  SELECT c.colocataire INTO v_coloc FROM public.logements_colocations c WHERE c.bail_id = v_id;
  SELECT r.colocataire INTO v_reprise FROM public.logements_reprises r
   WHERE r.bail_id = v_id AND r.statut = 'en_attente' AND r.expire_le > now();
  RETURN jsonb_build_object('bail', v_id, 'pays', p_pays, 'ville', p_ville, 'batiment', p_batiment,
    'base', v_base, 'chambre', v_ch, 'type', v_type,
    'titulaire', nullif(replace(coalesce(v_bail->>'locataire', ''), 'pj:', ''), ''),
    'colocataire', v_coloc, 'reprise', v_reprise,
    'premium', EXISTS (SELECT 1 FROM public.logements_premium p
                        WHERE p.pays = p_pays AND p.ville = p_ville AND p.batiment = p_batiment AND p.piece = v_base),
    'premium_possible', h.piece IS NOT NULL AND public.logement_premium_possible_interne(p_batiment),
    'moral', coalesce(nullif(v_bail->>'bonusMoralSommeil', '')::integer, h.bonus_moral, 0),
    'sante', coalesce(nullif(v_bail->>'bonusSanteSommeil', '')::integer, h.bonus_sante, 0),
    'label', coalesce(v_bail->>'localLabel', h.label, v_base));
END $function$;

-- titulaire | conjoint (du titulaire) | colocataire | reprise (ancien colocataire, offre de reprise en cours) | NULL
CREATE OR REPLACE FUNCTION public.logement_role_interne(p_acteur text, i jsonb)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN i IS NULL OR p_acteur IS NULL THEN NULL
    WHEN i->>'titulaire' = p_acteur THEN 'titulaire'
    WHEN i->>'colocataire' = p_acteur THEN 'colocataire'
    WHEN i->>'reprise' = p_acteur THEN 'reprise'
    WHEN i->>'titulaire' IS NOT NULL AND public.conjoint_actif_interne(i->>'titulaire') = p_acteur THEN 'conjoint'
    ELSE NULL END;
$function$;

-- Jouissance légale d'une pièce de logement populaire (matériel, serrure) :
-- pièce unique / salon : titulaire, conjoint, colocataire (et l'ancien colocataire pendant l'offre de reprise) ;
-- chambre 2 d'un grand appartement en colocation : le colocataire seul ; autres chambres : titulaire et conjoint.
CREATE OR REPLACE FUNCTION public.logement_jouissance_interne(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE i jsonb; r text; ch integer;
BEGIN
  i := public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece);
  IF i IS NULL THEN RETURN false; END IF;
  r := public.logement_role_interne(p_acteur, i);
  IF r IS NULL THEN RETURN false; END IF;
  ch := (i->>'chambre')::integer;
  IF ch = 0 THEN RETURN true; END IF;
  IF NOT (i->>'premium')::boolean THEN RETURN false; END IF;
  IF ch = 2 AND coalesce(i->>'colocataire', i->>'reprise') IS NOT NULL THEN RETURN r IN ('colocataire', 'reprise'); END IF;
  RETURN r IN ('titulaire', 'conjoint');
END $function$;

-- La jouissance générale d'un local l'inclut (corps d'origine inchangé, logement ajouté en dernier).
CREATE OR REPLACE FUNCTION public.local_jouissance_interne(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.locations_actives l
     WHERE l.id = p_pays || ':' || p_batiment || ':' || p_piece || ':' || p_ville
       AND ( replace(coalesce(l.data->>'locataire', ''), 'pj:', '') = p_acteur
          OR EXISTS (SELECT 1 FROM public.organisations o
                      WHERE o.id = l.data->>'orgaId'
                        AND ( o.data::jsonb->>'chef' = p_acteur
                           OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                                                                         THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) mb
                                       WHERE mb->>'nom' = p_acteur)))))
    -- appartements_populaires_v1 (12/11/2026) : conjoint, colocataire, chambres premium.
    OR public.logement_jouissance_interne(p_acteur, p_pays, p_ville, p_batiment, p_piece);
$function$;

-- Matériel abandonné par celui qui a perdu sa place (colocataire parti, conjoint divorcé, ancien
-- titulaire après une reprise) : il revient au titulaire du bail en cours, pas à la commune.
CREATE OR REPLACE FUNCTION public.logement_abandon_beneficiaire_interne(p_pays text, p_ville text, p_batiment text, p_piece text, p_proprietaire text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN i->>'titulaire' IS NOT NULL AND i->>'titulaire' <> p_proprietaire THEN 'pj:' || (i->>'titulaire') END
    FROM (SELECT public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece) AS i) x;
$function$;

DO $$
DECLARE f text; ancien text := 'v_foncier := public.local_proprietaire_foncier_interne(e.pays, e.ville, e.batiment, e.piece);';
BEGIN
  SELECT pg_get_functiondef('public.equipements_jouissance_nuit()'::regprocedure) INTO f;
  IF position('logement_abandon_beneficiaire_interne' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'jouissance_nuit_non_examinee'; END IF;
  EXECUTE replace(f, ancien, 'v_foncier := coalesce(public.logement_abandon_beneficiaire_interne(e.pays, e.ville, e.batiment, e.piece, e.proprietaire), public.local_proprietaire_foncier_interne(e.pays, e.ville, e.batiment, e.piece));');
END $$;

-- ===================================================================== 4. Emplacements de matériel
-- Gratuit : 3 (petit) / 5 (grand) dans la pièce unique. Premium : 3 au salon, 6 par chambre.
CREATE OR REPLACE FUNCTION public.equipements_emplacements_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE i jsonb;
BEGIN
  i := public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece);
  IF i IS NOT NULL THEN
    IF (i->>'premium')::boolean THEN RETURN CASE WHEN (i->>'chambre')::integer > 0 THEN 6 ELSE 3 END; END IF;
    RETURN CASE WHEN i->>'type' = 'grand' THEN 5 ELSE 3 END;
  END IF;
  RETURN CASE WHEN EXISTS (SELECT 1 FROM public.bureaux_option_premium b
                            WHERE b.pays = p_pays AND b.ville = p_ville AND b.batiment = p_batiment AND b.piece = p_piece
                              AND public.local_jouissance_interne(b.acheteur, p_pays, p_ville, p_batiment, p_piece))
              THEN 6 ELSE 3 END;
END $function$;

DO $$
DECLARE f text;
BEGIN
  -- La fenêtre des équipements sait qu'elle est dans un appartement (pas d'option « bureau » ici).
  SELECT pg_get_functiondef('public.equipements_local_lire()'::regprocedure) INTO f;
  IF position('''logement'', public.logement_info_interne' IN f) = 0 THEN
    IF position('''connexion'', public.trading_connexion_interne(v_moi),' IN f) = 0 THEN RAISE EXCEPTION 'local_lire_non_examinee'; END IF;
    EXECUTE replace(f, '''connexion'', public.trading_connexion_interne(v_moi),',
      '''logement'', public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room),
    ''connexion'', public.trading_connexion_interne(v_moi),');
  END IF;
  -- L'option premium « bureau » ne s'achète pas dans un appartement populaire : il a la sienne.
  SELECT pg_get_functiondef('public.equipement_option_premium_activer()'::regprocedure) INTO f;
  IF position('option_bureau_hors_logement' IN f) = 0 THEN
    IF position('RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_de_jouissance''); END IF;' IN f) = 0 THEN
      RAISE EXCEPTION 'option_premium_non_examinee'; END IF;
    EXECUTE replace(f, 'RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_de_jouissance''); END IF;',
      'RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_de_jouissance''); END IF;
  IF public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object(''ok'', false, ''raison'', ''option_bureau_hors_logement''); END IF;');
  END IF;
  -- Attribution d'un logement historique (bloc 1, différée : la table des reprises existe maintenant).
  f := current_setting('appartements.attribuer', true);
  IF f IS NOT NULL AND f <> '' THEN EXECUTE f; END IF;
  -- Lots sociaux des terrains : même garde contre une attribution pendant une reprise.
  SELECT pg_get_functiondef('public.logement_social_attribuer(text,text,text)'::regprocedure) INTO f;
  IF position('reprise_en_cours' IN f) = 0 THEN
    IF position('SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;' IN f) = 0 THEN
      RAISE EXCEPTION 'logement_social_attribuer_non_examinee'; END IF;
    EXECUTE replace(f, 'SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;',
      'IF EXISTS (SELECT 1 FROM public.logements_reprises rp WHERE rp.bail_id = idb AND rp.statut = ''en_attente'' AND rp.expire_le > now()) THEN
    RETURN jsonb_build_object(''ok'',false,''raison'',''reprise_en_cours''); END IF;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;');
  END IF;
END $$;

-- ===================================================================== 5. Sommeil : +1 PA
-- Titulaire, conjoint ou colocataire qui dort dans l'appartement : pièce unique en gratuit, une chambre
-- en premium (le salon ne donne rien). Moral et santé du logement suivent la même règle.
CREATE OR REPLACE FUNCTION public.logement_sommeil_interne(p_acteur text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; i jsonb; r text;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_acteur;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN NULL; END IF;
  r := public.logement_role_interne(p_acteur, i);
  IF r IS NULL OR r = 'reprise' THEN RETURN NULL; END IF;
  IF (i->>'premium')::boolean THEN
    IF (i->>'chambre')::integer = 0 THEN RETURN NULL; END IF;
  ELSIF (i->>'chambre')::integer <> 0 THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('pa', 1, 'moral', (i->>'moral')::integer, 'sante', (i->>'sante')::integer,
    'role', r, 'premium', (i->>'premium')::boolean, 'label', i->>'label');
END $function$;

DO $$
DECLARE f text;
BEGIN
  SELECT pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure) INTO f;
  IF position('appartements_populaires_repos_v1' IN f) > 0 THEN RETURN; END IF;
  IF position('v_hosp jsonb;' IN f) = 0
     OR position('    PERFORM public.residence_bonus_nuit_interne(p_acteur);' IN f) = 0
     OR position('''caserne'', v_caserne, ''tente'', v_tente);' IN f) = 0 THEN
    RAISE EXCEPTION 'pa_repos_nocturne_non_examinee'; END IF;
  f := replace(f, 'v_hosp jsonb;', 'v_hosp jsonb; v_logement jsonb;');
  f := replace(f, '    PERFORM public.residence_bonus_nuit_interne(p_acteur);',
    '    -- appartements_populaires_repos_v1 (Fred, 12/11/2026) : +1 PA dans son appartement populaire.
    v_logement := public.logement_sommeil_interne(p_acteur);
    IF v_logement IS NOT NULL THEN v_gain := v_gain + coalesce((v_logement->>''pa'')::integer, 0); END IF;
    PERFORM public.residence_bonus_nuit_interne(p_acteur);');
  f := replace(f, '''caserne'', v_caserne, ''tente'', v_tente);', '''caserne'', v_caserne, ''tente'', v_tente, ''logement'', v_logement);');
  EXECUTE f;
END $$;

-- ===================================================================== 6. Navigation et serrures
CREATE OR REPLACE FUNCTION public.logement_chambre_valide_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_piece ~ '_chambre_[12]$'
     AND (i->>'chambre')::integer > 0 AND (i->>'premium')::boolean, false)
    FROM (SELECT public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece) AS i) x;
$function$;

CREATE OR REPLACE FUNCTION public.navigation_piece_referencee_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays=p_pays AND ville=p_ville AND batiment=p_batiment AND pieces ? p_piece)
 OR (SELECT count(*)=1 FROM public.terrains_etat t
 CROSS JOIN LATERAL public.terrain_etat_lire(t.data) e
 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e->'subdivisions')='array' THEN e->'subdivisions' ELSE '[]'::jsonb END) lot
 WHERE t.country=p_pays AND t.building_id=p_batiment AND e->>'city'=p_ville
 AND nullif(btrim(lot->>'id'),'') IS NOT NULL
 AND 'lot_dyn_'||regexp_replace(btrim(lot->>'id'),'[^A-Za-z0-9_-]','_','g')=p_piece)
 -- appartements_populaires_v1 : chambres d'un appartement premium.
 OR public.logement_chambre_valide_interne(p_pays,p_ville,p_batiment,p_piece);
$function$;

-- Une serrure de chambre se rattache au bail de l'appartement (pas à un bail de chambre inexistant).
DO $$
DECLARE f text;
  ancien text := 'v_bail := d.country || '':'' || d.current_building || '':'' || d.current_room || '':'' || d.current_city;';
BEGIN
  SELECT pg_get_functiondef('public.serrure_poser(uuid,uuid,text,uuid)'::regprocedure) INTO f;
  IF position('logement_info_interne' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'serrure_poser_non_examinee'; END IF;
  EXECUTE replace(f, ancien, 'v_bail := d.country || '':'' || d.current_building || '':'' || coalesce(public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room)->>''base'', d.current_room) || '':'' || d.current_city;');
END $$;

-- Une serrure de logement populaire tombe aussi quand son poseur perd la jouissance de la pièce
-- (colocataire parti, conjoint divorcé) ; celle de l'ancien colocataire tient pendant l'offre de reprise.
CREATE OR REPLACE FUNCTION public.serrure_valide_interne(s serrures)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT s.statut = 'posee' AND (s.cible = 'armoire'
    OR (s.cible = 'vehicule' AND EXISTS (SELECT 1 FROM public.vehicules v WHERE v.serrure = s.id)) -- vehicules_socle_v1
    OR (s.cible = 'batiment' AND public.batiment_jouissance_integrale_interne(s.poseur, s.pays, s.ville, s.batiment))
    OR (s.cible = 'lieu' AND (EXISTS (
      SELECT 1 FROM public.locations_actives l
       WHERE l.id = s.bail_ref
         AND coalesce(nullif(l.data->>'orgaId', ''), replace(coalesce(l.data->>'locataire', ''), 'pj:', '')) = s.bail_titulaire)
      -- appartements_populaires_v1
      OR EXISTS (SELECT 1 FROM public.logements_reprises r WHERE r.bail_id = s.bail_ref AND r.statut = 'en_attente'
                    AND r.expire_le > now() AND r.colocataire = s.poseur))
      AND (public.logement_info_interne(s.pays, s.ville, s.batiment, s.piece) IS NULL
           OR public.local_jouissance_interne(s.poseur, s.pays, s.ville, s.batiment, s.piece))));
$function$;

-- ===================================================================== 7. Reprise du bail par le colocataire
CREATE OR REPLACE FUNCTION public.logements_bail_fin_reprise()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c public.logements_colocations;
BEGIN
  SELECT * INTO c FROM public.logements_colocations WHERE bail_id = OLD.id;
  IF c.bail_id IS NULL THEN RETURN OLD; END IF;
  DELETE FROM public.logements_colocations WHERE bail_id = OLD.id;
  INSERT INTO public.logements_reprises (bail_id, pays, ville, batiment, piece, colocataire, ancien_titulaire, bail, offerte_le, expire_le, statut)
  VALUES (OLD.id, c.pays, c.ville, c.batiment, c.piece, c.colocataire, c.titulaire, OLD.data, now(), now() + interval '48 hours', 'en_attente')
  ON CONFLICT (bail_id) DO UPDATE SET colocataire = EXCLUDED.colocataire, ancien_titulaire = EXCLUDED.ancien_titulaire,
    bail = EXCLUDED.bail, offerte_le = EXCLUDED.offerte_le, expire_le = EXCLUDED.expire_le, statut = 'en_attente';
  BEGIN
    PERFORM public.mail_systeme_poser_interne('Mairie', c.colocataire, 'Reprendre le bail',
      c.titulaire || ' n''est plus titulaire du bail de ' || coalesce(OLD.data->>'localLabel', 'votre logement')
      || '. En tant que colocataire, vous êtes prioritaire pour le reprendre à votre nom, au même loyer et avec la même option premium. '
      || 'Rendez-vous dans l''appartement, ordre « Mon logement », pour accepter ou refuser. L''offre est valable 48 h ; '
      || 'si vous refusez ou ne répondez pas, vous aurez encore 48 h pour partir avec votre matériel.', NULL);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN OLD;
END $function$;

DROP TRIGGER IF EXISTS logements_bail_fin_reprise ON public.locations_actives;
CREATE TRIGGER logements_bail_fin_reprise AFTER DELETE ON public.locations_actives
  FOR EACH ROW EXECUTE FUNCTION public.logements_bail_fin_reprise();

-- ===================================================================== 8. Portes des joueurs
-- Tout ce que la fenêtre « Mon logement » affiche, pour la pièce où l'on se trouve.
CREATE OR REPLACE FUNCTION public.logement_etat()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; r text; ch integer; n integer; k integer;
  v_pieces jsonb := '[]'::jsonb; v_piece text; v_reprise record;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  r := public.logement_role_interne(v_moi, i);
  n := CASE WHEN i->>'type' = 'grand' THEN 2 ELSE 1 END;
  FOR k IN 0..n LOOP
    v_piece := CASE WHEN k = 0 THEN i->>'base' ELSE (i->>'base') || '_chambre_' || k END;
    v_pieces := v_pieces || jsonb_build_array(jsonb_build_object('piece', v_piece, 'chambre', k,
      'decor', (SELECT x.image_path FROM public.logements_decors x
                 WHERE x.cle = d.country || '|' || d.current_city || '|' || d.current_building || '|' || v_piece AND x.retiree_le IS NULL),
      'peut_decorer', public.logement_decor_droit_interne(v_moi, d.country, d.current_city, d.current_building, v_piece)));
  END LOOP;
  SELECT expire_le INTO v_reprise FROM public.logements_reprises
   WHERE bail_id = i->>'bail' AND colocataire = v_moi AND statut = 'en_attente' AND expire_le > now();
  RETURN jsonb_build_object('ok', true, 'logement', i, 'role', r,
    'conjoint', CASE WHEN i->>'titulaire' IS NOT NULL THEN public.conjoint_actif_interne(i->>'titulaire') END,
    'pieces', CASE WHEN (i->>'premium')::boolean THEN v_pieces ELSE jsonb_build_array(v_pieces -> 0) END,
    'reprise_expire_le', v_reprise.expire_le,
    'ma_colocation', (SELECT jsonb_build_object('label', coalesce(l.data->>'localLabel', c.piece), 'titulaire', c.titulaire)
                        FROM public.logements_colocations c LEFT JOIN public.locations_actives l ON l.id = c.bail_id
                       WHERE c.colocataire = v_moi));
END $function$;

CREATE OR REPLACE FUNCTION public.logement_decor_droit_interne(p_nom text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE i jsonb; r text; ch integer;
BEGIN
  i := public.logement_info_interne(p_pays, p_ville, p_batiment, p_piece);
  IF i IS NULL OR NOT (i->>'premium')::boolean THEN RETURN false; END IF;
  r := public.logement_role_interne(p_nom, i);
  ch := (i->>'chambre')::integer;
  IF r = 'conjoint' THEN RETURN true; END IF;
  IF r = 'titulaire' THEN RETURN i->>'colocataire' IS NULL OR ch IN (0, 1); END IF;
  IF r = 'colocataire' THEN RETURN ch = 2; END IF;
  RETURN false;
END $function$;

-- Option premium : purement cosmétique, attachée à l'appartement, gratuite pendant la bêta.
CREATE OR REPLACE FUNCTION public.logement_premium_activer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; r text;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  r := public.logement_role_interne(v_moi, i);
  IF r IS NULL OR r NOT IN ('titulaire', 'conjoint') THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_titulaire'); END IF;
  IF NOT (i->>'premium_possible')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'premium_indisponible_ici'); END IF;
  IF (i->>'premium')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_premium'); END IF;
  -- Bêta : gratuite. Le paiement de l'option sera branché ici lors de la session premium.
  INSERT INTO public.logements_premium (pays, ville, batiment, piece, active_par)
  VALUES (d.country, d.current_city, d.current_building, i->>'base', v_moi) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'base', i->>'base', 'chambres', CASE WHEN i->>'type' = 'grand' THEN 2 ELSE 1 END);
END $function$;

CREATE OR REPLACE FUNCTION public.logement_coloc_designer(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; v jsonb; v_nom text := btrim(coalesce(p_nom, ''));
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  IF i->>'titulaire' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_titulaire'); END IF;
  IF i->>'type' <> 'grand' THEN RETURN jsonb_build_object('ok', false, 'raison', 'coloc_grand_seulement'); END IF;
  IF i->>'colocataire' IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_un_colocataire'); END IF;
  IF v_nom = '' OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_nom = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_soi_meme'); END IF;
  IF public.conjoint_actif_interne(v_moi) = v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_conjoint'); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_colocations WHERE colocataire = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_colocataire_ailleurs'); END IF;
  -- En premium, le colocataire reçoit la chambre 2 : elle doit être vide de matériel.
  IF (i->>'premium')::boolean AND EXISTS (SELECT 1 FROM public.equipements_installes e
       WHERE e.pays = d.country AND e.ville = d.current_city AND e.batiment = d.current_building AND e.piece = (i->>'base') || '_chambre_2') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chambre_2_occupee'); END IF;
  v := public.payer_ordre_interne(v_moi, 'logement_coloc_designer', 2, 0);
  IF NOT coalesce((v->>'ok')::boolean, false) THEN RETURN v; END IF;
  INSERT INTO public.logements_colocations (bail_id, pays, ville, batiment, piece, titulaire, colocataire)
  VALUES (i->>'bail', d.country, d.current_city, d.current_building, i->>'base', v_moi, v_nom);
  PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', v_nom, 'Colocation',
    v_moi || ' vous a désigné(e) colocataire de ' || (i->>'label') || '. Vous en avez désormais la jouissance légale : '
    || 'vous pouvez y dormir, y poser une serrure et y installer votre matériel'
    || CASE WHEN (i->>'premium')::boolean THEN ' ; la deuxième chambre est la vôtre' ELSE '' END
    || '. Le loyer reste au nom de ' || v_moi || ' : le partage se règle entre vous.', NULL);
  RETURN jsonb_build_object('ok', true, 'colocataire', v_nom, 'pa', v->'pa');
END $function$;

CREATE OR REPLACE FUNCTION public.logement_coloc_retirer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; v jsonb; c public.logements_colocations;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  IF i->>'titulaire' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_titulaire'); END IF;
  SELECT * INTO c FROM public.logements_colocations WHERE bail_id = i->>'bail' FOR UPDATE;
  IF c.bail_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_colocataire'); END IF;
  v := public.payer_ordre_interne(v_moi, 'logement_coloc_retirer', 2, 0);
  IF NOT coalesce((v->>'ok')::boolean, false) THEN RETURN v; END IF;
  DELETE FROM public.logements_colocations WHERE bail_id = c.bail_id;
  PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', c.colocataire, 'Fin de la colocation',
    v_moi || ' a mis fin à votre colocation (' || (i->>'label') || '). Vous disposez de 48 h pour venir désinstaller votre matériel ; '
    || 'passé ce délai, il reviendra au titulaire du bail.', NULL);
  RETURN jsonb_build_object('ok', true, 'colocataire', c.colocataire, 'pa', v->'pa');
END $function$;

-- Le colocataire part de lui-même : gratuit, où qu'il soit.
CREATE OR REPLACE FUNCTION public.logement_coloc_partir()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); c public.logements_colocations; v_label text;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO c FROM public.logements_colocations WHERE colocataire = v_moi FOR UPDATE;
  IF c.bail_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_colocation'); END IF;
  SELECT coalesce(data->>'localLabel', c.piece) INTO v_label FROM public.locations_actives WHERE id = c.bail_id;
  DELETE FROM public.logements_colocations WHERE bail_id = c.bail_id;
  PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', c.titulaire, 'Départ de votre colocataire',
    v_moi || ' a quitté la colocation (' || coalesce(v_label, c.piece) || '). Le matériel qu''il n''aura pas désinstallé sous 48 h vous reviendra.', NULL);
  RETURN jsonb_build_object('ok', true);
END $function$;

CREATE OR REPLACE FUNCTION public.logement_reprendre_bail(p_accepter boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); rp public.logements_reprises; v_jour integer;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO rp FROM public.logements_reprises
   WHERE colocataire = v_moi AND statut = 'en_attente' AND expire_le > now() ORDER BY offerte_le DESC LIMIT 1 FOR UPDATE;
  IF rp.bail_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_reprise'); END IF;
  IF p_accepter IS NOT TRUE THEN
    UPDATE public.logements_reprises SET statut = 'refusee' WHERE bail_id = rp.bail_id;
    RETURN jsonb_build_object('ok', true, 'accepte', false);
  END IF;
  IF EXISTS (SELECT 1 FROM public.locations_actives WHERE id = rp.bail_id) THEN
    UPDATE public.logements_reprises SET statut = 'caduque' WHERE bail_id = rp.bail_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'local_occupe');
  END IF;
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = v_moi;
  INSERT INTO public.locations_actives (id, country, data)
  VALUES (rp.bail_id, rp.pays, rp.bail || jsonb_build_object('locataire', v_moi, 'depuis', v_jour,
          'reprisDe', rp.ancien_titulaire, 'reprisLe', now()));
  -- Ses serrures (sa chambre) restent valables sous son nouveau bail.
  UPDATE public.serrures SET bail_titulaire = v_moi
   WHERE statut = 'posee' AND cible = 'lieu' AND bail_ref = rp.bail_id AND poseur = v_moi;
  UPDATE public.logements_reprises SET statut = 'acceptee' WHERE bail_id = rp.bail_id;
  PERFORM public.mail_systeme_poser_interne('Mairie', v_moi, 'Bail repris',
    'Le bail de ' || coalesce(rp.bail->>'localLabel', 'votre logement') || ' est désormais à votre nom, au même loyer. '
    || 'Vous pouvez désigner un colocataire depuis l''ordre « Mon logement ».', NULL);
  RETURN jsonb_build_object('ok', true, 'accepte', true, 'bail', rp.bail_id);
END $function$;

-- ===================================================================== 9. Droits
REVOKE ALL ON FUNCTION public.logement_premium_possible_interne(text), public.conjoint_actif_interne(text),
  public.logement_info_interne(text,text,text,text), public.logement_role_interne(text,jsonb),
  public.logement_jouissance_interne(text,text,text,text,text), public.logement_abandon_beneficiaire_interne(text,text,text,text,text),
  public.logement_sommeil_interne(text), public.logement_chambre_valide_interne(text,text,text,text),
  public.logement_decor_droit_interne(text,text,text,text,text), public.logements_bail_fin_reprise()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.logement_premium_possible_interne(text), public.conjoint_actif_interne(text),
  public.logement_info_interne(text,text,text,text), public.logement_role_interne(text,jsonb),
  public.logement_jouissance_interne(text,text,text,text,text), public.logement_abandon_beneficiaire_interne(text,text,text,text,text),
  public.logement_sommeil_interne(text), public.logement_chambre_valide_interne(text,text,text,text),
  public.logement_decor_droit_interne(text,text,text,text,text)
  TO service_role;
REVOKE ALL ON FUNCTION public.logement_etat(), public.logement_premium_activer(), public.logement_coloc_designer(text),
  public.logement_coloc_retirer(), public.logement_coloc_partir(), public.logement_reprendre_bail(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logement_etat(), public.logement_premium_activer(), public.logement_coloc_designer(text),
  public.logement_coloc_retirer(), public.logement_coloc_partir(), public.logement_reprendre_bail(boolean)
  TO authenticated, service_role;

-- ===================================================================== 10. Preuves structurelles
DO $$
BEGIN
  IF (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'ville_a' AND batiment = 'logements-novomirsk') <> 8
     OR (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'logements-novomirsk') <> 8
     OR position('appartements_populaires_repos_v1' IN pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) = 0
     OR position('logement_jouissance_interne' IN pg_get_functiondef('public.local_jouissance_interne(text,text,text,text,text)'::regprocedure)) = 0
     OR position('logement_info_interne' IN pg_get_functiondef('public.serrure_poser(uuid,uuid,text,uuid)'::regprocedure)) = 0
     OR position('logement_abandon_beneficiaire_interne' IN pg_get_functiondef('public.equipements_jouissance_nuit()'::regprocedure)) = 0
     OR position('x.ville = p_ville' IN pg_get_functiondef('public.logement_historique_attribuer_interne(text,text,text,text,text)'::regprocedure)) = 0
     OR position('reprise_en_cours' IN pg_get_functiondef('public.logement_historique_attribuer_interne(text,text,text,text,text)'::regprocedure)) = 0
     OR position('reprise_en_cours' IN pg_get_functiondef('public.logement_social_attribuer(text,text,text)'::regprocedure)) = 0
     OR position('option_bureau_hors_logement' IN pg_get_functiondef('public.equipement_option_premium_activer()'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'logements_bail_fin_reprise')
     OR public.equipements_emplacements_interne('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_1') <> 5
     OR public.equipements_emplacements_interne('republic', 'ville_b', 'logements-montrouge', 'petit_appartement_1') <> 3
     OR public.logement_chambre_valide_interne('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_1_chambre_1')
     OR has_function_privilege('authenticated', 'public.logement_info_interne(text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'appartements_populaires_incomplet';
  END IF;
END $$;

COMMIT;
