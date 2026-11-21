-- CLIMAT — décisions de Fred du 21/11/2026 sur les parades (GAME-DESIGN-CLIMAT-20261121.md, réponses aux questions).
-- • Sels de réhydratation en Sovarka : règle de moitié prix (22 PSK ; 44 FR en Républia, inchangé). Vaut partout où ils se
--   vendent en Sovarka : boutique climat de Pharmanov et pharmacie d'État de Novomirsk.
-- • Port-Sainte-Marie sans quincaillerie : voulu ; la consigne renvoie toujours à Luthécia et Montrouge (rien à changer).
-- • Bidons de carburant aussi au garage de Novomirsk, au prix de la station-service de Krasnov (20) : le groupe électrogène
--   et son carburant au même endroit. La consigne de l'orage le dit (« en vente au même endroit ») quand tous les lieux
--   cités vendent aussi les bidons ; le contrôle des parades le vérifie.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Prix par pays ────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pharmacie_prix_pays_interne(p_cle_maladie text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_cle_maladie = 'coup_de_chaleur' AND p_pays = 'soviet'
              THEN greatest(1, round(public.pharmacie_prix_interne(p_cle_maladie) / 2.0))::integer
              ELSE public.pharmacie_prix_interne(p_cle_maladie) END;
$$;
CREATE OR REPLACE FUNCTION public.climat_prix_pays_interne(p_cle text, p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_cle = 'sels_rehydratation' THEN public.pharmacie_prix_pays_interne('coup_de_chaleur', p_pays)::numeric
              ELSE public.climat_prix_interne(p_cle) END;
$$;
SELECT pg_temp.rp_raccorder('public.boutique_climat_acheter(uuid,text,integer)'::regprocedure,
  $a$v_prix := public.climat_prix_interne(p_cle);$a$,
  $b$v_prix := public.climat_prix_pays_interne(p_cle, b.pays) /* climat_prix_pays_v1 */;$b$, 'climat_prix_pays_v1');
SELECT pg_temp.rp_raccorder('public.boutique_climat_etat()'::regprocedure,
  $a$'prix', public.climat_prix_interne(c)$a$,
  $b$'prix', public.climat_prix_pays_interne(c, b.pays) /* climat_prix_pays_v1 */$b$, 'climat_prix_pays_v1');
SELECT pg_temp.rp_raccorder('public.pharmacie_acheter_interne(text,text,integer)'::regprocedure,
  $a$v_prix := public.pharmacie_prix_interne(m.cle);$a$,
  $b$v_prix := public.pharmacie_prix_pays_interne(m.cle, pv.pays) /* climat_prix_pays_v1 */;$b$, 'climat_prix_pays_v1');
SELECT pg_temp.rp_raccorder('public.pharmacie_etat()'::regprocedure,
  $a$'prix', public.pharmacie_prix_interne(m.cle),$a$,
  $b$'prix', public.pharmacie_prix_pays_interne(m.cle, pv.pays) /* climat_prix_pays_v1 */,$b$, 'climat_prix_pays_v1');

-- ── Bidons au garage de Novomirsk ────────────────────────────────────────────────────────────────
UPDATE public.climat_boutiques SET cles = cles || ARRAY['bidon_carburant']
 WHERE id = 'garage-novomirsk' AND NOT ('bidon_carburant' = ANY (cles));

-- ── Consigne de l'orage : bidons « en vente au même endroit » quand c'est vrai partout où l'on renvoie ──
CREATE OR REPLACE FUNCTION public.climat_bidons_meme_lieu_interne(p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH cites AS (SELECT lv.pays, lv.ville FROM public.climat_lieux_vente lv
                  WHERE lv.cle = 'groupe_electrogene' AND lv.pays = p_pays
                    AND (lv.ville = p_ville OR NOT EXISTS (SELECT 1 FROM public.climat_lieux_vente x
                          WHERE x.cle = 'groupe_electrogene' AND x.pays = p_pays AND x.ville = p_ville)))
  SELECT EXISTS (SELECT 1 FROM cites)
     AND NOT EXISTS (SELECT 1 FROM cites c WHERE NOT EXISTS (SELECT 1 FROM public.climat_boutiques b
           WHERE b.pays = c.pays AND b.ville = c.ville AND 'groupe_electrogene' = ANY (b.cles) AND 'bidon_carburant' = ANY (b.cles)));
$$;
SELECT pg_temp.rp_raccorder('public.climat_consigne_interne(text,text,text)'::regprocedure,
  $a$      || ', avec ' || public.aliments_param_interne('groupe_bidons', 5)::integer || ' bidons de carburant.';$a$,
  $b$      || ', avec ' || public.aliments_param_interne('groupe_bidons', 5)::integer || ' bidons de carburant'
      || CASE WHEN public.climat_bidons_meme_lieu_interne(p_pays, p_ville) THEN ', en vente au même endroit' ELSE '' END || '.' /* climat_bidons_meme_lieu_v1 */;$b$,
  'climat_bidons_meme_lieu_v1');

-- ── Contrôle des parades, complété : bidons là où la consigne dit « au même endroit » ─────────────
CREATE OR REPLACE FUNCTION public.climat_parades_verifier_interne()
RETURNS TABLE (pays text, cle text, probleme text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH vendeurs AS (
    SELECT b.pays, b.ville, k AS cle FROM public.climat_boutiques b, unnest(b.cles) k
    UNION SELECT pv.pays, pv.ville, 'sels_rehydratation' FROM public.pharmacies_points_vente pv
    UNION SELECT pe.pays, pe.ville, 'bouteille_eau' FROM public.climat_points_eau pe WHERE pe.actif
    UNION SELECT e.data->>'country', e.data->>'city', 'bidon_carburant' FROM public.entreprises e WHERE e.data->>'type' = 'station-service'),
  parades AS (SELECT * FROM (VALUES ('orage', 'groupe_electrogene'), ('orage', 'bidon_carburant'), ('crue', 'sac_de_sable'),
                                    ('canicule', 'bouteille_eau'), ('canicule', 'sels_rehydratation')) x(type, cle)),
  citees AS (SELECT DISTINCT c.pays, p.cle FROM public.climat_parametres c JOIN parades p ON p.type = c.type WHERE c.actif)
  SELECT lv.pays, lv.cle, 'lieu cité sans vente réelle : ' || lv.ville || ' (' || lv.chez || ')'
    FROM public.climat_lieux_vente lv
   WHERE NOT EXISTS (SELECT 1 FROM vendeurs v WHERE v.pays = lv.pays AND v.ville = lv.ville AND v.cle = lv.cle)
  UNION ALL
  SELECT ci.pays, ci.cle, 'parade citée en consigne, introuvable dans le pays'
    FROM citees ci WHERE NOT EXISTS (SELECT 1 FROM vendeurs v WHERE v.pays = ci.pays AND v.cle = ci.cle)
  UNION ALL
  -- Sovarka (et Républia) : groupe et bidons au même endroit, comme la consigne l'annonce.
  SELECT lv.pays, 'bidon_carburant', 'bidons absents du lieu du groupe électrogène : ' || lv.ville || ' (' || lv.chez || ')'
    FROM public.climat_lieux_vente lv
   WHERE lv.cle = 'groupe_electrogene'
     AND NOT EXISTS (SELECT 1 FROM vendeurs v WHERE v.pays = lv.pays AND v.ville = lv.ville AND v.cle = 'bidon_carburant');
$$;
REVOKE ALL ON FUNCTION public.climat_parades_verifier_interne(), public.pharmacie_prix_pays_interne(text, text),
  public.climat_prix_pays_interne(text, text), public.climat_bidons_meme_lieu_interne(text, text) FROM PUBLIC, anon, authenticated;

DO $v$ BEGIN
  IF EXISTS (SELECT 1 FROM public.climat_parades_verifier_interne()) THEN
    RAISE EXCEPTION 'parade sans lieu de vente : %', (SELECT string_agg(pays || '/' || cle || ' : ' || probleme, ' ; ') FROM public.climat_parades_verifier_interne());
  END IF;
  -- Moitié prix en Sovarka (22 PSK pour 44 FR au 21/11/2026).
  IF public.climat_prix_pays_interne('sels_rehydratation', 'soviet') <> greatest(1, round(public.climat_prix_pays_interne('sels_rehydratation', 'republic') / 2.0)) THEN
    RAISE EXCEPTION 'prix des sels : % / %', public.climat_prix_pays_interne('sels_rehydratation', 'soviet'), public.climat_prix_pays_interne('sels_rehydratation', 'republic');
  END IF;
END $v$;

COMMIT;
