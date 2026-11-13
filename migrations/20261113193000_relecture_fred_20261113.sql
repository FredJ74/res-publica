-- Registre Supabase : relecture_fred_appartements_sovarka_20261113193000 (APPLIQUÉE le 13/11/2026, NE PAS RÉAPPLIQUER).
-- Fichier nommé sans « sovarka » : ses courriers (option premium) sont communs à tous les pays.
-- Relecture de Fred du 13/11/2026 au soir (GAME-DESIGN-APPARTEMENTS.md « Choix de Claude » et
-- GAME-DESIGN-NOVOMIRSK.md « Relecture de Fred (13/11/2026) »). Patchs EN PLACE, gardés : chaque
-- remplacement vérifie que le texte attendu existe, sinon la migration s'arrête (rien n'est appliqué).
--
-- 1. Vol d'archives des centres d'écoute : 45 + (DIS - 50) / 3 + (VOL - 8) + (DUP - 8), borné 5-85 ;
--    puis les malus existants (ISN de la ville, hommes armés présents), dont le total est plafonné à 33.
--    Le plafond ne vaut QUE pour cet acte (question ouverte pour les autres actes illégaux).
-- 2. Repas chez l'habitant : +1 PA au prochain sommeil (au lieu de +2), la maison étant un logement gratuit.
-- 3. Trinquer : le verdict nomme l'alcool ; nouvelle lecture sovarka_maison_trinquer_lire, consommée une
--    seule fois, pour que /api/chat?mode=trinquer fasse écrire la réaction de l'habitant par DeepSeek.
-- 4. Appartements : option premium pour TOUS les logements populaires (y compris ceux construits en
--    cours de partie) ; nombre de chambres enregistré avec l'option ; demande du colocataire acceptée
--    ou refusée par le titulaire (courrier à boutons, 48 h) ; images de référence des décors.

-- ===================================================================== 1. Vol d'archives
DO $$
DECLARE f text;
  sel_ancien text := 'SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;';
  jet_ancien text := 'v_taux := greatest(5, 45 - public.crime_malus_isn_interne(p.country, p.current_city));
  v_roll := least(100, floor(random() * 100)::integer + 1 + public.securite_malus_lieu_interne(a)); /* securite_dissuasion */';
