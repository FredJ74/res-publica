-- Mission du 28/11/2026 (après-midi, Claude), étape 4 — PAIEMENT PAR STRIPE, EN FONCTIONNEMENT MIXTE (décision de Fred du 28/11).
-- APPLIQUÉE en production le 28/11/2026 (feu vert de Fred pour la mission) : essai en transaction annulée « TESTS_OK », application, relecture.
-- • Acheteurs de France et de l'Union européenne : Stripe classique, l'éditeur est le vendeur (franchise de TVA : « TVA non
--   applicable, article 293 B du CGI ») ; acheteurs du reste du monde : Stripe Managed Payments, Stripe (Link) est le vendeur.
--   Réglage serveur premium_parametres.paiement_mp_pour_ue = 1 : Managed Payments aussi pour l'Union européenne, sans recoder.
--   paiement_mp_actif = 0 tant que Managed Payments n'est pas activé dans le compte Stripe : hors UE, pas d'achat (jeu gratuit).
--   Pays que Stripe ne sert pas (liste documentée de Managed Payments, réglable) : jeu gratuit, aucun achat.
-- • Abonnement mensuel et ANNUEL (nouveau produit abonnement_annuel, prix non fixé), renouvelés automatiquement ; résiliation
--   à la fin de la période payée ; rappel par e-mail au moins 30 jours (réglage : 35) avant le renouvellement d'un annuel.
-- • Ce qui est activé pendant l'abonnement reste acquis : la première activation d'une option attachée à un lieu (bureau à 6,
--   personnalisation du local, commerce premium) inscrit un droit durable (source « abonnement »).
-- • Remboursement intégral sur demande dans les 14 jours suivant le premier paiement si aucun avantage n'a été utilisé ;
--   achat ou abonnement payé en double : remboursé automatiquement.
-- • Avant tout achat à l'unité ou d'option : CGV acceptées et renonciation expresse au droit de rétractation (case non
--   pré-cochée), enregistrées sur l'achat ; sinon l'achat est annulé avant tout paiement.
-- Remplacements contrôlés (marque paiement_stripe_v1) : premium_achat_confirmer_service (durée annuelle), premium_achat_preparer
--   (rend la durée),
--   premium_option_source_interne (droit acquis, usage noté). Corps relus en production le 28/11/2026 (lecture seule).
--
-- Contrôles en lecture après application :
--   SELECT nature, intervalle, prix_centimes FROM public.premium_produits WHERE produit = 'abonnement_annuel';        -- abonnement | year | NULL
--   SELECT valeur FROM public.premium_parametres WHERE cle IN ('paiement_mp_actif', 'paiement_mp_pour_ue');             -- 0, 0
--   SELECT position('paiement_stripe_v1' in pg_get_functiondef('public.premium_achat_confirmer_service(uuid,text,text,integer,text)'::regprocedure)) > 0
--      AND position('paiement_stripe_v1' in pg_get_functiondef('public.premium_option_source_interne(uuid,text,text)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.premium_abonnement_lire()', 'EXECUTE');                       -- vrai
--   SELECT has_function_privilege('authenticated', 'public.premium_paiement_contexte_service(text)', 'EXECUTE');         -- faux
--   SELECT (public.premium_paiement_contexte_service('FR'))->>'mode';                                                    -- editeur
--   SELECT (public.premium_paiement_contexte_service('US'))->>'raison';                                                  -- vente_hors_ue_fermee
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $$;

-- 1. Réglages serveur (modifiables par le MJ : premium_admin_paiement_fixer).
INSERT INTO public.premium_parametres (cle, valeur) VALUES
  ('paiement_mp_actif', '0'),             -- 1 quand Managed Payments est activé dans le compte Stripe (sinon : pas d'achat hors UE)
  ('paiement_mp_pour_ue', '0'),           -- 1 : Managed Payments aussi pour la France et l'UE (Stripe vendeur partout)
  ('paiement_pays_ue', 'AT,BE,BG,HR,CY,CZ,DK,EE,FI,FR,DE,GR,HU,IE,IT,LV,LT,LU,MT,NL,PL,PT,RO,SK,SI,ES,SE,GP,MQ,GF,RE,YT,MF,MC'),
  ('paiement_pays_exclus', 'AC,CN,CU,IR,XK,KP,RU,SY,TA'),   -- pays restreints de Managed Payments (docs.stripe.com, 28/11/2026)
  ('vendeur_editeur_nom', ''),            -- nom légal de l'éditeur, affiché comme vendeur (UE) : à remplir par Fred
  ('cgv_url', ''),                        -- adresse des CGV : à remplir par Fred (sans CGV, pas d'achat réel)
  ('remboursement_abonnement_jours', '14'),
  ('rappel_annuel_jours', '35')           -- e-mail de rappel envoyé au plus tard 30 jours avant le renouvellement annuel
ON CONFLICT (cle) DO NOTHING;

-- 2. Produits : durée des abonnements, abonnement annuel (prix non fixé, réglage MJ).
ALTER TABLE public.premium_produits ADD COLUMN IF NOT EXISTS intervalle text CHECK (intervalle IS NULL OR intervalle IN ('month', 'year'));
UPDATE public.premium_produits SET intervalle = 'month' WHERE produit = 'abonnement_mensuel' AND intervalle IS NULL;
INSERT INTO public.premium_produits (produit, nature, libelle, intervalle) VALUES ('abonnement_annuel', 'abonnement', 'Abonnement annuel', 'year')
ON CONFLICT (produit) DO NOTHING;

-- 3. Achats : consentements, mode de vente, pays, langue, référence du paiement, e-mail de confirmation.
ALTER TABLE public.premium_achats
  ADD COLUMN IF NOT EXISTS cgv_acceptees_le timestamptz,
  ADD COLUMN IF NOT EXISTS renonciation_retractation_le timestamptz,
  ADD COLUMN IF NOT EXISTS mode_vente text CHECK (mode_vente IS NULL OR mode_vente IN ('editeur', 'stripe')),
  ADD COLUMN IF NOT EXISTS pays_acheteur text,
  ADD COLUMN IF NOT EXISTS langue text,
  ADD COLUMN IF NOT EXISTS ref_paiement text,
  ADD COLUMN IF NOT EXISTS email_confirmation_le timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS premium_achats_ref_paiement_idx ON public.premium_achats (ref_paiement) WHERE ref_paiement IS NOT NULL;

-- 4. Abonnements : durée, achat d'origine, vendeur, e-mail de facturation (rappel annuel), usage d'un avantage, rappel, demandes.
ALTER TABLE public.premium_abonnements
  ADD COLUMN IF NOT EXISTS intervalle text CHECK (intervalle IS NULL OR intervalle IN ('month', 'year')),
  ADD COLUMN IF NOT EXISTS achat_id uuid REFERENCES public.premium_achats(id),
  ADD COLUMN IF NOT EXISTS mode_vente text CHECK (mode_vente IS NULL OR mode_vente IN ('editeur', 'stripe')),
  ADD COLUMN IF NOT EXISTS email_facturation text,
  ADD COLUMN IF NOT EXISTS langue text,
  ADD COLUMN IF NOT EXISTS premier_paiement_le timestamptz,
  ADD COLUMN IF NOT EXISTS avantage_utilise_le timestamptz,
  ADD COLUMN IF NOT EXISTS rappel_envoye_pour timestamptz,
  ADD COLUMN IF NOT EXISTS resiliation_demandee_le timestamptz,
  ADD COLUMN IF NOT EXISTS remboursement_demande_le timestamptz;

-- 5. Droits : « abonnement » = activé pendant l'abonnement, acquis durablement.
ALTER TABLE public.premium_droits DROP CONSTRAINT IF EXISTS premium_droits_source_check;
ALTER TABLE public.premium_droits ADD CONSTRAINT premium_droits_source_check CHECK (source IN ('achat', 'offre_lancement', 'mj', 'abonnement')) NOT VALID;
ALTER TABLE public.premium_droits VALIDATE CONSTRAINT premium_droits_source_check;

-- 6. Fonctions internes.
CREATE OR REPLACE FUNCTION public.premium_liste_interne(p_cle text, p_defaut text)
 RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(string_to_array(nullif(upper(replace(public.premium_param_interne(p_cle, p_defaut), ' ', '')), ''), ','), ARRAY[]::text[]) $function$;

-- Un avantage de l'abonnement a-t-il été utilisé ? (option activée, droit acquis, renouvellement d'image inclus)
CREATE OR REPLACE FUNCTION public.premium_abonnement_avantage_interne(p_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.premium_abonnements a WHERE a.id = p_id AND (
       a.avantage_utilise_le IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.premium_renouvellements r WHERE r.user_id = a.user_id AND r.source = 'abonnement' AND r.cree_le >= a.debut)
    OR EXISTS (SELECT 1 FROM public.premium_droits d WHERE d.user_id = a.user_id AND d.source = 'abonnement' AND d.accorde_le >= a.debut)))
$function$;

CREATE OR REPLACE FUNCTION public.premium_abonnement_remboursable_interne(p_id uuid)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN a.id IS NULL THEN 'aucun_abonnement'
    WHEN a.statut = 'expire' OR a.fin <= now() THEN 'aucun_abonnement'
    WHEN a.premier_paiement_le IS NULL THEN 'paiement_non_confirme'
    WHEN now() > a.premier_paiement_le + make_interval(days => greatest(14, coalesce(public.premium_param_interne('remboursement_abonnement_jours', '14')::integer, 14)))
      THEN 'delai_depasse'
    WHEN public.premium_abonnement_avantage_interne(a.id) THEN 'avantage_utilise'
    ELSE NULL END
  FROM (SELECT 1) un LEFT JOIN public.premium_abonnements a ON a.id = p_id
$function$;

-- 7. Contexte d'achat décidé par le serveur à partir du pays de l'acheteur (géolocalisation de Vercel, transmise par le
--    serveur seulement) : mode « editeur » (Stripe classique) ou « stripe » (Managed Payments), ou aucun achat.
CREATE OR REPLACE FUNCTION public.premium_paiement_contexte_service(p_pays text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text := upper(btrim(coalesce(p_pays, ''))); v_ue boolean; v_mp boolean := public.premium_param_interne('paiement_mp_actif', '0') = '1';
        v_mode text; v_raison text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF v_pays !~ '^[A-Z]{2}$' THEN v_raison := 'pays_inconnu';
  ELSIF v_pays = ANY (public.premium_liste_interne('paiement_pays_exclus', '')) THEN v_raison := 'pays_non_servi';
  ELSE
    v_ue := v_pays = ANY (public.premium_liste_interne('paiement_pays_ue', ''));
    IF v_ue THEN v_mode := CASE WHEN v_mp AND public.premium_param_interne('paiement_mp_pour_ue', '0') = '1' THEN 'stripe' ELSE 'editeur' END;
    ELSIF v_mp THEN v_mode := 'stripe';
    ELSE v_raison := 'vente_hors_ue_fermee'; END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'pays', nullif(v_pays, ''), 'ue', coalesce(v_ue, false), 'achats_possibles', v_mode IS NOT NULL,
    'mode', v_mode, 'raison', v_raison, 'editeur_nom', nullif(btrim(public.premium_param_interne('vendeur_editeur_nom', '')), ''),
    'cgv_url', nullif(btrim(public.premium_param_interne('cgv_url', '')), '')); /* paiement_stripe_v1 */
END $function$;

-- 8. Consentements enregistrés AVANT le paiement (le serveur transmet les cases cochées par le joueur).
CREATE OR REPLACE FUNCTION public.premium_achat_consentir_service(p_achat uuid, p_cgv boolean, p_renonciation boolean, p_mode text, p_pays text, p_langue text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x public.premium_achats; v_nature text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO x FROM public.premium_achats WHERE id = p_achat FOR UPDATE;
  IF x.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_inconnu'); END IF;
  IF x.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_' || x.statut); END IF;
  SELECT nature INTO v_nature FROM public.premium_produits WHERE produit = x.produit;
  IF coalesce(p_mode, '') NOT IN ('editeur', 'stripe') THEN
    UPDATE public.premium_achats SET statut = 'annule' WHERE id = x.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF p_cgv IS NOT TRUE THEN
    UPDATE public.premium_achats SET statut = 'annule' WHERE id = x.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'cgv_requises'); END IF;
  IF v_nature IN ('option', 'unite') AND p_renonciation IS NOT TRUE THEN
    UPDATE public.premium_achats SET statut = 'annule' WHERE id = x.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'renonciation_requise'); END IF;
  UPDATE public.premium_achats SET cgv_acceptees_le = now(),
    renonciation_retractation_le = CASE WHEN v_nature IN ('option', 'unite') THEN now() END,
    mode_vente = p_mode, pays_acheteur = nullif(upper(left(btrim(coalesce(p_pays, '')), 2)), ''), langue = nullif(left(btrim(coalesce(p_langue, '')), 8), '')
   WHERE id = x.id;
  RETURN jsonb_build_object('ok', true, 'nature', v_nature); /* paiement_stripe_v1 */
