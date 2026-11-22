-- Santé — socle commun (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md).
-- Le serveur décide de tout. Toutes les valeurs chiffrées sont dans sante_parametres, réglables par un MJ.
-- Ce socle ne modifie AUCUNE Santé actuelle (point 16) et ne branche encore aucun gain ni aucune perte :
-- les migrations suivantes (combat, consommation, maladies, médecin) appellent ces fonctions.
--
--  • sante_parametres (cle, valeur, groupe, libelle) + sante_param(cle, défaut).
--  • sante_facteur_robustesse(hp) : 1,3 à 0, 1,0 à 50, 0,8 à 100, linéaire (point 1).
--  • sante_perte_combat_interne(hp, perte) : perte × facteur, arrondie, au moins 1 si le coup touche (point 1).
--  • sante_modulation_moral(moral) : ×1,5 dès 75, ×1 de 25 à 74, ×0,5 sous 25 (point 11).
--  • sante_gagner_interne(nom, gain, source, détails) : gain modulé par le Moral ; perte (gain < 0) jamais modulée ;
--    bornes 0 et sante_max. sante_perdre_interne(nom, perte, source) : perte brute, plancher 0.
--  • personnage_evenements + personnage_evenement_ajouter_interne + RPC personnage_evenements_lire : journal
--    d'événements du joueur écrit par le serveur (jamais par courrier), lu par le navigateur et prévenu en direct.
--  • sante_reveil_interne(nom) : point d'accroche appelé au réveil (Dormir) ; vide ici, la migration des maladies
--    y branche la révélation de la MST.
--  • admin_sante_parametres_lire / admin_sante_parametre_fixer (MJ, journalisé).
-- Rejouable. Rien du goulag.

CREATE TABLE IF NOT EXISTS public.sante_parametres (
  cle text PRIMARY KEY,
  valeur numeric NOT NULL,
  groupe text NOT NULL DEFAULT 'general',
  libelle text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);
ALTER TABLE public.sante_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sante_parametres FROM PUBLIC, anon, authenticated;

INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('sante_max', 100, 'general', 'Santé maximale'),
  ('robustesse_f0', 1.3, 'combat', 'Facteur de perte de PA à Santé 0'),
  ('robustesse_f50', 1.0, 'combat', 'Facteur de perte de PA à Santé 50'),
  ('robustesse_f100', 0.8, 'combat', 'Facteur de perte de PA à Santé 100'),
  ('blessure_sante_par_pa', 1, 'combat', 'Santé perdue par PA perdu en combat'),
  ('moral_seuil_haut', 75, 'moral', 'Moral à partir duquel les gains de Santé sont majorés'),
  ('moral_seuil_bas', 25, 'moral', 'Moral sous lequel les gains de Santé sont réduits'),
  ('moral_mult_haut', 1.5, 'moral', 'Multiplicateur des gains (Moral haut)'),
  ('moral_mult_moyen', 1, 'moral', 'Multiplicateur des gains (Moral moyen)'),
  ('moral_mult_bas', 0.5, 'moral', 'Multiplicateur des gains (Moral bas)'),
  ('alcool_verre_1', 1, 'alcool', 'Santé du 1er verre alcoolisé du jour'),
  ('alcool_verre_2', 0, 'alcool', 'Santé du 2e verre alcoolisé du jour'),
  ('alcool_verre_3_et_plus', -2, 'alcool', 'Santé de chaque verre alcoolisé à partir du 3e'),
  ('sommeil_chambre', 5, 'sommeil', 'Dormir dans une chambre (chez soi, hôtel)'),
  ('sommeil_batiment', 3, 'sommeil', 'Dormir dans un bâtiment hors chambre'),
  ('sommeil_dehors', 2, 'sommeil', 'Dormir dehors (rue, plein air)'),
  ('sommeil_hopital', 5, 'sommeil', 'Dormir à l''hôpital public ou au dispensaire'),
  ('sommeil_clinique', 7, 'sommeil', 'Dormir à la clinique privée'),
  ('repas_menu_sante', 5, 'repas', 'Menu gastronomique : Santé'),
  ('repas_menu_pa', 3, 'repas', 'Menu gastronomique : PA différés'),
  ('repas_plat_sante', 4, 'repas', 'Plat du jour : Santé'),
  ('repas_plat_pa', 2, 'repas', 'Plat du jour : PA différés'),
  ('repas_sandwich_sante', 3, 'repas', 'Sandwich, tartine de salo : Santé'),
  ('repas_sandwich_pa', 1, 'repas', 'Sandwich, tartine de salo : PA différés'),
  ('repas_petitdej_sante', 2, 'repas', 'Petit-déjeuner : Santé'),
  ('repas_petitdej_pa', 1, 'repas', 'Petit-déjeuner : PA différés'),
  ('repas_snack_sante', 1, 'repas', 'Snack : Santé'),
  ('repas_snack_pa', 0, 'repas', 'Snack : PA différés'),
  ('repas_joueur_p5_sante', 3, 'repas', 'Produit de joueur, palier 5 à 9,99 : Santé'),
  ('repas_joueur_p5_pa', 1, 'repas', 'Produit de joueur, palier 5 à 9,99 : PA différés'),
  ('repas_joueur_p10_sante', 4, 'repas', 'Produit de joueur, palier 10 à 14,99 : Santé'),
  ('repas_joueur_p10_pa', 2, 'repas', 'Produit de joueur, palier 10 à 14,99 : PA différés'),
  ('soin_public_sante', 8, 'soins', 'Soin public au dispensaire : Santé'),
  ('soin_public_pa', 1, 'soins', 'Soin public au dispensaire : PA'),
  ('soin_clinique_sante', 15, 'soins', 'Soin à la clinique privée : Santé'),
  ('soin_clinique_pa', 2, 'soins', 'Soin à la clinique privée : PA'),
  ('soin_urgence_sante', 25, 'soins', 'Soins accélérés (urgence) : Santé'),
  ('soin_sans_trace_sante', 15, 'soins', 'Soins sans trace : Santé'),
  ('medecin_diagnostic_pa', 1, 'medecin', 'Médecin : PA d''un diagnostic'),
  ('medecin_soin_pa', 2, 'medecin', 'Médecin : PA d''un soin'),
  ('medecin_soin_sante', 12, 'medecin', 'Médecin : Santé rendue par un soin'),
  ('mst_fenetre_jours', 10, 'maladies', 'MST : fenêtre glissante (jours)'),
  ('mst_seuil_partenaires', 2, 'maladies', 'MST : nombre d''escorts différentes à partir duquel il y a un risque'),
  ('mst_risque_par_partenaire', 0.15, 'maladies', 'MST : risque par partenaire au-delà du premier')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sante_param(p_cle text, p_defaut numeric)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce((SELECT valeur FROM public.sante_parametres WHERE cle = p_cle), p_defaut) /* sante_socle_v1 */ $function$;

