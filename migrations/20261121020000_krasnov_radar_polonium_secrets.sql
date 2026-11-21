-- LOT DE KRASNOV (1re partie), point 8 (Fred, 20/11/2026) : le colonel Gleb Voronov vend le polonium sous le manteau.
--  • Secret « colonel_polonium », attaché au personnage et acquis définitivement (table personnages_secrets) ; l'ordre
--    du colonel reste caché tant que le PJ ne l'a pas.
--  • Sources : l'habitué du bar de Krasnov (offrir un verre, 1 PA + 5 PSK ; il parle selon le palier d'informateur du PJ :
--    aucun 10 %, palier 1 25 %, palier 2 50 %, palier 3 ou 4 toujours) ; Kalachnikov à Novomirsk (toujours) ; Ganbaatar
--    Tsybikov à Starovka refuse, indigné (écran seul).
--  • Achat : phrase de passe « Demander au colonel des nouvelles de notre ami de Luthécia » ; 2 PA ; 50 % de réussite ;
--    réussite : 150 PSK et la fiole de polonium ; échec : « Je ne connais personne à Luthécia, camarade » (seuls les PA
--    sont perdus) ; échec critique (jet 98-100) : dénonciation, une trace exploitable contre l'acheteur seulement.
--  • Carnet privé « Contacts et secrets » : secrets_lire() ne rend que les secrets du joueur.
-- Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.personnages_secrets (
  personnage text NOT NULL, cle text NOT NULL, source text NOT NULL, acquis_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (personnage, cle));
ALTER TABLE public.personnages_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.personnages_secrets FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.secret_fiche_interne(p_cle text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_cle
    WHEN 'colonel_polonium' THEN jsonb_build_object('titre', 'Colonel Gleb Voronov — station radar de Krasnov',
      'texte', 'Vend du polonium sous le manteau. Phrase de passe : « Demander au colonel des nouvelles de notre ami de Luthécia ».')
  END;
$$;

CREATE OR REPLACE FUNCTION public.secrets_lire()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'secrets', coalesce(jsonb_agg(jsonb_build_object('cle', s.cle, 'source', s.source,
           'acquis_le', s.acquis_le) || coalesce(public.secret_fiche_interne(s.cle), '{}'::jsonb) ORDER BY s.acquis_le), '[]'::jsonb))
    FROM public.personnages_secrets s WHERE s.personnage = public.mon_personnage();
$$;
REVOKE ALL ON FUNCTION public.secrets_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.secrets_lire() TO authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT v.f, v.pa, v.c FROM (VALUES ('offrir_verre_habitue_krasnov', 1, 5), ('demander_fournisseur_kalachnikov', 1, 0),
  ('acheter_polonium_colonel', 2, 0), ('polonium_colonel_paiement', 0, 150)) v(f, pa, c)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v.f);

-- Sources du secret (habitué du bar Sever de Krasnov, Kalachnikov à Novomirsk).
CREATE OR REPLACE FUNCTION public.secret_source_interne(p_acteur text, p_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_paie jsonb; v_niveau integer; v_chance integer; v_appris boolean; v_deja boolean;
BEGIN
  SELECT country, current_city, current_building, informateurs INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF p_source = 'habitue_krasnov' THEN
    IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    v_paie := public.payer_ordre(p_acteur, 'offrir_verre_habitue_krasnov', 1, 5);
  ELSIF p_source = 'kalachnikov' THEN
    IF (p.country, p.current_city) IS DISTINCT FROM ('soviet', 'capitale') OR p.current_building IS DISTINCT FROM 'armurerie' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    v_paie := public.payer_ordre(p_acteur, 'demander_fournisseur_kalachnikov', 1, 0);
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'source_inconnue'); END IF;
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_deja := EXISTS (SELECT 1 FROM public.personnages_secrets WHERE personnage = p_acteur AND cle = 'colonel_polonium');
  IF p_source = 'kalachnikov' THEN v_appris := true;
  ELSE
    SELECT coalesce(max((i ->> 'niveau')::integer), 0) INTO v_niveau
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.informateurs) = 'array' THEN p.informateurs ELSE '[]'::jsonb END) i
     WHERE (i ->> 'niveau') ~ '^[0-9]+$';
    v_chance := CASE WHEN v_niveau >= 3 THEN 100 WHEN v_niveau = 2 THEN 50 WHEN v_niveau = 1 THEN 25 ELSE 10 END;
    v_appris := floor(random() * 100)::integer < v_chance;
  END IF;
  IF v_appris AND NOT v_deja THEN
    INSERT INTO public.personnages_secrets (personnage, cle, source) VALUES (p_acteur, 'colonel_polonium', p_source) ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('ok', true, 'source', p_source, 'appris', v_appris, 'deja', v_deja, 'pa', v_paie -> 'pa',
    'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg', 'secret', CASE WHEN v_appris THEN public.secret_fiche_interne('colonel_polonium') END);
END $$;
REVOKE ALL ON FUNCTION public.secret_source_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.secret_source_ecouter(p_requete uuid, p_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('source', p_source); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'secret_source_ecouter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.secret_source_interne(a, p_source);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'secret_source_ecouter', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.secret_source_ecouter(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.secret_source_ecouter(uuid, text) TO authenticated;

-- Achat chez le colonel (station radar de Krasnov).
CREATE OR REPLACE FUNCTION public.polonium_colonel_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_paie jsonb; v_prix jsonb; v_roll integer; v_objet jsonb; v_dep jsonb;
BEGIN
  SELECT country, current_city, current_building, inventory INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'station-radar-krasnov') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_secrets WHERE personnage = p_acteur AND cle = 'colonel_polonium') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'secret_inconnu'); END IF;
  IF public.inventaire_place_restante(coalesce(p.inventory, '[]'::jsonb)) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  IF (SELECT coalesce(d.liquide, 0) + coalesce((SELECT b.solde FROM public.comptes_bancaires b WHERE b.personnage = d.name AND b.banque = 'nationale'), 0)
        FROM public.personnages_donnees d WHERE d.name = p_acteur) < 150 THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', 150); END IF;
  v_paie := public.payer_ordre(p_acteur, 'acheter_polonium_colonel', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > 50 THEN
    IF v_roll >= 98 THEN
      PERFORM public.crime_tracer_interne(p_acteur, 'acheter_polonium', 'station radar de Krasnov');
      PERFORM public.crime_detecter_interne(p_acteur, 'acheter_polonium', false);
    END IF;
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'denonce', v_roll >= 98, 'jet', v_roll, 'pa', v_paie -> 'pa');
  END IF;
  v_prix := public.payer_ordre(p_acteur, 'polonium_colonel_paiement', 0, 150);
  IF coalesce((v_prix ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'polonium_colonel: paiement refusé %', v_prix; END IF;
  SELECT m.objet INTO v_objet FROM public.objets_modeles m WHERE m.id = 'poison:polonium';
  v_dep := public.inventaire_deposer_interne(p_acteur, v_objet);
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'polonium_colonel: dépôt refusé'; END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'jet', v_roll, 'paye', 150, 'pa', v_prix -> 'pa',
    'liquide', v_prix -> 'liquide', 'arg', v_prix -> 'arg');
END $$;
REVOKE ALL ON FUNCTION public.polonium_colonel_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.polonium_colonel_acheter(p_requete uuid, p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb := '{}'::jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'polonium_colonel_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.polonium_colonel_interne(p_acteur);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'polonium_colonel_acheter', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.polonium_colonel_acheter(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.polonium_colonel_acheter(uuid, text) TO authenticated;

COMMIT;
