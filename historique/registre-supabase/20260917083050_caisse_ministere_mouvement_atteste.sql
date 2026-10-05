-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917083050
-- Nom original      : caisse_ministere_mouvement_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 08:30:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 15c1bdfa1836589554f53a40c1776aec
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
-- LOT D — VIREMENTS MINISTERIELS : FERMETURE DE L'AUTORITE ET DE L'ATOMICITE
-- Suite de l'audit des frontieres d'autorite, 17 septembre 2026.
--
-- CONSTAT (verifie site par site) : sept ordres ministeriels ne verifient le poste requis QU'A
-- L'OUVERTURE de leur modale, jamais au moment de l'action, et jamais cote serveur. Les fonctions
-- sont globales : confirmerSubventionMinInt(), confirmerVirementPonctuel(),
-- confirmerVirementPonctuelQHS(), confirmerPropositionGrace(), annulerAffaire(),
-- confirmerRechercheMilitaireDepuisMinistere()... un appel direct depuis la console d'un joueur
-- authentifie quelconque contourne integralement l'autorite voulue. Le grisage du bouton
-- (requiresPost, data.js) est purement cosmetique.
-- Second defaut : debit de la caisse source et credit de la caisse destination sont DEUX appels
-- HTTP separes. Entre les deux, l'argent n'existe nulle part -- un echec du second le detruit.
--
-- REGLE APPLIQUEE, MECANIQUEMENT DEDUITE, RIEN D'INVENTE : une caisse ministerielle porte
-- l'identifiant '<pays>_gouvernement-<posteId>' (verifie sur les 28 caisses ministerielles des
-- quatre empires en production : republic_gouvernement-min_fin, narco_gouvernement-min_def...).
-- Le poste habilite est donc LITTERALEMENT inscrit dans l'identifiant de la caisse. On exige ce
-- poste, plus l'appartenance au meme pays. Aucun bareme, aucun montant, aucune autorite nouvelle :
-- c'est exactement ce que data.js declarait deja via requiresPost, enfin applique par le serveur.
--
-- Le MONTANT reste une intention libre du client : c'est voulu, un ministre choisit ce qu'il
-- verse. Ce flux ne peut pas etre ferme par un montant canonique -- seule l'autorite peut l'etre,
-- et c'est ce que fait cette RPC.
--
-- p_destination_id NULL = depense seche (frais de dossier, recherche), sans caisse en face.
-- p_plafonne = true reproduit debiterCaisseBatimentPlafonne (verse au plus ce qui est disponible) ;
-- false reproduit debiterCaisseBatimentAtomique (tout ou rien).
CREATE OR REPLACE FUNCTION public.caisse_ministere_mouvement(
  p_source_id text, p_montant numeric,
  p_destination_id text DEFAULT NULL, p_plafonne boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_pays text; v_poste text; v_acteur text; v_pays_acteur text;
  v_data jsonb; v_solde numeric; v_verse numeric;
  v_dest_data jsonb; v_dest_solde numeric;
BEGIN
  IF COALESCE(btrim(p_source_id), '') = '' OR p_montant IS NULL
     OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- La source DOIT etre une caisse ministerielle : cette RPC ne sert qu'a celles-la.
  v_pays  := substring(p_source_id from '^([^_]+)_gouvernement-');
  v_poste := substring(p_source_id from '^[^_]+_gouvernement-(.+)$');
  IF v_pays IS NULL OR v_poste IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_non_ministerielle');
  END IF;

  -- AUTORITE : leve si le compte connecte n'occupe pas CE ministere.
  v_acteur := public.exiger_poste(v_poste);
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays_acteur FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_pays_acteur IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction',
                              'pays_caisse', v_pays, 'pays_acteur', v_pays_acteur);
  END IF;

  -- Verrous dans un ordre fixe (source puis destination) : deux virements simultanes se serialisent.
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_source_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;

  IF p_plafonne THEN
    v_verse := LEAST(GREATEST(v_solde, 0), p_montant);
  ELSE
    IF v_solde < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_solde);
    END IF;
    v_verse := p_montant;
  END IF;
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_solde, 'verse', 0);
  END IF;

  UPDATE public.caisses_batiments
     SET data = COALESCE(v_data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_source_id;

  -- Credit de la destination DANS LA MEME TRANSACTION : l'argent ne peut plus se perdre entre
  -- les deux mouvements, ce que deux appels HTTP separes ne garantissaient pas.
  IF COALESCE(btrim(p_destination_id), '') <> '' THEN
    SELECT data INTO v_dest_data FROM public.caisses_batiments WHERE id = p_destination_id FOR UPDATE;
    v_dest_solde := CASE WHEN FOUND AND jsonb_typeof(v_dest_data->'solde') = 'number'
                         THEN (v_dest_data->>'solde')::numeric ELSE 0 END;
    IF FOUND THEN
      UPDATE public.caisses_batiments
         SET data = COALESCE(v_dest_data,'{}'::jsonb) || jsonb_build_object('solde', v_dest_solde + v_verse),
             updated_at = now()
       WHERE id = p_destination_id;
    ELSE
      INSERT INTO public.caisses_batiments (id, data, updated_at)
      VALUES (p_destination_id, jsonb_build_object('solde', v_verse), now());
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'acteur', v_acteur,
    'poste', v_poste, 'source', p_source_id, 'destination', p_destination_id,
    'solde_source', v_solde - v_verse);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.caisse_ministere_mouvement(text, numeric, text, boolean) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.caisse_ministere_mouvement(text, numeric, text, boolean) TO authenticated;