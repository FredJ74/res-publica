-- Mission du soir du 25/11/2026 (Claude), bloc 4 — NON APPLIQUÉE : Fred la valide devant l'écran.
-- PREMIUM : LE SOCLE (décisions de Fred du 25/11 au soir). Jamais de pay-to-win : mêmes statistiques en gratuit et en premium.
-- • Options à achat unique et durables : commerce premium (3 familles / 10 articles au lieu de 2 / 4), bureau à 6 emplacements,
--   personnalisation du local ou du bâtiment privé, publicités de joueurs. Chaque renouvellement d'image se paie à l'unité.
-- • Abonnement mensuel : toutes les options sans les acheter + UN renouvellement d'image par semaine (semaine ISO, heure de
--   Paris), non cumulable ; au-delà, à l'unité.
-- • Euros, achat par achat, aucune monnaie intermédiaire. AUCUN PRIX FIXÉ : premium_produits.prix_centimes est NULL tant que le
--   MJ ne l'a pas réglé (rien n'est affiché aux joueurs, l'achat répond « prix_non_fixe »). Plancher : 2 € (commission fixe par
--   paiement) — un prix inférieur est refusé par la base (contrainte) et par premium_admin_prix_fixer.
-- • Bêta : premium_parametres.beta_tout_gratuit = 1 → droits accordés à tous, comme aujourd'hui (plafonds 3 / 10 pour chacun,
--   bureau à 6 et appartements premium par activation gratuite, ateliers de décoration et publicités gratuits).
-- • Publicité des annonceurs extérieurs : une seule par jour, au « Dormir », jamais pour un abonné ; réglage MJ
--   pub_externe_active (éteint) ; aucune régie branchée : sans annonce en table, rien ne s'affiche.
-- • Publicités de joueurs : pop-up en ville (une par jour et par joueur), réclame dans les salles du cinéma de Montrouge, annonce
--   dans les journaux (atelier existant publicites_premium_presse, dont les tarifs 4,99 € / 7,99 € écrits en dur disparaissent).
-- • Paiement : tables d'achats prêtes pour un revendeur (api/_paiement.js) ; confirmation et remboursement par le seul serveur.
-- Raccords contrôlés (marque premium_socle_v1) : fonds_definir_types, fonds_reference_creer (plafonds lus sur le FONDS),
--   equipements_emplacements_interne, equipement_option_premium_activer, logement_premium_activer, publicite_premium_creer_beta.
-- Sans cette migration : comportement actuel (tout gratuit) ; l'écran retombe sur « inclus pendant la bêta ».
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.premium_produits WHERE prix_centimes IS NULL;                                         -- 9
--   SELECT valeur FROM public.premium_parametres WHERE cle = 'beta_tout_gratuit';                                      -- 1
--   SELECT valeur FROM public.premium_parametres WHERE cle = 'pub_externe_active';                                     -- 0
--   SELECT position('premium_socle_v1' in pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure)) > 0
--      AND position('premium_socle_v1' in pg_get_functiondef('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure)) > 0
--      AND position('premium_socle_v1' in pg_get_functiondef('public.equipements_emplacements_interne(text,text,text,text)'::regprocedure)) > 0
--      AND position('premium_socle_v1' in pg_get_functiondef('public.equipement_option_premium_activer()'::regprocedure)) > 0
--      AND position('premium_socle_v1' in pg_get_functiondef('public.logement_premium_activer()'::regprocedure)) > 0
--      AND position('premium_socle_v1' in pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.premium_droits_lire()', 'EXECUTE');                         -- vrai
--   SELECT has_function_privilege('authenticated', 'public.premium_achat_confirmer_service(uuid,text,text,integer,text)', 'EXECUTE');  -- faux
--   SELECT has_function_privilege('anon', 'public.premium_droits_lire()', 'EXECUTE');                                  -- faux
BEGIN;

-- 1. Réglages, produits et prix (réglages MJ).
CREATE TABLE IF NOT EXISTS public.premium_parametres (cle text PRIMARY KEY, valeur text NOT NULL, maj_le timestamptz NOT NULL DEFAULT now());
INSERT INTO public.premium_parametres (cle, valeur) VALUES
  ('beta_tout_gratuit', '1'), ('pub_externe_active', '0'), ('publicite_joueur_duree_jours', '7')
ON CONFLICT (cle) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.premium_produits (
  produit text PRIMARY KEY,
  nature text NOT NULL CHECK (nature IN ('option', 'unite', 'abonnement')),
  libelle text NOT NULL,
  prix_centimes integer CHECK (prix_centimes IS NULL OR prix_centimes >= 200),   -- NULL = prix non fixé ; jamais sous 2 €
  maj_le timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.premium_produits (produit, nature, libelle) VALUES
  ('commerce_premium', 'option', 'Commerce premium : 3 familles et 10 articles'),
  ('bureau_six', 'option', 'Bureau à 6 emplacements'),
  ('personnalisation_local', 'option', 'Personnalisation du local ou du bâtiment privé'),
  ('publicite_joueur', 'option', 'Publicités de joueur (rue, cinéma, presse)'),
  ('renouvellement_image', 'unite', 'Renouvellement d''une image'),
  ('credit_publicite_presse', 'unite', 'Une annonce dans la presse'),
  ('credit_publicite_rue', 'unite', 'Une publicité dans la rue'),
  ('credit_publicite_cinema', 'unite', 'Une réclame au cinéma de Montrouge'),
  ('abonnement_mensuel', 'abonnement', 'Abonnement mensuel')
ON CONFLICT (produit) DO NOTHING;

-- 2. Abonnements, achats, droits, renouvellements.
CREATE TABLE IF NOT EXISTS public.premium_abonnements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  statut text NOT NULL CHECK (statut IN ('actif', 'annule', 'expire')),
  debut timestamptz NOT NULL DEFAULT now(),
  fin timestamptz NOT NULL,
  fournisseur text NOT NULL,
  ref_fournisseur text UNIQUE,
  maj_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS premium_abonnements_user_idx ON public.premium_abonnements (user_id, fin DESC);

CREATE TABLE IF NOT EXISTS public.premium_achats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  personnage text,
  produit text NOT NULL REFERENCES public.premium_produits(produit),
  cible text,
  montant_centimes integer NOT NULL CHECK (montant_centimes >= 200),
  devise text NOT NULL DEFAULT 'EUR' CHECK (devise = 'EUR'),
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'paye', 'annule', 'rembourse')),
  fournisseur text,
  ref_fournisseur text UNIQUE,
  cree_le timestamptz NOT NULL DEFAULT now(),
  paye_le timestamptz,
  rembourse_le timestamptz
);
CREATE INDEX IF NOT EXISTS premium_achats_user_idx ON public.premium_achats (user_id, cree_le DESC);

CREATE TABLE IF NOT EXISTS public.premium_droits (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  produit text NOT NULL REFERENCES public.premium_produits(produit),
  cible text,                    -- fonds, bureau (pays|ville|bâtiment|pièce), logement ; NULL = à attacher au premier usage
  source text NOT NULL CHECK (source IN ('achat', 'offre_lancement', 'mj')),
  achat_id uuid REFERENCES public.premium_achats(id),
  accorde_le timestamptz NOT NULL DEFAULT now(),
  consomme_le timestamptz,       -- unités (renouvellement, crédit de publicité) : date d'usage
  revoque_le timestamptz,        -- remboursement
  note text
);
CREATE INDEX IF NOT EXISTS premium_droits_user_idx ON public.premium_droits (user_id, produit);

CREATE TABLE IF NOT EXISTS public.premium_renouvellements (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  semaine text NOT NULL,          -- semaine ISO, heure de Paris : 2026-S48
  type_visuel text NOT NULL,
  objet text,
  source text NOT NULL CHECK (source IN ('beta', 'abonnement', 'unite')),
  cree_le timestamptz NOT NULL DEFAULT now()
);
-- Un seul renouvellement inclus dans l'abonnement par semaine (non cumulable).
CREATE UNIQUE INDEX IF NOT EXISTS premium_renouvellements_abonnement_idx ON public.premium_renouvellements (user_id, semaine) WHERE source = 'abonnement';

-- 3. Publicité des annonceurs extérieurs (emplacement prêt ; aucune régie branchée).
CREATE TABLE IF NOT EXISTS public.premium_pub_externe_annonces (
  id bigserial PRIMARY KEY,
  annonceur text NOT NULL,
  texte text NOT NULL CHECK (length(texte) BETWEEN 1 AND 400),
  image_url text CHECK (image_url IS NULL OR image_url ~ '^https://'),
  lien_url text CHECK (lien_url IS NULL OR lien_url ~ '^https://'),
  actif boolean NOT NULL DEFAULT false,
  debut timestamptz NOT NULL DEFAULT now(),
  fin timestamptz,
  cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.premium_pub_externe_vues (
  user_id uuid NOT NULL, jour date NOT NULL, annonce_id bigint REFERENCES public.premium_pub_externe_annonces(id),
  vue_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, jour)
);

-- 4. Publicités de joueurs (rue, cinéma). La presse garde son atelier (publicites_premium_presse).
CREATE TABLE IF NOT EXISTS public.publicites_joueurs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  personnage text NOT NULL,
  support text NOT NULL CHECK (support IN ('rue', 'cinema')),
  pays text NOT NULL,
  ville text NOT NULL,
  objet text NOT NULL CHECK (objet IN ('commerce', 'cause')),
  titre text NOT NULL CHECK (length(titre) BETWEEN 3 AND 60),
  texte text NOT NULL CHECK (length(texte) BETWEEN 10 AND 280),
  debut date NOT NULL,
  fin date NOT NULL,
  statut text NOT NULL DEFAULT 'active' CHECK (statut IN ('active', 'retiree')),
  motif_retrait text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  CHECK (fin >= debut)
);
CREATE INDEX IF NOT EXISTS publicites_joueurs_diffusion_idx ON public.publicites_joueurs (support, pays, ville, debut, fin) WHERE statut = 'active';
CREATE TABLE IF NOT EXISTS public.publicites_joueurs_vues (
  personnage text NOT NULL, jour date NOT NULL, support text NOT NULL, publicite uuid REFERENCES public.publicites_joueurs(id) ON DELETE SET NULL,
  vue_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (personnage, jour, support)
);