CREATE OR REPLACE FUNCTION public.sante_facteur_robustesse(p_hp integer)
 RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE h numeric := least(100, greatest(0, coalesce(p_hp, 100)));
        f0 numeric := public.sante_param('robustesse_f0', 1.3); f50 numeric := public.sante_param('robustesse_f50', 1.0);
        f100 numeric := public.sante_param('robustesse_f100', 0.8);
BEGIN
  IF h <= 50 THEN RETURN f0 + (f50 - f0) * h / 50; END IF;
  RETURN f50 + (f100 - f50) * (h - 50) / 50; /* sante_socle_v1 */
END $function$;

-- Perte de PA d'un coup après robustesse : arrondie, au moins 1 si le coup touche (perte brute > 0).
CREATE OR REPLACE FUNCTION public.sante_perte_combat_interne(p_hp integer, p_perte integer)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN coalesce(p_perte, 0) <= 0 THEN 0
              ELSE greatest(1, round(p_perte * public.sante_facteur_robustesse(p_hp))::integer) END /* sante_socle_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.sante_modulation_moral(p_moral integer)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN coalesce(p_moral, 50) >= public.sante_param('moral_seuil_haut', 75) THEN public.sante_param('moral_mult_haut', 1.5)
              WHEN coalesce(p_moral, 50) < public.sante_param('moral_seuil_bas', 25) THEN public.sante_param('moral_mult_bas', 0.5)
              ELSE public.sante_param('moral_mult_moyen', 1) END /* sante_socle_v1 */
$function$;

