-- Mission de fin de soirée du 25/11/2026 (Claude), point 2.4, revue le 26/11 (décision n° 2 de Fred) — NON APPLIQUÉE.
-- Après 20261125700000 (premium, appliquée).
-- PUBLICITÉS DE JOUEURS (décision de Fred, 26/11/2026) : premium ponctuel, on vend une CAMPAGNE (une seule génération
-- d'image, rediffusée). Deux durées au choix, 5 et 10 jours, prix DÉGRESSIF ; durées et prix réglables dans la page MJ.
-- Mêmes règles pour tous les supports (rue, avant le film du cinéma de Montrouge, presse) ; les formules « 5 / 10
-- parutions » de l'atelier de presse disparaissent.
-- • Réglages MJ (premium_parametres) : publicite_duree_courte (5), publicite_duree_longue (10), 1 à 60, courte < longue
--   (premium_admin_parametre_fixer, réécrite). L'ancien réglage unique publicite_joueur_duree_jours n'est plus lu.
-- • Produits (premium_produits, prix NULL tant que le MJ ne les fixe pas) : campagne_publicite_courte et
--   campagne_publicite_longue, valables pour n'importe quel support. Les anciens crédits par support
--   (credit_publicite_presse / rue / cinema) sont retirés s'ils n'ont jamais servi. Prix dégressif tenu par
--   premium_admin_prix_fixer : le prix par jour de la campagne longue doit rester inférieur à celui de la courte.
-- • Rue et cinéma : publicite_joueur_creer(p_support, p_objet, p_titre, p_texte, p_duree DEFAULT 'courte') remplace la
--   version à quatre arguments (mêmes appels nommés acceptés). Droit d'option, sinon une campagne de la durée choisie.
-- • Presse : publicite_premium_creer_beta (réécrite, marque presse_campagne_v1) : p_formule = 'courte' / 'longue'
--   ('cinq' / 'dix' acceptés comme courte / longue) ; nb_parutions = durée de la campagne en jours ; une campagne de
--   presse à la fois par compte. La fonction publicite-premium programme la campagne sur nb_parutions jours (à
--   redéployer après cette migration).
-- Sans cette migration : comportement actuel (une campagne de 5 ou 10 parutions en presse, 7 jours en rue).
--
-- Contrôles en lecture après application :
--   SELECT string_agg(cle || '=' || valeur, ',' ORDER BY cle) FROM public.premium_parametres WHERE cle LIKE 'publicite_duree_%';   -- publicite_duree_courte=5,publicite_duree_longue=10
--   SELECT count(*) FROM public.premium_produits WHERE produit IN ('campagne_publicite_courte', 'campagne_publicite_longue') AND prix_centimes IS NULL;  -- 2
--   SELECT position('presse_campagne_v1' in pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) > 0;  -- vrai
--   SELECT position('publicite_duree_v1' in pg_get_functiondef('public.publicite_joueur_creer(text,text,text,text,text)'::regprocedure)) > 0;     -- vrai
--   SELECT to_regprocedure('public.publicite_joueur_creer(text,text,text,text)') IS NULL;                                                         -- vrai
--   SELECT position('nb_parutions' in pg_get_constraintdef(oid)) > 0 FROM pg_constraint WHERE conname = 'programmation_payee';                     -- vrai
--   SELECT position('prix_degressif_v1' in pg_get_functiondef('public.premium_admin_prix_fixer(text,integer)'::regprocedure)) > 0;               -- vrai
BEGIN;

-- 1. Réglages et produits.
INSERT INTO public.premium_parametres (cle, valeur) VALUES ('publicite_duree_courte', '5'), ('publicite_duree_longue', '10')
ON CONFLICT (cle) DO NOTHING;
INSERT INTO public.premium_produits (produit, nature, libelle) VALUES
  ('campagne_publicite_courte', 'unite', 'Campagne de publicité courte (rue, cinéma ou presse)'),
  ('campagne_publicite_longue', 'unite', 'Campagne de publicité longue (rue, cinéma ou presse)')
ON CONFLICT (produit) DO NOTHING;
DELETE FROM public.premium_produits p
 WHERE p.produit IN ('credit_publicite_presse', 'credit_publicite_rue', 'credit_publicite_cinema')
   AND NOT EXISTS (SELECT 1 FROM public.premium_droits d WHERE d.produit = p.produit)
   AND NOT EXISTS (SELECT 1 FROM public.premium_achats a WHERE a.produit = p.produit);

-- Durée en jours d'une campagne ('courte' / 'longue' ; 'cinq' / 'dix' : anciennes valeurs de l'écran de presse).
CREATE OR REPLACE FUNCTION public.premium_publicite_duree_interne(p_choix text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1, least(60, coalesce(nullif(public.premium_param_interne(
           CASE WHEN p_choix IN ('longue', 'dix') THEN 'publicite_duree_longue' ELSE 'publicite_duree_courte' END,
           CASE WHEN p_choix IN ('longue', 'dix') THEN '10' ELSE '5' END), '')::integer,
           CASE WHEN p_choix IN ('longue', 'dix') THEN 10 ELSE 5 END))) /* publicite_duree_v1 */