ALTER TABLE public.premium_parametres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_produits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_abonnements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_achats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_droits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_renouvellements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_pub_externe_annonces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_pub_externe_vues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publicites_joueurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publicites_joueurs_vues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.premium_parametres, public.premium_produits, public.premium_abonnements, public.premium_achats,
  public.premium_droits, public.premium_renouvellements, public.premium_pub_externe_annonces, public.premium_pub_externe_vues,
  public.publicites_joueurs, public.publicites_joueurs_vues FROM PUBLIC, anon, authenticated;

-- Plafonds gratuits des commerces (les valeurs *_base existantes, 3 et 10, deviennent celles du premium).
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('types_commerce_max_gratuit', '2'), ('references_max_gratuit', '4')
ON CONFLICT (cle) DO NOTHING;

-- 5. Fonctions internes.
CREATE OR REPLACE FUNCTION public.premium_param_interne(p_cle text, p_defaut text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce((SELECT valeur FROM public.premium_parametres WHERE cle = p_cle), p_defaut) $function$;

CREATE OR REPLACE FUNCTION public.premium_beta_interne()
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT public.premium_param_interne('beta_tout_gratuit', '1') = '1' $function$;

CREATE OR REPLACE FUNCTION public.premium_semaine_interne()
 RETURNS text LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT to_char(now() AT TIME ZONE 'Europe/Paris', 'IYYY-"S"IW') $function$;

CREATE OR REPLACE FUNCTION public.premium_jour_interne()
 RETURNS date LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT (now() AT TIME ZONE 'Europe/Paris')::date $function$;

CREATE OR REPLACE FUNCTION public.premium_user_de_interne(p_nom text)
 RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT user_id FROM public.personnages WHERE name = regexp_replace(coalesce(p_nom, ''), '^pj:', '') LIMIT 1 $function$;

CREATE OR REPLACE FUNCTION public.premium_abonne_interne(p_user uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_user IS NOT NULL AND EXISTS (SELECT 1 FROM public.premium_abonnements a
     WHERE a.user_id = p_user AND a.statut IN ('actif', 'annule') AND a.fin > now()) /* premium_socle_v1 : un abonnement annulé court jusqu'à sa fin */
$function$;

-- Un droit d'option est-il ouvert pour ce compte ? (bêta, abonnement, ou option achetée / offerte pour cette cible)
CREATE OR REPLACE FUNCTION public.premium_droit_interne(p_user uuid, p_produit text, p_cible text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_user IS NOT NULL AND (
       public.premium_beta_interne()
    OR (public.premium_abonne_interne(p_user) AND EXISTS (SELECT 1 FROM public.premium_produits WHERE produit = p_produit AND nature = 'option'))
    OR EXISTS (SELECT 1 FROM public.premium_droits d WHERE d.user_id = p_user AND d.produit = p_produit AND d.revoque_le IS NULL
                 AND d.consomme_le IS NULL AND (d.cible IS NULL OR p_cible IS NULL OR d.cible = p_cible))) /* premium_socle_v1 */
$function$;

-- Source d'une activation d'option, ou NULL si aucun droit. Attache au premier usage un droit acheté ou offert sans cible.
CREATE OR REPLACE FUNCTION public.premium_option_source_interne(p_user uuid, p_produit text, p_cible text)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.premium_droits;
BEGIN
  IF p_user IS NULL THEN RETURN NULL; END IF;
  IF public.premium_beta_interne() THEN RETURN 'gratuit_beta'; END IF;
  SELECT * INTO d FROM public.premium_droits x WHERE x.user_id = p_user AND x.produit = p_produit AND x.revoque_le IS NULL
     AND x.consomme_le IS NULL AND (x.cible IS NULL OR p_cible IS NULL OR x.cible = p_cible)
   ORDER BY (x.cible IS NOT DISTINCT FROM p_cible) DESC, x.accorde_le LIMIT 1 FOR UPDATE;
  IF d.id IS NOT NULL THEN
    IF d.cible IS NULL AND p_cible IS NOT NULL THEN UPDATE public.premium_droits SET cible = p_cible WHERE id = d.id; END IF;
    RETURN CASE WHEN d.source = 'achat' THEN 'achat' ELSE 'offre' END;
  END IF;
  IF public.premium_abonne_interne(p_user) AND EXISTS (SELECT 1 FROM public.premium_produits WHERE produit = p_produit AND nature = 'option') THEN
    RETURN 'abonnement'; END IF;
  RETURN NULL; /* premium_socle_v1 */
END $function$;

-- Consomme un crédit à l'unité (annonce presse, publicité de rue, réclame de cinéma, renouvellement d'image).
CREATE OR REPLACE FUNCTION public.premium_unite_utiliser_interne(p_user uuid, p_produit text, p_cible text DEFAULT NULL)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id bigint;
BEGIN
  SELECT id INTO v_id FROM public.premium_droits WHERE user_id = p_user AND produit = p_produit AND revoque_le IS NULL AND consomme_le IS NULL
   ORDER BY accorde_le LIMIT 1 FOR UPDATE SKIP LOCKED;
  IF v_id IS NULL THEN RETURN false; END IF;
  UPDATE public.premium_droits SET consomme_le = now(), cible = coalesce(cible, p_cible) WHERE id = v_id;
  RETURN true; /* premium_socle_v1 */
END $function$;

-- Commerce : premium si le fonds l'est (achat attaché), ou si son propriétaire a le droit (bêta, abonnement, achat pour ce fonds).
CREATE OR REPLACE FUNCTION public.premium_fonds_droit_interne(p_fonds_id text, p_data jsonb)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((p_data->>'premium')::boolean, false)
      OR public.premium_droit_interne(public.premium_user_de_interne(p_data->>'proprietaire'), 'commerce_premium', p_fonds_id)
$function$;

CREATE OR REPLACE FUNCTION public.premium_fonds_types_max_interne(p_fonds_id text, p_data jsonb)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.premium_fonds_droit_interne(p_fonds_id, p_data) THEN public.fonds_types_max(p_data->>'proprietaire')
    ELSE least(public.fonds_types_max(p_data->>'proprietaire'),
               greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'types_commerce_max_gratuit'), 2))) END
