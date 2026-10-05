-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918150723
-- Nom original      : impacts_indices_attente_fermeture
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:07:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ed2bdc9393af3d60a0ceb2640ff2344f
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =========================================================================================
-- FERMETURE DU CANAL DE DEGATS `impacts_indices_attente` (19 septembre 2026)
-- =========================================================================================
-- La table etait en RLS mais portait une politique unique `allow_all` en ALL, USING true /
-- WITH CHECK true, et `anon` comme `authenticated` avaient INSERT/UPDATE/SELECT. N'importe qui
-- pouvait donc deposer un `hp_set` arbitraire sur n'importe quelle victime -- sans jet, sans arme,
-- sans PA, sans etre present, sans meme etre authentifie. C'est le canal par lequel transitent
-- TOUS les degats physiques entre joueurs.
--
-- INVENTAIRE COMPLET DES PRODUCTEURS (releve exhaustif avant fermeture) :
--   hp_set              x4 : Neutraliser reussi, Neutraliser echec partiel, explosion, mission
--                            militaire `assassiner`
--   poison_start        x1 : empoisonnement
--   moral_carte_postale x1 : bonus de lecture d'une carte postale
--   pop / inf / dis     x0 : CONSOMMES par le client mais plus AUCUN producteur -- vestiges.
-- CONSOMMATEUR unique : traiterImpactsEnAttente (plateau-communication.js).
--
-- CE QUE CETTE FERMETURE FAIT ET NE FAIT PAS. Elle rend le CANAL atteste : il faut desormais etre
-- authentifie, exister, et -- pour un degat physique -- etre REELLEMENT DANS LA MEME PIECE que la
-- victime. Elle ne rend pas le JET de Neutraliser serveur : celui-ci reste client, c'est une dette
-- anterieure et distincte, signalee au rapport. Le nouveau moteur militaire, lui, n'emprunte pas
-- ce canal du tout : il travaille en PA canoniques.
CREATE OR REPLACE FUNCTION public.impact_deposer(
  p_id text, p_victime text, p_indice text, p_delta integer, p_palier text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; a record; c record; v_delta integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_id,'')),'') = '' OR length(p_id) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_invalide');
  END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT name, country, current_city, current_building, current_room INTO c
    FROM public.personnages_donnees WHERE name = btrim(coalesce(p_victime,''));
  IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'victime_introuvable'); END IF;
  IF c.name = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'auto_impact_refuse'); END IF;

  IF p_indice = 'hp_set' THEN
    -- LA CO-PRESENCE EST LA GARDE ESSENTIELLE. Elle ne remplace pas un jet serveur, mais elle
    -- supprime a elle seule l'attaque a distance sur une victime quelconque, qui etait le vrai
    -- danger : frapper sans etre la, sans arme et sans PA.
    IF a.country IS DISTINCT FROM c.country
       OR a.current_city IS DISTINCT FROM c.current_city
       OR a.current_building IS DISTINCT FROM c.current_building
       OR a.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    v_delta := greatest(0, least(100, coalesce(p_delta, 0)));

  ELSIF p_indice = 'moral_carte_postale' THEN
    -- Une carte postale est distante par nature : aucune co-presence exigee. Le montant n'est pas
    -- negociable et le plafond quotidien reste pose cote lecteur, la ou il l'a toujours ete.
    v_delta := 10;

  ELSIF p_indice = 'poison_start' THEN
    -- REFUS EXPLICITE, ET C'EST UN CONSTAT, PAS UNE DECISION. Le producteur envoie `poisonType` et
    -- `statsTouchees`, DEUX COLONNES QUI N'EXISTENT PAS dans cette table, et omet `delta` qui est
    -- NOT NULL sans defaut. Cet INSERT a donc toujours ete rejete par PostgREST, silencieusement
    -- (sbInsert journalise et rend null, l'appelant avale le null) : l'empoisonnement n'a jamais
    -- atteint sa victime. On refuse desormais VISIBLEMENT au lieu d'echouer en silence. Reparer
    -- l'empoisonnement est un lot a part : il demande un schema, pas un correctif de canal.
    RETURN jsonb_build_object('ok', false, 'raison', 'schema_incomplet',
      'detail', 'poison_start exige des colonnes absentes de la table');

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_non_autorise', 'indice', p_indice);
  END IF;

  -- Idempotence : un retry apres un accuse de reception perdu ne cree pas de seconde ligne.
  INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite)
  VALUES (p_id, c.name, p_indice, v_delta, nullif(btrim(coalesce(p_palier,'')),''), false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'victime', c.name,
    'indice', p_indice, 'delta', v_delta);
END;
$$;

-- Marquage « traite » : reserve a la VICTIME elle-meme. C'est elle qui consomme sa file.
CREATE OR REPLACE FUNCTION public.impact_marquer_traite(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.impacts_indices_attente SET traite = true
   WHERE id = p_id AND victime = v_moi AND traite IS NOT TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'marques', v_n);
END;
$$;

REVOKE ALL ON FUNCTION public.impact_deposer(text, text, text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.impact_marquer_traite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_deposer(text, text, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.impact_marquer_traite(text) TO authenticated;

-- FERMETURE DE LA TABLE. SELECT est conserve mais restreint a SES PROPRES lignes : la politique
-- precedente laissait lire la file de n'importe qui, donc savoir qui venait d'etre agresse ou
-- empoisonne. INSERT et UPDATE directs disparaissent -- les deux RPC ci-dessus sont desormais les
-- seuls chemins.
DROP POLICY IF EXISTS allow_all_impacts_indices_attente ON public.impacts_indices_attente;
CREATE POLICY impacts_lecture_victime ON public.impacts_indices_attente
  FOR SELECT TO authenticated
  USING (victime = public.mon_personnage());

REVOKE ALL ON public.impacts_indices_attente FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.impacts_indices_attente TO authenticated;