-- SOVARKA : BONS D'ETAT (decision de Fred du 09/11/2026 au soir, reponse 1 ; GAME-DESIGN-NOVOMIRSK.md).
-- Les banques de Sovarka (Banque nationale de Novomirsk, banques locales de Starovka et Krasnov) n'ont
-- ni placements prives ni prets. A la place, des bons d'Etat « pour soutenir l'economie de Sovarka » :
-- - motivation purement RP, aucun avantage en jeu ;
-- - rendement fixe a la souscription d'apres l'indice Economie moyen des trois villes : +3 % (economie
--   au plus haut, 100) a -10 % (au plus bas, 0), proportionnel ; un indice non encore persiste vaut 50
--   (valeur de depart du socle) ;
-- - duree 7 jours ; mise +/- rendement rendue a l'echeance, sur le compte de la Banque nationale ;
-- - l'argent va au Tresor de Sovarka (budgets_nationaux.soviet.reserveJour), qui rembourse ; Tresor
--   insuffisant a l'echeance : planche a billets, uniquement pour les bons -- le PJ est rembourse quand
--   meme, mais a -10 % quel que soit le rendement prevu, et le Tresor n'est pas debite ;
-- - pas de plancher ni de plafond de souscription hors l'argent du PJ.
-- L'echeance est traitee par sovarka_bons_etat_passe, appelee par la passe de minuit AVANT
-- sovarka_pouvoir_passe (qui redistribue le Tresor du jour) ; chaque remboursement est revendique dans
-- actes_nocturnes (jamais deux fois).
BEGIN;

CREATE TABLE IF NOT EXISTS public.sovarka_bons_etat (
  id bigserial PRIMARY KEY,
  requete text NOT NULL UNIQUE,
  souscripteur text NOT NULL,
  montant numeric NOT NULL CHECK (montant > 0),
  taux numeric NOT NULL,
  indice_economie numeric NOT NULL,
  ville text NOT NULL,
  souscrit_le timestamptz NOT NULL DEFAULT now(),
  echeance date NOT NULL,
  statut text NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'rembourse')),
  rembourse numeric,
  planche_a_billets boolean,
  rembourse_le timestamptz
);
CREATE INDEX IF NOT EXISTS sovarka_bons_etat_echeance ON public.sovarka_bons_etat (statut, echeance);
CREATE INDEX IF NOT EXISTS sovarka_bons_etat_souscripteur ON public.sovarka_bons_etat (souscripteur);
ALTER TABLE public.sovarka_bons_etat ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_bons_etat FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_bons_etat_id_seq FROM PUBLIC, anon, authenticated;

INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
VALUES ('sovarka_bon_etat_echeance', false, 'Remboursement d''un bon d''État de Sovarka à l''échéance ; un rejeu paierait deux fois.')
ON CONFLICT (mecanisme) DO NOTHING;

-- Taux du jour : -10 % a +3 % selon l'indice Economie moyen des trois villes de Sovarka.
CREATE OR REPLACE FUNCTION public.sovarka_bons_etat_taux_interne()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH v(id) AS (VALUES ('soviet_capitale'), ('soviet_ville_a'), ('soviet_ville_b')),
  ie AS (SELECT least(100, greatest(0, coalesce((i.data->>'ie')::numeric, 50))) AS x
           FROM v LEFT JOIN public.indices_villes i ON i.id = v.id)
  SELECT jsonb_build_object('indice', round(avg(x), 1), 'taux', round(-10 + 13 * avg(x) / 100, 1)) FROM ie;
$$;
REVOKE ALL ON FUNCTION public.sovarka_bons_etat_taux_interne() FROM PUBLIC, anon, authenticated;

