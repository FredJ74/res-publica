-- APPLIQUÉE EN PRODUCTION le 31/10/2026 (registre `transfert_prime_signature_serveur_20261031220000`,
-- version 20261031211256). NEUTRALISÉE par 20261101190000_transfert_sans_prime_signature.sql
-- (décision de Fred, 01/11 : pas de prime de signature dans le transfert, question entre PJ).
-- Fichier conservé comme trace de ce qui est en base ; ne pas le rejouer.
-- PRIME DE SIGNATURE D'UN TRANSFERT PAR LE SERVEUR (31/10/2026, suite de #295 / PR #300).
--
-- Avant : quand le joueur acceptait un transfert, `club_transfert_conclure` réglait le prix entre
-- les clubs, puis l'écran ajoutait lui-même `prixJoueur` à l'argent du joueur
-- (`crediterFondsOrdinaires`). Cet argent ne sortait d'aucune caisse (création monétaire) et ne
-- tenait qu'à la sauvegarde de l'écran ; `prixJoueur` pouvait de plus être posé à n'importe quelle
-- valeur dans l'INSERT de l'offre.
--
-- Règle reprise telle quelle : la prime est le montant `prixJoueur` inscrit dans l'offre du club
-- d'arrivée (absent = 0 ; aucun écran ne le propose aujourd'hui), affiché au joueur comme
-- « Prime de signature proposée », versé au joueur quand il accepte. Ce qui change : la prime sort
-- de la caisse du club d'arrivée, dans la même transaction que le prix du transfert.
--
--   * transferts_clubs_garder : à l'INSERT, `prixJoueur` absent ou entier >= 0 (déjà immuable ensuite).
--   * club_transfert_conclure : le club d'arrivée doit couvrir prix + prime, sinon refus intégral ;
--     prime créditée au joueur par `assemblee_crediter_joueur` (table `personnages_donnees`),
--     tracée dans l'historique de la caisse et dans le transfert (`primeVersee`) ; réponse avec
--     la fiche canonique (`liquide`, `arg`). Le verrou du transfert et `concluPar` garantissent un
--     seul versement (double clic, réponse perdue, reconnexion : rejeu sans mouvement).
--
-- Indépendante de l'écran : l'ancien écran continue de fonctionner (il ajoutait la prime
-- localement, la garde de la fiche annulait déjà cet ajout à la sauvegarde) ; le nouvel écran
-- adopte la fiche rendue par le serveur.
-- Banc : outils/bancs/banc-prime-signature-local.py --local-jetable

BEGIN;

DO $g$ DECLARE h text; BEGIN
  -- Empreinte sans les lignes de commentaire : l'application par Supabase les retire du corps.
  SELECT md5(regexp_replace(prosrc, E'\\n[ \\t]*--[^\\n]*', '', 'g')) INTO h FROM pg_proc WHERE oid = to_regprocedure('public.club_transfert_conclure(text)');
  IF h IS NULL OR h <> '057d4b8e51e41eae3bc59d615a4df391' AND NOT EXISTS (
       SELECT 1 FROM pg_proc WHERE oid = to_regprocedure('public.club_transfert_conclure(text)') AND prosrc LIKE '%primeVersee%') THEN
    RAISE EXCEPTION 'definition_non_examinee: public.club_transfert_conclure(text) %', h;
  END IF;
  SELECT md5(regexp_replace(prosrc, E'\\n[ \\t]*--[^\\n]*', '', 'g')) INTO h FROM pg_proc WHERE oid = to_regprocedure('public.transferts_clubs_garder()');
  IF h IS NULL OR h <> '57b1fac354c1140d9644954909424b1f' AND NOT EXISTS (
       SELECT 1 FROM pg_proc WHERE oid = to_regprocedure('public.transferts_clubs_garder()') AND prosrc LIKE '%transfert_prime_invalide%') THEN
    RAISE EXCEPTION 'definition_non_examinee: public.transferts_clubs_garder() %', h;
  END IF;
  IF to_regprocedure('public.assemblee_crediter_joueur(text,integer)') IS NULL
     OR to_regprocedure('public.club_caisse_ajuster_interne(text,numeric,text,integer)') IS NULL THEN
    RAISE EXCEPTION 'primitives_requises: assemblee_crediter_joueur, club_caisse_ajuster_interne';
  END IF;
