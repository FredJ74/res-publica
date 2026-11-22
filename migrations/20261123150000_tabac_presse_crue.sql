-- TABAC-PRESSE DE KRASNOV ET CRUE — décisions de Fred du 22/11/2026 (soir), GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md,
-- parties E (points 27 à 29) et F (points 30 à 32). Écrite à partir des définitions de PRODUCTION (pg_get_functiondef
-- du 22/11/2026, soir) ; chaque ancrage est compté (remplacement contrôlé, marque unique). Rejouable, sans BEGIN/COMMIT.
--
-- PARTIE E
--  27. Cigarettes papirossy « Étoile du Nord » : déposées dans l'inventaire par la vente (famille de produit « tabac »),
--      fumées quand on veut par inventaire_consommer (même entonnoir serveur que les chocolats et aliments à emporter),
--      +2 Moral (réglage aliments_parametres.papirossy_moral).
--  28. Carte postale : nouvelle RPC carte_postale_envoyer (le serveur écrit la carte une seule fois : message, signature
--      de l'expéditeur, date ; la carte part au sas objets_recus du destinataire, plafond commun des dons) ;
--      inventaire_donner n'accepte plus les champs d'écriture d'une carte dans ses mutations (une carte ne s'écrit plus par
--      le navigateur) ; souvenir_utilisable_interne (critère des armoires à souvenirs) accepte les cartes, vierges ou
--      écrites, et les revues lues ; description « sous la pluie d'automne ».
--  29. Revue « Chasse, Pêche & Tracteurs » : +1 ENT pendant 24 h à partir de l'achat (réglages revue_ent_bonus,
--      revue_ent_heures), non cumulable (un nouvel achat pendant le bonus ne l'augmente ni ne le prolonge) ; la revue
--      reste dans l'inventaire, lue, avec le numéro du mois. Elle ne porte plus de bonus d'intégration permanent.
-- Aucune donnée de joueur modifiée (la carte vierge déjà achetée par Arnie garde son ancienne description).

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;
-- Deux ancrages remplacés dans une même réécriture (une parenthèse ouverte par l'un est fermée par l'autre).
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer_deux(p_fn regprocedure, p_avant1 text, p_apres1 text, p_avant2 text, p_apres2 text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n1 integer; n2 integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n1 := (length(d) - length(replace(d, p_avant1, ''))) / length(p_avant1);
  n2 := (length(d) - length(replace(d, p_avant2, ''))) / length(p_avant2);
  IF n1 <> 1 OR n2 <> 1 THEN RAISE EXCEPTION '% : ancrages % et % au lieu de 1 et 1', p_fn, n1, n2; END IF;
  EXECUTE replace(replace(d, p_avant1, p_apres1), p_avant2, p_apres2);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- E.0 Réglages (MJ : table aliments_parametres)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.aliments_parametres (cle, valeur) VALUES
  ('papirossy_moral', 2), ('revue_ent_bonus', 1), ('revue_ent_heures', 24), ('carte_postale_message_max', 500)
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- E.1 Catalogue du tabac-presse de Krasnov
-- ---------------------------------------------------------------------------------------------------------------
UPDATE public.recettes_commerce
   SET label = 'Cigarettes papirossy « Étoile du Nord »', famille_produit_marche = 'tabac', categorie = 'objet', effets = NULL,
       description = 'Cigarettes à bout de carton roulées avec la makhorka du kolkhoze. On les garde sur soi et on les fume quand on veut, en regardant passer les tracteurs.'
 WHERE id = 'krasnov_papirossy';
UPDATE public.recettes_commerce
   SET description = 'La statue de l''Ours, ses bancs et la mairie, sous la pluie d''automne. À écrire et à envoyer.'
 WHERE id = 'carte_krasnov_place_ours';
UPDATE public.recettes_commerce SET bonus_integration_ville = NULL WHERE id = 'revue_chasse_peche_tracteurs';

-- ---------------------------------------------------------------------------------------------------------------
-- E.2 Revue : bonus d'ENT de 24 h, non cumulable
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revue_bonus_appliquer_interne(p_acteur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_now numeric := floor(extract(epoch FROM clock_timestamp()) * 1000); v_eff jsonb; v_actif jsonb; v_fin numeric;
BEGIN
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff
    FROM public.personnages_donnees p, jsonb_array_elements(coalesce(p.effets_actifs, '[]'::jsonb)) e
   WHERE p.name = p_acteur AND jsonb_typeof(e) = 'object' AND coalesce((e->>'expireA')::numeric, 0) > v_now;
  SELECT e INTO v_actif FROM jsonb_array_elements(v_eff) e WHERE e->>'cle' = 'revue_chasse_peche_ent' LIMIT 1;
  IF v_actif IS NOT NULL THEN  -- ni augmenté ni prolongé
    RETURN jsonb_build_object('applique', false, 'expireA', v_actif->'expireA');
  END IF;
  v_fin := v_now + public.aliments_param_interne('revue_ent_heures', 24) * 3600 * 1000;
  v_eff := v_eff || jsonb_build_array(jsonb_build_object('cle', 'revue_chasse_peche_ent', 'cible', 'pj',
    'deltas', jsonb_build_object('ENT', public.aliments_param_interne('revue_ent_bonus', 1)),
    'libelle', 'Revue « Chasse, Pêche & Tracteurs »', 'poseA', v_now, 'expireA', v_fin));
  UPDATE public.personnages_donnees SET effets_actifs = v_eff, updated_at = now() WHERE name = p_acteur;
  RETURN jsonb_build_object('applique', true, 'expireA', v_fin);
END $function$;

-- Exemplaire livré par la vente (commerce_vendre_produit_interne) : la revue porte le numéro du mois, elle est lue
-- (le bonus part de l'achat) ; les autres produits passent inchangés.
CREATE OR REPLACE FUNCTION public.produit_marche_livrer_interne(p_acteur text, p_objet jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_mois text; v_b jsonb;
BEGIN
  IF coalesce(p_objet->>'type', '') = 'revue_chasse_peche_tracteurs' THEN
    v_mois := (ARRAY['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'])
              [extract(month FROM v_jour)::integer] || ' ' || extract(year FROM v_jour)::integer;
    v_b := public.revue_bonus_appliquer_interne(p_acteur);
    RETURN (p_objet - 'bonusIntegrationVille') || jsonb_build_object(
      'name', coalesce(p_objet->>'name', 'Revue') || ' — numéro de ' || v_mois,
      'numero', to_char(v_jour, 'YYYY-MM'), 'numeroLibelle', v_mois, 'lue', true, 'souvenir', true,
      'bonusEntApplique', coalesce((v_b->>'applique')::boolean, false));
  END IF;
  IF coalesce(p_objet->>'familleProduitMarche', '') = 'carte_postale' THEN
    RETURN p_objet || jsonb_build_object('souvenir', true);
  END IF;
  RETURN p_objet;
END $function$;

-- Une seule jonction dans la vente commune : l'objet déposé passe par produit_marche_livrer_interne.
SELECT pg_temp.rp_remplacer_deux('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure,
  $a$        v_r := public.inventaire_deposer_interne(p_acteur, jsonb_strip_nulls(jsonb_build_object($a$,
  $b$        v_r := public.inventaire_deposer_interne(p_acteur, public.produit_marche_livrer_interne(p_acteur, jsonb_strip_nulls(jsonb_build_object( /* produit_marche_livrer_v1 */$b$,
  $a$'bonusIntegrationVille', v_ligne -> 'bonusIntegrationVille')), true);$a$,
  $b$'bonusIntegrationVille', v_ligne -> 'bonusIntegrationVille'))), true); /* produit_marche_livrer_fin_v1 */$b$,
  'produit_marche_livrer_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- E.3 Cigarettes : fumées depuis l'inventaire (inventaire_consommer), +2 Moral
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tabac_fumer_interne(p_acteur text, p_item jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_gain integer := greatest(0, public.aliments_param_interne('papirossy_moral', 2)::integer); v_moral integer;
BEGIN
  UPDATE public.personnages_donnees SET moral = least(100, greatest(0, coalesce(moral, 0) + v_gain)), updated_at = now()
   WHERE name = p_acteur RETURNING moral INTO v_moral;
  RETURN jsonb_build_object('tabac', true, 'moral', v_moral, 'effets', jsonb_build_object('moral', v_gain));
END $function$;

SELECT pg_temp.rp_remplacer('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$ IF NOT (v_aliment OR v_boisson IS NOT NULL OR coalesce(v_item->>'type','') IN ('medicament','explosif','poison','drogue')) THEN$a$,
  $b$ IF NOT (v_aliment OR v_boisson IS NOT NULL OR coalesce(v_item->>'type','') IN ('medicament','explosif','poison','drogue')
   OR coalesce(v_item->>'familleProduitMarche','') = 'tabac' /* tabac_fumer_v1 */) THEN$b$,
  1, 'tabac_fumer_v1');
SELECT pg_temp.rp_remplacer('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  E' RETURN v_r;\nEND;$function$',
  E' IF coalesce(v_item->>''familleProduitMarche'','''') = ''tabac'' THEN v_r := v_r || public.tabac_fumer_interne(p_acteur, v_item); END IF; /* tabac_fumer_effet_v1 */\n RETURN v_r;\nEND;$function$',
  1, 'tabac_fumer_effet_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- E.4 Carte postale écrite et envoyée par le serveur, une seule fois
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.carte_postale_envoyer(p_acteur text, p_index integer, p_signature jsonb,
  p_destinataire text, p_message text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_pos integer; v_item jsonb; v_r jsonb; v_objet jsonb; v_id text; v_place integer;
        v_msg text := btrim(coalesce(p_message, '')); v_max integer := public.aliments_param_interne('carte_postale_message_max', 500)::integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  IF v_msg = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  IF char_length(v_msg) > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_trop_long', 'max', v_max); END IF;
  SELECT coalesce(inventory, '[]'::jsonb), quete_carriere INTO v_inv, v_quete FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;
  IF coalesce(v_item->>'familleProduitMarche', '') <> 'carte_postale' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_une_carte_postale'); END IF;
  IF coalesce(v_item->>'etatCarte', 'vierge') <> 'vierge' THEN  -- une carte ne s'écrit qu'une fois
    RETURN jsonb_build_object('ok', false, 'raison', 'carte_deja_ecrite'); END IF;
  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, v_pos, p_signature, 1);
  IF NOT coalesce((v_r->>'ok')::boolean, false) THEN RETURN v_r; END IF;
  v_objet := (v_r->'objet') || jsonb_build_object('etatCarte', 'ecrite', 'auteur', p_acteur, 'destinataireInitial', p_destinataire,
    'message', v_msg, 'dateEnvoi', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY à HH24:MI'),
    'envoyeeLe', floor(extract(epoch FROM now()) * 1000), 'bonusDeclenche', false, 'souvenir', true);
  v_place := public.inventaire_place_destinataire_interne(p_destinataire);  -- plafond commun des dons
  IF greatest(1, public.inventaire_unites_interne(jsonb_build_array(v_objet))) > coalesce(v_place, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_plein', 'place', coalesce(v_place, 0), 'destinataire', p_destinataire);
  END IF;
  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data) VALUES (v_id, p_destinataire, p_acteur, to_jsonb(v_objet::text));
  RETURN jsonb_build_object('ok', true, 'objet', v_objet, 'objet_id', v_id, 'destinataire', p_destinataire)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $function$;
REVOKE ALL ON FUNCTION public.carte_postale_envoyer(text, integer, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.carte_postale_envoyer(text, integer, jsonb, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.revue_bonus_appliquer_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.produit_marche_livrer_interne(text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tabac_fumer_interne(text, jsonb) FROM PUBLIC, anon, authenticated;

-- Le don ordinaire ne peut plus écrire une carte (champs d'écriture retirés des mutations du navigateur).
SELECT pg_temp.rp_remplacer('public.inventaire_donner(text,text,integer,jsonb,integer,jsonb)'::regprocedure,
  $a$                         - 'encombrement' - 'type' - 'legal' - 'id';$a$,
  $b$                         - 'encombrement' - 'type' - 'legal' - 'id'
                         - 'etatCarte' - 'auteur' - 'destinataireInitial' - 'message' - 'dateEnvoi' - 'envoyeeLe'
                         - 'bonusDeclenche' - 'familleProduitMarche' - 'modele' - 'lue' - 'souvenir'; /* carte_postale_ecrite_serveur_v1 */$b$,
  1, 'carte_postale_ecrite_serveur_v1');

-- Armoires à souvenirs : critère serveur des objets acceptés (le dépôt dans l'armoire n'est pas encore codé, décision
-- de Fred du 13/11/2026 ; ce critère le prépare).
CREATE OR REPLACE FUNCTION public.souvenir_utilisable_interne(p_acteur text, p_objet jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_objet->>'type' = 'feuille_enigme_krasnov'
              THEN EXISTS (SELECT 1 FROM public.enigmes_resolues WHERE personnage = p_acteur AND enigme = 'krasnov')
              WHEN p_objet->>'familleProduitMarche' = 'carte_postale' THEN true  /* souvenirs_cartes_revues_v1 */
              WHEN p_objet->>'type' = 'revue_chasse_peche_tracteurs' THEN coalesce((p_objet->>'lue')::boolean, false)
              ELSE true END;
$function$;
REVOKE ALL ON FUNCTION public.souvenir_utilisable_interne(text, jsonb) FROM PUBLIC, anon, authenticated;

-- Contrôles de la partie E.
DO $$ BEGIN
  IF position('produit_marche_livrer_fin_v1' IN pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)) = 0
     OR position('tabac_fumer_effet_v1' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR position('carte_postale_ecrite_serveur_v1' IN pg_get_functiondef('public.inventaire_donner(text,text,integer,jsonb,integer,jsonb)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM public.recettes_commerce WHERE id = 'krasnov_papirossy' AND famille_produit_marche = 'tabac') THEN
    RAISE EXCEPTION 'tabac_presse : contrôle de la partie E en échec';
  END IF;
END $$;

-- ===== PARTIE F : CRUE =====
-- GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 30 et 31 (Fred, 22/11/2026, soir). Principe : « un événement climatique peut
-- coûter quelque chose, il ne bloque jamais le jeu d'un joueur ».
--  • Point 30 : la crue arrête seulement les chantiers de sa ville pendant une journée. Le travail des joueurs sur un chantier
--    de la ville est refusé du début de la crue jusqu'à minuit de ce jour-là (climat_chantiers_bloques_interne, appelée par
--    chantier_travailler) ; la nuit qui suit, le chantier n'avance pas : il prend un jour de retard (nouvelle
--    chantier_crue_jour_interne, appelée par UNE ligne dans chantier_jour_traiter, marque crue_chantier_jour_v1). Les deux
--    obéissent au réglage MJ existant climat_parametres.bloque_chantiers de la crue (vrai en production).
--    Plus aucune fermeture de lieu (climat_batiment_inonde_interne → toujours faux ; climat_evenement_json_interne ne
--    renvoie plus de lieux fermés), plus aucune perte de stock (climat_crue_appliquer_interne réécrite), plus de sacs de
--    sable (pose refusée « sacs_retires », vente retirée des boutiques et des consignes). La ligne ordres_couts
--    poser_sacs_sable est gardée (listes en dur inchangées) : la fonction refuse avant tout paiement.
--    Gardés : alerte 48 h avant, filtre de pluie, bandeau clignotant et sa fenêtre ; consigne de la crue réécrite.
--  • Point 31 : état de catastrophe naturelle en sommeil : nouvelle colonne climat_parametres.catastrophe_active (faux),
--    réglable par le MJ (admin_climat_parametre_modifier, marque catastrophe_active_v1) ; catastrophe_proposer,
--    catastrophe_declarer et catastrophe_etat refusent « catastrophe_en_sommeil » tant qu'elle est fausse (marque
--    catastrophe_en_sommeil_v1). Rien n'est supprimé.
-- Aucune donnée de joueur modifiée. Configuration : climat_boutiques (sac retiré ; la boutique Chasse et Pêche de PSM, qui
-- ne vendait que des sacs, est supprimée), climat_lieux_vente (lignes sac_de_sable supprimées). Rejouable.

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer_crue(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $rp$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : ancrage trouvé % fois au lieu de % (%)', p_fn, n, p_n, left(p_avant, 80); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque % absente', p_fn, p_marque; END IF;
END $rp$;

-- 1. Réglage MJ de l'état de catastrophe naturelle (en sommeil par défaut).
ALTER TABLE public.climat_parametres ADD COLUMN IF NOT EXISTS catastrophe_active boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.climat_parametres.catastrophe_active IS
  'Crue : état de catastrophe naturelle proposable et déclarable. En sommeil (faux) depuis le 22/11/2026, intérêt à définir (Fred).';

CREATE OR REPLACE FUNCTION public.catastrophe_active_interne(p_pays text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT coalesce((SELECT c.catastrophe_active FROM public.climat_parametres c WHERE c.type = 'crue' AND c.pays = p_pays), false);
$f$;
REVOKE ALL ON FUNCTION public.catastrophe_active_interne(text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer_crue('public.admin_climat_parametre_modifier(text,text,jsonb)'::regprocedure,
  $a$'preavis_heures', 'bloque_chantiers') THEN$a$,
  $a$'preavis_heures', 'bloque_chantiers', 'catastrophe_active') THEN /* catastrophe_active_v1 */$a$, 1, 'catastrophe_active_v1');
SELECT pg_temp.rp_remplacer_crue('public.admin_climat_parametre_modifier(text,text,jsonb)'::regprocedure,
  $a$    bloque_chantiers = coalesce((p_parametres->>'bloque_chantiers')::boolean, bloque_chantiers)
$a$,
  $a$    bloque_chantiers = coalesce((p_parametres->>'bloque_chantiers')::boolean, bloque_chantiers),
    catastrophe_active = coalesce((p_parametres->>'catastrophe_active')::boolean, catastrophe_active) /* catastrophe_active_set_v1 */
$a$, 1, 'catastrophe_active_set_v1');

DO $do$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.catastrophe_proposer(bigint)', 'public.catastrophe_declarer(bigint,boolean)', 'public.catastrophe_etat(bigint)'] LOOP
    PERFORM pg_temp.rp_remplacer_crue(f::regprocedure,
      $a$  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
$a$,
      $a$  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  IF NOT public.catastrophe_active_interne(e.pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'catastrophe_en_sommeil'); END IF; /* catastrophe_en_sommeil_v1 */
$a$, 1, 'catastrophe_en_sommeil_v1');
  END LOOP;
END $do$;

-- 2. Plus aucune fermeture de lieu : la crue ne ferme rien (navigation_commander_personnage_interne, commune, n'est pas touchée).
CREATE OR REPLACE FUNCTION public.climat_batiment_inonde_interne(p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT false; /* crue_sans_fermeture_v1 : un événement climatique ne bloque jamais le jeu d'un joueur (Fred, 22/11/2026) */
$f$;
-- Les sacs de sable n'existent plus : aucun lieu « protégé ».
CREATE OR REPLACE FUNCTION public.climat_lieu_protege_interne(e public.climat_evenements, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT false; /* crue_sans_sacs_v1 */
$f$;
CREATE OR REPLACE FUNCTION public.climat_evenement_json_interne(e public.climat_evenements)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT jsonb_build_object('id', e.id, 'type', e.type, 'ville', e.ville, 'debut', e.debut, 'fin', e.fin,
    'en_cours', now() >= e.debut AND now() < e.fin,
    'lieux', '[]'::jsonb, 'lieux_proteges', '[]'::jsonb,   -- crue_sans_fermeture_v1 : plus aucun lieu fermé ni protégé
    'chantiers_arretes', e.type = 'crue',
    'consigne', public.climat_consigne_interne(e.type, e.pays, e.ville));
$f$;

-- 3. Plus aucune perte de stock ; le courrier au ministre de l'Intérieur seulement si l'état de catastrophe est réveillé.
CREATE OR REPLACE FUNCTION public.climat_crue_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
DECLARE v_min text;
BEGIN
  -- crue_sans_perte_v1 (Fred, 22/11/2026) : ni stock perdu ni lieu fermé ; seuls les chantiers de la ville s'arrêtent
  -- pour la journée (climat_chantiers_bloques_interne, chantier_crue_jour_interne).
  IF public.catastrophe_active_interne(e.pays) THEN
    SELECT name INTO v_min FROM public.personnages_donnees WHERE country = e.pays AND poste->>'id' = 'min_int' LIMIT 1;
    IF v_min IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Ministère de l''Intérieur', v_min, 'Crue à ' || public.climat_nom_ville_interne(e.pays, e.ville),
        'Une crue frappe ' || public.climat_nom_ville_interne(e.pays, e.ville) || '. Vous pouvez proposer au Premier ministre de déclarer l''état de catastrophe naturelle (72 h après la crue au plus tard). '
        || '[[act:catastrophe_proposer|' || e.id || ']]', NULL);
    END IF;
  END IF;
  RETURN 0;
END $f$;

-- 4. Sacs de sable retirés : pose refusée, plus en vente, plus cités.
CREATE OR REPLACE FUNCTION public.sacs_sable_poser(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
BEGIN
  IF public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sacs_retires'); /* crue_sans_sacs_v1 : la crue ne ferme plus rien */
END $f$;

UPDATE public.climat_boutiques SET cles = array_remove(cles, 'sac_de_sable') WHERE 'sac_de_sable' = ANY (cles);
DELETE FROM public.climat_boutiques WHERE cardinality(cles) = 0;
DELETE FROM public.climat_lieux_vente WHERE cle = 'sac_de_sable';

CREATE OR REPLACE FUNCTION public.climat_objet_interne(p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE p_cle
    WHEN 'bouteille_eau' THEN jsonb_build_object('name', 'Bouteille d''eau', 'icon', 'ti-bottle', 'type', 'bouteille_eau',
      'stackable', true, 'stackKey', 'bouteille_eau', 'qty', p_qte, 'legal', true, 'desc', 'Protège de la canicule (consommée).')
    -- crue_sans_sacs_v1 : plus de sac de sable.
    WHEN 'groupe_electrogene' THEN jsonb_build_object('name', 'Groupe électrogène', 'icon', 'ti-bolt', 'type', 'groupe-electrogene',
      'generique_id', 'groupe-electrogene', 'stackable', false, 'legal', true, 'bidons', 0,
      'desc', 'Installé dans un bureau, il maintient l''ordinateur, la box et les caméras pendant une coupure (5 bidons par coupure).')
    WHEN 'bidon_carburant' THEN jsonb_build_object('name', 'carburant', 'stackKey', 'carburant', 'stackable', true, 'qty', p_qte,
      'desc', 'Bidons de carburant (1 bidon = 1 unité).')
    WHEN 'sels_rehydratation' THEN jsonb_build_object('name', 'Sels de réhydratation', 'icon', 'ti-pill', 'type', 'medicament_maladie',
      'medicament', 'sels_rehydratation', 'soigne', 'coup_de_chaleur', 'stackable', true, 'stackKey', 'medicament_sels_rehydratation', 'qty', p_qte)
  END;
$f$;

CREATE OR REPLACE FUNCTION public.climat_prix_interne(p_cle text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT CASE p_cle
    WHEN 'bouteille_eau' THEN public.aliments_param_interne('prix_bouteille_eau', 0)
    -- crue_sans_sacs_v1 : plus de sac de sable (la ligne de paramètre prix_sac_sable reste, inutilisée).
    WHEN 'bidon_carburant' THEN public.aliments_param_interne('prix_bidon_carburant', 20)
    WHEN 'sels_rehydratation' THEN public.pharmacie_prix_interne('coup_de_chaleur')::numeric
    ELSE public.aliments_param_interne('prix_groupe_electrogene', 0) END;
$f$;

SELECT pg_temp.rp_remplacer_crue('public.climat_parades_verifier_interne()'::regprocedure,
  $a$('orage', 'bidon_carburant'), ('crue', 'sac_de_sable'),$a$,
  $a$('orage', 'bidon_carburant'), /* crue_sans_sacs_v1 */$a$, 1, 'crue_sans_sacs_v1');

-- 5. Consigne et texte d'alerte de la crue (message du gouvernement, bandeau, fenêtre, accueil du nouveau personnage).
SELECT pg_temp.rp_remplacer_crue('public.climat_consigne_interne(text,text,text)'::regprocedure,
  $a$    RETURN 'Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent '
      || public.aliments_param_interne('crue_perte_pct', 20)::integer || ' % de leurs stocks, et les chantiers sont à l''arrêt. '
      || 'Sécurisez vos propriétés : posez des sacs de sable'
      || coalesce(', en vente ' || public.climat_vente_interne('sac_de_sable', p_pays, p_ville), '')
      || ' (1 PA, valables pour une crue). Les lieux protégés restent ouverts. La gare et tous les déplacements restent libres.';$a$,
  $a$    RETURN 'Tous les chantiers de la ville s''arrêtent pour la journée : ils prennent un jour de retard. '
      || 'Rien d''autre ne change : commerces, entrepôts, gare et déplacements restent ouverts, et aucun stock n''est perdu.'; /* crue_consigne_v2 */$a$,
  1, 'crue_consigne_v2');

CREATE OR REPLACE FUNCTION public.climat_texte_alerte_interne(e public.climat_evenements)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT public.climat_nom_type_interne(e.type) || ' annoncé' || CASE WHEN e.type IN ('crue', 'canicule') THEN 'e' ELSE '' END
      || ' à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' ' || public.climat_quand_interne(e.debut) /* climat_heure_hasard_v1 */
      -- crue_consigne_v2 : plus de « zone inondable menacée » (aucun lieu n'est fermé).
      || '. ' || coalesce(public.climat_consigne_interne(e.type, e.pays, e.ville), '') /* climat_consignes_v1 */;
$f$;

-- 6. Chantiers : arrêt du travail des joueurs pendant la journée de la crue ; la nuit suivante, un jour de retard.
CREATE OR REPLACE FUNCTION public.climat_chantiers_bloques_interne(p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
                  WHERE e.pays = p_pays AND e.ville = p_ville AND NOT e.annule AND e.alerte_le IS NOT NULL
                    AND now() >= e.debut AND c.bloque_chantiers
                    -- crue_chantier_jour_v1 : la crue arrête les chantiers jusqu'à minuit du jour où elle commence.
                    AND now() < CASE WHEN e.type = 'crue'
                                     THEN greatest(e.fin, public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + 1))
                                     ELSE e.fin END);
$f$;

CREATE OR REPLACE FUNCTION public.chantier_crue_jour_interne(p_terrain_id text, p_pays text, p_etat jsonb, p_emplacement text, p_jour text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
-- Nuit des chantiers (crue_chantier_jour_v1, Fred, 22/11/2026) : si une crue a commencé dans la ville du terrain le jour de
-- Paris qui précède p_jour (le jour du traitement de nuit), cette journée est perdue : aucune avance, aucun salaire, aucune
-- consommation ni commande de matériaux, aucun appel de fonds ; le chantier prend un jour de retard. Les heures déjà faites
-- par les joueurs ce jour-là restent acquises pour la nuit suivante. Rend NULL quand la nuit doit suivre son cours normal.
DECLARE ch jsonb := p_etat -> p_emplacement; v_id bigint; v_etat jsonb;
BEGIN
  IF jsonb_typeof(ch) IS DISTINCT FROM 'object' OR coalesce((ch->>'attenteReception')::boolean, false) THEN RETURN NULL; END IF;
  SELECT e.id INTO v_id FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
   WHERE e.type = 'crue' AND e.pays = p_pays AND e.ville = p_etat->>'city' AND NOT e.annule AND e.alerte_le IS NOT NULL
     AND c.bloque_chantiers AND e.debut <= now() AND (e.debut AT TIME ZONE 'Europe/Paris')::date = p_jour::date - 1
   ORDER BY e.debut LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  ch := ch || jsonb_build_object('jourTraite', p_jour,
    'evenements', coalesce(ch->'evenements', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('cle', 'crue', 'date', p_jour, 'avance', 0, 'evenement', v_id)));
  v_etat := p_etat || jsonb_build_object(p_emplacement, ch);
  UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = p_terrain_id;
  RETURN jsonb_build_object('ok', true, 'etat', v_etat, 'attenteReception', false, 'avance', 0, 'crue', true, 'evenement', v_id);
END $f$;
REVOKE ALL ON FUNCTION public.chantier_crue_jour_interne(text, text, jsonb, text, text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer_crue('public.chantier_jour_traiter(text)'::regprocedure,
  $a$ IF ch->>'jourTraite'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat);END IF;
$a$,
  $a$ IF ch->>'jourTraite'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat);END IF;
 rep:=public.chantier_crue_jour_interne(p_terrain_id,r.country,etat,emplacement,jour);IF rep IS NOT NULL THEN RETURN rep;END IF; /* crue_chantier_jour_v1 */
$a$, 1, 'crue_chantier_jour_v1');

-- 7. Contrôles.
DO $do$
BEGIN
  IF public.climat_batiment_inonde_interne('republic', 'ville_b', 'zone-production')
     OR EXISTS (SELECT 1 FROM public.climat_boutiques WHERE 'sac_de_sable' = ANY (cles))
     OR EXISTS (SELECT 1 FROM public.climat_lieux_vente WHERE cle = 'sac_de_sable')
     OR position('sac' IN public.climat_consigne_interne('crue', 'republic', 'ville_b')) > 0
     OR position('crue_chantier_jour_v1' IN pg_get_functiondef('public.chantier_jour_traiter(text)'::regprocedure)) = 0
     OR position('catastrophe_en_sommeil_v1' IN pg_get_functiondef('public.catastrophe_declarer(bigint,boolean)'::regprocedure)) = 0
     OR position('catastrophe_en_sommeil_v1' IN pg_get_functiondef('public.catastrophe_proposer(bigint)'::regprocedure)) = 0
     OR position('catastrophe_en_sommeil_v1' IN pg_get_functiondef('public.catastrophe_etat(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'partie F (crue) : contrôle structurel en échec';
  END IF;
END $do$;
-- ===== FIN PARTIE F =====