-- Lecture : taux du jour et bons du joueur (le guichet ne montre rien d'autre).
CREATE OR REPLACE FUNCTION public.sovarka_bons_etat_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'jour', public.sovarka_bons_etat_taux_interne(),
    'bons', coalesce((SELECT jsonb_agg(jsonb_build_object('montant', b.montant, 'taux', b.taux, 'echeance', b.echeance,
                 'statut', b.statut, 'rembourse', b.rembourse, 'planche_a_billets', b.planche_a_billets,
                 'souscrit_le', b.souscrit_le) ORDER BY b.souscrit_le DESC)
               FROM (SELECT * FROM public.sovarka_bons_etat WHERE souscripteur = a ORDER BY souscrit_le DESC LIMIT 20) b), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_bons_etat_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_bons_etat_lire() TO authenticated;

-- Souscription, au guichet d'une banque de Sovarka.
CREATE OR REPLACE FUNCTION public.sovarka_bon_etat_souscrire(p_requete text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; v_jour jsonb; v_pris numeric; v_tr jsonb; b public.sovarka_bons_etat;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:bon_etat:' || a, 0));
  SELECT * INTO b FROM public.sovarka_bons_etat WHERE requete = p_requete;
  IF FOUND THEN
    IF b.souscripteur <> a THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_etrangere'); END IF;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'montant', b.montant, 'taux', b.taux, 'echeance', b.echeance);
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR NOT (
       (p.current_city = 'capitale' AND p.current_building = 'banque-nationale')
    OR (p.current_city IN ('ville_a', 'ville_b') AND p.current_building = 'banque-locale')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  v_pris := public.argent_debiter_interne(a, p_montant, 'liquide_puis_nationale');
  IF v_pris < p_montant THEN RAISE EXCEPTION USING MESSAGE = 'fonds_insuffisants', ERRCODE = 'P0001'; END IF;
  v_tr := public.fret_tresor_crediter_interne('soviet', p_montant);
  IF (v_tr->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'tresor_sovarka_refuse: %', v_tr; END IF;
  v_jour := public.sovarka_bons_etat_taux_interne();
  INSERT INTO public.sovarka_bons_etat (requete, souscripteur, montant, taux, indice_economie, ville, echeance)
  VALUES (p_requete, a, p_montant, (v_jour->>'taux')::numeric, (v_jour->>'indice')::numeric, p.current_city,
          public.sovarka_jour_paris() + 7)
  RETURNING * INTO b;
  RETURN jsonb_build_object('ok', true, 'montant', b.montant, 'taux', b.taux, 'echeance', b.echeance,
    'attendu', round(b.montant * (1 + b.taux / 100)),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = a),
    'arg', (SELECT arg FROM public.personnages WHERE name = a));
EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM = 'fonds_insuffisants' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  RAISE;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_bon_etat_souscrire(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_bon_etat_souscrire(text, integer) TO authenticated;

-- Echeances, chaque nuit (passe de minuit, avant la redistribution du Tresor).
CREATE OR REPLACE FUNCTION public.sovarka_bons_etat_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE b public.sovarka_bons_etat; v_du numeric; v_res numeric; v_planche boolean; v_n int := 0; v_p int := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR b IN SELECT * FROM public.sovarka_bons_etat WHERE statut = 'en_cours' AND echeance <= public.sovarka_jour_paris()
           ORDER BY souscrit_le FOR UPDATE LOOP
    CONTINUE WHEN NOT public.acte_nocturne_revendiquer('soviet', 'sovarka_bon_etat_echeance', b.id::text, NULL);
    v_du := round(b.montant * (1 + b.taux / 100));
    SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO v_res FROM public.budgets_nationaux WHERE id = 'soviet' FOR UPDATE;
    v_planche := coalesce(v_res, 0) < v_du;
    IF v_planche THEN
      v_du := round(b.montant * 0.9);
      v_p := v_p + 1;
    ELSE
      UPDATE public.budgets_nationaux
         SET data = jsonb_set(data, '{reserveJour}', to_jsonb(v_res - v_du)), updated_at = now()
       WHERE id = 'soviet';
    END IF;
    PERFORM public.argent_crediter_interne(b.souscripteur, v_du, 'nationale');
    UPDATE public.sovarka_bons_etat SET statut = 'rembourse', rembourse = v_du, planche_a_billets = v_planche,
           rembourse_le = now() WHERE id = b.id;
    PERFORM public.mail_systeme_poser_interne('Banque de Sovarka', b.souscripteur,
      'Bon d''État remboursé',
      CASE WHEN v_planche THEN
        'Camarade, votre bon d''État de ' || b.montant || ' PSK arrive à échéance. Le Trésor de Sovarka traverse une '
        || 'période de rigueur patriotique : la Banque a imprimé les billets nécessaires. Vous recevez ' || v_du
        || ' PSK (−10 %) sur votre compte. La Patrie vous remercie de votre sacrifice.'
      ELSE
        'Camarade, votre bon d''État de ' || b.montant || ' PSK arrive à échéance (rendement fixé à ' || b.taux
        || ' %). Le Trésor de Sovarka vous rend ' || v_du || ' PSK sur votre compte. La Patrie vous remercie.'
      END);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rembourses', v_n, 'planche_a_billets', v_p);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_bons_etat_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_bons_etat_passe() TO service_role;

COMMIT;
