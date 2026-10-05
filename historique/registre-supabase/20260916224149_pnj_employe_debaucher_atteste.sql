-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916224149
-- Nom original      : pnj_employe_debaucher_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:41:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7d0fbb079623643271c611588095d8a2
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
-- LOT 3 — DEBAUCHAGE D'UN PNJ EMPLOYE : FIN DE LA DUPLICATION
-- Audit des frontieres d'autorite, 17 septembre 2026.
--
-- CONSTAT : confirmerDebauchage (plateau-multijoueur.js) retirait le PNJ de la liste de son
-- ancien employeur par un sbGet + sbUpdate DIRECTS sur la fiche d'AUTRUI, tous deux enveloppes
-- dans un try/catch et un .catch(() => {}) decoratifs. Or, depuis la fermeture RLS, un joueur ne
-- peut plus ecrire la fiche d'un autre : sbUpdate rend null sans lever. Le retrait echouait donc
-- TOUJOURS en silence, tandis que l'ajout chez le debaucheur, lui, reussissait (ecriture de sa
-- propre fiche). Resultat : le meme PNJ restait employe de l'ancien proprietaire ET apparaissait
-- chez le nouveau -- duplication permanente, declenchable a volonte par n'importe quel joueur
-- contre n'importe qui, et annoncee par un toast « Debauchage reussi ! » et un mail a la victime.
--
-- Cette RPC ne fait QUE ce que le code tentait deja de faire, mais reellement et sous verrou.
-- Aucune regle de jeu ne change : ni le jet, ni le taux, ni le cout, ni qui peut debaucher --
-- tout cela reste decide par l'appelant, inchange. Elle repond aussi « deja_parti » quand le PNJ
-- n'est plus chez l'ancien employeur (course entre deux debaucheurs), ce qui permet a l'appelant
-- de ne pas creer un second exemplaire.
CREATE OR REPLACE FUNCTION public.pnj_employe_debaucher(
  p_ancien_proprietaire text, p_pnj_nom text, p_job text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_col text; v_liste jsonb; v_reste jsonb; v_present boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_pnj_nom), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_invalide');
  END IF;
  -- Un PNJ sans proprietaire (employeur PNJ ou personne) : rien a retirer, le debauchage est
  -- simplement libre. On le dit explicitement plutot que d'echouer.
  IF COALESCE(btrim(p_ancien_proprietaire), '') = '' OR p_ancien_proprietaire = v_moi THEN
    RETURN jsonb_build_object('ok', true, 'retire', false, 'sans_proprietaire', true);
  END IF;

  v_col := CASE WHEN p_job = 'escort' THEN 'escort_active' ELSE 'employes' END;

  IF v_col = 'escort_active' THEN
    SELECT escort_active INTO v_liste FROM public.personnages_donnees
     WHERE name = p_ancien_proprietaire FOR UPDATE;
  ELSE
    SELECT employes INTO v_liste FROM public.personnages_donnees
     WHERE name = p_ancien_proprietaire FOR UPDATE;
  END IF;
  IF NOT FOUND THEN
    -- L'ancien proprietaire n'existe plus : plus rien ne detient ce PNJ.
    RETURN jsonb_build_object('ok', true, 'retire', false, 'proprietaire_absent', true);
  END IF;

  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;

  SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) INTO v_reste
    FROM jsonb_array_elements(v_liste) e
   WHERE e->>'nom' IS DISTINCT FROM p_pnj_nom;

  v_present := jsonb_array_length(v_liste) > jsonb_array_length(v_reste);
  IF NOT v_present THEN
    -- Deja parti (double-clic, ou un autre joueur l'a debauche entre-temps).
    RETURN jsonb_build_object('ok', true, 'retire', false, 'deja_parti', true);
  END IF;

  IF v_col = 'escort_active' THEN
    UPDATE public.personnages_donnees SET escort_active = v_reste, updated_at = now()
     WHERE name = p_ancien_proprietaire;
  ELSE
    UPDATE public.personnages_donnees SET employes = v_reste, updated_at = now()
     WHERE name = p_ancien_proprietaire;
  END IF;

  RETURN jsonb_build_object('ok', true, 'retire', true,
                            'ancien_proprietaire', p_ancien_proprietaire, 'pnj', p_pnj_nom);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.pnj_employe_debaucher(text, text, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.pnj_employe_debaucher(text, text, text) TO authenticated;