END $g$;

-- ------------------------------------------------------- 1. garde : prime de l'offre bornée
-- Pas SECURITY DEFINER : la garde s'appuie sur current_user (anon / authenticated = l'écran).
CREATE OR REPLACE FUNCTION public.transferts_clubs_garder() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_n jsonb; v_o jsonb; v_pres_arr text; v_pres_dep text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RAISE EXCEPTION 'transfert_acteur_non_authentifie' USING ERRCODE = '42501'; END IF;
  v_n := NEW.data;
  IF NEW.statut IS DISTINCT FROM v_n->>'statut' THEN
    RAISE EXCEPTION 'transfert_statut_incoherent' USING ERRCODE = '42501';
  END IF;
  IF NEW.statut = 'termine' AND (v_n ? 'concluPar' OR v_n ? 'primeVersee')
     AND (TG_OP = 'INSERT' OR NOT (OLD.data ? 'concluPar' OR OLD.data ? 'primeVersee')) THEN
    RAISE EXCEPTION 'transfert_reglement_reserve_au_serveur' USING ERRCODE = '42501';
  END IF;
  v_pres_arr := (SELECT data->>'president' FROM public.presidents_clubs WHERE id = v_n->>'clubArriveeId');

  IF TG_OP = 'INSERT' THEN
    IF NEW.statut <> 'propose' OR v_n->>'proposePar' IS DISTINCT FROM v_moi OR v_pres_arr IS DISTINCT FROM v_moi
       OR jsonb_typeof(v_n->'prixClub') <> 'number' OR (v_n->>'prixClub')::numeric <= 0 THEN
      RAISE EXCEPTION 'transfert_offre_non_autorisee' USING ERRCODE = '42501';
    END IF;
    IF v_n ? 'prixJoueur' AND (jsonb_typeof(v_n->'prixJoueur') <> 'number'
         OR (v_n->>'prixJoueur')::numeric < 0 OR (v_n->>'prixJoueur')::numeric <> trunc((v_n->>'prixJoueur')::numeric)) THEN
      RAISE EXCEPTION 'transfert_prime_invalide' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  v_o := OLD.data;
  IF (v_n->>'joueur', v_n->>'clubDepartId', v_n->>'clubArriveeId', v_n->>'proposePar', v_n->'prixJoueur')
     IS DISTINCT FROM (v_o->>'joueur', v_o->>'clubDepartId', v_o->>'clubArriveeId', v_o->>'proposePar', v_o->'prixJoueur') THEN
    RAISE EXCEPTION 'transfert_termes_immuables' USING ERRCODE = '42501';
  END IF;
  v_pres_dep := (SELECT data->>'president' FROM public.presidents_clubs WHERE id = v_o->>'clubDepartId');

  IF OLD.statut = 'propose' AND v_pres_dep = v_moi
     AND NEW.statut IN ('termine', 'contre_offre', 'attente_joueur')
     AND ((v_n->'prixClub') = (v_o->'prixClub')
          OR (NEW.statut = 'contre_offre' AND jsonb_typeof(v_n->'prixClub') = 'number' AND (v_n->>'prixClub')::numeric > 0)) THEN
    RETURN NEW;
  END IF;
  IF OLD.statut = 'contre_offre' AND v_pres_arr = v_moi AND NEW.statut IN ('termine', 'attente_joueur')
     AND (v_n->'prixClub') = (v_o->'prixClub') THEN
    RETURN NEW;
  END IF;
  IF OLD.statut = 'attente_joueur' AND v_o->>'joueur' = v_moi AND NEW.statut = 'termine'
     AND (v_n->'prixClub') = (v_o->'prixClub') AND NOT v_n ? 'concluPar' AND NOT v_n ? 'primeVersee' THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'transfert_etape_non_autorisee' USING ERRCODE = '42501';
END $$;

