-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920123205
-- Nom original      : football_pari_engager_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 12:32:05 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f8000d8dae888f75bdfde1eb53d70d76
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
-- §6.3 — LE PARI S'ENGAGE DESORMAIS PAR UN GUICHET SERVEUR
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait inserer une ligne dans
-- paris_sportifs (INSERT reussi sous veritable role authenticated).
--
-- CE QUE CELA PERMETTAIT, PRECISEMENT. football_paris_resoudre() est une RPC
-- rigoureuse : elle retrouve le match, exige qu'il soit JOUE, lit le score
-- persiste, applique ses propres cotes et fait resolution et paiement dans la
-- meme transaction. Mais elle paie ce qu'on lui presente. Il suffisait donc
-- d'inserer, APRES le coup de sifflet, un pari portant le bon pronostic, la
-- mise de son choix et son propre nom -- sans avoir jamais paye la mise, que le
-- client se contentait de retrancher localement (state.arg -= mise).
-- Gain net garanti, sans risque et sans limite.
--
-- LE GUICHET. p_mise est le seul parametre libre, et il est borne ; tout le
-- reste est etabli par le serveur :
--   * le parieur est l'appelant, jamais un nom transmis ;
--   * la saison est lue dans le championnat, pas annoncee ;
--   * le match doit exister dans la journee ET NE PAS ETRE JOUE ;
--   * la mise est reellement prelevee, avant l'inscription, et le pari n'existe
--     pas si le prelevement echoue ;
--   * l'anti-rejeu EST la cle : l'identifiant est deterministe
--     (parieur + saison + journee + match), donc un second pari sur la meme
--     rencontre est refuse par la contrainte, pas par une garde applicative.
--
-- CE QUI N'EST PAS CHANGE ICI, VOLONTAIREMENT : la mise est prise sur `arg` et
-- le gain y est recredite, exactement comme avant. Les cotes (2,5 / 3,5 / 3) et
-- le minimum de 10 FR sont repris tels quels de l'existant. Aucune regle de jeu
-- n'est arbitree dans cette migration -- elle ne fait que rendre serveur ce qui
-- etait client.
-- Note remontee au rapport : le reste de l'economie distingue `liquide`
-- (depensable) de `arg` (fortune affichee) ; les paris vivent entierement dans
-- `arg`. C'est une asymetrie preexistante, a trancher dans le lot monetaire.

CREATE OR REPLACE FUNCTION public.football_pari_engager(
  p_home    text,
  p_away    text,
  p_journee integer,
  p_choix   text,
  p_mise    integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb;
  v_id text; v_arg numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF p_choix IS NULL OR p_choix NOT IN ('domicile', 'nul', 'adversaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;
  -- Minimum repris de l'ecran existant. Plafond de securite : une mise ne peut
  -- pas etre un nombre arbitraire, meme si le joueur avait les fonds.
  IF p_mise IS NULL OR p_mise < 10 OR p_mise > 1000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mise_invalide');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data ->> 'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data -> 'calendrier', '[]'::jsonb)) j
   WHERE (j ->> 'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  SELECT m INTO v_m FROM jsonb_array_elements(coalesce(v_j -> 'matchs', '[]'::jsonb)) m
   WHERE m ->> 'home' = p_home AND m ->> 'away' = p_away;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_inconnu');
  END IF;
  -- LE POINT CENTRAL : on ne parie pas sur un resultat connu.
  IF coalesce((v_m ->> 'played')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_deja_joue');
  END IF;

  v_id := 'pari:' || v_moi || ':' || v_saison || ':' || p_journee || ':' || p_home || ':' || p_away;

  -- La mise EST prelevee, et elle l'est AVANT toute inscription. Verrou sur la
  -- fiche : deux paris simultanes ne peuvent pas depenser le meme argent.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_introuvable');
  END IF;
  IF v_arg < p_mise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'arg', v_arg, 'mise', p_mise);
  END IF;

  BEGIN
    INSERT INTO public.paris_sportifs (id, resolu, data)
    VALUES (v_id, false, jsonb_build_object(
      'joueur', v_moi, 'homeId', p_home, 'awayId', p_away, 'choix', p_choix,
      'mise', p_mise, 'journeeNumero', p_journee, 'saisonNumero', v_saison));
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pari_deja_engage');
  END;

  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) - p_mise, updated_at = now()
   WHERE name = v_moi
   RETURNING arg INTO v_arg;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mise', p_mise,
                            'saison', v_saison, 'arg', v_arg);
END;
$$;

REVOKE ALL ON FUNCTION public.football_pari_engager(text, text, integer, text, integer)
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.football_pari_engager(text, text, integer, text, integer)
  TO authenticated, service_role;