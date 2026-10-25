-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025183757 ;
-- retour 'paiement' ajoute ensuite par patch SQL direct (meme jour), recopie ci-dessous.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- BUREAU NATIONAL DE L'EMPLOI -- lot 3 : les annonces des joueurs (GAME-DESIGN-BNE.md, Fred 25/10)
-- ============================================================================
-- DECISIONS DE FRED :
--   - une annonce contient l'intitule, le descriptif, le lieu, le salaire -- rien d'autre -- et
--     l'adresse mail (le nom) du recruteur ;
--   - service public gratuit : 1 PA, affichee 7 jours, sans limite de nombre ;
--   - option payante : parution aussi dans La Tribune de Republia, au prix de l'ordre « Deposer
--     une petite annonce » (30 FR, 3 jours, une seule petite annonce active a la fois) ; L'ARGENT
--     RESTE AU BUREAU, le journal ne touche rien ;
--   - l'embauche, la paie et la suite se reglent entre joueurs : le jeu ne code pas de contrat.
-- Les lieux : les villes du pays, ou « international » (affiche, raccorde aux autres empires plus
-- tard). Tout est decide et enregistre par le serveur. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bne_annonces (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pays        text NOT NULL,
  auteur      text NOT NULL,
  intitule    text NOT NULL CHECK (char_length(intitule) BETWEEN 1 AND 80),
  descriptif  text NOT NULL CHECK (char_length(descriptif) BETWEEN 1 AND 600),
  lieu        text NOT NULL,
  salaire     text NOT NULL CHECK (char_length(salaire) BETWEEN 1 AND 60),
  presse      boolean NOT NULL DEFAULT false,
  statut      text NOT NULL DEFAULT 'active' CHECK (statut IN ('active','retiree')),
  cree_le     timestamptz NOT NULL DEFAULT now(),
  expire_le   timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS bne_annonces_actives ON public.bne_annonces (pays, expire_le) WHERE statut = 'active';
ALTER TABLE public.bne_annonces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bne_annonces FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.bne_annonces IS
  'HG annonces du Bureau de l''Emploi (25/10/2026) : lue et ecrite uniquement par les fonctions bne_annonce*';

-- Couts declares : l'annonce gratuite (ordre visible) et sa variante avec parution presse.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('bne_passer_annonce', 1, 0), ('bne_passer_annonce_presse', 1, 30)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.bne_annonce_publier(p_intitule text, p_descriptif text, p_lieu text,
                                                      p_salaire text, p_presse boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_ville text; v_paie jsonb; v_id uuid;
  v_int text := btrim(coalesce(p_intitule, '')); v_desc text := btrim(coalesce(p_descriptif, ''));
  v_lieu text := btrim(coalesce(p_lieu, '')); v_sal text := btrim(coalesce(p_salaire, ''));
  v_presse boolean := coalesce(p_presse, false); v_caisse text; v_nom_lieu text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;

  IF char_length(v_int) NOT BETWEEN 1 AND 80 THEN RETURN jsonb_build_object('ok', false, 'raison', 'intitule_invalide'); END IF;
  IF char_length(v_desc) NOT BETWEEN 1 AND 600 THEN RETURN jsonb_build_object('ok', false, 'raison', 'descriptif_invalide'); END IF;
  IF char_length(v_sal) NOT BETWEEN 1 AND 60 THEN RETURN jsonb_build_object('ok', false, 'raison', 'salaire_invalide'); END IF;
  IF v_lieu NOT IN ('capitale', 'ville_a', 'ville_b', 'international') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;

  -- La parution presse suit la regle du journal : une seule petite annonce active a la fois.
  IF v_presse AND EXISTS (SELECT 1 FROM public.petites_annonces
                           WHERE auteur = v_moi AND statut = 'active' AND expire_at > now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'annonce_presse_deja_active');
  END IF;

  v_paie := public.payer_ordre(v_moi,
              CASE WHEN v_presse THEN 'bne_passer_annonce_presse' ELSE 'bne_passer_annonce' END,
              1, CASE WHEN v_presse THEN 30 ELSE 0 END);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  INSERT INTO public.bne_annonces (pays, auteur, intitule, descriptif, lieu, salaire, presse, expire_le)
  VALUES (v_pays, v_moi, v_int, v_desc, v_lieu, v_sal, v_presse, now() + interval '7 days')
  RETURNING id INTO v_id;

  IF v_presse THEN
    v_nom_lieu := CASE v_lieu WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                              WHEN 'ville_b' THEN 'Montrouge' ELSE 'à l''international' END;
    INSERT INTO public.petites_annonces (id, country, ville_depot, auteur, categorie, texte,
                                         cout_paye, duree_jours, expire_at, statut)
    VALUES ('annonce-bne-' || replace(v_id::text, '-', ''), v_pays, v_ville, v_moi, 'Emploi',
            left(v_int || ' — ' || v_desc || ' — Lieu : ' || v_nom_lieu || ' — Salaire : ' || v_sal
                 || ' — Contact : ' || v_moi || ' (via le Bureau de l''Emploi)', 900),
            30, 3, now() + interval '3 days', 'active');
    -- L'argent reste au Bureau (decision de Fred) : caisse du Bureau de l'Emploi du pays.
    v_caisse := v_pays || '_bureau-national-emploi';
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_caisse, jsonb_build_object('solde', 30), now())
    ON CONFLICT (id) DO UPDATE
       SET data = coalesce(public.caisses_batiments.data, '{}'::jsonb)
                  || jsonb_build_object('solde', coalesce((public.caisses_batiments.data ->> 'solde')::numeric, 0) + 30),
           updated_at = now();
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'presse', v_presse,
                            'pa', v_paie -> 'pa', 'paiement', v_paie, 'expire_le', now() + interval '7 days');
END; $function$;
REVOKE ALL ON FUNCTION public.bne_annonce_publier(text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_annonce_publier(text, text, text, text, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.bne_annonces_lister()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'annonces', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', a.id, 'auteur', a.auteur, 'intitule', a.intitule,
             'descriptif', a.descriptif, 'lieu', a.lieu, 'salaire', a.salaire, 'presse', a.presse,
             'cree_le', a.cree_le, 'expire_le', a.expire_le, 'de_moi', a.auteur = v_moi)
             ORDER BY a.cree_le DESC)
      FROM public.bne_annonces a
     WHERE a.pays = v_pays AND a.statut = 'active' AND a.expire_le > now()), '[]'::jsonb));
END; $function$;
REVOKE ALL ON FUNCTION public.bne_annonces_lister() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_annonces_lister() TO authenticated;

CREATE OR REPLACE FUNCTION public.bne_annonce_retirer(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.bne_annonces SET statut = 'retiree'
   WHERE id = p_id AND auteur = v_moi AND statut = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'annonce_introuvable'); END IF;
  RETURN jsonb_build_object('ok', true);
END; $function$;
REVOKE ALL ON FUNCTION public.bne_annonce_retirer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_annonce_retirer(uuid) TO authenticated;