BEGIN
  SELECT pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure) INTO f;
  IF position('vol_archives_formule_v2' IN f) > 0 THEN RETURN; END IF;
  IF position(sel_ancien IN f) = 0 OR position(jet_ancien IN f) = 0 THEN RAISE EXCEPTION 'vol_archives_non_examine'; END IF;
  f := replace(f, sel_ancien, 'SELECT country, current_city, current_building, resources, stats INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;');
  f := replace(f, jet_ancien, '/* vol_archives_formule_v2 (Fred, 13/11/2026) : 45 + (DIS - 50) / 3 + (VOL - 8) + (DUP - 8), borné 5-85 ;
     malus de sécurité (ISN + hommes armés) plafonnés à 33 au total, pour cet acte seulement. */
  v_taux := least(85, greatest(5, round(45
      + (coalesce(CASE WHEN jsonb_typeof(p.resources -> ''dis'') = ''number'' THEN (p.resources ->> ''dis'')::numeric END, 50) - 50) / 3.0
      + coalesce(CASE WHEN jsonb_typeof(p.stats -> ''VOL'') = ''number'' THEN (p.stats ->> ''VOL'')::numeric END, 8) - 8
      + coalesce(CASE WHEN jsonb_typeof(p.stats -> ''DUP'') = ''number'' THEN (p.stats ->> ''DUP'')::numeric END, 8) - 8)::integer));
  v_taux := greatest(5, v_taux - least(33, public.crime_malus_isn_interne(p.country, p.current_city)
      + public.securite_malus_lieu_interne(a))); /* securite_dissuasion */
  v_roll := floor(random() * 100)::integer + 1;');
  EXECUTE f;
END $$;

-- ===================================================================== 2. Repas chez l'habitant
UPDATE public.pa_bonus_differes SET montant = 1 WHERE source = 'repas_habitant' AND montant <> 1;

-- ===================================================================== 3. Trinquer : réaction par l'IA
DO $$
DECLARE f text; ancien text := '''reaction'', v_reaction,';
BEGIN
  SELECT pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure) INTO f;
  IF position('''alcool'', l->>''cle''' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'trinquer_non_examine'; END IF;
  EXECUTE replace(f, ancien, '''reaction'', v_reaction, ''alcool'', l->>''cle'',');
END $$;

-- Lecture d'un « trinquer » réussi de l'acteur, pour l'écriture de la réaction par DeepSeek.
-- Consommée une seule fois (un seul appel à l'IA par bouteille) et dans les 15 minutes.
CREATE OR REPLACE FUNCTION public.sovarka_maison_trinquer_lire(p_requete text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); x record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO x FROM public.sovarka_maisons_actes WHERE acteur = a AND requete = p_requete FOR UPDATE;
  IF NOT FOUND OR x.resultat->>'action' IS DISTINCT FROM 'trinquer' OR NOT coalesce((x.resultat->>'ok')::boolean, false)
     OR x.cree_le < now() - interval '15 minutes' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_introuvable'); END IF;
  IF x.resultat ? 'reaction_ia' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_demandee'); END IF;
  UPDATE public.sovarka_maisons_actes SET resultat = resultat || jsonb_build_object('reaction_ia', now())
   WHERE acteur = a AND requete = p_requete;
  RETURN jsonb_build_object('ok', true, 'habitant', x.resultat->>'habitant',
    'alcool', coalesce(x.resultat->>'alcool', 'alcool'), 'reaction', x.resultat->>'reaction');
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_maison_trinquer_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_maison_trinquer_lire(text) TO authenticated;

-- ===================================================================== 4a. Premium pour tous les logements
-- Décision de Fred (13/11) : l'option premium concerne tous les logements populaires, y compris ceux
-- construits en cours de partie (lots des terrains, immeubles des mairies de Sovarka). Purement
-- cosmétique : +1 PA avec ou sans premium.
CREATE OR REPLACE FUNCTION public.logement_premium_possible_interne(p_batiment text)
 RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT p_batiment IS NOT NULL /* premium_tous_logements_v1 */ $function$;

DO $$
DECLARE f text;
  garde_ancienne text := 'IF v_ch > 0 AND (h.piece IS NULL OR NOT public.logement_premium_possible_interne(p_batiment)) THEN RETURN NULL; END IF;';
  possible_ancien text := '''premium_possible'', h.piece IS NOT NULL AND public.logement_premium_possible_interne(p_batiment),';
BEGIN
  SELECT pg_get_functiondef('public.logement_info_interne(text,text,text,text)'::regprocedure) INTO f;
  IF position('premium_tous_logements_v1' IN f) > 0 THEN RETURN; END IF;
  IF position(garde_ancienne IN f) = 0 OR position(possible_ancien IN f) = 0 THEN RAISE EXCEPTION 'logement_info_non_examine'; END IF;
  f := replace(f, garde_ancienne, '/* premium_tous_logements_v1 : chambres aussi dans les logements construits en cours de partie */
  IF v_ch > 0 AND NOT public.logement_premium_possible_interne(p_batiment) THEN RETURN NULL; END IF;');
  f := replace(f, possible_ancien, '''premium_possible'', public.logement_premium_possible_interne(p_batiment),');
  EXECUTE f;
END $$;

-- Le nombre de chambres voyage avec l'option : l'écran crée les chambres des logements dynamiques.
ALTER TABLE public.logements_premium ADD COLUMN IF NOT EXISTS chambres smallint;
UPDATE public.logements_premium SET chambres = CASE WHEN piece ~ '^grand_' THEN 2 ELSE 1 END WHERE chambres IS NULL;

DO $$
DECLARE f text;
  cols_ancien text := 'INSERT INTO public.logements_premium (pays, ville, batiment, piece, active_par)';
  vals_ancien text := 'i->>''base'', v_moi) ON CONFLICT DO NOTHING;';
BEGIN
  SELECT pg_get_functiondef('public.logement_premium_activer()'::regprocedure) INTO f;
  IF position('active_par, chambres' IN f) > 0 THEN RETURN; END IF;
  IF position(cols_ancien IN f) = 0 OR position(vals_ancien IN f) = 0 THEN RAISE EXCEPTION 'premium_activer_non_examine'; END IF;
  f := replace(f, cols_ancien, 'INSERT INTO public.logements_premium (pays, ville, batiment, piece, active_par, chambres)');
  f := replace(f, vals_ancien, 'i->>''base'', v_moi, CASE WHEN i->>''type'' = ''grand'' THEN 2 ELSE 1 END) ON CONFLICT DO NOTHING;');
  EXECUTE f;
END $$;

-- ===================================================================== 4b. Demande du colocataire
CREATE TABLE IF NOT EXISTS public.logements_premium_demandes (
  bail_id text PRIMARY KEY,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  colocataire text NOT NULL, titulaire text NOT NULL, chambres smallint NOT NULL,
  demandee_le timestamptz NOT NULL DEFAULT now(), expire_le timestamptz NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'acceptee', 'refusee', 'caduque')));