$function$;

CREATE OR REPLACE FUNCTION public.premium_fonds_references_max_interne(p_fonds_id text, p_data jsonb)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.premium_fonds_droit_interne(p_fonds_id, p_data) THEN public.fonds_references_max(p_data->>'proprietaire')
    ELSE least(public.fonds_references_max(p_data->>'proprietaire'),
               greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'references_max_gratuit'), 4))) END
$function$;

-- Bureau à 6 : une option activée compte tant que sa source vaut (achat, offre : toujours ; abonnement : tant qu'il court ;
-- bêta : tant que la bêta gratuite dure, ou si l'acheteur est abonné).
CREATE OR REPLACE FUNCTION public.premium_bureau_option_valide_interne(p_paiement text, p_acheteur text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE coalesce(p_paiement, 'gratuit_beta')
    WHEN 'abonnement' THEN public.premium_abonne_interne(public.premium_user_de_interne(p_acheteur))
    WHEN 'gratuit_beta' THEN public.premium_beta_interne() OR public.premium_abonne_interne(public.premium_user_de_interne(p_acheteur))
    ELSE true END
$function$;

-- 6. Lecture des droits du joueur (écran). Les prix non fixés ne sont jamais rendus.
CREATE OR REPLACE FUNCTION public.premium_droits_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); v_ab public.premium_abonnements; v_sem text := public.premium_semaine_interne();
BEGIN
  IF u IS NULL OR public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_ab FROM public.premium_abonnements WHERE user_id = u AND statut IN ('actif', 'annule') AND fin > now() ORDER BY fin DESC LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'beta', public.premium_beta_interne(), 'abonne', v_ab.id IS NOT NULL,
    'abonnement', CASE WHEN v_ab.id IS NOT NULL THEN jsonb_build_object('fin', v_ab.fin, 'annule', v_ab.statut = 'annule') END,
    'semaine', jsonb_build_object('cle', v_sem,
       'renouvellement_inclus_utilise', EXISTS (SELECT 1 FROM public.premium_renouvellements WHERE user_id = u AND semaine = v_sem AND source = 'abonnement')),
    'produits', (SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('produit', p.produit, 'nature', p.nature, 'libelle', p.libelle,
                   'prix_fixe', p.prix_centimes IS NOT NULL, 'prix_centimes', p.prix_centimes,
                   'droit', CASE WHEN p.nature = 'option' THEN public.premium_droit_interne(u, p.produit, NULL) END)) ORDER BY p.produit), '[]'::jsonb)
                 FROM public.premium_produits p),
    'droits', (SELECT coalesce(jsonb_agg(jsonb_build_object('produit', d.produit, 'cible', d.cible, 'source', d.source,
                 'accorde_le', d.accorde_le, 'consomme', d.consomme_le IS NOT NULL) ORDER BY d.accorde_le DESC), '[]'::jsonb)
               FROM public.premium_droits d WHERE d.user_id = u AND d.revoque_le IS NULL),
    'paiement_ouvert', NOT public.premium_beta_interne() AND EXISTS (SELECT 1 FROM public.premium_produits WHERE prix_centimes IS NOT NULL)); /* premium_socle_v1 */
