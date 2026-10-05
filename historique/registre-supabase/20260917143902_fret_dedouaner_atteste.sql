-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917143902
-- Nom original      : fret_dedouaner_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 14:39:02 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8cbcf7f5cb0e739dbaae746923dcf331
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
-- CAISSES FRET/DOUANE — LE DEDOUANEMENT DEVIENT UNE SEULE TRANSACTION ATTESTEE.
--
-- CONSTAT : dedouanerCaisseFret debitait le joueur en local (state.arg -= total) puis creditait
-- la caisse du port par un SECOND appel, en .catch(() => {}). Entre les deux, l'argent n'existait
-- nulle part : un echec du credit le detruisait, apres que le joueur l'ait paye. Le montant etait
-- calcule par le navigateur, et l'autorite (« etre le destinataire ») verifiee cote client
-- seulement -- le PATCH de caisses_fret ne filtrait pas sur destinataire, si bien qu'un appel
-- direct pouvait dedouaner la caisse d'un autre.
--
-- MONTANT RECALCULE SERVEUR, a la formule existante et inchangee :
--   douane       = round(valeur_declaree * 10 / 100)                       [TAUX_DOUANE_FRET]
--   gardiennage  = round(valeur_declaree * 1 / 100 * jours_factures)       [TAUX_..._JOUR]
--   jours_factures = max(0, floor(jours ecoules depuis date_arrivee_reelle) - 7)  [FRANCHISE]
-- Le « maintenant » est celui du SERVEUR, plus celui du navigateur : une horloge locale avancee
-- ne peut plus gonfler ni reduire le gardiennage.
--
-- Le debit porte sur les FONDS ORDINAIRES (liquide puis Banque nationale), primitive canonique de
-- depense du projet -- `arg` inclut Helvetia et les placements, qui ne doivent jamais couvrir une
-- depense courante. Meme doctrine que eviction_indemniser.
--
-- IDEMPOTENCE : la transition dedouanee false -> true a lieu dans la meme transaction, sous
-- verrou de ligne. Un rejeu trouve dedouanee = true et rend 'deja_dedouanee' sans rien debiter.
-- C'est le meme garde-fou que le filtre &dedouanee=eq.false du client, mais cote serveur.
CREATE OR REPLACE FUNCTION public.fret_dedouaner(p_caisse_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; c record; v_val numeric; v_jours int; v_factures int;
  v_douane numeric; v_gard numeric; v_total numeric; v_caisse text; v_mvt jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  IF c.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF COALESCE(c.dedouanee, false) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'deja_dedouanee');
  END IF;
  IF COALESCE(c.statut, '') <> 'arrivee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide', 'statut', c.statut);
  END IF;

  v_val := GREATEST(0, COALESCE(c.valeur_declaree, 0));
  v_douane := round(v_val * 10 / 100.0);
  v_gard := 0;
  IF c.date_arrivee_reelle IS NOT NULL THEN
    v_jours := floor(EXTRACT(epoch FROM (now() - c.date_arrivee_reelle)) / 86400)::int;
    v_factures := GREATEST(0, v_jours - 7);
    IF v_factures > 0 THEN v_gard := round(v_val * 1 / 100.0 * v_factures); END IF;
  END IF;
  v_total := v_douane + v_gard;

  IF v_total > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                                'douane', v_douane, 'gardiennage', v_gard);
    END IF;
    -- Credit de la caisse du port DANS LA MEME TRANSACTION que le debit.
    v_caisse := c.pays_destination || '_' || c.building_destination;
    v_mvt := public.caisse_institution_mouvement(v_caisse, v_total, false);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'credit_caisse_port_impossible: %', COALESCE(v_mvt->>'raison','?');
    END IF;
  END IF;

  UPDATE public.caisses_fret
     SET dedouanee = true, date_dedouanement = now()
   WHERE id = p_caisse_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'douane', v_douane,
    'gardiennage', v_gard, 'jours_factures', COALESCE(v_factures, 0), 'caisse', v_caisse,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END; $fn$;
REVOKE EXECUTE ON FUNCTION public.fret_dedouaner(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fret_dedouaner(uuid) TO authenticated;