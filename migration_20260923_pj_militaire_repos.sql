-- =============================================================================================
-- SOMMEIL DU PJ MILITAIRE (23 septembre 2026) — complement du repos quotidien de la section
-- =============================================================================================
-- CE QUI CHANGE, ET POUR QUI. Un PJ militaire n'est PAS soumis au plafond de 12 PA des soldats
-- PNJ : il garde le plafond general des joueurs (30) et continue de declencher son sommeil
-- lui-meme par l'ordre « Dormir ». Le Lieutenant ne le fait jamais dormir -- « Faire reposer la
-- section » ne touche que les PNJ. Seul le GAIN de son sommeil depend desormais de sa situation :
--
--   a la caserne militaire ............ +12 PA  (inchange par rapport a aujourd'hui)
--   hors caserne, sans tente .......... +8  PA
--   hors caserne, avec tente .......... +10 PA  (+8, +2 pour la tente)
--
-- C'est bien un GAIN additif, jamais une remise a une valeur fixe : un Lieutenant a 14 PA qui
-- dort a la caserne passe a 26, pas a 12.
--
-- LE PJ CIVIL EST STRICTEMENT INCHANGE : +12, meme plafond, meme garde journaliere. La branche
-- QHS est elle aussi intacte, et garde sa priorite -- une sanction de detention ne se negocie pas
-- avec un grade militaire, et un detenu n'est de toute facon pas a la caserne.
--
-- QUI EST « MILITAIRE ». public.militaire_grade_effectif(), le helper canonique deja utilise par
-- la solde et le calepin : il rend le poste militaire d'un officier, 'soldat' pour un PJ inscrit
-- comme tel dans une section, et NULL pour tous les autres. Aucun nouveau critere n'est invente.
--
-- LA TENTE : L'INVENTAIRE DU DORMEUR. La regle des PNJ lit la tente chez le LEADER du groupe,
-- parce qu'un soldat PNJ n'a pas d'inventaire. Un PJ, lui, en a un, et aucune structure du moteur
-- ne place un PJ sous l'autorite de campement d'un autre : un PJ soldat est une entree
-- { pj:true, nom } sans leaderCourant ni position, que ni militaire_recuperer_soldats ni
-- militaire_affecter_leader ne peuvent saisir. Le dormeur est donc son propre chef de campement,
-- et c'est SON inventaire qui est lu -- meme champ, meme convention que partout ailleurs
-- (produitMilitaire = 'tente'). Aucune capacite a calculer : il dort seul sous sa propre tente,
-- et inventer un partage de tente entre PJ serait exactement la mecanique parallele a eviter.
-- La tente n'est pas consommee, comme pour le bivouac.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.pa_repos_nocturne(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max         constant integer := 30;
  c_gain_civil     constant integer := 12;
  c_gain_caserne   constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  v_pa integer; v_qhs jsonb; v_bonus integer; v_deja date;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_nouveau integer; v_plafond_qhs integer;
  v_caserne boolean; v_tente boolean; v_grade text; v_gain integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT coalesce(pa, 0), detention_qhs, coalesce(bonus_pa_differe, 0), pa_repos_le,
         coalesce(current_building, '') = 'caserne-militaire',
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'tente')
    INTO v_pa, v_qhs, v_bonus, v_deja, v_caserne, v_tente
    FROM public.personnages_donnees d WHERE d.name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repose', 'pa', v_pa);
  END IF;

  IF v_qhs IS NOT NULL AND jsonb_typeof(v_qhs) = 'object' AND (v_qhs ->> 'enQHS')::boolean IS TRUE THEN
    -- Sanction QHS : REMPLACE le stock, elle ne s'y ajoute pas (comportement d'origine).
    v_plafond_qhs := CASE WHEN (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN 1 ELSE 3 END;
    v_nouveau := least(c_pa_max, greatest(0, v_plafond_qhs + v_bonus));
    IF (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN
      UPDATE public.personnages_donnees
         SET detention_qhs = v_qhs || jsonb_build_object('paLimite1Jour', false)
       WHERE name = p_acteur;
    END IF;
  ELSE
    -- CIVIL : exactement le comportement d'avant. MILITAIRE : le gain depend de la situation.
    v_grade := public.militaire_grade_effectif(p_acteur);
    IF v_grade IS NULL THEN
      v_gain := c_gain_civil;
    ELSIF v_caserne THEN
      v_gain := c_gain_caserne;
    ELSIF v_tente THEN
      v_gain := c_gain_terrain + c_bonus_tente;
    ELSE
      v_gain := c_gain_terrain;
    END IF;
    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));
  END IF;

  UPDATE public.personnages_donnees
     SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau, 'bonus_consomme', v_bonus,
                            'qhs', (v_qhs ->> 'enQHS')::boolean IS TRUE,
                            'grade_militaire', v_grade, 'gain', v_gain,
                            'caserne', v_caserne, 'tente', v_tente);
END;
$function$;
