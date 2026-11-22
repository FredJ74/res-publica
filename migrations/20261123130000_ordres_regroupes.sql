-- Regroupement des ordres dans les pièces (Fred, 22/11/2026, soir : GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie C,
-- point 17, côté serveur). ÉCRITE, NON APPLIQUÉE : le coordinateur l'applique après validation de Fred.
-- Écrite à partir des définitions de PRODUCTION du 22/11/2026 (pg_get_functiondef, lecture seule ; md5(prosrc) :
-- desinstaller_lire 53fbc951…, desinstaller_materiel f841877f…), chaque ancrage compté en production (1 occurrence).
--
-- « Inspecter la pièce » devient une fenêtre à trois volets (plateau-surveillance.js) : « Ce qui est installé ici »
-- (desinstaller_lire, 0 PA ; bouton « Voler » = règles existantes du vol de matériel, crim_cambrioler 'materiel', le même
-- moteur que voler_materiel), « Fouiller les lieux » (inspecter_piece, 1 PA, inchangé) et « Désinstaller ».
--   • desinstaller_materiel : désinstaller est désormais TOUJOURS légal. Le matériel d'autrui hors de chez soi est refusé
--     (raison 'pas_a_vous') : il ne s'emporte plus que par le vol. Chez soi (local_jouissance_interne, y compris le local de
--     son organisation) ou pour son propre matériel : inchangé (2 PA, l'objet tombe au sol). La branche « vol » de la
--     fonction devient inatteignable ; elle est laissée en place (remplacement contrôlé, aucune réécriture).
--     Marque : ordres_regroupes_desinstaller_legal_v1.
--   • desinstaller_lire : chaque matériel porte en plus 'volable' (ni à moi, ni armoire à souvenirs), pour que l'écran ne
--     propose « Voler » que là où crim_cambrioler l'accepte. Marque : ordres_regroupes_lire_volable_v1.
-- Plein air (piece_plein_air_interne, en production) : inchangé, les deux fonctions refusent toujours 'plein_air'.
-- Aucune donnée modifiée, aucun tarif (ordres_couts) modifié. Rien du goulag. Rejouable, sans BEGIN/COMMIT.

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

-- 1. Désinstaller : légal seulement (son matériel, ou tout le matériel chez soi).
SELECT pg_temp.rp_remplacer('public.desinstaller_materiel(uuid, uuid)'::regprocedure,
  $a$  IF e.generique_id = 'armoire_souvenirs' AND NOT v_legal THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;$a$,
  $b$  IF e.generique_id = 'armoire_souvenirs' AND NOT v_legal THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  /* ordres_regroupes_desinstaller_legal_v1 (Fred, 22/11/2026, point 17) : désinstaller le matériel d'autrui hors de chez soi
     n'existe plus ; cela passe uniquement par le vol (crim_cambrioler 'materiel'). */
  IF NOT v_legal THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_vous'); END IF;$b$,
  1, 'ordres_regroupes_desinstaller_legal_v1');

-- 2. Lecture du matériel installé : drapeau 'volable' décidé par le serveur.
SELECT pg_temp.rp_remplacer('public.desinstaller_lire()'::regprocedure,
  $a$        'legal', v_chez_soi OR public.equipement_a_moi_interne(e.proprietaire, a),$a$,
  $b$        'legal', v_chez_soi OR public.equipement_a_moi_interne(e.proprietaire, a),
        'volable', e.generique_id <> 'armoire_souvenirs' AND NOT public.equipement_a_moi_interne(e.proprietaire, a), /* ordres_regroupes_lire_volable_v1 */$b$,
  1, 'ordres_regroupes_lire_volable_v1');