END $function$;

-- 9. Après la confirmation (webhook signé) : référence du paiement, fiche d'abonnement complétée, doublon détecté,
--    e-mail de confirmation à envoyer (une seule fois).
CREATE OR REPLACE FUNCTION public.premium_achat_paiement_noter_service(p_achat uuid, p_ref_paiement text, p_abonnement_ref text, p_email text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x public.premium_achats; p public.premium_produits; a public.premium_abonnements; v_doublon boolean := false;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO x FROM public.premium_achats WHERE id = p_achat FOR UPDATE;
  IF x.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_inconnu'); END IF;
  IF x.statut <> 'paye' THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_' || x.statut); END IF;
  SELECT * INTO p FROM public.premium_produits WHERE produit = x.produit;
  IF nullif(btrim(coalesce(p_ref_paiement, '')), '') IS NOT NULL AND x.ref_paiement IS NULL
     AND NOT EXISTS (SELECT 1 FROM public.premium_achats WHERE ref_paiement = p_ref_paiement) THEN
    UPDATE public.premium_achats SET ref_paiement = p_ref_paiement WHERE id = x.id;
  END IF;
  IF p.nature = 'abonnement' AND nullif(btrim(coalesce(p_abonnement_ref, '')), '') IS NOT NULL THEN
    UPDATE public.premium_abonnements SET intervalle = coalesce(p.intervalle, 'month'), achat_id = x.id, mode_vente = x.mode_vente, langue = x.langue,
      email_facturation = coalesce(nullif(left(btrim(coalesce(p_email, '')), 254), ''), email_facturation),
      premier_paiement_le = coalesce(premier_paiement_le, x.paye_le, now()), maj_le = now()
     WHERE ref_fournisseur = p_abonnement_ref AND user_id = x.user_id
    RETURNING * INTO a;
    -- Un autre abonnement court déjà : débit en double.
    v_doublon := a.id IS NOT NULL AND EXISTS (SELECT 1 FROM public.premium_abonnements o WHERE o.user_id = x.user_id AND o.id <> a.id
                   AND o.statut IN ('actif', 'annule') AND o.fin > now() AND o.debut <= a.debut);
  ELSIF p.nature = 'option' THEN
    v_doublon := EXISTS (SELECT 1 FROM public.premium_achats y WHERE y.user_id = x.user_id AND y.produit = x.produit AND y.id <> x.id
                   AND y.cible IS NOT DISTINCT FROM x.cible AND y.statut = 'paye' AND y.paye_le <= x.paye_le);
  END IF;
  RETURN jsonb_build_object('ok', true, 'achat', x.id, 'user', x.user_id, 'produit', x.produit, 'libelle', p.libelle, 'nature', p.nature,
    'intervalle', p.intervalle, 'montant_centimes', x.montant_centimes, 'langue', x.langue, 'mode_vente', x.mode_vente,
    'renonciation', x.renonciation_retractation_le IS NOT NULL, 'envoyer_courriel', x.email_confirmation_le IS NULL,
    'doublon', v_doublon, 'ref_fournisseur', x.ref_fournisseur, 'ref_paiement', coalesce(x.ref_paiement, nullif(p_ref_paiement, '')),
    'abonnement_ref', a.ref_fournisseur); /* paiement_stripe_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.premium_achat_courriel_noter_service(p_achat uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  UPDATE public.premium_achats SET email_confirmation_le = now() WHERE id = p_achat AND email_confirmation_le IS NULL;
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

-- Remboursement notifié par Stripe pour un paiement à l'unité ou une option (référence du paiement).
CREATE OR REPLACE FUNCTION public.premium_achat_rembourser_paiement_service(p_ref_paiement text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x public.premium_achats;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO x FROM public.premium_achats WHERE ref_paiement = p_ref_paiement;
  IF x.id IS NULL OR x.ref_fournisseur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_inconnu'); END IF;
  RETURN public.premium_achat_rembourser_service(x.ref_fournisseur);
END $function$;

-- 10. Abonnement : lecture (fiche du compte), résiliation, remboursement.
CREATE OR REPLACE FUNCTION public.premium_abonnement_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); a public.premium_abonnements; v_remb text; v_jours integer;
BEGIN
  IF u IS NULL OR public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO a FROM public.premium_abonnements WHERE user_id = u AND statut IN ('actif', 'annule') AND fin > now() ORDER BY fin DESC LIMIT 1;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', true, 'abonne', false); END IF;
  v_remb := public.premium_abonnement_remboursable_interne(a.id);
  v_jours := greatest(14, coalesce(public.premium_param_interne('remboursement_abonnement_jours', '14')::integer, 14));
  RETURN jsonb_build_object('ok', true, 'abonne', true, 'intervalle', coalesce(a.intervalle, 'month'), 'fin', a.fin,
    'annule', a.statut = 'annule', 'mode_vente', a.mode_vente, 'resiliable', a.statut = 'actif' AND a.ref_fournisseur IS NOT NULL,
    'remboursable', v_remb IS NULL, 'raison_non_remboursable', v_remb,
    'remboursable_jusqu_au', a.premier_paiement_le + make_interval(days => v_jours)); /* paiement_stripe_v1 */
END $function$;

-- Le joueur (son jeton) demande une action : le serveur obtient la référence Stripe de SON abonnement, si l'action est permise.
CREATE OR REPLACE FUNCTION public.premium_abonnement_action_preparer(p_action text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u uuid := auth.uid(); a public.premium_abonnements; v_remb text;
BEGIN
  IF u IS NULL OR public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(p_action, '') NOT IN ('resilier', 'rembourser') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  SELECT * INTO a FROM public.premium_abonnements WHERE user_id = u AND statut IN ('actif', 'annule') AND fin > now() ORDER BY fin DESC LIMIT 1;
  IF a.id IS NULL OR a.ref_fournisseur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_abonnement'); END IF;
  IF p_action = 'resilier' AND a.statut = 'annule' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_resilie', 'fin', a.fin); END IF;
  IF p_action = 'rembourser' THEN
    v_remb := public.premium_abonnement_remboursable_interne(a.id);
    IF v_remb IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', v_remb); END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'ref', a.ref_fournisseur, 'fournisseur', a.fournisseur, 'fin', a.fin, 'user', u); /* paiement_stripe_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.premium_abonnement_resilier_service(p_user uuid, p_ref text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.premium_abonnements;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT * INTO a FROM public.premium_abonnements WHERE ref_fournisseur = p_ref AND user_id = p_user FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_abonnement'); END IF;
  IF a.statut = 'annule' THEN RETURN jsonb_build_object('ok', true, 'deja', true, 'fin', a.fin); END IF;
  IF a.statut <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_abonnement'); END IF;
  -- Effet à la fin de la période payée : l'abonnement « annulé » reste actif jusqu'à sa fin (premium_abonne_interne).
  UPDATE public.premium_abonnements SET statut = 'annule', resiliation_demandee_le = now(), maj_le = now() WHERE id = a.id;
  RETURN jsonb_build_object('ok', true, 'fin', a.fin); /* paiement_stripe_v1 */
END $function$;

-- p_motif : 'demande_14_jours' (conditions revérifiées) ou 'doublon' (débit en double, toujours remboursé).
CREATE OR REPLACE FUNCTION public.premium_abonnement_rembourser_service(p_user uuid, p_ref text, p_motif text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.premium_abonnements; v_remb text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF coalesce(p_motif, '') NOT IN ('demande_14_jours', 'doublon') THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_invalide'); END IF;
  SELECT * INTO a FROM public.premium_abonnements WHERE ref_fournisseur = p_ref AND user_id = p_user FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_abonnement'); END IF;
  IF a.remboursement_demande_le IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'deja', true); END IF;
  IF p_motif = 'demande_14_jours' THEN
    v_remb := public.premium_abonnement_remboursable_interne(a.id);
    IF v_remb IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', v_remb); END IF;
  END IF;
  UPDATE public.premium_abonnements SET statut = 'expire', fin = least(fin, now()), remboursement_demande_le = now(), maj_le = now() WHERE id = a.id;
  UPDATE public.premium_achats SET statut = 'rembourse', rembourse_le = now() WHERE id = a.achat_id AND statut = 'paye';
  RETURN jsonb_build_object('ok', true); /* paiement_stripe_v1 */
END $function$;

-- 11. Rappel des abonnements annuels (traitement de nuit, api/cron-minuit.js) : au plus tard 30 jours avant le renouvellement.
CREATE OR REPLACE FUNCTION public.premium_rappels_annuels_service()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jours integer := greatest(30, coalesce(public.premium_param_interne('rappel_annuel_jours', '35')::integer, 35));
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  RETURN jsonb_build_object('ok', true, 'rappels', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'email', a.email_facturation,
      'langue', a.langue, 'fin', a.fin, 'mode_vente', a.mode_vente, 'montant_centimes', x.montant_centimes) ORDER BY a.fin), '[]'::jsonb)
    FROM public.premium_abonnements a LEFT JOIN public.premium_achats x ON x.id = a.achat_id
   WHERE a.intervalle = 'year' AND a.statut = 'actif' AND a.fin > now() AND a.fin <= now() + make_interval(days => v_jours)
     AND a.email_facturation IS NOT NULL AND a.rappel_envoye_pour IS DISTINCT FROM a.fin)); /* paiement_stripe_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.premium_rappel_noter_service(p_id uuid, p_fin timestamptz)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  UPDATE public.premium_abonnements SET rappel_envoye_pour = p_fin WHERE id = p_id;
  RETURN jsonb_build_object('ok', FOUND);
END $function$;

-- 12. Réglages MJ du paiement.
CREATE OR REPLACE FUNCTION public.premium_admin_paiement_fixer(p_cle text, p_valeur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v text := btrim(coalesce(p_valeur, ''));
BEGIN
  PERFORM public.admin_exiger();
  IF p_cle IN ('paiement_mp_actif', 'paiement_mp_pour_ue') THEN
    IF v NOT IN ('0', '1') THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSIF p_cle IN ('paiement_pays_ue', 'paiement_pays_exclus') THEN
    v := upper(replace(v, ' ', ''));
    IF v <> '' AND v !~ '^[A-Z]{2}(,[A-Z]{2})*$' THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSIF p_cle = 'vendeur_editeur_nom' THEN
    IF length(v) > 160 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSIF p_cle = 'cgv_url' THEN
    IF v <> '' AND (length(v) > 300 OR v !~ '^(https://[^\s"<>]+|/[^\s"<>]*)$') THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSIF p_cle = 'remboursement_abonnement_jours' THEN
    IF v !~ '^[0-9]{1,2}$' OR v::integer NOT BETWEEN 14 AND 60 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSIF p_cle = 'rappel_annuel_jours' THEN
    IF v !~ '^[0-9]{1,2}$' OR v::integer NOT BETWEEN 30 AND 60 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'reglage_inconnu');
  END IF;
  INSERT INTO public.premium_parametres (cle, valeur, maj_le) VALUES (p_cle, v, now())
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur, maj_le = now();
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'premium_paiement', jsonb_build_object('cle', p_cle, 'valeur', v), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true); /* paiement_stripe_v1 */
END $function$;