END $function$;

-- 7. Renouvellement d'image (décor du local, enseigne, relooking, portrait…) : appelé par les ateliers côté serveur (service).
--    Bêta : libre (noté). Abonné : un par semaine ISO inclus, non cumulable. Sinon : une unité achetée, ou refus.
CREATE OR REPLACE FUNCTION public.premium_renouvellement_autoriser_service(p_user uuid, p_type text, p_objet text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_sem text := public.premium_semaine_interne();
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF p_user IS NULL OR coalesce(p_type, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF public.premium_beta_interne() THEN
    INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source) VALUES (p_user, v_sem, p_type, p_objet, 'beta');
    RETURN jsonb_build_object('ok', true, 'source', 'beta');
  END IF;
  IF public.premium_abonne_interne(p_user) AND NOT EXISTS (SELECT 1 FROM public.premium_renouvellements
       WHERE user_id = p_user AND semaine = v_sem AND source = 'abonnement') THEN
    INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source) VALUES (p_user, v_sem, p_type, p_objet, 'abonnement');
    RETURN jsonb_build_object('ok', true, 'source', 'abonnement');
  END IF;
  IF public.premium_unite_utiliser_interne(p_user, 'renouvellement_image', p_type || ':' || coalesce(p_objet, '')) THEN
    INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source) VALUES (p_user, v_sem, p_type, p_objet, 'unite');
    RETURN jsonb_build_object('ok', true, 'source', 'unite');
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'renouvellement_a_payer', 'produit', 'renouvellement_image',
    'prix_fixe', (SELECT prix_centimes IS NOT NULL FROM public.premium_produits WHERE produit = 'renouvellement_image')); /* premium_socle_v1 */
END $function$;

-- Première personnalisation d'un lieu (atelier de décoration) : droit d'option, côté serveur.
CREATE OR REPLACE FUNCTION public.premium_personnalisation_autoriser_service(p_user uuid, p_produit text, p_cible text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_src text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF p_produit NOT IN ('personnalisation_local', 'commerce_premium') THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide'); END IF;
  v_src := public.premium_option_source_interne(p_user, p_produit, p_cible);
  -- Un commerce premium (acheté pour ce fonds) comprend sa personnalisation (règle des commerces du 06/11).
  IF v_src IS NULL AND p_produit = 'personnalisation_local' THEN v_src := public.premium_option_source_interne(p_user, 'commerce_premium', p_cible); END IF;
  IF v_src IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'option_premium_requise', 'produit', p_produit); END IF;
  RETURN jsonb_build_object('ok', true, 'source', v_src); /* premium_socle_v1 */
END $function$;

-- 8. Achat : préparation (joueur), confirmation et remboursement (serveur, après le webhook signé du revendeur).
CREATE OR REPLACE FUNCTION public.premium_achat_preparer(p_produit text, p_cible text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); a text := public.mon_personnage(); p public.premium_produits; v_cible text := nullif(btrim(coalesce(p_cible, '')), '');
        v_id uuid; v_proprio text;