$function$;
CREATE OR REPLACE FUNCTION public.premium_publicite_choix_interne(p_choix text)
 RETURNS text LANGUAGE sql IMMUTABLE AS $function$ SELECT CASE WHEN p_choix IN ('longue', 'dix') THEN 'longue' ELSE 'courte' END $function$;

-- 2. Réglages MJ : les deux durées (courte < longue).
CREATE OR REPLACE FUNCTION public.premium_admin_parametre_fixer(p_cle text, p_valeur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_cle IN ('beta_tout_gratuit', 'pub_externe_active') AND p_valeur NOT IN ('0', '1') THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  IF p_cle IN ('publicite_duree_courte', 'publicite_duree_longue') AND (p_valeur !~ '^[0-9]{1,2}$' OR p_valeur::integer NOT BETWEEN 1 AND 60) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  IF p_cle = 'publicite_duree_courte' AND p_valeur::integer >= public.premium_publicite_duree_interne('longue') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'courte_doit_rester_plus_courte'); END IF;
  IF p_cle = 'publicite_duree_longue' AND p_valeur::integer <= public.premium_publicite_duree_interne('courte') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'longue_doit_rester_plus_longue'); END IF;
  IF p_cle NOT IN ('beta_tout_gratuit', 'pub_externe_active', 'publicite_duree_courte', 'publicite_duree_longue') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reglage_inconnu'); END IF;
  INSERT INTO public.premium_parametres (cle, valeur, maj_le) VALUES (p_cle, p_valeur, now())
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur, maj_le = now();
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'premium_parametre', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true); /* publicite_duree_v1 */
END $function$;

-- 3. Prix MJ : plancher de 2 €, et prix dégressif des campagnes (le jour de la longue coûte moins que celui de la courte).
CREATE OR REPLACE FUNCTION public.premium_admin_prix_fixer(p_produit text, p_centimes integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_autre integer; v_dc integer := public.premium_publicite_duree_interne('courte'); v_dl integer := public.premium_publicite_duree_interne('longue');
BEGIN
  PERFORM public.admin_exiger();
  IF p_centimes IS NOT NULL AND p_centimes < 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inferieur_minimum', 'minimum_centimes', 200); END IF;
  IF p_centimes IS NOT NULL AND p_produit IN ('campagne_publicite_courte', 'campagne_publicite_longue') THEN
    SELECT prix_centimes INTO v_autre FROM public.premium_produits
     WHERE produit = CASE WHEN p_produit = 'campagne_publicite_courte' THEN 'campagne_publicite_longue' ELSE 'campagne_publicite_courte' END;
    IF v_autre IS NOT NULL AND (
         (p_produit = 'campagne_publicite_longue' AND (p_centimes::numeric / v_dl >= v_autre::numeric / v_dc OR p_centimes <= v_autre))
      OR (p_produit = 'campagne_publicite_courte' AND (v_autre::numeric / v_dl >= p_centimes::numeric / v_dc OR v_autre <= p_centimes))) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_degressif'); END IF; /* prix_degressif_v1 */
  END IF;
  UPDATE public.premium_produits SET prix_centimes = p_centimes, maj_le = now() WHERE produit = p_produit;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'premium_prix', jsonb_build_object('produit', p_produit, 'centimes', p_centimes), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'prix_centimes', p_centimes);
END $function$;

-- 4. Rue et cinéma : la durée choisie.
DROP FUNCTION IF EXISTS public.publicite_joueur_creer(text, text, text, text);
CREATE OR REPLACE FUNCTION public.publicite_joueur_creer(p_support text, p_objet text, p_titre text, p_texte text, p_duree text DEFAULT 'courte')
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); a text := public.mon_personnage(); d record; v_titre text := public.publicite_joueur_texte_interne(p_titre, 60);
        v_texte text := public.publicite_joueur_texte_interne(p_texte, 280); v_jour date := public.premium_jour_interne();
        v_choix text := public.premium_publicite_choix_interne(p_duree); v_duree integer := public.premium_publicite_duree_interne(p_duree);
        v_pays text; v_ville text; v_id uuid; v_src text;
