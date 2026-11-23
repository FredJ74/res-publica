-- NON APPLIQUÉE — à faire valider par Fred avant toute application (pause Supabase).
-- Bloc 3 de la mission « Novomirsk, PNJ, interface et suites des rapports » (Fred, 23/11/2026 ;
-- GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 24 à 28). Rejouable (IF NOT EXISTS, NOT EXISTS, ON CONFLICT).
-- Rien du goulag n'est touché ; aucune donnée de joueur n'est modifiée ni effacée.
--
-- 1. Points 24 et 25 — les deux ordres de pièce disparus quittent le miroir des tarifs : « Acheter une information »
--    (informateur_payer, 0 PA, 0 PSK : on clique désormais sur le PNJ informateur) et « Offrir un verre à l'habitué »
--    (offrir_verre_habitue_krasnov, 0 PA, 0 PSK : bouton « Lui offrir un verre » sur la fiche de l'habitué). Les RPC
--    informateurs_ici / informateur_payer restent les juges (aucune ne lit ces lignes d'ordres_couts, vérifié le 23/11).
-- 2. Point 25 — l'habitué du Bar Sever offre un verre UNE fois par jour (heure de Paris) et par PJ ; le verre compte dans
--    la Santé (maladie_verre_interne : verres_du_jour, sante_alcool_verre_interne, gueule de bois au-delà du seuil). Le
--    serveur décide et mémorise (table pnj_verres_offerts). Réglages MJ dans sante_parametres (groupe « pnj ») :
--      habitue_krasnov_verres_par_jour (1 ; 0 = il n'offre plus) et habitue_krasnov_accueil_heures (3 : délai avant qu'il
--      accueille de nouveau le même PJ en se souvenant de lui).
--    RPC habitue_krasnov_accueillir() : position vérifiée (Bar Sever de Krasnov), rencontre comptée (pnj_social_entrer),
--    puis mode « verre » (verre offert et bu), « souvenir » (déjà servi aujourd'hui, accueil chaleureux) ou rien.
-- 3. Point 26 — PNJ sociaux (relation tenue, rencontres et conversations comptées, règle de jalon inatteignable comme
--    Kouzma et Praskovia : aucune interpellation automatique) : l'habitué, Matveï Starikov (EHPAD de Krasnov) et les
--    habitants des petites maisons (Antonina Merkoulova, Matveï Rybakov, Ignat Lykov, Stepan Kouznetsov ; Dolgor
--    Tsybikova à Starovka). Kouzma Lapchine et Praskovia Pakhomova le sont déjà (20261115120500).
-- 4. Point 28 — Matveï Rybakov, référent chasse et bûcheronnage de Krasnov (pnj_referents ; listes client et banc alignés).
BEGIN;

-- 1. Tarifs des ordres disparus.
DELETE FROM public.ordres_couts WHERE (fn, pa, cost) IN (('informateur_payer', 0, 0), ('offrir_verre_habitue_krasnov', 0, 0));

-- 2. Verre offert par l'habitué.
CREATE TABLE IF NOT EXISTS public.pnj_verres_offerts (
  pnj_id text NOT NULL, joueur text NOT NULL, jour date NOT NULL, n integer NOT NULL DEFAULT 0, le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pnj_id, joueur, jour));
ALTER TABLE public.pnj_verres_offerts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pnj_verres_offerts FROM anon, authenticated;

INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('habitue_krasnov_verres_par_jour', 1, 'pnj', 'Verres offerts par l’habitué du Bar Sever (Krasnov), par PJ et par jour (0 = aucun)'),
  ('habitue_krasnov_accueil_heures', 3, 'pnj', 'Heures avant que l’habitué du Bar Sever accueille de nouveau le même PJ')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.habitue_krasnov_accueillir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; r record; v_social jsonb; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_max integer := greatest(0, public.sante_param('habitue_krasnov_verres_par_jour', 1)::integer);
  v_delai numeric := greatest(0, public.sante_param('habitue_krasnov_accueil_heures', 3));
  v_n integer; v_mode text; v_dernier timestamptz; v_hp integer; /* bloc3_habitue_verre_v1 */
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = a;
  IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  -- La rencontre est comptée comme pour tout PNJ social (pnj_social_relations).
  v_social := public.pnj_social_entrer('habitue_krasnov');
  SELECT * INTO r FROM public.pnj_social_relations WHERE pnj_id = 'habitue_krasnov' AND joueur = a FOR UPDATE;
  SELECT coalesce(n, 0) INTO v_n FROM public.pnj_verres_offerts WHERE pnj_id = 'habitue_krasnov' AND joueur = a AND jour = v_jour FOR UPDATE;
  v_n := coalesce(v_n, 0);
  IF v_n < v_max THEN
    INSERT INTO public.pnj_verres_offerts (pnj_id, joueur, jour, n) VALUES ('habitue_krasnov', a, v_jour, 1)
    ON CONFLICT (pnj_id, joueur, jour) DO UPDATE SET n = public.pnj_verres_offerts.n + 1, le = now();
    PERFORM public.maladie_verre_interne(a);   -- le verre compte dans la Santé (et dans les verres du jour)
    v_mode := 'verre';
  ELSE
    v_dernier := nullif(r.memoire ->> 'habitue_accueil_le', '')::timestamptz;
    IF v_dernier IS NULL OR v_dernier < now() - make_interval(secs => (v_delai * 3600)::double precision) THEN v_mode := 'souvenir'; END IF;
  END IF;
  IF v_mode IS NOT NULL THEN
    UPDATE public.pnj_social_relations SET memoire = memoire || jsonb_build_object('habitue_accueil_le', now())
     WHERE pnj_id = 'habitue_krasnov' AND joueur = a;
  END IF;
  SELECT hp INTO v_hp FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'nom', a, 'rencontres', coalesce(r.rencontres, 1),
    'connu', coalesce(r.rencontres, 1) > 1, 'verres_offerts', v_n + CASE WHEN v_mode = 'verre' THEN 1 ELSE 0 END, 'sante', v_hp);
END $$;
REVOKE ALL ON FUNCTION public.habitue_krasnov_accueillir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.habitue_krasnov_accueillir() TO authenticated;

-- 3. PNJ sociaux (règle de jalon inatteignable : relation tenue, aucune interpellation automatique).
INSERT INTO public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang)
SELECT x.id, x.id || '_sans_interpellation_automatique', 2147483647, NULL, 999 FROM (VALUES
  ('habitue_krasnov'), ('matvei_starikov'), ('antonina_merkoulova'), ('matvei_rybakov'), ('ignat_lykov'),
  ('stepan_kouznetsov'), ('dolgor_tsybikova')) AS x(id)
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = x.id);

-- 4. Référent chasse et bûcheronnage de Krasnov.
INSERT INTO public.pnj_referents (referent_id, domaine, pays)
SELECT 'matvei_rybakov', 'chasse et bûcheronnage — forêt et Exploitation forestière de Krasnov', 'soviet'
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = 'matvei_rybakov');

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn IN ('informateur_payer', 'offrir_verre_habitue_krasnov'))
     OR (SELECT count(DISTINCT pnj_id) FROM public.pnj_social_jalons_regles WHERE pnj_id IN ('habitue_krasnov', 'matvei_starikov',
         'antonina_merkoulova', 'matvei_rybakov', 'ignat_lykov', 'stepan_kouznetsov', 'dolgor_tsybikova')) <> 7
     OR NOT EXISTS (SELECT 1 FROM public.pnj_referents WHERE referent_id = 'matvei_rybakov')
     OR position('bloc3_habitue_verre_v1' IN pg_get_functiondef('public.habitue_krasnov_accueillir()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'bloc3_pnj_habitue_sociaux : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
