-- Décisions du 26/11/2026 (Claude), bloc C — APPLIQUÉE en production le 26/11/2026 (feu vert de Fred, contrôlée en lecture). Après 20261126100000.
-- DOTATIONS INITIALES DU LANCEMENT (décisions n° 5 et 6 de Fred, 26/11/2026) : à la remise à zéro du 19/12, TOUS les commerces
-- (ceux des PNJ compris ; ceux des joueurs disparaissent avec eux) et TOUTES les caisses publiques (mairies, ministères,
-- Sovarka comme Républia) repartent d'une dotation initiale permettant d'amorcer le jeu, réglable dans la page MJ.
-- Cette migration ne touche à AUCUN solde : elle pose seulement les réglages que lira la procédure de remise à zéro
-- (historique/preparations-lancement/, jamais exécutée avant le jour dit).
-- • lancement_dotations_commerces (pays, type) : caisse, quantité de chaque matière et de chaque produit déjà tenus par le
--   commerce (la liste reste celle du commerce, seules les quantités sont remises). Type « * » : valeur par défaut du pays.
--   Défauts : Républia 2 000 FR, Sovarka 600 PSK ; 10 par matière, 6 par produit.
-- • lancement_dotations_caisses (pays, categorie) : solde de départ de chaque caisse publique ; la catégorie est l'identifiant
--   de la caisse sans le pays ni la ville (lancement_caisse_categorie : « republic_commissariat_ville_a » → « commissariat »).
--   Défauts : Républia = montants arbitrés le 05/10/2026 (seed baseline/seeds/92_mixte/caisses_batiments.sql), ports à 20 000
--   (décision du 16/11) ; Sovarka = mêmes montants × 0,3 (rapport des deux revenus universels, 45 / 150), entrepôts et port à
--   l'identique ; « * » : 200 FR / 60 PSK. Les empires fermés ne sont pas touchés.
-- • Page MJ : admin_dotations_lancement_lire, admin_dotation_commerce_fixer, admin_dotation_caisse_fixer.
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.lancement_dotations_commerces WHERE type = '*';                                   -- 2
--   SELECT montant FROM public.lancement_dotations_caisses WHERE pays = 'republic' AND categorie = 'gouvernement-min_def';  -- 35000
--   SELECT public.lancement_caisse_categorie('republic_commissariat_ville_a');                                   -- commissariat
--   SELECT has_function_privilege('authenticated', 'public.admin_dotation_caisse_fixer(text,text,numeric)', 'EXECUTE');  -- vrai (admin_exiger filtre)
--   SELECT has_table_privilege('authenticated', 'public.lancement_dotations_caisses', 'SELECT');                -- faux
BEGIN;

CREATE TABLE IF NOT EXISTS public.lancement_dotations_commerces (
  pays text NOT NULL, type text NOT NULL,
  caisse numeric NOT NULL CHECK (caisse >= 0), matieres_qte integer NOT NULL CHECK (matieres_qte BETWEEN 0 AND 1000),
  produits_qte integer NOT NULL CHECK (produits_qte BETWEEN 0 AND 1000), maj_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, type));
CREATE TABLE IF NOT EXISTS public.lancement_dotations_caisses (
  pays text NOT NULL, categorie text NOT NULL, montant numeric NOT NULL CHECK (montant >= 0),
  maj_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (pays, categorie));
ALTER TABLE public.lancement_dotations_commerces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lancement_dotations_caisses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lancement_dotations_commerces, public.lancement_dotations_caisses FROM PUBLIC, anon, authenticated;

INSERT INTO public.lancement_dotations_commerces (pays, type, caisse, matieres_qte, produits_qte) VALUES
  ('republic', '*', 2000, 10, 6), ('soviet', '*', 600, 10, 6)
ON CONFLICT (pays, type) DO NOTHING;

INSERT INTO public.lancement_dotations_caisses (pays, categorie, montant) VALUES
  ('republic', '*', 200), ('republic', 'agence-grobras-securite', 0), ('republic', 'assemblee', 5000), ('republic', 'caserne-militaire', 0),
  ('republic', 'centre-multinodal-luthecia', 200), ('republic', 'centre-multinodal-montrouge', 200), ('republic', 'centre-multinodal-port-sainte-marie', 200),
  ('republic', 'commissariat', 200), ('republic', 'dispensaire', 200), ('republic', 'douane', 0), ('republic', 'entrepot', 5000),
  ('republic', 'gouvernement-min_ae', 10000), ('republic', 'gouvernement-min_def', 35000), ('republic', 'gouvernement-min_fin', 10000),
  ('republic', 'gouvernement-min_info', 10000), ('republic', 'gouvernement-min_int', 10000), ('republic', 'gouvernement-min_just', 10000),
  ('republic', 'gouvernement-pm', 10000), ('republic', 'hotel', 200), ('republic', 'mairie', 5000), ('republic', 'mairie-capitale', 5000),
  ('republic', 'marche', 200), ('republic', 'office-notarial', 200), ('republic', 'palais-gouvernement', 0), ('republic', 'palais-presidentiel', 10000),
  ('republic', 'port-sainte-marie', 20000), ('republic', 'qhs-prison', 200), ('republic', 'reserve-nationale', 200), ('republic', 'stade', 200),
  ('republic', 'tribunal', 200),
  ('soviet', '*', 60), ('soviet', 'assemblee', 1500), ('soviet', 'caserne-militaire', 0), ('soviet', 'commissariat', 60), ('soviet', 'dispensaire', 60),
  ('soviet', 'entrepot', 5000), ('soviet', 'gouvernement-min_ae', 3000), ('soviet', 'gouvernement-min_def', 10500), ('soviet', 'gouvernement-min_fin', 3000),
  ('soviet', 'gouvernement-min_info', 3000), ('soviet', 'gouvernement-min_int', 3000), ('soviet', 'gouvernement-min_just', 3000),
  ('soviet', 'gouvernement-pm', 3000), ('soviet', 'hotel', 60), ('soviet', 'mairie', 1500), ('soviet', 'mairie-capitale', 1500), ('soviet', 'marche', 60),
  ('soviet', 'office-notarial', 60), ('soviet', 'palais-gouvernement', 0), ('soviet', 'palais-presidentiel', 3000), ('soviet', 'port-starovka', 20000),
  ('soviet', 'qhs-prison', 60), ('soviet', 'stade', 60), ('soviet', 'tribunal', 60)