BEGIN
  IF u IS NULL OR a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_support NOT IN ('rue', 'cinema') THEN RETURN jsonb_build_object('ok', false, 'raison', 'support_invalide'); END IF;
  IF p_objet NOT IN ('commerce', 'cause') THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide'); END IF;
  IF coalesce(p_duree, 'courte') NOT IN ('courte', 'longue') THEN RETURN jsonb_build_object('ok', false, 'raison', 'duree_invalide'); END IF;
  IF length(v_titre) < 3 OR length(v_texte) < 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_trop_court'); END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = a;
  IF p_support = 'cinema' THEN v_pays := 'republic'; v_ville := 'ville_b';
  ELSE v_pays := d.country; v_ville := d.current_city; END IF;
  IF v_pays IS NULL OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_inconnu'); END IF;
  IF EXISTS (SELECT 1 FROM public.publicites_joueurs WHERE user_id = u AND support = p_support AND statut = 'active' AND fin >= v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'campagne_deja_en_cours'); END IF;
  v_src := public.premium_option_source_interne(u, 'publicite_joueur', NULL);
  IF v_src IS NULL AND NOT public.premium_unite_utiliser_interne(u, 'campagne_publicite_' || v_choix, p_support) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_premium_requise', 'produit', 'campagne_publicite_' || v_choix); END IF;
  INSERT INTO public.publicites_joueurs (user_id, personnage, support, pays, ville, objet, titre, texte, debut, fin)
  VALUES (u, a, p_support, v_pays, v_ville, p_objet, v_titre, v_texte, v_jour, v_jour + v_duree - 1) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'debut', v_jour, 'fin', v_jour + v_duree - 1, 'ville', v_ville,
    'duree', v_choix, 'jours', v_duree); /* premium_socle_v1 */ /* publicite_duree_v1 */
END $function$;

-- 5. Presse : même modèle (une campagne à la fois, durée courte ou longue en jours).
ALTER TABLE public.publicites_premium_presse DROP CONSTRAINT IF EXISTS publicites_premium_presse_formule_check;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_formule_check
  CHECK (formule IN ('cinq', 'dix', 'campagne', 'courte', 'longue')) NOT VALID;
ALTER TABLE public.publicites_premium_presse VALIDATE CONSTRAINT publicites_premium_presse_formule_check;
ALTER TABLE public.publicites_premium_presse DROP CONSTRAINT IF EXISTS publicites_premium_presse_nb_parutions_check;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_nb_parutions_check
  CHECK (nb_parutions IS NULL OR nb_parutions BETWEEN 1 AND 60) NOT VALID;
ALTER TABLE public.publicites_premium_presse VALIDATE CONSTRAINT publicites_premium_presse_nb_parutions_check;
ALTER TABLE public.publicites_premium_presse DROP CONSTRAINT IF EXISTS programmation_payee;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT programmation_payee CHECK (
  etat NOT IN ('programmee', 'terminee')
  OR ((paiement_confirme_le IS NOT NULL OR mode_beta_gratuit) AND image_path IS NOT NULL AND premiere_parution IS NOT NULL
      AND derniere_parution = premiere_parution
          + coalesce(nb_parutions, CASE WHEN formule = 'cinq' THEN 5 WHEN formule = 'dix' THEN 10 END) - 1)) NOT VALID;
ALTER TABLE public.publicites_premium_presse VALIDATE CONSTRAINT programmation_payee;

DO $garde$
BEGIN
  IF position('presse_campagne_v1' IN pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) = 0
     AND position('premium_socle_v1' IN pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'publicite_premium_creer_beta : version de production inattendue (marque premium_socle_v1 absente)';
  END IF;
END $garde$;

CREATE OR REPLACE FUNCTION public.publicite_premium_creer_beta(p_personnage text, p_formule text, p_instructions text, p_assistance boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid; v_choix text := public.premium_publicite_choix_interne(p_formule);
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Session requise'; END IF;
 IF coalesce(p_formule, '') NOT IN ('courte', 'longue', 'cinq', 'dix') THEN RAISE EXCEPTION 'Durée invalide'; END IF;
 IF length(trim(coalesce(p_instructions,''))) < 10 OR length(p_instructions)>1500 THEN RAISE EXCEPTION 'Description invalide'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;
 IF EXISTS (SELECT 1 FROM public.publicites_premium_presse x WHERE x.acheteur_user_id = auth.uid() AND x.retiree_le IS NULL
       AND (x.etat IN ('brouillon', 'paiement_en_attente', 'payee', 'en_generation', 'apercu', 'validee')
            OR (x.etat = 'programmee' AND x.derniere_parution >= (now() AT TIME ZONE 'Europe/Paris')::date))) THEN
   RAISE EXCEPTION 'Campagne de presse déjà en cours'; END IF;
 IF public.premium_option_source_interne(auth.uid(), 'publicite_joueur', NULL) IS NULL
    AND NOT public.premium_unite_utiliser_interne(auth.uid(), 'campagne_publicite_' || v_choix, 'presse') THEN
   RAISE EXCEPTION 'Option premium requise'; END IF; /* premium_socle_v1 */
 INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,nb_parutions,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,v_choix,public.premium_publicite_duree_interne(v_choix),0,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon')
 RETURNING id INTO v_id;
 RETURN v_id; /* presse_campagne_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.premium_publicite_duree_interne(text), public.premium_publicite_choix_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publicite_joueur_creer(text, text, text, text, text), public.publicite_premium_creer_beta(text, text, text, boolean),
  public.premium_admin_parametre_fixer(text, text), public.premium_admin_prix_fixer(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publicite_joueur_creer(text, text, text, text, text), public.publicite_premium_creer_beta(text, text, text, boolean),
  public.premium_admin_parametre_fixer(text, text), public.premium_admin_prix_fixer(text, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