-- ---------------------------------------- 2. conclusion : prix + prime, une seule transaction
CREATE OR REPLACE FUNCTION public.club_transfert_conclure(p_transfert text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_row record; v_t jsonb; v_prix numeric; v_prime numeric; v_jour integer;
        v_solde numeric; v_arr numeric; v_dep numeric; v_fiche jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_row FROM public.transferts_clubs WHERE id = p_transfert FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'transfert_introuvable'); END IF;
  v_t := v_row.data;
  IF v_t->>'joueur' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_joueur');
  END IF;
  IF v_row.statut = 'termine' AND v_t->>'concluPar' = v_moi THEN
    SELECT jsonb_build_object('liquide', liquide, 'arg', arg) INTO v_fiche
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'transfert', v_t,
                              'prime', coalesce(v_t->'primeVersee', '0'::jsonb), 'fiche', v_fiche);
  END IF;
  IF v_row.statut IS DISTINCT FROM 'attente_joueur' OR v_t->>'statut' IS DISTINCT FROM 'attente_joueur' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'transfert_non_ouvert', 'statut', v_row.statut);
  END IF;
  v_prix := CASE WHEN jsonb_typeof(v_t->'prixClub') = 'number' THEN (v_t->>'prixClub')::numeric END;
  IF v_prix IS NULL OR v_prix < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  -- Prime : celle inscrite dans l'offre du club d'arrivée (immuable depuis), 0 si absente.
  v_prime := CASE WHEN NOT v_t ? 'prixJoueur' OR jsonb_typeof(v_t->'prixJoueur') = 'null' THEN 0
                  WHEN jsonb_typeof(v_t->'prixJoueur') = 'number' THEN (v_t->>'prixJoueur')::numeric END;
  IF v_prime IS NULL OR v_prime < 0 OR v_prime <> trunc(v_prime) OR v_prime > 2147483647 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prime_invalide');
  END IF;
  v_jour := coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1);

  -- Ordre des verrous stable (identifiant croissant) pour éviter l'interblocage entre deux transferts.
  PERFORM 1 FROM public.budgets_clubs WHERE id IN (v_t->>'clubDepartId', v_t->>'clubArriveeId') ORDER BY id FOR UPDATE;
  -- Le club d'arrivée couvre prix ET prime, sinon rien ne bouge (ni club de départ, ni joueur).
  v_solde := (SELECT CASE WHEN jsonb_typeof(data->'caisse') = 'number' THEN (data->>'caisse')::numeric ELSE 0 END
                FROM public.budgets_clubs WHERE id = v_t->>'clubArriveeId');
  IF coalesce(v_solde, 0) < v_prix + v_prime THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_club_insuffisante');
  END IF;
  v_arr := public.club_caisse_ajuster_interne(v_t->>'clubArriveeId', -v_prix, 'Transfert de ' || v_moi, v_jour);
  IF v_arr IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_club_insuffisante');
  END IF;
  v_dep := public.club_caisse_ajuster_interne(v_t->>'clubDepartId', v_prix, 'Transfert de ' || v_moi, v_jour);
  IF v_prime > 0 THEN
    v_arr := public.club_caisse_ajuster_interne(v_t->>'clubArriveeId', -v_prime, 'Prime de signature de ' || v_moi, v_jour);
    IF v_arr IS NULL THEN RAISE EXCEPTION 'transfert: caisse insuffisante pour la prime'; END IF;
    v_fiche := public.assemblee_crediter_joueur(v_moi, v_prime::integer);
  ELSE
    SELECT jsonb_build_object('liquide', liquide, 'arg', arg) INTO v_fiche
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;

  v_t := v_t || jsonb_build_object('statut', 'termine', 'concluPar', v_moi, 'concluLe', now(), 'primeVersee', v_prime);
  UPDATE public.transferts_clubs SET statut = 'termine', data = v_t, updated_at = now() WHERE id = p_transfert;
  RETURN jsonb_build_object('ok', true, 'transfert', v_t, 'caisseArrivee', v_arr, 'caisseDepart', v_dep,
                            'prime', v_prime, 'fiche', v_fiche);
END $$;

REVOKE ALL ON FUNCTION public.club_transfert_conclure(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_transfert_conclure(text) TO authenticated;

-- ------------------------------------------------------------------------------ preuves
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_transferts_clubs_garder' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'garde des transferts absente';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.transferts_clubs_garder()'::regprocedure) THEN
    RAISE EXCEPTION 'la garde des transferts ne doit pas être SECURITY DEFINER';
  END IF;
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.club_transfert_conclure(text)'::regprocedure) NOT LIKE '%assemblee_crediter_joueur%' THEN
    RAISE EXCEPTION 'prime non raccordée';
  END IF;
END $$;

COMMIT;
