-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919171638
-- Nom original      : cellule_renseignement_creer
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:16:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ba5bc3f3ae12f116b92813b28105018d
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
-- Creation d'une cellule de renseignement. 500 FR + 3 PA, 10 jours REELS.
--
-- AUTORITE ET PAIEMENT NON CONTOURNABLES. Consigne explicite : ne pas rendre
-- l'espionnage dependant d'un debit falsifiable. caisse_institution_mouvement
-- n'exige aujourd'hui qu'"un personnage authentifie" -- dette connue, signalee,
-- hors perimetre de ce lot. Elle n'est donc PAS appelee par le navigateur ici :
-- c'est CETTE RPC qui verifie d'abord le poste min_def atteste, puis debite
-- elle-meme, dans la meme transaction. Le chemin de paiement de la cellule est
-- ainsi serveur-autoritaire de bout en bout, independamment de cette dette.
--
-- CAISSE DEBITEE : <pays>_gouvernement-min_def. Le GD confie la cellule au
-- Ministre de la Defense ; c'est sa caisse. (La caisse de caserne, utilisee par
-- l'ancien ordre `renseignement`, contient 200 FR pour un cout de 500 : cet
-- ordre etait donc inexecutable, constat deja rapporte.) Un seul identifiant a
-- changer si l'arbitrage differe.
--
-- AUCUN CONTENU DE GAME DESIGN INVENTE : les vraies identites et les noms de
-- couverture sont LUS dans renseignement_identites_reelles et
-- renseignement_couvertures. Tant que le GD ne les a pas garnies, la fonction
-- refuse proprement (`identites_reelles_incompletes`, `pool_couvertures_insuffisant`)
-- au lieu de fabriquer un nom.
--
-- Les couvertures sont tirees UNE FOIS ici et restent FIXES pour les 10 jours :
-- aucun reroll a l'affichage, au deplacement ou a la reconnexion.

CREATE OR REPLACE FUNCTION public.cellule_renseignement_creer(p_pays_cible text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa   constant integer := 3;
  c_cout constant numeric := 500;
  v_nom text; v_poste text; v_pays text;
  v_pa integer; v_caisse text; v_mvt jsonb;
  v_cellule text; v_echeance timestamptz;
  v_nb_id integer; v_nb_couv integer;
  v_agents jsonb := '[]'::jsonb;
  r record; v_couv text; v_idx integer := 0;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_pays_cible IS NULL OR btrim(p_pays_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente');
  END IF;
  IF p_pays_cible = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_mon_pays');
  END IF;

  -- Les quatre identites reelles doivent etre definies par le GD.
  SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;
  IF v_nb_id < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identites_reelles_incompletes',
                              'definies', v_nb_id, 'attendues', 4);
  END IF;

  -- Il faut au moins quatre couvertures LIBRES pour le pays cible.
  SELECT count(*) INTO v_nb_couv
    FROM public.renseignement_couvertures c
   WHERE c.pays = p_pays_cible
     AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                      WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                        AND a.statut IN ('actif', 'detenu'));
  IF v_nb_couv < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pool_couvertures_insuffisant',
                              'libres', v_nb_couv, 'requises', 4);
  END IF;

  -- PA : lus et debites ici, jamais annonces par le client.
  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'disponibles', v_pa);
  END IF;

  -- 500 FR : debit atomique AVANT toute creation. Si la caisse ne couvre pas,
  -- rien n'est cree et aucun PA n'est preleve.
  v_caisse := v_pays || '_gouvernement-min_def';
  v_mvt := public.caisse_institution_mouvement(v_caisse, -c_cout, false);
  IF coalesce((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'requis', c_cout,
                              'detail', v_mvt ->> 'raison');
  END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_nom;

  v_cellule  := 'cel-' || (extract(epoch from clock_timestamp())*1000)::bigint
                       || '-' || substr(md5(random()::text), 1, 6);
  v_echeance := now() + interval '10 days';

  INSERT INTO public.cellules_renseignement
    (id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)
  VALUES (v_cellule, v_pays, p_pays_cible, v_nom, 'active', c_cout, v_caisse, v_echeance);

  -- Un agent par role, couverture tiree au sort parmi les noms LIBRES du pays
  -- cible, puis figee. Le tirage se fait role par role pour que deux agents ne
  -- puissent jamais recevoir la meme couverture.
  FOR r IN SELECT role, vrai_nom, dup FROM public.renseignement_identites_reelles ORDER BY role
  LOOP
    SELECT c.nom INTO v_couv
      FROM public.renseignement_couvertures c
     WHERE c.pays = p_pays_cible
       AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                        WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                          AND a.statut IN ('actif', 'detenu'))
     ORDER BY random() LIMIT 1;
    IF v_couv IS NULL THEN
      RAISE EXCEPTION 'pool_couvertures_epuise';   -- annule toute la transaction
    END IF;
    v_idx := v_idx + 1;
    INSERT INTO public.agents_renseignement
      (id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut)
    VALUES (v_cellule || '-a' || v_idx, v_cellule, r.role, r.vrai_nom, r.dup,
            p_pays_cible, v_couv, 'actif');
    -- Le MINISTRE PROPRIETAIRE a le droit de connaitre les siens.
    v_agents := v_agents || jsonb_build_array(jsonb_build_object(
      'role', r.role, 'vrai_nom', r.vrai_nom, 'couverture', v_couv, 'dup', r.dup,
      'statut', 'actif'));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'cellule', v_cellule, 'pays_cible', p_pays_cible,
    'echeance', v_echeance, 'cout', c_cout, 'caisse', v_caisse,
    'pa_restants', v_pa - c_pa, 'agents', v_agents);
END;
$function$;

REVOKE ALL ON FUNCTION public.cellule_renseignement_creer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_creer(text) TO authenticated, service_role;