BEGIN
  IF u IS NULL OR a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.premium_produits WHERE produit = p_produit;
  IF p.produit IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;
  IF public.premium_beta_interne() AND p.nature <> 'unite' THEN RETURN jsonb_build_object('ok', false, 'raison', 'inclus_pendant_la_beta'); END IF;
  IF p.prix_centimes IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe'); END IF;
  IF p.prix_centimes < 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inferieur_minimum'); END IF;
  IF length(coalesce(v_cible, '')) > 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF p.produit = 'commerce_premium' THEN
    SELECT regexp_replace(coalesce(data::jsonb->>'proprietaire', ''), '^pj:', '') INTO v_proprio FROM public.entreprises WHERE id = v_cible;
    IF v_proprio IS DISTINCT FROM a THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_proprietaire_fonds'); END IF;
  ELSIF p.produit IN ('bureau_six', 'personnalisation_local') AND v_cible IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_requise');
  END IF;
  IF p.nature = 'option' AND public.premium_droit_interne(u, p.produit, v_cible) AND NOT public.premium_beta_interne() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_deja_acquise'); END IF;
  IF p.nature = 'abonnement' AND public.premium_abonne_interne(u) THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_abonne'); END IF;
  INSERT INTO public.premium_achats (user_id, personnage, produit, cible, montant_centimes) VALUES (u, a, p.produit, v_cible, p.prix_centimes)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'achat', v_id, 'produit', p.produit, 'nature', p.nature, 'libelle', p.libelle,
    'montant_centimes', p.prix_centimes, 'devise', 'EUR'); /* premium_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.premium_achat_lier_service(p_achat uuid, p_fournisseur text, p_ref text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  UPDATE public.premium_achats SET fournisseur = p_fournisseur, ref_fournisseur = coalesce(ref_fournisseur, p_ref)
   WHERE id = p_achat AND statut = 'en_attente';
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

CREATE OR REPLACE FUNCTION public.premium_achat_confirmer_service(p_achat uuid, p_fournisseur text, p_ref text, p_montant integer, p_devise text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x public.premium_achats; p public.premium_produits; v_fin timestamptz;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO x FROM public.premium_achats WHERE id = p_achat FOR UPDATE;
  IF x.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_inconnu'); END IF;
  IF x.statut = 'paye' THEN RETURN jsonb_build_object('ok', true, 'deja', true); END IF;           -- webhook rejoué : idempotent
  IF x.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_' || x.statut); END IF;
  IF p_montant IS DISTINCT FROM x.montant_centimes OR upper(coalesce(p_devise, '')) <> 'EUR' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_incoherent'); END IF;
  SELECT * INTO p FROM public.premium_produits WHERE produit = x.produit;
  UPDATE public.premium_achats SET statut = 'paye', paye_le = now(), fournisseur = p_fournisseur, ref_fournisseur = coalesce(ref_fournisseur, p_ref)
   WHERE id = x.id;
  IF p.nature = 'abonnement' THEN
    SELECT max(fin) INTO v_fin FROM public.premium_abonnements WHERE user_id = x.user_id AND statut IN ('actif', 'annule') AND fin > now();
    INSERT INTO public.premium_abonnements (user_id, statut, debut, fin, fournisseur, ref_fournisseur)
    VALUES (x.user_id, 'actif', now(), greatest(coalesce(v_fin, now()), now()) + interval '1 month', p_fournisseur, coalesce(p_ref, x.id::text))
    ON CONFLICT (ref_fournisseur) DO UPDATE SET statut = 'actif', fin = EXCLUDED.fin, maj_le = now();
  ELSE
    INSERT INTO public.premium_droits (user_id, produit, cible, source, achat_id) VALUES (x.user_id, x.produit, x.cible, 'achat', x.id);
    -- Commerce premium : attaché au fonds (transmis avec le commerce).
    IF x.produit = 'commerce_premium' AND x.cible IS NOT NULL THEN
      UPDATE public.entreprises SET data = (data::jsonb || jsonb_build_object('premium', true, 'premiumDepuis', now(), 'premiumSource', 'achat'))
       WHERE id = x.cible;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'produit', x.produit, 'user', x.user_id); /* premium_socle_v1 */
END $function$;

-- Renouvellement ou fin d'abonnement notifiés par le revendeur (référence d'abonnement du fournisseur).
CREATE OR REPLACE FUNCTION public.premium_abonnement_maj_service(p_ref text, p_statut text, p_fin timestamptz)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF p_statut NOT IN ('actif', 'annule', 'expire') THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide'); END IF;
  UPDATE public.premium_abonnements SET statut = p_statut, fin = coalesce(p_fin, fin), maj_le = now() WHERE ref_fournisseur = p_ref;
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

