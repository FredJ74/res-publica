-- =============================================================================================
-- CONSOMMATION D'UNE RATION DE COMBAT PAR UN PJ (23 septembre 2026)
-- =============================================================================================
-- LE TROU FERME. La ration de combat existait deja de bout en bout, sauf pour son proprietaire :
-- militaire_rations_retirer la depose dans l'inventaire du joueur, et militaire_ordre_collectif
-- la consomme -- mais uniquement au profit des soldats PNJ menes, avec un filtre explicite
-- NOT (sol->>'pj')::boolean. Aucun chemin, ni client ni serveur, ne permettait a un PJ de manger
-- la sienne : aucun fichier du depot ne mentionnait meme 'ration_combat'. Le joueur pouvait donc
-- emporter des rations qu'il ne pourrait jamais utiliser lui-meme.
--
-- MOTIF REPRIS TEL QUEL DE militaire_trousse_utiliser, l'autre consommable a usage unique d'un PJ :
-- le serveur verifie la possession, retire l'objet et credite les PA DANS LA MEME TRANSACTION.
-- Le client ne supprime jamais l'objet lui-meme et ne calcule jamais le gain -- sans quoi un
-- navigateur modifie s'accorderait des PA sans rien posseder.
--
-- PROTECTION CONTRE LE DOUBLE USAGE ET CONTRE LE DEPASSEMENT DE QUOTA. Le SELECT ... FOR UPDATE
-- verrouille la fiche AVANT toute lecture d'inventaire et de compteur : deux appels simultanes
-- sont serialises, le second relit un inventaire ampute et un compteur deja incremente. Ni la
-- ration ni le quota ne peuvent etre doubles, y compris par appel direct a la RPC.
--
-- PLAFOND. Celui des joueurs, 30 PA, identique a militaire_trousse_utiliser et a
-- pa_repos_nocturne. Le plafond de 12 PA des soldats PNJ ne s'applique jamais a un PJ.
--
-- DEUX REFUS QUI CONSERVENT LA RATION (arbitrage GD du 23 septembre 2026) : au plafond de 30 PA,
-- et au-dela de 2 rations consommees dans la journee. Dans les deux cas AUCUNE ecriture n'a lieu
-- -- les gardes sont placees avant toute modification, si bien qu'un refus ne coute jamais la
-- ration. Le joueur est prevenu par un message explicite.
--
-- SUIVI QUOTIDIEN : personnages_donnees.stats, exactement la structure et la reference de date
-- (Europe/Paris) que refectoire_repas utilise deja pour son 'repasCaserneJour'. Deux cles plates,
-- 'rationsCombatJour' et 'rationsCombatNb' : aucune colonne, aucune table, aucun compteur
-- parallele. Le changement de jour remet naturellement le quota a zero, puisque la cle de jour ne
-- correspond plus.
--
-- La regle des soldats PNJ (une ration par jour et par soldat, marqueur dernier_ration dans le
-- blob de la compagnie) n'est pas touchee : c'est une mecanique distincte, sur d'autres donnees.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_ration_consommer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj    constant integer := 30;
  c_gain         constant integer := 1;
  c_max_par_jour constant integer := 2;
  v_moi text; v_inv jsonb; v_stats jsonb; v_pos integer;
  v_pa_avant integer; v_pa_apres integer; v_reste integer;
  v_jour text; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- VERROU AVANT TOUTE LECTURE : deux appels simultanes sont serialises ici, le second relit
  -- un inventaire et un compteur deja a jour. Ni la ration ni le quota ne peuvent etre doubles.
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END,
         CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,
         coalesce(pa, 0)
    INTO v_inv, v_stats, v_pa_avant
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_deja := CASE WHEN coalesce(v_stats->>'rationsCombatJour', '') = v_jour
                 THEN coalesce((v_stats->>'rationsCombatNb')::integer, 0) ELSE 0 END;

  -- LA POSSESSION EST VERIFIEE ICI, jamais crue sur parole. La premiere ration trouvee est
  -- consommee : elles sont interchangeables, aucun choix a offrir au joueur.
  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ration'); END IF;

  -- LES DEUX REFUS CONSERVENT LA RATION : aucune ecriture n'a encore eu lieu a ce stade.
  IF v_pa_avant >= c_pa_max_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_maximum', 'pa', v_pa_avant, 'plafond', c_pa_max_pj);
  END IF;
  IF v_deja >= c_max_par_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_quotidien',
      'consommees_aujourdhui', v_deja, 'maximum', c_max_par_jour);
  END IF;

  v_pa_apres := least(c_pa_max_pj, v_pa_avant + c_gain);

  -- USAGE UNIQUE : la ration quitte l'inventaire dans la MEME transaction que le gain et que
  -- l'incrementation du compteur du jour.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;

  UPDATE public.personnages_donnees
     SET inventory = v_inv, pa = v_pa_apres,
         stats = v_stats || jsonb_build_object('rationsCombatJour', v_jour,
                                               'rationsCombatNb', v_deja + 1)
   WHERE name = v_moi;

  SELECT count(*)::integer INTO v_reste FROM jsonb_array_elements(v_inv) i
   WHERE i->>'produitMilitaire' = 'ration_combat';

  RETURN jsonb_build_object('ok', true, 'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres,
    'gain_reel', v_pa_apres - v_pa_avant, 'rations_restantes', v_reste,
    'consommees_aujourdhui', v_deja + 1, 'maximum', c_max_par_jour);
END;
$function$;

-- PIEGE RECURRENT : une RPC non accordee repond 42501 « permission denied », pas un refus metier.
REVOKE ALL ON FUNCTION public.militaire_ration_consommer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_ration_consommer() TO authenticated;

-- =============================================================================================
-- TEXTE DE L'OBJET. « Consommee sur le terrain : +1 PA par jour » etait herite de la regle des
-- soldats PNJ et devenait faux pour un PJ. Seule la chaine 'desc' change ; le reste de la
-- fonction est reproduit a l'identique.
-- =============================================================================================
CREATE OR REPLACE FUNCTION public.militaire_rations_retirer(p_nombre integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_ref jsonb; v_dispo integer; v_n integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_n := greatest(0, coalesce(p_nombre, 0));
  IF v_n = 0 OR v_n > 50 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i2->>'qty')::numeric, (i2->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i2;
  IF v_occupe + v_n > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  v_ref := CASE WHEN jsonb_typeof(v_data->'refectoire')='object' THEN v_data->'refectoire' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, coalesce((v_ref->>'rations')::integer, 0));
  IF v_dispo < v_n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes', 'disponibles', v_dispo);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_dispo - v_n)),
         updated_at = now()
   WHERE id = v_pays;

  FOR i IN 1 .. v_n LOOP
    v_inv := v_inv || jsonb_build_array(jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'vivres', 'sousType', 'militaire', 'produitMilitaire', 'ration_combat',
      'origineMilitaire', true, 'usageUnique', true,
      'name', 'Ration de combat', 'icon', 'ti-soup', 'legal', true,
      'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-ration-combat.png',
      'desc', 'Ration de combat. +1 PA par ration, 2 rations par jour au maximum.'));
  END LOOP;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'retirees', v_n, 'restantes', v_dispo - v_n);
END;
$function$;
