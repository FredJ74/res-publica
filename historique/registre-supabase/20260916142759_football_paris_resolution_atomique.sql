-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916142759
-- Nom original      : football_paris_resolution_atomique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 14:27:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ab2729d6aed0d063bce7c31e2b37b5d4
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
-- UN PARI RESOLU EST UN PARI PAYE (16 septembre 2026).
--
-- LE DEFAUT. sbResoudrePari marquait d'abord le pari `resolu = true` -- ecriture qui aboutit,
-- paris_sportifs est ouverte -- puis creditait le gagnant par une ecriture directe sur SA fiche,
-- refusee depuis le chantier B. Le pari devenait donc DEFINITIVEMENT resolu sans que le gain
-- soit jamais verse, pendant qu'un mail « Pari gagne ! +X FR » partait. Irreversible : le pari
-- n'est plus repris par aucune passe.
--
-- LA REGLE, retrouvee dans le code et NON MODIFIEE : cotes 2.5 (domicile), 3.5 (nul), 3
-- (adversaire) ; gain = round(mise x cote) pour un pari gagnant, rien sinon ; la mise a deja ete
-- prelevee au moment du pari.
--
-- CE QUE LE SERVEUR FAIT : il retrouve le match dans le championnat, exige qu'il soit joue, en
-- lit le score persiste, en deduit le resultat reel, calcule le gain et -- dans la MEME
-- transaction -- marque le pari resolu ET credite le parieur. Soit les deux, soit aucun.
-- L'appelant ne designe qu'une journee : ni parieur, ni montant, ni cote.
--
-- IDEMPOTENCE : seuls les paris `resolu = false` sont repris, et la ligne est verrouillee
-- (FOR UPDATE SKIP LOCKED) -- deux navigateurs qui resolvent la meme journee au meme instant ne
-- paient jamais deux fois. Un rejeu ne retrouve plus rien a faire.

CREATE OR REPLACE FUNCTION public.football_paris_resoudre(p_journee integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_j jsonb; v_p record; v_m jsonb;
  v_reel text; v_cote numeric; v_gain integer; v_gagne boolean;
  v_regles integer := 0; v_payes integer := 0; v_total integer := 0;
  v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  FOR v_p IN
    SELECT id, data FROM public.paris_sportifs
     WHERE resolu = false
       AND (data->>'journeeNumero')::int = p_journee
       AND (data->>'saisonNumero')::int = v_saison
     FOR UPDATE SKIP LOCKED
  LOOP
    -- Le match doit exister ET etre joue : un pari sur une rencontre non disputee reste ouvert.
    SELECT m INTO v_m FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m
     WHERE m->>'home' = v_p.data->>'homeId' AND m->>'away' = v_p.data->>'awayId';
    CONTINUE WHEN v_m IS NULL OR NOT coalesce((v_m->>'played')::boolean, false);

    v_reel := CASE
      WHEN coalesce((v_m->>'scoreHome')::int, 0) > coalesce((v_m->>'scoreAway')::int, 0) THEN 'domicile'
      WHEN coalesce((v_m->>'scoreHome')::int, 0) < coalesce((v_m->>'scoreAway')::int, 0) THEN 'adversaire'
      ELSE 'nul' END;
    v_gagne := (v_reel = (v_p.data->>'choix'));
    v_cote  := CASE v_p.data->>'choix'
                 WHEN 'domicile' THEN 2.5 WHEN 'nul' THEN 3.5 WHEN 'adversaire' THEN 3
                 ELSE NULL END;
    IF v_cote IS NULL THEN CONTINUE; END IF;   -- choix inconnu : on ne touche a rien
    v_gain := CASE WHEN v_gagne
                   THEN round(coalesce((v_p.data->>'mise')::numeric, 0) * v_cote)::int
                   ELSE 0 END;

    -- LES DEUX ENSEMBLE : resolution et paiement.
    UPDATE public.paris_sportifs SET resolu = true WHERE id = v_p.id;
    IF v_gain > 0 THEN
      UPDATE public.personnages_donnees
         SET arg = coalesce(arg, 0) + v_gain
       WHERE name = v_p.data->>'joueur';
      IF FOUND THEN
        v_payes := v_payes + 1; v_total := v_total + v_gain;
      END IF;
    END IF;

    v_regles := v_regles + 1;
    v_detail := v_detail || jsonb_build_object(
      'id', v_p.id, 'joueur', v_p.data->>'joueur', 'gagne', v_gagne, 'gain', v_gain,
      'homeId', v_p.data->>'homeId', 'awayId', v_p.data->>'awayId');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'journee', p_journee, 'regles', v_regles,
                            'payes', v_payes, 'total', v_total, 'detail', v_detail);
END; $$;

REVOKE ALL ON FUNCTION public.football_paris_resoudre(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.football_paris_resoudre(integer) TO authenticated;