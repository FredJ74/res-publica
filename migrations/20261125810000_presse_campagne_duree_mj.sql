-- Mission de fin de soirée du 25/11/2026 (Claude), point 2.4 — NON APPLIQUÉE. Après 20261125700000 (premium, appliquée).
-- Choix tranché : les publicités de joueurs suivent un seul modèle, « une campagne à la fois par support, durée réglée par le
-- MJ » (premium_parametres.publicite_joueur_duree_jours, 7 par défaut, 1 à 60). Les formules « 5 / 10 parutions » de
-- l'atelier de presse disparaissent :
-- • publicites_premium_presse : la colonne formule n'a plus de valeur imposée (« campagne » pour les nouvelles ; les deux
--   lignes existantes gardent la leur) ; nb_parutions porte la durée de la campagne, fixée à la création ; la contrainte
--   programmation_payee ne dépend plus de la formule (dernière parution = première + nb_parutions − 1, ou, pour une ligne
--   ancienne sans durée, 5 / 10 parutions comme avant).
-- • publicite_premium_creer_beta : p_formule est ignoré (signature gardée pour l'écran) ; une seule campagne de presse à la
--   fois par compte (brouillon, aperçu ou parution en cours ou à venir) : refus « Campagne de presse déjà en cours ».
--   Remplacement contrôlé (marque presse_campagne_v1).
-- • La fonction publicite-premium (supabase/edge-functions/publicite-premium) programme la campagne sur nb_parutions jours
--   (repli : 5 / 10 selon l'ancienne formule) ; elle est à redéployer après cette migration.
-- Sans cette migration : comportement actuel (l'écran envoie encore « cinq », accepté par l'ancienne fonction).
--
-- Contrôles en lecture après application :
--   SELECT position('campagne' in pg_get_constraintdef(oid)) > 0 FROM pg_constraint WHERE conname = 'publicites_premium_presse_formule_check';  -- vrai
--   SELECT position('nb_parutions' in pg_get_constraintdef(oid)) > 0 FROM pg_constraint WHERE conname = 'programmation_payee';                     -- vrai
--   SELECT position('presse_campagne_v1' in pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) > 0;  -- vrai
--   SELECT count(*) FROM public.publicites_premium_presse WHERE formule NOT IN ('cinq', 'dix', 'campagne');               -- 0
BEGIN;

ALTER TABLE public.publicites_premium_presse DROP CONSTRAINT IF EXISTS publicites_premium_presse_formule_check;
ALTER TABLE public.publicites_premium_presse ADD CONSTRAINT publicites_premium_presse_formule_check
  CHECK (formule IN ('cinq', 'dix', 'campagne')) NOT VALID;
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

SELECT pg_temp.rp_remplacer_n('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure,
  ARRAY[$a$ IF p_formule NOT IN ('cinq','dix') THEN RAISE EXCEPTION 'Formule invalide'; END IF;$a$,
        $a$ IF public.premium_option_source_interne(auth.uid(), 'publicite_joueur', NULL) IS NULL$a$,
        $a$ INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,p_formule,0,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon') RETURNING id INTO v_id;$a$],
  ARRAY[$b$ -- p_formule ignoré : une campagne à la fois, durée réglée par le MJ (presse_campagne_v1).$b$,
        $b$ IF EXISTS (SELECT 1 FROM public.publicites_premium_presse x WHERE x.acheteur_user_id = auth.uid() AND x.retiree_le IS NULL
              AND (x.etat IN ('brouillon', 'paiement_en_attente', 'payee', 'en_generation', 'apercu', 'validee')
                   OR (x.etat = 'programmee' AND x.derniere_parution >= (now() AT TIME ZONE 'Europe/Paris')::date))) THEN
   RAISE EXCEPTION 'Campagne de presse déjà en cours'; END IF; /* presse_campagne_v1 */
 IF public.premium_option_source_interne(auth.uid(), 'publicite_joueur', NULL) IS NULL$b$,
        $b$ INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,nb_parutions,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,'campagne',
        greatest(1, least(60, coalesce(nullif(public.premium_param_interne('publicite_joueur_duree_jours', '7'), '')::integer, 7))),
        0,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon') RETURNING id INTO v_id; /* presse_campagne_v1 */$b$],
  ARRAY[1, 1, 1], 'presse_campagne_v1');

COMMIT;
