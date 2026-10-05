-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163827
-- Nom original      : socle_pnj_employe_recruter_licencier_au_socle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 16:38:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d20ed4ffd8b81de666fd553c555684f6
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
-- CHECKPOINT A2 (2/2) — LA FAMILLE `employe` ENTRE AU SOCLE, DIRECTEMENT AUTORITAIRE
--
-- POURQUOI SANS PHASE MIROIR. Verifie avant d'ecrire : la production ne contient AUCUN employe,
-- AUCUNE escorte, AUCUN informateur (0 ligne dans personnages_donnees.employes / escort_active).
-- Il n'y a donc rien a importer et aucune divergence possible a couvrir. Le socle peut etre
-- autoritaire des le premier recrutement, ce qui evite de construire un miroir pour zero donnee.
--
-- UN PNJ EXISTE UNE FOIS. Aucune de ces fonctions n'ecrit dans room.persons : c'est la strategie de
-- l'informateur, celle qui a fonctionne. La presence de l'employe vient de son etat -- leader_pj
-- pose, position propre nulle -- exactement comme un soldat qui suit son lieutenant.
--
-- CE QUI N'EST PAS FAIT ICI, VOLONTAIREMENT :
--   * `codetenu` est ABSENT des metiers recrutables. Le metier n'a jamais eu de chemin vivant et ne
--     doit pas en recevoir un ; son profil reste au referentiel pour le futur.
--   * la loyaute n'est pas stockee : le debauchage continue de lire PNJ_STATS_PAR_JOB cote client,
--     comportement inchange. L'y recopier aurait invente une source.
--   * aucun combatBonus, aucun effet dormant n'est reveille.
CREATE OR REPLACE FUNCTION public.employe_metiers_recrutables()
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  -- codetenu volontairement exclu : metier prevu, jamais active.
  SELECT ARRAY['escort','informateur']::text[];
$$;

-- Identifiant stable et lisible. Le proprietaire en fait partie : deux joueurs peuvent employer
-- deux PNJ portant le meme nom de catalogue sans collision.
CREATE OR REPLACE FUNCTION public.employe_pnj_id(p_proprietaire text, p_metier text, p_nom text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'emp-' || p_metier || '-' || substr(md5(lower(btrim(p_proprietaire)) || '|' ||
                                                 lower(btrim(p_nom))), 1, 12);
$$;

CREATE OR REPLACE FUNCTION public.employe_recruter(
  p_metier text, p_nom text, p_genre text DEFAULT NULL,
  p_fn text DEFAULT NULL, p_pa integer DEFAULT NULL, p_cost integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_max_employes constant integer := 10;   -- MAX_EMPLOYES cote client, valeur historique
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb;
  v_pa integer; v_cost integer; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_metier IS NOT TRUE IS NULL THEN NULL; END IF;  -- garde syntaxique neutre
  IF NOT (p_metier = ANY (public.employe_metiers_recrutables())) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
      'metier', COALESCE(p_metier, '<NULL>'),
      'recrutables', public.employe_metiers_recrutables()); END IF;

  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = p_metier;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  -- QUOTAS, lus sur le socle qui fait desormais autorite.
  SELECT count(*) INTO v_deja
    FROM public.pnj_membres m WHERE m.famille = 'employe'
     AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
      'plafond', c_max_employes); END IF;

  IF p_metier = 'escort' THEN
    -- Un par genre : c'est la regle historique, conservee telle quelle.
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'
                  AND e.job = 'escort' AND e.genre IS NOT DISTINCT FROM p_genre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'genre', p_genre); END IF;
  ELSE
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif' AND e.job = p_metier) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier); END IF;
  END IF;

  v_id := public.employe_pnj_id(v_moi, p_metier, v_nom);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employe', 'pnj_id', v_id); END IF;

  -- PAIEMENT, DANS LA MEME TRANSACTION QUE LA CREATION. Un refus de paiement ne laisse donc aucun
  -- employe derriere lui, et un echec de creation ne laisse aucun debit.
  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL THEN
    -- Chemin d'un ORDRE declare : payer_ordre revalide le cout contre le miroir de data.js.
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSIF v_cost > 0 THEN
    -- Chemin d'un bouton de fiche PNJ : pas d'ordre, donc pas de cout a revalider.
    v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  -- IDENTITE AU SOCLE. classe beta explicite ; propriete au JOUEUR ; il suit son employeur, donc
  -- aucune position propre (contrainte pnj_position_deux_etats). Les caracteristiques viennent du
  -- referentiel : aucun tirage.
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', 'beta', v_nom,
      (SELECT COALESCE(country, 'republic') FROM public.personnages_donnees WHERE name = v_moi),
      v_moi, v_moi, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, ville = NULL, building_id = NULL, room_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, depuis_jour)
  VALUES (v_id, p_metier,
          CASE p_metier WHEN 'escort' THEN 'Escort — Agence Roxane Velours'
                        WHEN 'informateur' THEN 'Informateur' ELSE initcap(p_metier) END,
          v_prof.cout_jour, p_genre, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
      job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'metier', p_metier, 'nom', v_nom,
    'genre', p_genre, 'cout_jour', v_prof.cout_jour, 'cout_initial', v_cost, 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(p_metier),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END; $$;

-- LICENCIEMENT / DEPART. Jamais un DELETE : la garde de suppression refuserait un PNJ actif, et un
-- employe qui s'en va n'est pas mort. On le delie et on le marque disparu, comme un agent de la
-- force publique retire faute de budget.
CREATE OR REPLACE FUNCTION public.employe_liberer(p_pnj_id text, p_motif text DEFAULT 'licenciement')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_m record;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT m.*, e.job INTO v_m FROM public.pnj_membres m
    LEFT JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
   WHERE m.id = p_pnj_id FOR UPDATE;
  IF v_m.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'employe_introuvable'); END IF;
  IF v_m.famille IS DISTINCT FROM 'employe' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_employe',
      'famille', v_m.famille); END IF;
  -- Seul son proprietaire le libere. Un appel serveur (cron d'impaye) n'a pas de proprietaire a
  -- prouver, mais un joueur ne peut pas licencier l'employe d'un autre.
  IF v_moi IS NOT NULL AND v_m.proprietaire_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_employe'); END IF;
  IF v_m.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', true, 'deja_parti', true, 'pnj_id', p_pnj_id); END IF;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id = p_pnj_id;
  RETURN jsonb_build_object('ok', true, 'pnj_id', p_pnj_id, 'metier', v_m.job, 'motif', p_motif);
END; $$;

-- Lecture pour le client : ses employes, avec leur metier et leurs caracteristiques fixes.
CREATE OR REPLACE FUNCTION public.employe_mes_employes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'employes', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'pnj_id', m.id, 'nom', m.nom, 'metier', e.job, 'role', e.role_libelle,
             'genre', e.genre, 'cout_jour', e.cout_jour, 'pa', m.pa, 'liquide', m.liquide,
             'porte', (m.leader_pj = v_moi),
             'caracteristiques', public.pnj_caracteristiques_base(m.id))
           ORDER BY e.job, m.nom)
      FROM public.pnj_membres m JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'), '[]'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.employe_pnj_id(text, text, text) FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.employe_metiers_recrutables() FROM anon;