ON CONFLICT (pays, categorie) DO NOTHING;

-- Catégorie d'une caisse : son identifiant sans le pays ni la ville.
CREATE OR REPLACE FUNCTION public.lancement_caisse_categorie(p_id text)
 RETURNS text LANGUAGE sql IMMUTABLE AS $function$
  SELECT regexp_replace(substr(p_id, length(split_part(p_id, '_', 1)) + 2), '_(capitale|ville_a|ville_b)$', '') /* dotations_lancement_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.admin_dotations_lancement_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'commerces', (SELECT coalesce(jsonb_agg(to_jsonb(c) - 'maj_le' ORDER BY c.pays, c.type), '[]'::jsonb) FROM public.lancement_dotations_commerces c),
    'types_commerces', (SELECT coalesce(jsonb_agg(DISTINCT e.data ->> 'type'), '[]'::jsonb) FROM public.entreprises e WHERE e.data ->> 'type' IS NOT NULL),
    'caisses', (SELECT coalesce(jsonb_agg(to_jsonb(c) - 'maj_le' ORDER BY c.pays, c.categorie), '[]'::jsonb) FROM public.lancement_dotations_caisses c));
END $function$;

CREATE OR REPLACE FUNCTION public.admin_dotation_commerce_fixer(p_pays text, p_type text, p_caisse numeric, p_matieres integer, p_produits integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_pays NOT IN ('republic', 'soviet') OR coalesce(btrim(p_type), '') = '' OR length(p_type) > 60 THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_caisse IS NULL AND p_matieres IS NULL AND p_produits IS NULL THEN
    IF p_type = '*' THEN RETURN jsonb_build_object('ok', false, 'raison', 'defaut_obligatoire'); END IF;
    DELETE FROM public.lancement_dotations_commerces WHERE pays = p_pays AND type = p_type;   -- retour à la valeur par défaut
  ELSE
    IF p_caisse IS NULL OR p_caisse < 0 OR p_caisse > 10000000 OR p_matieres IS NULL OR p_matieres NOT BETWEEN 0 AND 1000
       OR p_produits IS NULL OR p_produits NOT BETWEEN 0 AND 1000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
    INSERT INTO public.lancement_dotations_commerces (pays, type, caisse, matieres_qte, produits_qte) VALUES (p_pays, p_type, p_caisse, p_matieres, p_produits)
    ON CONFLICT (pays, type) DO UPDATE SET caisse = EXCLUDED.caisse, matieres_qte = EXCLUDED.matieres_qte, produits_qte = EXCLUDED.produits_qte, maj_le = now();
  END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'dotation_commerce', jsonb_build_object('pays', p_pays, 'type', p_type, 'caisse', p_caisse, 'matieres', p_matieres, 'produits', p_produits), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true); /* dotations_lancement_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_dotation_caisse_fixer(p_pays text, p_categorie text, p_montant numeric)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_pays NOT IN ('republic', 'soviet') OR coalesce(btrim(p_categorie), '') = '' OR length(p_categorie) > 80 THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_montant IS NULL THEN
    IF p_categorie = '*' THEN RETURN jsonb_build_object('ok', false, 'raison', 'defaut_obligatoire'); END IF;
    DELETE FROM public.lancement_dotations_caisses WHERE pays = p_pays AND categorie = p_categorie;
  ELSE
    IF p_montant < 0 OR p_montant > 100000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
    INSERT INTO public.lancement_dotations_caisses (pays, categorie, montant) VALUES (p_pays, p_categorie, p_montant)
    ON CONFLICT (pays, categorie) DO UPDATE SET montant = EXCLUDED.montant, maj_le = now();
  END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'dotation_caisse', jsonb_build_object('pays', p_pays, 'categorie', p_categorie, 'montant', p_montant), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true); /* dotations_lancement_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.admin_dotations_lancement_lire(), public.admin_dotation_commerce_fixer(text, text, numeric, integer, integer),
  public.admin_dotation_caisse_fixer(text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dotations_lancement_lire(), public.admin_dotation_commerce_fixer(text, text, numeric, integer, integer),
  public.admin_dotation_caisse_fixer(text, text, numeric) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