-- 13. Remplacements contrôlés.
-- Abonnement annuel : un an au lieu d'un mois à la confirmation (la date exacte suit ensuite les événements de Stripe).
SELECT pg_temp.rp_remplacer('public.premium_achat_confirmer_service(uuid,text,text,integer,text)'::regprocedure,
  $a$greatest(coalesce(v_fin, now()), now()) + interval '1 month'$a$,
  $b$greatest(coalesce(v_fin, now()), now()) + CASE WHEN p.intervalle = 'year' THEN interval '1 year' ELSE interval '1 month' END /* paiement_stripe_v1 */$b$,
  'paiement_stripe_v1');

-- La préparation d'un achat rend aussi la durée de l'abonnement (mensuel ou annuel) au serveur de paiement.
SELECT pg_temp.rp_remplacer('public.premium_achat_preparer(text,text)'::regprocedure,
  $a$'montant_centimes', p.prix_centimes, 'devise', 'EUR'); /* premium_socle_v1 */$a$,
  $b$'montant_centimes', p.prix_centimes, 'devise', 'EUR', 'intervalle', p.intervalle); /* premium_socle_v1 */ /* paiement_stripe_v1 */$b$,
  'paiement_stripe_v1');

-- Ce qui est activé pendant l'abonnement reste acquis ; tout usage d'une option par l'abonnement est noté (remboursement).
SELECT pg_temp.rp_remplacer('public.premium_option_source_interne(uuid,text,text)'::regprocedure,
  $a$    RETURN 'abonnement'; END IF;$a$,
  $b$    -- paiement_stripe_v1 (Fred, 28/11/2026) : un avantage de l'abonnement est utilisé ; l'activation d'un lieu reste acquise.
    UPDATE public.premium_abonnements SET avantage_utilise_le = coalesce(avantage_utilise_le, now())
     WHERE user_id = p_user AND statut IN ('actif', 'annule') AND fin > now();
    IF p_cible IS NOT NULL AND p_produit IN ('bureau_six', 'personnalisation_local', 'commerce_premium') THEN
      INSERT INTO public.premium_droits (user_id, produit, cible, source, note)
      VALUES (p_user, p_produit, p_cible, 'abonnement', 'Activé pendant l''abonnement : acquis.');
      RETURN 'acquis_abonnement';
    END IF;
    RETURN 'abonnement'; END IF;$b$,
  'paiement_stripe_v1');

