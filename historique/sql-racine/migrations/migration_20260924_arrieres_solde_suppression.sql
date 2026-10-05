-- =============================================================================================
-- SUPPRESSION DE LA MECANIQUE DES ARRIERES DE SOLDE (24 septembre 2026)
-- =============================================================================================
-- ARBITRAGE. La solde quotidienne des PNJ a ete abandonnee le 18 septembre. Celle des PJ se
-- percoit en dormant. Il ne restait, des arrieres, qu'une promesse : une dette inscrite, affichee
-- au calepin, accompagnee d'un « reclamez-la, c'est votre droit » -- et aucun ecran pour le faire.
-- La mecanique disparait donc entierement.
--
-- CE QUI EST SUPPRIME : militaire_arrieres_regler (aucun appelant, 100 % arrieres) et la cle
-- arrieres_dus du calepin, avec le calcul qui l'alimentait.
--
-- CE QUI EST CONSERVE, ET POURQUOI : la table soldes_militaires reste. Elle n'est pas la table
-- des arrieres, c'est le REGISTRE DE PAIE : son INSERT sur la cle primaire « nom:jour » EST le
-- verrou anti-rejeu qui empeche un joueur de toucher deux soldes le meme jour. La supprimer
-- casserait la solde des PJ, qui elle fonctionne et reste hors de cette suppression.
-- Consequence assumee : la part non versee continue d'etre enregistree, mais n'est plus ni
-- reclamable ni affichee. Aucune donnee n'est perdue -- la table est vide a ce jour.
--
-- LE CALEPIN EST MODIFIE PAR TRANSFORMATION DE SA PROPRE DEFINITION, et non retranscrit a la
-- main : tout le reste (services, periodes, competences, decorations) est ainsi repris a
-- l'identique, sans risque d'ecart. Les deux garde-fous RAISE verifient que les fragments visés
-- ont bien ete trouves et qu'il ne reste aucune reference aux arrieres.
-- =============================================================================================

DROP FUNCTION IF EXISTS public.militaire_arrieres_regler();

DO $migration$
DECLARE v_def text; v_nouveau text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'militaire_calepin';
  IF v_def IS NULL THEN RAISE EXCEPTION 'militaire_calepin introuvable'; END IF;

  v_nouveau := replace(v_def,
    '  SELECT coalesce(sum(greatest(0, coalesce(s.du,0) - coalesce(s.verse,0))), 0)::integer INTO v_du
    FROM public.soldes_militaires s WHERE s.personnage = v_moi;

', '');
  v_nouveau := replace(v_nouveau, ',
    ''arrieres_dus'', v_du)', ')');
  v_nouveau := replace(v_nouveau, ' v_grade text; v_du integer; v_pays text;', ' v_grade text; v_pays text;');

  IF v_nouveau = v_def THEN
    RAISE EXCEPTION 'aucun fragment d''arriere retire : la definition a change, verification requise';
  END IF;
  IF position('arrieres_dus' in v_nouveau) > 0 OR position('soldes_militaires' in v_nouveau) > 0 THEN
    RAISE EXCEPTION 'il reste une reference aux arrieres dans le calepin';
  END IF;

  EXECUTE v_nouveau;
END
$migration$;