ALTER TABLE public.logements_premium_demandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_premium_demandes FROM anon, authenticated;

-- Le colocataire demande l'option ; le titulaire du bail doit accepter (courrier, 48 h).
CREATE OR REPLACE FUNCTION public.logement_premium_demander()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); d record; i jsonb; v_exp timestamptz := now() + interval '48 hours';
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_logement'); END IF;
  IF public.logement_role_interne(v_moi, i) IS DISTINCT FROM 'colocataire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_colocataire'); END IF;
  IF NOT (i->>'premium_possible')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'premium_indisponible_ici'); END IF;
  IF (i->>'premium')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_premium'); END IF;
  IF i->>'titulaire' IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_titulaire'); END IF;
  PERFORM 1 FROM public.logements_premium_demandes WHERE bail_id = i->>'bail' FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.logements_premium_demandes
              WHERE bail_id = i->>'bail' AND statut = 'en_attente' AND expire_le > now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours'); END IF;
  INSERT INTO public.logements_premium_demandes (bail_id, pays, ville, batiment, piece, colocataire, titulaire, chambres, demandee_le, expire_le, statut)
  VALUES (i->>'bail', d.country, d.current_city, d.current_building, i->>'base', v_moi, i->>'titulaire',
          CASE WHEN i->>'type' = 'grand' THEN 2 ELSE 1 END, now(), v_exp, 'en_attente')
  ON CONFLICT (bail_id) DO UPDATE SET colocataire = EXCLUDED.colocataire, titulaire = EXCLUDED.titulaire,
    chambres = EXCLUDED.chambres, demandee_le = EXCLUDED.demandee_le, expire_le = EXCLUDED.expire_le, statut = 'en_attente';
  PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', i->>'titulaire', 'Option premium demandée',
    v_moi || ', votre colocataire, demande l''option premium pour ' || (i->>'label') || ' : un salon et des chambres séparées, '
    || 'des décors par IA et des emplacements de matériel répartis par pièce. Purement cosmétique, sans aucun avantage '
    || 'd''indices ni de PA ; gratuite pendant la bêta, et attachée à l''appartement. En tant que titulaire du bail, '
    || 'c''est à vous d''accepter ou de refuser. La demande est valable 48 h ; sans réponse, elle tombe.'
    || ' [[act:premium_oui|' || replace(replace(replace(i->>'bail', '|', ''), '[', ''), ']', '') || ']]'
    || ' [[act:premium_non|' || replace(replace(replace(i->>'bail', '|', ''), '[', ''), ']', '') || ']]', NULL);
  RETURN jsonb_build_object('ok', true, 'titulaire', i->>'titulaire', 'expire_le', v_exp);
END $function$;