CREATE OR REPLACE FUNCTION public.premium_achat_rembourser_service(p_ref text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x public.premium_achats;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO x FROM public.premium_achats WHERE ref_fournisseur = p_ref FOR UPDATE;
  IF x.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_inconnu'); END IF;
  IF x.statut = 'rembourse' THEN RETURN jsonb_build_object('ok', true, 'deja', true); END IF;
  UPDATE public.premium_achats SET statut = 'rembourse', rembourse_le = now() WHERE id = x.id;
  UPDATE public.premium_droits SET revoque_le = now() WHERE achat_id = x.id AND revoque_le IS NULL;
  UPDATE public.premium_abonnements SET statut = 'expire', fin = least(fin, now()), maj_le = now() WHERE ref_fournisseur = p_ref;
  RETURN jsonb_build_object('ok', true); /* premium_socle_v1 */
END $function$;

-- 9. Publicité des annonceurs extérieurs, au « Dormir » : une par jour, joueurs gratuits seulement, réglage MJ éteint.
CREATE OR REPLACE FUNCTION public.premium_pub_externe_dormir()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); v_jour date := public.premium_jour_interne(); an public.premium_pub_externe_annonces;
BEGIN
  IF u IS NULL OR public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.premium_param_interne('pub_externe_active', '0') <> '1' THEN RETURN jsonb_build_object('ok', true, 'annonce', NULL); END IF;
  IF public.premium_abonne_interne(u) THEN RETURN jsonb_build_object('ok', true, 'annonce', NULL, 'abonne', true); END IF;
  IF EXISTS (SELECT 1 FROM public.premium_pub_externe_vues WHERE user_id = u AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', true, 'annonce', NULL, 'deja_vue', true); END IF;
  SELECT * INTO an FROM public.premium_pub_externe_annonces WHERE actif AND debut <= now() AND (fin IS NULL OR fin > now()) ORDER BY random() LIMIT 1;
  IF an.id IS NULL THEN RETURN jsonb_build_object('ok', true, 'annonce', NULL); END IF;     -- aucune régie : rien ne s'affiche
  INSERT INTO public.premium_pub_externe_vues (user_id, jour, annonce_id) VALUES (u, v_jour, an.id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'annonce', NULL, 'deja_vue', true); END IF;
  RETURN jsonb_build_object('ok', true, 'annonce', jsonb_strip_nulls(jsonb_build_object('id', an.id, 'annonceur', an.annonceur,
    'texte', an.texte, 'image_url', an.image_url, 'lien_url', an.lien_url))); /* premium_socle_v1 */
END $function$;

-- 10. Publicités de joueurs (rue, cinéma de Montrouge).
CREATE OR REPLACE FUNCTION public.publicite_joueur_texte_interne(p text, n integer)
 RETURNS text LANGUAGE sql IMMUTABLE AS $function$
  SELECT left(btrim(regexp_replace(regexp_replace(coalesce(p, ''), '[[:cntrl:]<>]', ' ', 'g'), '\s+', ' ', 'g')), n)
$function$;

CREATE OR REPLACE FUNCTION public.publicite_joueur_creer(p_support text, p_objet text, p_titre text, p_texte text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); a text := public.mon_personnage(); d record; v_titre text := public.publicite_joueur_texte_interne(p_titre, 60);
        v_texte text := public.publicite_joueur_texte_interne(p_texte, 280); v_jour date := public.premium_jour_interne();
        v_duree integer := greatest(1, least(60, coalesce(nullif(public.premium_param_interne('publicite_joueur_duree_jours', '7'), '')::integer, 7)));
        v_pays text; v_ville text; v_id uuid; v_src text;
BEGIN
  IF u IS NULL OR a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_support NOT IN ('rue', 'cinema') THEN RETURN jsonb_build_object('ok', false, 'raison', 'support_invalide'); END IF;
  IF p_objet NOT IN ('commerce', 'cause') THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide'); END IF;
  IF length(v_titre) < 3 OR length(v_texte) < 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_trop_court'); END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = a;
  IF p_support = 'cinema' THEN v_pays := 'republic'; v_ville := 'ville_b';               -- le cinéma de Montrouge
  ELSE v_pays := d.country; v_ville := d.current_city; END IF;
  IF v_pays IS NULL OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_inconnu'); END IF;
  IF EXISTS (SELECT 1 FROM public.publicites_joueurs WHERE user_id = u AND support = p_support AND statut = 'active' AND fin >= v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'campagne_deja_en_cours'); END IF;
  v_src := public.premium_option_source_interne(u, 'publicite_joueur', NULL);
  IF v_src IS NULL AND NOT public.premium_unite_utiliser_interne(u, 'credit_publicite_' || p_support, p_support) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_premium_requise', 'produit', 'publicite_joueur'); END IF;
  INSERT INTO public.publicites_joueurs (user_id, personnage, support, pays, ville, objet, titre, texte, debut, fin)
  VALUES (u, a, p_support, v_pays, v_ville, p_objet, v_titre, v_texte, v_jour, v_jour + v_duree - 1) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'debut', v_jour, 'fin', v_jour + v_duree - 1, 'ville', v_ville); /* premium_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.publicite_joueur_tirer(p_support text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record; v_jour date := public.premium_jour_interne(); x public.publicites_joueurs;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_support NOT IN ('rue', 'cinema') THEN RETURN jsonb_build_object('ok', false, 'raison', 'support_invalide'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = a;
  IF p_support = 'cinema' AND (d.country, d.current_city, d.current_building) IS DISTINCT FROM ('republic', 'ville_b', 'cinema-montrouge') THEN
    RETURN jsonb_build_object('ok', true, 'publicite', NULL); END IF;
  IF EXISTS (SELECT 1 FROM public.publicites_joueurs_vues WHERE personnage = a AND jour = v_jour AND support = p_support) THEN
    RETURN jsonb_build_object('ok', true, 'publicite', NULL, 'deja_vue', true); END IF;
  SELECT * INTO x FROM public.publicites_joueurs WHERE support = p_support AND statut = 'active' AND v_jour BETWEEN debut AND fin
     AND pays = d.country AND ville = d.current_city AND personnage <> a AND NOT public.est_compte_test(personnage)
   ORDER BY random() LIMIT 1;
  IF x.id IS NULL THEN RETURN jsonb_build_object('ok', true, 'publicite', NULL); END IF;
  INSERT INTO public.publicites_joueurs_vues (personnage, jour, support, publicite) VALUES (a, v_jour, p_support, x.id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'publicite', NULL, 'deja_vue', true); END IF;
  RETURN jsonb_build_object('ok', true, 'publicite', jsonb_build_object('id', x.id, 'support', x.support, 'objet', x.objet,
    'titre', x.titre, 'texte', x.texte, 'annonceur', x.personnage)); /* premium_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.publicite_joueur_mes()
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', auth.uid() IS NOT NULL, 'publicites', coalesce((SELECT jsonb_agg(jsonb_build_object('id', id, 'support', support,
    'objet', objet, 'titre', titre, 'texte', texte, 'debut', debut, 'fin', fin, 'statut', statut, 'ville', ville) ORDER BY cree_le DESC)
    FROM public.publicites_joueurs WHERE user_id = auth.uid()), '[]'::jsonb))
$function$;

CREATE OR REPLACE FUNCTION public.publicite_joueur_retirer(p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.publicites_joueurs SET statut = 'retiree', motif_retrait = 'retiree_par_son_auteur' WHERE id = p_id AND user_id = auth.uid() AND statut = 'active';
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

-- 11. Réglages MJ.
CREATE OR REPLACE FUNCTION public.premium_admin_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'parametres', (SELECT coalesce(jsonb_object_agg(cle, valeur), '{}'::jsonb) FROM public.premium_parametres),
    'produits', (SELECT coalesce(jsonb_agg(jsonb_build_object('produit', produit, 'nature', nature, 'libelle', libelle, 'prix_centimes', prix_centimes) ORDER BY produit), '[]'::jsonb) FROM public.premium_produits),
    'annonces', (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id DESC), '[]'::jsonb) FROM public.premium_pub_externe_annonces a),
    'achats', jsonb_build_object('payes', (SELECT count(*) FROM public.premium_achats WHERE statut = 'paye'),
                                 'en_attente', (SELECT count(*) FROM public.premium_achats WHERE statut = 'en_attente')),
    'abonnes', (SELECT count(DISTINCT user_id) FROM public.premium_abonnements WHERE statut IN ('actif', 'annule') AND fin > now()),
    'publicites_joueurs', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'personnage', personnage, 'support', support, 'titre', titre,
        'texte', texte, 'ville', ville, 'fin', fin) ORDER BY cree_le DESC), '[]'::jsonb) FROM public.publicites_joueurs WHERE statut = 'active'));
END $function$;

CREATE OR REPLACE FUNCTION public.premium_admin_prix_fixer(p_produit text, p_centimes integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_centimes IS NOT NULL AND p_centimes < 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inferieur_minimum', 'minimum_centimes', 200); END IF;
  UPDATE public.premium_produits SET prix_centimes = p_centimes, maj_le = now() WHERE produit = p_produit;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'premium_prix', jsonb_build_object('produit', p_produit, 'centimes', p_centimes), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true, 'produit', p_produit, 'prix_centimes', p_centimes);
END $function$;

CREATE OR REPLACE FUNCTION public.premium_admin_parametre_fixer(p_cle text, p_valeur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_cle IN ('beta_tout_gratuit', 'pub_externe_active') AND p_valeur NOT IN ('0', '1') THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  IF p_cle = 'publicite_joueur_duree_jours' AND (p_valeur !~ '^[0-9]{1,2}$' OR p_valeur::integer NOT BETWEEN 1 AND 60) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  IF p_cle NOT IN ('beta_tout_gratuit', 'pub_externe_active', 'publicite_joueur_duree_jours') THEN RETURN jsonb_build_object('ok', false, 'raison', 'reglage_inconnu'); END IF;
  INSERT INTO public.premium_parametres (cle, valeur, maj_le) VALUES (p_cle, p_valeur, now())
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur, maj_le = now();
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'premium_parametre', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true);
END $function$;

CREATE OR REPLACE FUNCTION public.premium_admin_publicite_retirer(p_id uuid, p_motif text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  UPDATE public.publicites_joueurs SET statut = 'retiree', motif_retrait = left(coalesce(nullif(btrim(p_motif), ''), 'moderation'), 200) WHERE id = p_id;
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

-- 12. Raccords contrôlés dans les options existantes.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer_n(p_fn regprocedure, p_avants text[], p_apres text[], p_ns integer[], p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer; i integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  FOR i IN 1 .. array_length(p_avants, 1) LOOP
    n := (length(d) - length(replace(d, p_avants[i], ''))) / length(p_avants[i]);
    IF n <> p_ns[i] THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_ns[i], left(p_avants[i], 60); END IF;
    d := replace(d, p_avants[i], p_apres[i]);
  END LOOP;
  EXECUTE d;
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

SELECT pg_temp.rp_remplacer_n('public.fonds_definir_types(text,text,text[])'::regprocedure,
  ARRAY[$a$v_max := public.fonds_types_max(v_data ->> 'proprietaire');$a$],
  ARRAY[$b$v_max := public.premium_fonds_types_max_interne(p_fonds_id, v_data::jsonb); /* premium_socle_v1 */$b$], ARRAY[1], 'premium_socle_v1');