-- 14. Droits d'exécution.
REVOKE ALL ON FUNCTION public.premium_liste_interne(text, text), public.premium_abonnement_avantage_interne(uuid),
  public.premium_abonnement_remboursable_interne(uuid), public.premium_paiement_contexte_service(text),
  public.premium_achat_consentir_service(uuid, boolean, boolean, text, text, text), public.premium_achat_paiement_noter_service(uuid, text, text, text),
  public.premium_achat_courriel_noter_service(uuid), public.premium_achat_rembourser_paiement_service(text),
  public.premium_abonnement_resilier_service(uuid, text), public.premium_abonnement_rembourser_service(uuid, text, text),
  public.premium_rappels_annuels_service(), public.premium_rappel_noter_service(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.premium_paiement_contexte_service(text),
  public.premium_achat_consentir_service(uuid, boolean, boolean, text, text, text), public.premium_achat_paiement_noter_service(uuid, text, text, text),
  public.premium_achat_courriel_noter_service(uuid), public.premium_achat_rembourser_paiement_service(text),
  public.premium_abonnement_resilier_service(uuid, text), public.premium_abonnement_rembourser_service(uuid, text, text),
  public.premium_rappels_annuels_service(), public.premium_rappel_noter_service(uuid, timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.premium_abonnement_lire(), public.premium_abonnement_action_preparer(text), public.premium_admin_paiement_fixer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.premium_abonnement_lire(), public.premium_abonnement_action_preparer(text), public.premium_admin_paiement_fixer(text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