-- Le titulaire répond, où qu'il soit (bouton du courrier ou fenêtre « Mon logement »).
CREATE OR REPLACE FUNCTION public.logement_premium_demande_repondre(p_bail text, p_accepter boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); q public.logements_premium_demandes; v_tit text;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO q FROM public.logements_premium_demandes WHERE bail_id = p_bail FOR UPDATE;
  IF q.bail_id IS NULL OR q.statut <> 'en_attente' OR q.expire_le <= now() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_demande'); END IF;
  SELECT nullif(replace(coalesce(l.data->>'locataire', ''), 'pj:', ''), '') INTO v_tit FROM public.locations_actives l WHERE l.id = q.bail_id;
  IF v_tit IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_titulaire'); END IF;
  -- La demande tombe si le demandeur n'est plus colocataire de ce bail.
  IF NOT EXISTS (SELECT 1 FROM public.logements_colocations c WHERE c.bail_id = q.bail_id AND c.colocataire = q.colocataire) THEN
    UPDATE public.logements_premium_demandes SET statut = 'caduque' WHERE bail_id = q.bail_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_caduque'); END IF;
  IF p_accepter IS NOT TRUE THEN
    UPDATE public.logements_premium_demandes SET statut = 'refusee' WHERE bail_id = q.bail_id;
    PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', q.colocataire, 'Option premium refusée',
      v_moi || ', titulaire du bail, a refusé votre demande d''option premium.', NULL);
    RETURN jsonb_build_object('ok', true, 'accepte', false, 'colocataire', q.colocataire);
  END IF;
  -- Bêta : gratuite. Le paiement de l'option sera branché ici lors de la session premium.
  INSERT INTO public.logements_premium (pays, ville, batiment, piece, active_par, chambres)
  VALUES (q.pays, q.ville, q.batiment, q.piece, q.colocataire, q.chambres) ON CONFLICT DO NOTHING;
  UPDATE public.logements_premium_demandes SET statut = 'acceptee' WHERE bail_id = q.bail_id;
  PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', q.colocataire, 'Option premium acceptée',
    v_moi || ', titulaire du bail, a accepté votre demande : l''option premium est active. Les portes des chambres s''ouvrent depuis le salon.', NULL);
  RETURN jsonb_build_object('ok', true, 'accepte', true, 'colocataire', q.colocataire,
    'pays', q.pays, 'ville', q.ville, 'batiment', q.batiment, 'base', q.piece, 'chambres', q.chambres);
END $function$;

REVOKE ALL ON FUNCTION public.logement_premium_demander(), public.logement_premium_demande_repondre(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logement_premium_demander(), public.logement_premium_demande_repondre(text, boolean) TO authenticated, service_role;

-- La fenêtre « Mon logement » montre la demande en cours (au colocataire comme au titulaire).
DO $$
DECLARE f text; ancien text := '''reprise_expire_le'', v_reprise.expire_le,';
BEGIN
  SELECT pg_get_functiondef('public.logement_etat()'::regprocedure) INTO f;
  IF position('premium_demande' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'logement_etat_non_examine'; END IF;
  EXECUTE replace(f, ancien, '''reprise_expire_le'', v_reprise.expire_le,
    ''premium_demande'', (SELECT jsonb_build_object(''colocataire'', q.colocataire, ''expire_le'', q.expire_le)
                          FROM public.logements_premium_demandes q
                         WHERE q.bail_id = i->>''bail'' AND q.statut = ''en_attente'' AND q.expire_le > now()),');
END $$;

-- ===================================================================== 4c. Images de référence des décors
-- Comme l'atelier du Commerce Premium : jusqu'à 5 images fournies par le joueur, conservées en privé
-- pour la traçabilité (bucket publicites-premium-sources), avec la case de droits cochée.
CREATE TABLE IF NOT EXISTS public.logements_decors_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle text NOT NULL,
  proprietaire_user_id uuid NOT NULL REFERENCES auth.users(id),
  chemin text NOT NULL, nom_original text, type_mime text NOT NULL,
  taille_octets integer, empreinte_sha256 text,
  consentement_le timestamptz NOT NULL DEFAULT now(),
  utilisee_pour text,
  cree_le timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS logements_decors_sources_cle ON public.logements_decors_sources (cle, proprietaire_user_id);
ALTER TABLE public.logements_decors_sources ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_decors_sources FROM anon, authenticated;

-- ===================================================================== Contrôles structurels
DO $$
BEGIN
  IF position('vol_archives_formule_v2' IN pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure)) = 0
     OR position('''alcool'', l->>''cle''' IN pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure)) = 0
     OR position('premium_tous_logements_v1' IN pg_get_functiondef('public.logement_info_interne(text,text,text,text)'::regprocedure)) = 0
     OR position('active_par, chambres' IN pg_get_functiondef('public.logement_premium_activer()'::regprocedure)) = 0
     OR position('premium_demande' IN pg_get_functiondef('public.logement_etat()'::regprocedure)) = 0
     OR (SELECT montant FROM public.pa_bonus_differes WHERE source = 'repas_habitant') <> 1 THEN
    RAISE EXCEPTION 'relecture_fred_20261113_incomplete';
  END IF;
END $$;