SELECT pg_temp.rp_remplacer_n('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure,
  ARRAY[$a$public.fonds_references_max(v_data->>'proprietaire')$a$],
  ARRAY[$b$public.premium_fonds_references_max_interne(p_fonds_id, v_data::jsonb /* premium_socle_v1 */)$b$], ARRAY[2], 'premium_socle_v1');

SELECT pg_temp.rp_remplacer_n('public.equipements_emplacements_interne(text,text,text,text)'::regprocedure,
  ARRAY[$a$AND public.local_jouissance_interne(b.acheteur, p_pays, p_ville, p_batiment, p_piece))$a$],
  ARRAY[$b$AND public.local_jouissance_interne(b.acheteur, p_pays, p_ville, p_batiment, p_piece)
                              AND public.premium_bureau_option_valide_interne(b.paiement, b.acheteur) /* premium_socle_v1 */)$b$], ARRAY[1], 'premium_socle_v1');

SELECT pg_temp.rp_remplacer_n('public.equipement_option_premium_activer()'::regprocedure,
  ARRAY[$a$DECLARE v_moi text; d record;$a$,
        $a$  -- Beta : gratuite. Le paiement de l'option premium sera branche ici.
  INSERT INTO public.bureaux_option_premium (acheteur, pays, ville, batiment, piece)
  VALUES (v_moi, d.country, d.current_city, d.current_building, d.current_room);$a$],
  ARRAY[$b$DECLARE v_moi text; d record; v_paiement text;$b$,
        $b$  -- Droit d'option tenu par le serveur : bêta, abonnement, achat ou offre (premium_socle_v1).
  v_paiement := public.premium_option_source_interne(auth.uid(), 'bureau_six',
    d.country || '|' || d.current_city || '|' || d.current_building || '|' || d.current_room);
  IF v_paiement IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'option_premium_requise', 'produit', 'bureau_six'); END IF;
  INSERT INTO public.bureaux_option_premium (acheteur, pays, ville, batiment, piece, paiement)
  VALUES (v_moi, d.country, d.current_city, d.current_building, d.current_room, v_paiement);$b$], ARRAY[1, 1], 'premium_socle_v1');

