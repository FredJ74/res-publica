-- #66 — Fonds et murs des commerces : socle commun (Claude, 01/11/2026).
-- Règles : GAME-DESIGN-FONDS-MURS.md. Indépendante de l'écran (l'ancien écran n'appelle rien ici).
--
-- Titre des murs : murs_titres (id = identifiant de l'entreprise exploitante).
-- Titre du fonds : entreprises.data.proprietaire (inchangé) ; offre d'un PJ dans data.offreVente.
-- Un seul moteur d'achat (immobilier_acheter), idempotent par requête, tout ou rien.

-- ---------------------------------------------------------------------------
-- 1. Données
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.immobilier_baremes (
  country text PRIMARY KEY,
  prix_m2 integer NOT NULL CHECK (prix_m2 > 0)
);
INSERT INTO public.immobilier_baremes (country, prix_m2) VALUES ('republic', 150)
ON CONFLICT (country) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.murs_titres (
  id          text PRIMARY KEY,
  country     text NOT NULL,
  ville       text NOT NULL,
  building_id text NOT NULL,
  type_fonds  text NOT NULL,
  room_id     text,
  libelle     text NOT NULL,
  surface     integer NOT NULL CHECK (surface > 0),
  proprietaire text NOT NULL DEFAULT 'commune',
  offre       jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.immobilier_actes_recus (
  requete    uuid PRIMARY KEY,
  acteur     text NOT NULL,
  titre      text NOT NULL,
  objet      text NOT NULL,
  resultat   jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.immobilier_baremes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.murs_titres            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immobilier_actes_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.immobilier_baremes, public.murs_titres, public.immobilier_actes_recus
  FROM anon, authenticated;
GRANT SELECT ON public.immobilier_baremes, public.murs_titres TO authenticated;
DROP POLICY IF EXISTS immobilier_baremes_lecture ON public.immobilier_baremes;
CREATE POLICY immobilier_baremes_lecture ON public.immobilier_baremes FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS murs_titres_lecture ON public.murs_titres;
CREATE POLICY murs_titres_lecture ON public.murs_titres FOR SELECT TO authenticated USING (true);

-- Surfaces validées par Fred (21/10 pour La Republica, 01/11 pour les autres).
INSERT INTO public.murs_titres (id, country, ville, building_id, type_fonds, room_id, libelle, surface) VALUES
  ('brasserie-republic-capitale-hotel-republica',                  'republic','capitale','hotel-republica',              'brasserie', NULL, 'Hôtel-Restaurant La Républia',               1200),
  ('cafe-republic-ville_b-hotel-mineur',                           'republic','ville_b', 'hotel-mineur',                 'cafe',      NULL, 'Hôtel de la Victoire',                800),
  ('cafe-republic-ville_a-hotel-port-hall_port',                   'republic','ville_a', 'hotel-port',                   'cafe',      'hall_port', 'Hôtel du Port',         800),
  ('cafe-republic-ville_b-cafe-gare-montrouge',                    'republic','ville_b', 'cafe-gare-montrouge',          'cafe',      NULL, 'Café de la Gare',                550),
  ('brasserie-republic-ville_b-brasserie-voyageurs-montrouge',     'republic','ville_b', 'brasserie-voyageurs-montrouge','brasserie', NULL, 'Brasserie des Voyageurs',                550),
  ('cafe-republic-ville_b-cafe-tabac-cheminots-montrouge',         'republic','ville_b', 'cafe-tabac-cheminots-montrouge','cafe',     NULL, 'Café des Cheminots — Bar-Tabac',                550),
  ('bar-republic-ville_a-bar-des-pecheurs-salle_bar',              'republic','ville_a', 'bar-des-pecheurs',             'bar',       'salle_bar', 'Bar des Pêcheurs',         550),
  ('brasserie-republic-ville_a-capitaine-sauvage-salle_principale','republic','ville_a', 'capitaine-sauvage',            'brasserie', 'salle_principale', 'Le Capitaine Sauvage',  550),
  ('armurerie-republic-capitale',                                  'republic','capitale','armurerie',                    'armurerie', NULL, 'Armurerie Martinon',                550),
  ('armurerie-republic-ville_b',                                   'republic','ville_b', 'armurerie',                    'armurerie', NULL, 'Armurerie-Quincaillerie de Montrouge',                550),
  ('armurerie-republic-ville_a',                                   'republic','ville_a', 'chasse-peche-psm',             'armurerie', NULL, 'Maison Le Gall — Chasse et Pêche',                550),
  ('imprimerie-republic-capitale-la-tribune',                      'republic','capitale','la-tribune',                   'imprimerie',NULL, 'L''Autruche Entravée',                700),
  ('imprimerie-republic-ville_b-la-tribune',                       'republic','ville_b', 'la-tribune',                   'imprimerie',NULL, 'Le Cheminot Informé (LCI)',                700),
  ('imprimerie-republic-ville_a-imprimerie-librairie',             'republic','ville_a', 'imprimerie-librairie',         'imprimerie',NULL, 'Imprimerie-Librairie Gutenberg',                700)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Lecture : état d'un titre (moteur sans autorité, injoignable du réseau)
-- ---------------------------------------------------------------------------
-- Rend, pour un titre et un observateur, l'offre des murs, celle du fonds et l'offre conjointe,
-- avec les prix décidés ici. La fin de priorité se décide sur l'heure du serveur : aucun cron.
CREATE OR REPLACE FUNCTION public.immobilier_titre_etat_interne(p_titre text, p_observateur text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  t public.murs_titres%ROWTYPE; e jsonb; v_m2 integer;
  v_ms bigint := (extract(epoch from now())*1000)::bigint;
  v_prop_fonds text; v_prix_fonds numeric; v_fonds_vendable boolean := false; v_fonds_regime text;
  v_sous_compromis boolean := false;
  v_prix_murs numeric; v_murs_vendable boolean := false; v_murs_regime text; v_statut text;
  v_prioritaire text; v_jusque bigint; v_ref numeric;
BEGIN
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT prix_m2 INTO v_m2 FROM public.immobilier_baremes WHERE country = t.country;
  v_ref := CASE WHEN v_m2 IS NULL THEN NULL ELSE t.surface * v_m2 END;

  -- Murs
  IF t.proprietaire = 'commune' THEN
    v_murs_regime := 'reference'; v_prix_murs := v_ref; v_murs_vendable := v_ref IS NOT NULL;
    v_statut := CASE WHEN v_murs_vendable THEN 'disponible' ELSE 'non_en_vente' END;
  ELSIF t.offre IS NOT NULL AND (t.offre->>'prix') IS NOT NULL THEN
    v_murs_regime := 'libre'; v_prix_murs := (t.offre->>'prix')::numeric; v_murs_vendable := true;
    v_prioritaire := t.offre->>'prioritaire';
    v_jusque := (t.offre->>'prioriteJusque')::bigint;
    IF t.offre->>'statut' = 'priorite' AND v_jusque IS NOT NULL AND v_jusque > v_ms THEN
      v_statut := 'priorite';
    ELSE
      v_statut := 'disponible'; v_prioritaire := NULL; v_jusque := NULL;
    END IF;
  ELSE
    v_murs_regime := 'libre'; v_statut := 'non_en_vente';
  END IF;

  -- Fonds
  SELECT data INTO e FROM public.entreprises WHERE id = t.id;
  v_prop_fonds := coalesce(e->>'proprietaire', 'PNJ');
  v_sous_compromis := coalesce((e->>'compromis')::boolean, false)
                      AND coalesce((e->>'compromisExpireAt')::bigint, 0) > v_ms;
  IF v_prop_fonds = 'PNJ' THEN
    v_fonds_regime := 'reference';
    v_prix_fonds := public.entreprise_prix_rachat(coalesce(e, '{}'::jsonb)
                      || jsonb_build_object('type', t.type_fonds, 'buildingId', t.building_id));
    v_fonds_vendable := v_prix_fonds IS NOT NULL AND NOT v_sous_compromis;
  ELSIF e ? 'offreVente' AND (e->'offreVente'->>'prix') IS NOT NULL THEN
    v_fonds_regime := 'libre'; v_prix_fonds := (e->'offreVente'->>'prix')::numeric;
    v_fonds_vendable := NOT v_sous_compromis;
  ELSE
    v_fonds_regime := 'libre';
  END IF;

  RETURN jsonb_build_object(
    'id', t.id, 'country', t.country, 'ville', t.ville, 'buildingId', t.building_id,
    'roomId', t.room_id, 'libelle', t.libelle, 'typeFonds', t.type_fonds, 'surface', t.surface,
    'prixM2', v_m2, 'prixReferenceMurs', v_ref,
    'murs', jsonb_build_object('proprietaire', t.proprietaire, 'regime', v_murs_regime,
              'prix', v_prix_murs, 'vendable', v_murs_vendable, 'statut', v_statut,
              'prioritaire', v_prioritaire, 'prioriteJusque', v_jusque,
              'vendeur', CASE WHEN t.proprietaire = 'commune' THEN 'commune' ELSE t.offre->>'vendeur' END),
    'fonds', jsonb_build_object('proprietaire', v_prop_fonds, 'regime', v_fonds_regime,
              'prix', v_prix_fonds, 'vendable', v_fonds_vendable, 'sousCompromis', v_sous_compromis),
    'ensemble', jsonb_build_object(
              'vendable', v_murs_vendable AND v_fonds_vendable,
              'prix', CASE WHEN v_murs_vendable AND v_fonds_vendable THEN v_prix_murs + v_prix_fonds END),
    'moi', jsonb_build_object(
              'proprioMurs', t.proprietaire = p_observateur,
              'proprioFonds', v_prop_fonds = p_observateur,
              'prioritaire', v_statut = 'priorite' AND v_prioritaire = p_observateur));
END; $function$;

-- Catalogue de l'Office notarial (porte de lecture).
CREATE OR REPLACE FUNCTION public.immobilier_catalogue()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT coalesce(jsonb_agg(public.immobilier_titre_etat_interne(t.id, v_moi) ORDER BY t.ville, t.id), '[]'::jsonb)
    INTO v_res FROM public.murs_titres t WHERE t.country = v_pays;
  RETURN jsonb_build_object('ok', true, 'titres', v_res, 'maintenant', (extract(epoch from now())*1000)::bigint);
END; $function$;

-- ---------------------------------------------------------------------------
-- 3. Mise en vente, retrait, renoncement à la priorité
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.immobilier_mettre_en_vente(p_acteur text, p_titre text, p_objet text, p_prix integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  t public.murs_titres%ROWTYPE; e jsonb; v_exploitant text; v_ms bigint := (extract(epoch from now())*1000)::bigint;
  v_offre jsonb; v_nom text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_objet NOT IN ('murs','fonds') THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_inconnu'); END IF;
  IF p_prix IS NULL OR p_prix <= 0 OR p_prix > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  SELECT data INTO e FROM public.entreprises WHERE id = t.id FOR UPDATE;
  v_nom := t.libelle;

  IF p_objet = 'murs' THEN
    IF t.proprietaire IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
    IF t.offre IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_vente'); END IF;
    v_exploitant := coalesce(e->>'proprietaire', 'PNJ');
    IF v_exploitant <> 'PNJ' AND v_exploitant <> p_acteur THEN
      v_offre := jsonb_build_object('prix', p_prix, 'vendeur', p_acteur, 'deposeeAt', v_ms,
                   'statut', 'priorite', 'prioritaire', v_exploitant, 'prioriteJusque', v_ms + 3*86400000);
      PERFORM public.mail_systeme_poser_interne('Office notarial', v_exploitant,
        'Priorité d''achat des murs que vous exploitez',
        p_acteur || ' met en vente les murs du commerce que vous exploitez (' || v_nom || ') au prix de '
        || p_prix::text || ' FR. Vous avez 3 jours de priorité pour les acheter à ce prix, à l''Office notarial '
        || '(« Fonds et murs des commerces »). Vous pouvez aussi y renoncer. Sans réponse, la vente sera ouverte à tous. '
        || 'Votre exploitation n''est pas affectée par la vente.');
    ELSE
      v_offre := jsonb_build_object('prix', p_prix, 'vendeur', p_acteur, 'deposeeAt', v_ms, 'statut', 'publique');
    END IF;
    UPDATE public.murs_titres SET offre = v_offre, updated_at = now() WHERE id = t.id;
  ELSE
    IF e IS NULL OR coalesce(e->>'proprietaire','PNJ') IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
    IF e ? 'offreVente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_vente'); END IF;
    UPDATE public.entreprises
       SET data = e || jsonb_build_object('offreVente', jsonb_build_object('prix', p_prix, 'vendeur', p_acteur, 'deposeeAt', v_ms)),
           updated_at = now()
     WHERE id = t.id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'titre', public.immobilier_titre_etat_interne(t.id, p_acteur));
END; $function$;

CREATE OR REPLACE FUNCTION public.immobilier_retirer_vente(p_acteur text, p_titre text, p_objet text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE t public.murs_titres%ROWTYPE; e jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF p_objet = 'murs' THEN
    IF t.proprietaire IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
    UPDATE public.murs_titres SET offre = NULL, updated_at = now() WHERE id = t.id;
  ELSIF p_objet = 'fonds' THEN
    SELECT data INTO e FROM public.entreprises WHERE id = t.id FOR UPDATE;
    IF e IS NULL OR coalesce(e->>'proprietaire','PNJ') IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
    UPDATE public.entreprises SET data = e - 'offreVente', updated_at = now() WHERE id = t.id;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_inconnu');
  END IF;
  RETURN jsonb_build_object('ok', true, 'titre', public.immobilier_titre_etat_interne(t.id, p_acteur));
END; $function$;

CREATE OR REPLACE FUNCTION public.immobilier_priorite_renoncer(p_acteur text, p_titre text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE t public.murs_titres%ROWTYPE; v_ms bigint := (extract(epoch from now())*1000)::bigint;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF t.offre IS NULL OR t.offre->>'statut' <> 'priorite' OR (t.offre->>'prioriteJusque')::bigint <= v_ms THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_priorite'); END IF;
  IF t.offre->>'prioritaire' IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_prioritaire'); END IF;
  UPDATE public.murs_titres
     SET offre = (t.offre - 'prioritaire' - 'prioriteJusque') || jsonb_build_object('statut','publique','renonceAt', v_ms),
         updated_at = now()
   WHERE id = t.id;
  PERFORM public.mail_systeme_poser_interne('Office notarial', t.offre->>'vendeur',
    'Renoncement à la priorité',
    p_acteur || ' renonce à sa priorité sur les murs de ' || t.libelle || ' : votre mise en vente est désormais ouverte à tous.');
  RETURN jsonb_build_object('ok', true, 'titre', public.immobilier_titre_etat_interne(t.id, p_acteur));
END; $function$;

-- ---------------------------------------------------------------------------
-- 4. Le moteur d'achat : murs, fonds mis en vente par un PJ, ou les deux
-- ---------------------------------------------------------------------------
-- Tout ou rien : toutes les mutations sont dans un seul bloc ; une erreur annule le bloc entier
-- (paiement, PA, titres) et rend un refus nommé. Rejouer la même requête rend le même verdict.
CREATE OR REPLACE FUNCTION public.immobilier_acheter(p_acteur text, p_titre text, p_objet text,
                                                     p_prix_annonce numeric, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_recu jsonb; t public.murs_titres%ROWTYPE; e jsonb; s jsonb;
  v_murs boolean := p_objet IN ('murs','ensemble'); v_fonds boolean := p_objet IN ('fonds','ensemble');
  v_prix_murs numeric := 0; v_prix_fonds numeric := 0; v_total numeric;
  v_vendeur_murs text; v_vendeur_fonds text; v_caisse text; v_ancien text; v_r jsonb; v_jour integer;
  v_res jsonb; v_etat text; v_msg text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_objet NOT IN ('murs','fonds','ensemble') THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_inconnu'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  SELECT resultat INTO v_recu FROM public.immobilier_actes_recus WHERE requete = p_requete;
  IF FOUND THEN RETURN v_recu || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF v_fonds AND NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = t.id) THEN
    PERFORM public.entreprise_assurer_existence(t.id, t.type_fonds, t.country, t.ville, t.building_id, t.room_id);
  END IF;
  SELECT data INTO e FROM public.entreprises WHERE id = t.id FOR UPDATE;
  s := public.immobilier_titre_etat_interne(t.id, p_acteur);

  IF v_murs THEN
    IF NOT (s#>>'{murs,vendable}')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'murs_pas_en_vente'); END IF;
    IF t.proprietaire = p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_proprietaire'); END IF;
    IF s#>>'{murs,statut}' = 'priorite' AND s#>>'{murs,prioritaire}' IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'priorite_exploitant',
                                'prioriteJusque', (s#>>'{murs,prioriteJusque}')::bigint); END IF;
    v_prix_murs := (s#>>'{murs,prix}')::numeric; v_vendeur_murs := t.proprietaire;
  END IF;
  IF v_fonds THEN
    IF coalesce((s#>>'{fonds,sousCompromis}')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_sous_compromis'); END IF;
    IF NOT (s#>>'{fonds,vendable}')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_pas_en_vente'); END IF;
    IF s#>>'{fonds,proprietaire}' = p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_proprietaire'); END IF;
    -- Un fonds PNJ seul se rachète par le parcours existant (compromis, prêt, acte).
    IF p_objet = 'fonds' AND s#>>'{fonds,proprietaire}' = 'PNJ' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_pnj_par_compromis'); END IF;
    v_prix_fonds := (s#>>'{fonds,prix}')::numeric; v_vendeur_fonds := s#>>'{fonds,proprietaire}';
  END IF;
  v_total := v_prix_murs + v_prix_fonds;
  IF p_prix_annonce IS DISTINCT FROM v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_change', 'prix', v_total); END IF;

  BEGIN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_total) THEN
      RAISE EXCEPTION 'fonds_insuffisants'; END IF;
    v_r := public.payer_ordre(p_acteur, 'officialiser_transaction', 1, 0);
    IF coalesce((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION '%', coalesce(v_r->>'raison', 'paiement_refuse'); END IF;

    SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;

    IF v_murs THEN
      IF v_vendeur_murs = 'commune' THEN
        v_caisse := public.salaire_caisse_de('maire', t.country, t.ville);
        IF v_caisse IS NULL THEN RAISE EXCEPTION 'caisse_mairie_introuvable'; END IF;
        v_ancien := current_setting('rp.caisse_interne', true);
        PERFORM set_config('rp.caisse_interne', 'on', true);
        v_r := public.caisse_institution_mouvement(v_caisse, v_prix_murs, true);
        PERFORM set_config('rp.caisse_interne', coalesce(v_ancien, ''), true);
        IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'caisse_mairie_refusee'; END IF;
      ELSE
        PERFORM public.helvetia_crediter_destination(v_vendeur_murs, v_prix_murs, 'liquide');
        UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_prix_murs WHERE name = v_vendeur_murs;
        IF NOT FOUND THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
      END IF;
      UPDATE public.murs_titres SET proprietaire = p_acteur, offre = NULL, updated_at = now() WHERE id = t.id;
    END IF;

    IF v_fonds THEN
      IF v_vendeur_fonds <> 'PNJ' THEN
        PERFORM public.helvetia_crediter_destination(v_vendeur_fonds, v_prix_fonds, 'liquide');
        UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_prix_fonds WHERE name = v_vendeur_fonds;
        IF NOT FOUND THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
      END IF;
      e := (e - 'offreVente' - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande')
           || jsonb_build_object('proprietaire', p_acteur);
      e := public.entreprise_ajouter_historique(e, 0,
             'Achat du fonds par ' || p_acteur || ' (acte notarié' || CASE WHEN v_murs THEN ', avec les murs' ELSE '' END || ')', v_jour);
      UPDATE public.entreprises SET data = e, updated_at = now() WHERE id = t.id;
    END IF;
  EXCEPTION WHEN others THEN
    GET STACKED DIAGNOSTICS v_etat = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    RETURN jsonb_build_object('ok', false,
      'raison', CASE WHEN v_etat = 'P0001' THEN v_msg ELSE 'erreur_acte' END,
      'detail', CASE WHEN v_etat = 'P0001' THEN NULL ELSE v_etat || ' ' || left(v_msg, 200) END,
      'prix', v_total);
  END;

  -- Courriers aux vendeurs PJ (une notification n'est pas l'autorité de l'acte).
  IF v_murs AND v_vendeur_murs <> 'commune' THEN
    PERFORM public.mail_systeme_poser_interne('Office notarial', v_vendeur_murs, 'Vente des murs conclue',
      p_acteur || ' a acheté les murs de ' || t.libelle || ' pour ' || v_prix_murs::text || ' FR, versés sur votre argent liquide.');
  END IF;
  IF v_fonds AND v_vendeur_fonds <> 'PNJ' THEN
    PERFORM public.mail_systeme_poser_interne('Office notarial', v_vendeur_fonds, 'Vente du fonds conclue',
      p_acteur || ' a acheté le fonds de ' || t.libelle || ' pour ' || v_prix_fonds::text || ' FR, versés sur votre argent liquide.');
  END IF;

  v_res := jsonb_build_object('ok', true, 'objet', p_objet, 'titreId', t.id,
    'prixMurs', v_prix_murs, 'prixFonds', v_prix_fonds, 'total', v_total,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
  INSERT INTO public.immobilier_actes_recus (requete, acteur, titre, objet, resultat)
  VALUES (p_requete, p_acteur, t.id, p_objet, v_res);
  RETURN v_res || jsonb_build_object('titre', public.immobilier_titre_etat_interne(t.id, p_acteur));
END; $function$;

-- ---------------------------------------------------------------------------
-- 5. Droits : les portes au client authentifié, le moteur de lecture injoignable
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.immobilier_titre_etat_interne(text, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.immobilier_catalogue() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.immobilier_mettre_en_vente(text, text, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.immobilier_retirer_vente(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.immobilier_priorite_renoncer(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.immobilier_acheter(text, text, text, numeric, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.immobilier_catalogue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_mettre_en_vente(text, text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_retirer_vente(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_priorite_renoncer(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_acheter(text, text, text, numeric, uuid) TO authenticated;

-- Preuve structurelle (la migration ne fait tourner aucun mécanisme).
DO $preuve$
BEGIN
  IF (SELECT count(*) FROM public.murs_titres WHERE country = 'republic') < 14 THEN
    RAISE EXCEPTION 'murs_titres : les 14 titres de Républia sont attendus'; END IF;
  IF has_function_privilege('authenticated', 'public.immobilier_titre_etat_interne(text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'le moteur de lecture doit rester injoignable'; END IF;
  IF has_table_privilege('authenticated', 'public.murs_titres', 'UPDATE') THEN
    RAISE EXCEPTION 'murs_titres ne doit pas être écrit par le client'; END IF;
END $preuve$;