-- Gain (ou perte si p_gain < 0) de Santé. Un gain est modulé par le Moral et arrondi ; une perte ne l'est jamais.
CREATE OR REPLACE FUNCTION public.sante_gagner_interne(p_nom text, p_gain integer, p_source text, p_details jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_hp integer; v_moral integer; v_max integer := public.sante_param('sante_max', 100)::integer; v_mult numeric := 1;
        v_gain integer; v_apres integer;
BEGIN
  SELECT coalesce(hp, v_max), coalesce(moral, 50) INTO v_hp, v_moral FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF coalesce(p_gain, 0) > 0 THEN
    v_mult := public.sante_modulation_moral(v_moral);
    v_gain := round(p_gain * v_mult)::integer;
  ELSE
    v_gain := coalesce(p_gain, 0);
  END IF;
  v_apres := least(v_max, greatest(0, v_hp + v_gain));
  IF v_apres <> v_hp THEN
    UPDATE public.personnages_donnees SET hp = v_apres WHERE name = p_nom;
  END IF;
  RETURN jsonb_build_object('ok', true, 'source', p_source, 'avant', v_hp, 'apres', v_apres, 'brut', coalesce(p_gain, 0),
    'multiplicateur', v_mult, 'gain', v_apres - v_hp, 'moral', v_moral) || coalesce(p_details, '{}'::jsonb); /* sante_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.sante_perdre_interne(p_nom text, p_perte integer, p_source text, p_details jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT public.sante_gagner_interne(p_nom, -abs(coalesce(p_perte, 0)), p_source, p_details) /* sante_socle_v1 */ $function$;

-- Journal d'événements du joueur, écrit par le serveur.
CREATE TABLE IF NOT EXISTS public.personnage_evenements (
  id bigserial PRIMARY KEY,
  destinataire text NOT NULL,
  cle text NOT NULL,
  texte text NOT NULL DEFAULT '',
  params jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  lu_le timestamptz
);
CREATE INDEX IF NOT EXISTS personnage_evenements_non_lus ON public.personnage_evenements (destinataire, id) WHERE lu_le IS NULL;
ALTER TABLE public.personnage_evenements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.personnage_evenements FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.personnage_evenement_ajouter_interne(p_dest text, p_cle text, p_texte text, p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id bigint;
BEGIN
  IF p_dest IS NULL THEN RETURN NULL; END IF;
  INSERT INTO public.personnage_evenements (destinataire, cle, texte, params)
  VALUES (p_dest, p_cle, coalesce(p_texte, ''), coalesce(p_params, '{}'::jsonb)) RETURNING id INTO v_id;
  IF to_regprocedure('public.personnage_signaler_interne(text)') IS NOT NULL THEN
    PERFORM public.personnage_signaler_interne(p_dest);
  END IF;
  RETURN v_id; /* sante_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.personnage_evenements_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); r jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  WITH u AS (
    UPDATE public.personnage_evenements SET lu_le = now() WHERE destinataire = a AND lu_le IS NULL
    RETURNING id, cle, texte, params, cree_le)
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'cle', cle, 'texte', texte, 'params', params, 'ts', cree_le) ORDER BY id), '[]'::jsonb)
    INTO r FROM u;
  RETURN jsonb_build_object('ok', true, 'evenements', r); /* sante_socle_v1 */
END $function$;

-- Point d'accroche du réveil : la migration des maladies y branche la révélation de la MST.
CREATE OR REPLACE FUNCTION public.sante_reveil_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ BEGIN RETURN '[]'::jsonb; /* sante_socle_v1 : vide */ END $function$;

CREATE OR REPLACE FUNCTION public.admin_sante_parametres_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'parametres', (SELECT coalesce(jsonb_agg(jsonb_build_object('cle', cle, 'valeur', valeur, 'groupe', groupe,
    'libelle', libelle, 'maj', updated_at) ORDER BY groupe, cle), '[]'::jsonb) FROM public.sante_parametres)); /* sante_socle_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_sante_parametre_fixer(p_cle text, p_valeur numeric)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant numeric;
BEGIN
  PERFORM public.admin_exiger();
  IF p_valeur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  SELECT valeur INTO v_avant FROM public.sante_parametres WHERE cle = p_cle FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametre_inconnu'); END IF;
  UPDATE public.sante_parametres SET valeur = p_valeur, updated_at = now(), updated_by = auth.uid() WHERE cle = p_cle;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'sante_parametre_fixer', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), jsonb_build_object('avant', v_avant), true);
  RETURN jsonb_build_object('ok', true, 'cle', p_cle, 'avant', v_avant, 'valeur', p_valeur); /* sante_socle_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.sante_param(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_facteur_robustesse(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_perte_combat_interne(integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_modulation_moral(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_gagner_interne(text, integer, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_perdre_interne(text, integer, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnage_evenement_ajouter_interne(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_reveil_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnage_evenements_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.personnage_evenements_lire() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_sante_parametres_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_sante_parametres_lire() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_sante_parametre_fixer(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_sante_parametre_fixer(text, numeric) TO authenticated, service_role;