SELECT pg_temp.rp_remplacer_n('public.logement_premium_activer()'::regprocedure,
  ARRAY[$a$  -- Bêta : gratuite. Le paiement de l'option sera branché ici lors de la session premium.$a$],
  ARRAY[$b$  -- Droit d'option tenu par le serveur : bêta, abonnement, achat ou offre (premium_socle_v1).
  IF public.premium_option_source_interne(auth.uid(), 'personnalisation_local',
       d.country || '|' || d.current_city || '|' || d.current_building || '|' || (i->>'base')) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_premium_requise', 'produit', 'personnalisation_local'); END IF;$b$], ARRAY[1], 'premium_socle_v1');

-- Atelier de presse : plus de tarif écrit en dur (499 / 799) ; droit d'option ou crédit d'annonce exigé.
ALTER TABLE public.publicites_premium_presse DROP CONSTRAINT IF EXISTS publicites_premium_presse_check;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_prix_check CHECK (prix_centimes = 0 OR prix_centimes >= 200) NOT VALID;
ALTER TABLE public.publicites_premium_presse VALIDATE CONSTRAINT publicites_premium_presse_prix_check;
SELECT pg_temp.rp_remplacer_n('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure,
  ARRAY[$a$ IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;$a$,
        $a$CASE WHEN p_formule='cinq' THEN 499 ELSE 799 END$a$],
  ARRAY[$b$ IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;
 IF public.premium_option_source_interne(auth.uid(), 'publicite_joueur', NULL) IS NULL
    AND NOT public.premium_unite_utiliser_interne(auth.uid(), 'credit_publicite_presse', 'presse') THEN
   RAISE EXCEPTION 'Option premium requise'; END IF; /* premium_socle_v1 */$b$,
        $b$0$b$], ARRAY[1, 1], 'premium_socle_v1');

-- 13. Droits d'exécution.
REVOKE ALL ON FUNCTION public.premium_param_interne(text, text), public.premium_beta_interne(), public.premium_semaine_interne(),
  public.premium_jour_interne(), public.premium_user_de_interne(text), public.premium_abonne_interne(uuid),
  public.premium_droit_interne(uuid, text, text), public.premium_option_source_interne(uuid, text, text),
  public.premium_unite_utiliser_interne(uuid, text, text), public.premium_fonds_droit_interne(text, jsonb),
  public.premium_fonds_types_max_interne(text, jsonb), public.premium_fonds_references_max_interne(text, jsonb),
  public.premium_bureau_option_valide_interne(text, text), public.publicite_joueur_texte_interne(text, integer),
  public.premium_renouvellement_autoriser_service(uuid, text, text), public.premium_personnalisation_autoriser_service(uuid, text, text),
  public.premium_achat_lier_service(uuid, text, text), public.premium_achat_confirmer_service(uuid, text, text, integer, text),
  public.premium_abonnement_maj_service(text, text, timestamptz), public.premium_achat_rembourser_service(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.premium_renouvellement_autoriser_service(uuid, text, text), public.premium_personnalisation_autoriser_service(uuid, text, text),
  public.premium_achat_lier_service(uuid, text, text), public.premium_achat_confirmer_service(uuid, text, text, integer, text),
  public.premium_abonnement_maj_service(text, text, timestamptz), public.premium_achat_rembourser_service(text) TO service_role;
REVOKE ALL ON FUNCTION public.premium_droits_lire(), public.premium_achat_preparer(text, text), public.premium_pub_externe_dormir(),
  public.publicite_joueur_creer(text, text, text, text), public.publicite_joueur_tirer(text), public.publicite_joueur_mes(),
  public.publicite_joueur_retirer(uuid), public.premium_admin_lire(), public.premium_admin_prix_fixer(text, integer),
  public.premium_admin_parametre_fixer(text, text), public.premium_admin_publicite_retirer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.premium_droits_lire(), public.premium_achat_preparer(text, text), public.premium_pub_externe_dormir(),
  public.publicite_joueur_creer(text, text, text, text), public.publicite_joueur_tirer(text), public.publicite_joueur_mes(),
  public.publicite_joueur_retirer(uuid), public.premium_admin_lire(), public.premium_admin_prix_fixer(text, integer),
  public.premium_admin_parametre_fixer(text, text), public.premium_admin_publicite_retirer(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
