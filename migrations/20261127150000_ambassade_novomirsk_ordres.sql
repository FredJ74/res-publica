-- Mission du 27/11/2026 (après-midi, Claude), étape 2 — NON APPLIQUÉE : à valider par Fred avant application en production.
-- AMBASSADE DE RÉPUBLIA À NOVOMIRSK : « Organiser une réception diplomatique » et « Financer une œuvre culturelle »
-- raccordées aux fonctions serveur de Luthécia (consigne de Fred du 27/11/2026 : mêmes fonctions, mêmes règles,
-- pays hôte Sovarka). « Consulter les relations bilatérales » n'a besoin d'aucun changement serveur.
-- « Demander le transfert d'un détenu » reste grisé (décision de Fred du 01/11 : il attend le voyage entre empires).
--
-- Relevé en lecture le 27/11 (définitions de production) :
--   • ambassade_ambassadeur_interne exigeait current_building = 'quartier-ambassades' (Luthécia) pour tout pays hôte :
--     un ambassadeur en poste à Novomirsk recevait toujours « pas_sur_place ». Désormais le bâtiment est celui du pays
--     hôte, comme pour les audiences et l'asile : 'quartier-ambassades' en Républia, 'palais-ambassades-novomirsk' en Sovarka.
--   • La salle d'une réception à Novomirsk est la Grande Salle de Réception du Pavillon des Ambassadeurs (#874, 13/11 :
--     « réception au Pavillon, non au Palais ») ; elle se réserve par l'ordre existant « Réserver la réception »
--     (pavillon_acte, 1 500 PSK payés par la caisse de l'institution, recettes à Sovarka : décision de Fred du 11/11).
--     La réservation gratuite de Luthécia (ambassade_reserver_salle) est donc refusée pour un pays hôte Sovarka.
--   • Réception (règles de Luthécia, GAME-DESIGN-AMBASSADES.md, 25/10) : la salle doit être réservée aujourd'hui par cet
--     ambassadeur ; 2 PA et 1 200 (portefeuille de l'ambassadeur) ; +1 Indice Diplomatique et +1 popularité par joueur
--     du pays hôte présent dans la salle (l'ambassadeur exclu), plafonds +10 et +5 ; personne : -3 et -3 ; une réception
--     par réservation (colonnes ajoutées à pavillon_receptions).
--   • Mécénat : inchangé (+3 Indice, +8 popularité, 1 PA, 600), annonce publique au pays hôte.
--
-- Contrôles en lecture après application :
--   SELECT position('ambassade_lieu_hote_v1' in pg_get_functiondef('public.ambassade_ambassadeur_interne(text)'::regprocedure)) > 0; -- vrai
--   SELECT position('pavillon-ambassadeurs-novomirsk' in pg_get_functiondef('public.ambassade_reception_organiser(text)'::regprocedure)) > 0; -- vrai
--   SELECT count(*) FROM information_schema.columns WHERE table_name = 'pavillon_receptions'
--      AND column_name IN ('reception_donnee_le', 'invites');                                                         -- 2
BEGIN;

ALTER TABLE public.pavillon_receptions ADD COLUMN IF NOT EXISTS reception_donnee_le timestamptz;
ALTER TABLE public.pavillon_receptions ADD COLUMN IF NOT EXISTS invites integer;

-- Bâtiment de l'ambassade selon le pays hôte (même correspondance que ambassade_demander_audience).
CREATE OR REPLACE FUNCTION public.ambassade_batiment_hote_interne(p_hote text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE p_hote WHEN 'republic' THEN 'quartier-ambassades' WHEN 'soviet' THEN 'palais-ambassades-novomirsk' END
$$;
REVOKE ALL ON FUNCTION public.ambassade_batiment_hote_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.ambassade_ambassadeur_interne(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- ambassade_lieu_hote_v1 : l'ambassadeur agit depuis le bâtiment des ambassades du pays où il est en poste.
DECLARE v_moi text; v_hote text; v_bat text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building INTO v_bat FROM public.personnages_donnees WHERE name = v_moi;
  SELECT a.pays_hote INTO v_hote FROM public.ambassades_ouvertes a
   WHERE a.empire = p_empire AND a.data ->> 'ambassadeur' = v_moi
   ORDER BY (public.ambassade_batiment_hote_interne(a.pays_hote) IS NOT DISTINCT FROM v_bat) DESC, a.pays_hote
   LIMIT 1;
  IF v_hote IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ambassadeur'); END IF;
  IF v_bat IS DISTINCT FROM public.ambassade_batiment_hote_interne(v_hote) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN jsonb_build_object('ok', true, 'moi', v_moi, 'hote', v_hote);
END; $function$;

CREATE OR REPLACE FUNCTION public.ambassade_reserver_salle(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_hote text; v_jour integer; v_id text; v_existant jsonb; v_paie jsonb;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_hote := m ->> 'hote';
  -- En Sovarka, la salle est celle du Pavillon : elle se réserve par « Réserver la réception » (pavillon_acte).
  IF v_hote = 'soviet' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reservation_au_pavillon'); END IF;
  v_jour := public.jour_de_jeu_pays(v_hote);
  v_id := v_hote || '-' || v_jour;
  PERFORM pg_advisory_xact_lock(hashtext('salle_reception:' || v_id));
  SELECT data INTO v_existant FROM public.reservations_salle_reception WHERE id = v_id;
  IF v_existant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_deja_reservee', 'empire', v_existant ->> 'empire'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'reserver_salle_reception', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.reservations_salle_reception (id, pays_hote, jour, data)
  VALUES (v_id, v_hote, v_jour, jsonb_build_object('empire', p_empire, 'reservePar', m ->> 'moi'));
  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'paie', v_paie);
END; $function$;

CREATE OR REPLACE FUNCTION public.ambassade_reception_organiser(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_moi text; v_hote text; v_id text; v_resa jsonb; v_paie jsonb;
  v_invites integer; v_did integer; v_dpop integer; v_indice integer; v_pop jsonb;
  v_jour date; v_pav public.pavillon_receptions%ROWTYPE;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_moi := m ->> 'moi'; v_hote := m ->> 'hote';
  IF v_hote = 'soviet' THEN
    -- Novomirsk : la Grande Salle de Réception du Pavillon, réservée aujourd'hui par cet ambassadeur pour son pays.
    v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
    SELECT * INTO v_pav FROM public.pavillon_receptions WHERE jour = v_jour FOR UPDATE;
    IF NOT FOUND OR v_pav.acteur IS DISTINCT FROM v_moi OR v_pav.pays_payeur IS DISTINCT FROM p_empire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'salle_non_reservee'); END IF;
    IF v_pav.reception_donnee_le IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reception_deja_donnee'); END IF;
  ELSE
    v_id := v_hote || '-' || public.jour_de_jeu_pays(v_hote);
    SELECT data INTO v_resa FROM public.reservations_salle_reception WHERE id = v_id FOR UPDATE;
    IF v_resa IS NULL OR v_resa ->> 'empire' IS DISTINCT FROM p_empire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'salle_non_reservee'); END IF;
    IF v_resa ? 'receptionDonnee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reception_deja_donnee'); END IF;
  END IF;
  v_paie := public.payer_ordre(v_moi, 'organiser_reception_diplomatique', 2, 1200);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT count(*) INTO v_invites FROM public.personnages_donnees
   WHERE country = v_hote
     AND current_building = CASE v_hote WHEN 'soviet' THEN 'pavillon-ambassadeurs-novomirsk' ELSE 'quartier-ambassades' END
     AND current_room = 'salle_reception' AND name <> v_moi;
  IF v_invites = 0 THEN v_did := -3; v_dpop := -3;
  ELSE v_did := least(10, v_invites); v_dpop := least(5, v_invites); END IF;
  v_indice := public.indice_diplomatique_varier_interne(p_empire, v_did, 'reception_diplomatique', v_moi);
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, v_dpop, NULL);
  IF v_hote = 'soviet' THEN
    UPDATE public.pavillon_receptions SET reception_donnee_le = now(), invites = v_invites WHERE jour = v_jour;
  ELSE
    UPDATE public.reservations_salle_reception
       SET data = data || jsonb_build_object('receptionDonnee', now(), 'invites', v_invites)
     WHERE id = v_id;
  END IF;
  PERFORM public.annonce_publique_interne(v_hote, CASE WHEN v_invites = 0
    THEN 'DIPLOMATIE : la réception de l''ambassade de ' || public.empire_nom_interne(p_empire) || ' s''est tenue devant une salle vide.'
    ELSE 'DIPLOMATIE : réception donnée à l''ambassade de ' || public.empire_nom_interne(p_empire) || ' (' || v_invites || ' invité' || CASE WHEN v_invites > 1 THEN 's' ELSE '' END || ').' END);
  RETURN jsonb_build_object('ok', true, 'invites', v_invites, 'delta_indice', v_did, 'delta_pop', v_dpop,
                            'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;

-- ambassade_mecenat : inchangée ; elle passe par ambassade_ambassadeur_interne et annonce au pays hôte.

COMMIT;
