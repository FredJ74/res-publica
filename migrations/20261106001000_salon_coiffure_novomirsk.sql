-- Salon de coiffure de Novomirsk (vue 12), decisions de Fred du 06/11/2026
-- (GAME-DESIGN-SALON-COIFFURE.md) :
--   * commerce de services, et d'accessoires non alimentaires choisis par le PJ coiffeur selon la
--     mecanique generale des fonds (types, references, plafond gratuit/premium) ;
--   * la coupe de cheveux : +5 POP, CHA +1 jusqu'a minuit sans cumul, une coupe tous les 3 jours ;
--   * salon tenu par un PNJ (Ludmila Permanentova), local rachetable par un PJ ;
--   * AUCUN PRIX pour l'instant : la logique de prix de Sovarka reste a decider. Sans prix, la
--     coupe est refusee (prix_non_fixe) avant tout debit, et l'ecran l'affiche « Bientot disponible ».
-- Generique : toute entreprise qui declare data.prestations.coupe peut vendre la coupe ; le prix
-- se lit dans data.prestations.coupe.prixVente. Independante de l'ecran.
BEGIN;

-- Derniere coupe de chaque PJ (jour de jeu). Aucune ecriture cliente.
CREATE TABLE IF NOT EXISTS public.salon_coupes (
  acteur text PRIMARY KEY,
  jour_coupe integer NOT NULL,
  coupe_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.salon_coupes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.salon_coupes FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.salon_coupe(p_requete uuid, p_entreprise text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a text := public.mon_personnage(); act text := 'salon:coupe'; par jsonb;
  v jsonb; dt text; v_data jsonb; d record; v_prix numeric; v_jour integer; v_der integer;
  v_now numeric; v_fin numeric; v_eff jsonb; v_cha boolean; v_enc jsonb; v_j jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  par := jsonb_build_object('entreprise', p_entreprise);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
    IF v_data IS NULL OR v_data->'prestations'->'coupe' IS NULL THEN
      v := jsonb_build_object('ok', false, 'raison', 'salon_introuvable');
    ELSE
      SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = a;
      v_prix := (v_data->'prestations'->'coupe'->>'prixVente')::numeric;
      v_jour := public.jour_de_jeu_pays(coalesce(d.country, 'republic'));
      SELECT jour_coupe INTO v_der FROM public.salon_coupes WHERE acteur = a FOR UPDATE;
      IF (d.country, d.current_city, d.current_building)
         IS DISTINCT FROM (v_data->>'country', v_data->>'city', v_data->>'buildingId') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF v_prix IS NULL OR v_prix <= 0 THEN
        v := jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
      ELSIF v_der IS NOT NULL AND v_jour < v_der + 3 THEN
        v := jsonb_build_object('ok', false, 'raison', 'cheveux_pas_repousses',
                                'prochaineCoupeJour', v_der + 3, 'jour', v_jour);
      ELSE
        -- Encaissement commun des prestations (debit du client, taxe locale, caisse, journal).
        v_enc := public.vehicule_encaisser_interne(a, p_entreprise, v_prix, 'Coupe de cheveux');
        IF (v_enc->>'ok')::boolean IS DISTINCT FROM true THEN
          v := v_enc;
        ELSE
          v_j := public.jauges_effet_appliquer_interne(a, 5, 0);
          v_now := extract(epoch FROM clock_timestamp()) * 1000;
          v_fin := extract(epoch FROM ((date_trunc('day', now() AT TIME ZONE 'Europe/Paris') + interval '1 day')
                   AT TIME ZONE 'Europe/Paris')) * 1000;
          SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff
            FROM public.personnages_donnees p, jsonb_array_elements(coalesce(p.effets_actifs, '[]'::jsonb)) e
           WHERE p.name = a AND jsonb_typeof(e) = 'object' AND coalesce((e->>'expireA')::numeric, 0) > v_now;
          v_cha := NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_eff) e WHERE e->>'cle' = 'coupe_cha');
          IF v_cha THEN
            v_eff := v_eff || jsonb_build_array(jsonb_build_object('cle', 'coupe_cha', 'cible', 'pj',
              'deltas', jsonb_build_object('CHA', 1), 'libelle', 'Fraîchement coiffé',
              'poseA', v_now, 'expireA', v_fin));
          END IF;
          UPDATE public.personnages_donnees SET effets_actifs = v_eff WHERE name = a;
          INSERT INTO public.salon_coupes (acteur, jour_coupe, coupe_le) VALUES (a, v_jour, now())
            ON CONFLICT (acteur) DO UPDATE SET jour_coupe = EXCLUDED.jour_coupe, coupe_le = EXCLUDED.coupe_le;
          v := jsonb_build_object('ok', true, 'prix', v_prix, 'pop', 5, 'bonusCha', v_cha,
                 'jauges', v_j->'jauges', 'effets_actifs', v_eff, 'prochaineCoupeJour', v_jour + 3)
               || public.vehicule_inventaire_reponse_interne(a);
        END IF;
      END IF;
    END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;

-- Lecture : le salon du lieu ou je me trouve, son prix de coupe et ma prochaine coupe.
CREATE OR REPLACE FUNCTION public.salon_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_salon jsonb; v_der integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = a;
  SELECT jsonb_build_object('id', e.id, 'proprietaire', e.data->>'proprietaire',
           'prixCoupe', e.data->'prestations'->'coupe'->'prixVente')
    INTO v_salon FROM public.entreprises e
   WHERE e.data->'prestations'->'coupe' IS NOT NULL
     AND (e.data->>'country', e.data->>'city', e.data->>'buildingId') = (d.country, d.current_city, d.current_building)
   LIMIT 1;
  SELECT jour_coupe INTO v_der FROM public.salon_coupes WHERE acteur = a;
  RETURN jsonb_build_object('ok', true, 'salon', v_salon,
    'jour', public.jour_de_jeu_pays(coalesce(d.country, 'republic')),
    'prochaineCoupeJour', CASE WHEN v_der IS NULL THEN NULL ELSE v_der + 3 END);
END $$;

REVOKE ALL ON FUNCTION public.salon_coupe(uuid, text), public.salon_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salon_coupe(uuid, text), public.salon_lire() TO authenticated;

-- Le salon PNJ d'exemple. Prix de coupe volontairement absent (decision de Fred). Un etat deja
-- vivant n'est jamais ecrase.
INSERT INTO public.entreprises (id, data, updated_at) VALUES
  ('salon-soviet-capitale', jsonb_build_object(
     'id', 'salon-soviet-capitale', 'type', 'salon-coiffure', 'country', 'soviet', 'city', 'capitale',
     'buildingId', 'salon-coiffure-novomirsk', 'proprietaire', 'PNJ', 'caisse', 2000, 'historique', '[]'::jsonb,
     'prestations', jsonb_build_object('coupe', jsonb_build_object('prixVente', NULL))), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'salon-coiffure-novomirsk', '["salon_coiffure"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-12', 'salon-coiffure-novomirsk')
ON CONFLICT DO NOTHING;

-- Ordre d'ecran (ouvre la fenetre, gratuit) : connu du miroir des couts.
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'salon_coupe', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = 'salon_coupe' AND o.pa = 0 AND o.cost = 0);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'salon-soviet-capitale' AND data->'prestations'->'coupe' IS NOT NULL)
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE building = 'salon-coiffure-novomirsk')
     OR has_table_privilege('authenticated', 'public.salon_coupes', 'SELECT')
     OR position('cheveux_pas_repousses' IN pg_get_functiondef('public.salon_coupe(uuid,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'salon_coiffure_incomplet';
  END IF;
END $$;

COMMIT;
