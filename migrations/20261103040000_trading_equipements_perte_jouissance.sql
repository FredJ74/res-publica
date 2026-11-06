-- APPLIQUEE le 03/11/2026 par Claude (registre trading_equipements_perte_jouissance_20261103040000), apres le banc
-- annule outils/bancs/banc-trading-perte-jouissance.sql joue en production (7 cas conformes).
-- 3 novembre 2026 -- TRADING, etape 3 : perte de la jouissance du local ou sont installes les equipements.
--
-- Decision de Fred du 31/10 (GAME-DESIGN-TRADING.md, point 16) : si le PJ perd la jouissance du local
-- (bail non valide), il perd la connexion immediatement (deja vrai : trading_connexion_interne exige
-- la jouissance) et dispose de 48 h pour desinstaller ; faute de quoi le materiel devient la propriete
-- du proprietaire foncier.
--
-- Mise en oeuvre :
--   * colonne equipements_installes.jouissance_perdue_le, posee par la passe de nuit
--     (equipements_jouissance_nuit, etape 5 d du cron) la premiere nuit ou le bail n'est plus valide,
--     avec un courrier « 48 h pour desinstaller » ; remise a NULL si le bail redevient valide ;
--   * deux nuits plus tard (48 h), transfert au proprietaire foncier, resolu comme le loyer
--     (prelever_loyer_bail) : lot dynamique d'un bien subdivise -> proprietaire actuel du terrain
--     (terrains_etat.proprietaire : PJ, 'orga:<id>' ou 'ville:<pays>:<ville>') ; tout autre local
--     (bureaux du centre d'affaires...) -> la commune ;
--       - PJ : l'equipement reste installe et lui appartient (il peut le desinstaller sur place) ;
--       - organisation : il appartient a l'organisation, son chef peut le desinstaller ;
--       - commune : saisi par la commune, retire du local (journal equipements_saisis) ;
--   * equipement_desinstaller : le chef d'une organisation proprietaire peut desinstaller ;
--     equipements_local_lire : indique a l'ancien locataire l'echeance de son delai.
-- REUTILISE : local_jouissance_interne, mail_systeme_poser_interne, inventaire_deposer_interne.
-- Idempotente. Aucun acte de joueur.

ALTER TABLE public.equipements_installes ADD COLUMN IF NOT EXISTS jouissance_perdue_le timestamptz;

CREATE TABLE IF NOT EXISTS public.equipements_saisis (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ancien_proprietaire text NOT NULL,
  nouveau_proprietaire text NOT NULL,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  generique_id text NOT NULL,
  objet jsonb NOT NULL,
  saisi_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.equipements_saisis ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.equipements_saisis FROM anon, authenticated;

-- Proprietaire foncier d'un local : meme resolution que le loyer.
CREATE OR REPLACE FUNCTION public.local_proprietaire_foncier_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN left(coalesce(p_piece, ''), 8) = 'lot_dyn_'
              THEN coalesce(nullif((SELECT data::jsonb->>'proprietaire' FROM public.terrains_etat
                                     WHERE country = p_pays AND building_id = p_batiment LIMIT 1), ''),
                            'ville:' || p_pays || ':' || p_ville)
              ELSE 'ville:' || p_pays || ':' || p_ville END;
$function$;

-- Peut-on agir sur un equipement : son proprietaire PJ, ou le chef de l'organisation proprietaire.
CREATE OR REPLACE FUNCTION public.equipement_a_moi_interne(p_proprietaire text, p_acteur text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_proprietaire = p_acteur
      OR (left(p_proprietaire, 5) = 'orga:'
          AND EXISTS (SELECT 1 FROM public.organisations o
                       WHERE o.id = substr(p_proprietaire, 6) AND o.data::jsonb->>'chef' = p_acteur));
$function$;

CREATE OR REPLACE FUNCTION public.equipements_jouissance_nuit()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE e record; v_foncier text; v_nom text; v_libelle text;
  n_avertis integer := 0; n_retablis integer := 0; n_transferes integer := 0; n_saisis integer := 0;
  v_err jsonb := '[]'::jsonb;
BEGIN
  FOR e IN SELECT * FROM public.equipements_installes
            WHERE left(proprietaire, 5) <> 'orga:' ORDER BY installe_le LOOP
    BEGIN
      v_libelle := CASE e.generique_id WHEN 'ordinateur-complet' THEN 'votre ordinateur'
                                       WHEN 'box-internet' THEN 'votre box internet'
                                       ELSE coalesce(e.objet->>'name', e.generique_id) END;
      IF public.local_jouissance_interne(e.proprietaire, e.pays, e.ville, e.batiment, e.piece) THEN
        IF e.jouissance_perdue_le IS NOT NULL THEN
          UPDATE public.equipements_installes SET jouissance_perdue_le = NULL WHERE id = e.id;
          n_retablis := n_retablis + 1;
        END IF;
      ELSIF e.jouissance_perdue_le IS NULL THEN
        UPDATE public.equipements_installes SET jouissance_perdue_le = now() WHERE id = e.id;
        PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', e.proprietaire,
          'Équipement à désinstaller sous 48 h',
          'Vous n''avez plus la jouissance légale du local où est installé ' || v_libelle || ' (' || e.piece
          || '). La connexion est coupée. Vous disposez de 48 h pour venir le désinstaller ; passé ce délai, '
          || 'il deviendra la propriété du propriétaire des lieux.');
        n_avertis := n_avertis + 1;
      ELSIF e.jouissance_perdue_le <= now() - interval '47 hours' THEN
        v_foncier := public.local_proprietaire_foncier_interne(e.pays, e.ville, e.batiment, e.piece);
        IF left(v_foncier, 6) = 'ville:' THEN
          INSERT INTO public.equipements_saisis (ancien_proprietaire, nouveau_proprietaire, pays, ville, batiment, piece, generique_id, objet)
          VALUES (e.proprietaire, v_foncier, e.pays, e.ville, e.batiment, e.piece, e.generique_id, e.objet);
          DELETE FROM public.equipements_installes WHERE id = e.id;
          v_nom := 'la commune';
          n_saisis := n_saisis + 1;
        ELSE
          UPDATE public.equipements_installes SET proprietaire = replace(v_foncier, 'pj:', ''), jouissance_perdue_le = NULL
           WHERE id = e.id;
          IF left(v_foncier, 5) = 'orga:' THEN
            SELECT coalesce(data::jsonb->>'nom', 'l''organisation propriétaire') INTO v_nom
              FROM public.organisations WHERE id = substr(v_foncier, 6);
            v_nom := coalesce(v_nom, 'l''organisation propriétaire');
          ELSE
            v_nom := replace(v_foncier, 'pj:', '');
            PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', v_nom,
              'Équipement abandonné dans votre bien',
              e.proprietaire || ' n''a pas désinstallé son équipement (' || coalesce(e.objet->>'name', e.generique_id)
              || ') dans les 48 h suivant la fin de son bail (' || e.piece || '). Il vous appartient désormais.');
          END IF;
          n_transferes := n_transferes + 1;
        END IF;
        PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', e.proprietaire,
          'Équipement perdu',
          'Le délai de 48 h est écoulé : ' || v_libelle || ' (' || e.piece || ') appartient désormais à '
          || v_nom || '.');
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_err := v_err || jsonb_build_object('id', e.id, 'erreur', SQLERRM);
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', jsonb_array_length(v_err) = 0, 'avertis', n_avertis, 'retablis', n_retablis,
                            'transferes', n_transferes, 'saisis', n_saisis, 'erreurs', v_err);
END; $function$;

-- equipement_desinstaller : seul changement, le chef d'une organisation proprietaire peut desinstaller.
CREATE OR REPLACE FUNCTION public.equipement_desinstaller(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; e public.equipements_installes; d record; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  IF NOT public.equipement_a_moi_interne(e.proprietaire, v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF d.country IS DISTINCT FROM e.pays OR d.current_city IS DISTINCT FROM e.ville
     OR d.current_building IS DISTINCT FROM e.batiment OR d.current_room IS DISTINCT FROM e.piece THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi)) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, e.objet);
  IF (v_dep->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'equipement: depot refuse'; END IF;
  DELETE FROM public.equipements_installes WHERE id = e.id;
  RETURN jsonb_build_object('ok', true, 'generique_id', e.generique_id)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- equipements_local_lire : a_moi elargi au chef de l'organisation proprietaire, echeance du delai.
CREATE OR REPLACE FUNCTION public.equipements_local_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, inventory INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_local'); END IF;
  RETURN jsonb_build_object('ok', true, 'emplacements', 2,
    'jouissance', public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room),
    'connexion', public.trading_connexion_interne(v_moi),
    'installes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique_id', e.generique_id,
                              'nom', coalesce(e.objet->>'name', e.generique_id),
                              'proprietaire', CASE WHEN left(e.proprietaire, 5) = 'orga:'
                                                   THEN coalesce((SELECT o.data::jsonb->>'nom' FROM public.organisations o
                                                                   WHERE o.id = substr(e.proprietaire, 6)), 'une organisation')
                                                   ELSE e.proprietaire END,
                              'a_moi', public.equipement_a_moi_interne(e.proprietaire, v_moi),
                              'delai_jusqu_au', CASE WHEN e.jouissance_perdue_le IS NOT NULL
                                                     THEN e.jouissance_perdue_le + interval '48 hours' END) ORDER BY e.installe_le)
                            FROM public.equipements_installes e
                           WHERE e.pays = d.country AND e.ville = d.current_city AND e.batiment = d.current_building
                             AND e.piece = d.current_room), '[]'::jsonb),
    'installables', coalesce((SELECT jsonb_agg(DISTINCT o->>'generique_id')
                                FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                               WHERE o->>'generique_id' IN ('ordinateur-complet', 'box-internet')), '[]'::jsonb));
END; $function$;

REVOKE ALL ON FUNCTION public.local_proprietaire_foncier_interne(text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.equipement_a_moi_interne(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.equipements_jouissance_nuit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.equipements_jouissance_nuit() TO service_role;
REVOKE ALL ON FUNCTION public.equipement_desinstaller(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equipements_local_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipement_desinstaller(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.equipements_local_lire() TO authenticated;
