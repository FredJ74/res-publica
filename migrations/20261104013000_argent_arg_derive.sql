-- ARGENT : `arg` DEVIENT UN TOTAL CALCULE (04/11/2026, Claude, point ouvert « écart général de arg »).
--
-- Constat (relevé du 04/11) : `arg` est censé valoir liquide + Banque nationale (c'est ce que
-- disent les relais et ce que vérifie `payer_ordre_interne`, qui ne dépense QUE liquide + compte
-- national). Mais 18 fonctions serveur et 3 traitements du cron créditaient ou débitaient `arg`
-- SEUL : l'argent reçu (vente d'un bien, succession, subvention, indemnité, prime, gain de pari,
-- prêt accordé au compromis, remboursement d'acompte...) n'arrivait dans aucune poche réelle et
-- ne pouvait jamais être dépensé ; à l'inverse un débit de `arg` seul (taxe foncière, cotisation,
-- mise d'un pari, vol) ne coûtait rien au joueur. Écarts mesurés : Jean Jaaj +46 834, Angie −2 000.
--
-- Correction :
--  1. `arg` n'est plus écrit par personne : un déclencheur le recalcule à chaque écriture de la
--     fiche (liquide + solde du compte Banque nationale), et chaque mouvement du compte national
--     le rafraîchit. Tant qu'un personnage n'a pas encore son compte (création, avant
--     `compte_bancaire_initial`), `arg` est laissé tel quel : c'est la fortune de départ.
--  2. Deux moteurs internes (jamais appelables par un joueur) : `argent_crediter_interne`
--     (poche 'nationale' par défaut, 'liquide' pour l'argent de poche) et `argent_debiter_interne`
--     (liquide puis compte national, ou liquide seul pour un vol). Les écritures « arg seul »
--     sont remplacées par ces moteurs, patch en place de fragments vérifiés (un seul exemplaire).
--  3. `argent_mouvement_serveur` : même chose pour le cron (rôle service seulement).
--  4. Recalcul unique de toutes les fiches.
-- Aucun argent réellement dépensable n'est retiré à personne : l'écart de Jean Jaaj n'était
-- dépensable nulle part (payer_ordre ne lit que les poches).

-- ── 1. Moteurs ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.argent_crediter_interne(p_nom text, p_montant numeric, p_poche text DEFAULT 'nationale')
 RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_m numeric := round(coalesce(p_montant, 0)); v_id text;
BEGIN
  IF p_poche IS NULL OR p_poche NOT IN ('liquide', 'nationale') THEN RAISE EXCEPTION 'poche_invalide'; END IF;
  IF p_nom IS NULL OR v_m <= 0 THEN RETURN 0; END IF;
  -- Ordre de verrou du jeu : personnage puis compte.
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN 0; END IF;
  IF p_poche = 'nationale' THEN
    SELECT id INTO v_id FROM public.comptes_bancaires
     WHERE personnage = p_nom AND banque = 'nationale' ORDER BY id LIMIT 1 FOR UPDATE;
    IF v_id IS NOT NULL THEN
      UPDATE public.comptes_bancaires SET solde = coalesce(solde, 0) + v_m, updated_at = now() WHERE id = v_id;
      RETURN v_m;
    END IF;
    -- Pas encore de compte : jamais en créer un ici (compte_bancaire_initial le ferait passer pour
    -- déjà créé et la fortune de départ serait perdue) ; l'argent va dans la poche.
  END IF;
  UPDATE public.personnages_donnees SET liquide = coalesce(liquide, 0) + v_m, updated_at = now() WHERE name = p_nom;
  RETURN v_m;
END;
$function$;

CREATE OR REPLACE FUNCTION public.argent_debiter_interne(p_nom text, p_montant numeric, p_poches text DEFAULT 'liquide_puis_nationale')
 RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_m numeric := round(coalesce(p_montant, 0)); v_liq numeric; v_id text; v_solde numeric;
        v_pris_l numeric := 0; v_pris_n numeric := 0;
BEGIN
  IF p_poches IS NULL OR p_poches NOT IN ('liquide', 'liquide_puis_nationale') THEN RAISE EXCEPTION 'poches_invalides'; END IF;
  IF p_nom IS NULL OR v_m <= 0 THEN RETURN 0; END IF;
  SELECT coalesce(liquide, 0) INTO v_liq FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN 0; END IF;
  v_pris_l := least(greatest(v_liq, 0), v_m);
  IF p_poches = 'liquide_puis_nationale' AND v_pris_l < v_m THEN
    SELECT id, coalesce(solde, 0) INTO v_id, v_solde FROM public.comptes_bancaires
     WHERE personnage = p_nom AND banque = 'nationale' ORDER BY id LIMIT 1 FOR UPDATE;
    IF v_id IS NOT NULL THEN v_pris_n := least(greatest(v_solde, 0), v_m - v_pris_l); END IF;
  END IF;
  IF v_pris_l > 0 THEN
    UPDATE public.personnages_donnees SET liquide = v_liq - v_pris_l, updated_at = now() WHERE name = p_nom;
  END IF;
  IF v_pris_n > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_n, updated_at = now() WHERE id = v_id;
  END IF;
  RETURN v_pris_l + v_pris_n;  -- ce qui a réellement été pris (jamais plus que ce qu'il y avait)
END;
$function$;

CREATE OR REPLACE FUNCTION public.argent_mouvement_serveur(p_nom text, p_montant numeric, p_sens text, p_poche text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v numeric;
BEGIN
  IF p_sens = 'credit' THEN
    v := public.argent_crediter_interne(p_nom, p_montant, coalesce(p_poche, 'nationale'));
  ELSIF p_sens = 'debit' THEN
    v := public.argent_debiter_interne(p_nom, p_montant, coalesce(p_poche, 'liquide_puis_nationale'));
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  RETURN jsonb_build_object('ok', true, 'applique', v,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_nom));
END;
$function$;

REVOKE ALL ON FUNCTION public.argent_crediter_interne(text, numeric, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.argent_debiter_interne(text, numeric, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.argent_mouvement_serveur(text, numeric, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.argent_mouvement_serveur(text, numeric, text, text) TO service_role;

-- ── 2. `arg` calculé ───────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.personnages_arg_deriver()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_solde numeric; v_n integer;
BEGIN
  SELECT sum(coalesce(solde, 0)), count(*) INTO v_solde, v_n
    FROM public.comptes_bancaires WHERE personnage = NEW.name AND banque = 'nationale';
  IF v_n > 0 THEN NEW.arg := round(coalesce(NEW.liquide, 0) + v_solde); END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS zzz_personnages_arg_derive ON public.personnages_donnees;
CREATE TRIGGER zzz_personnages_arg_derive BEFORE INSERT OR UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_arg_deriver();

CREATE OR REPLACE FUNCTION public.comptes_nationaux_arg_rafraichir()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text;
BEGIN
  FOR v_nom IN
    SELECT DISTINCT x FROM unnest(ARRAY[
      CASE WHEN TG_OP <> 'DELETE' AND NEW.banque = 'nationale' THEN NEW.personnage END,
      CASE WHEN TG_OP <> 'INSERT' AND OLD.banque = 'nationale' THEN OLD.personnage END]) x
    WHERE x IS NOT NULL
  LOOP
    IF EXISTS (SELECT 1 FROM public.comptes_bancaires WHERE personnage = v_nom AND banque = 'nationale') THEN
      UPDATE public.personnages_donnees p SET arg = arg      -- le déclencheur de la fiche recalcule
       WHERE p.name = v_nom
         AND p.arg IS DISTINCT FROM round(coalesce(p.liquide, 0) + (SELECT sum(coalesce(solde, 0))
               FROM public.comptes_bancaires WHERE personnage = v_nom AND banque = 'nationale'));
    ELSE
      UPDATE public.personnages_donnees p SET arg = coalesce(p.liquide, 0)
       WHERE p.name = v_nom AND p.arg IS DISTINCT FROM coalesce(p.liquide, 0);
    END IF;
  END LOOP;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_comptes_nationaux_arg ON public.comptes_bancaires;
CREATE TRIGGER trg_comptes_nationaux_arg AFTER INSERT OR DELETE OR UPDATE OF solde, banque, personnage
  ON public.comptes_bancaires FOR EACH ROW EXECUTE FUNCTION public.comptes_nationaux_arg_rafraichir();

-- ── 3. Les écritures « arg seul » passent par les moteurs ──────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.patcher(p_sig regprocedure, p_ancien text, p_nouveau text)
 RETURNS void LANGUAGE plpgsql AS $p$
DECLARE d text; motif text; n integer;
BEGIN
  d := pg_get_functiondef(p_sig);
  motif := regexp_replace(regexp_replace(btrim(p_ancien), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g'), '\s+', '\\s+', 'g');
  SELECT count(*) INTO n FROM regexp_matches(d, motif, 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'patch % : fragment trouvé % fois : %', p_sig, n, p_ancien; END IF;
  EXECUTE regexp_replace(d, motif, replace(p_nouveau, '\', '\\'));
END;
$p$;

SELECT pg_temp.patcher('public.compromis_expire_resoudre(text,text)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_montant WHERE name = v_pret->>'demandeur';$a$,
  $n$PERFORM public.argent_crediter_interne(v_pret->>'demandeur', v_montant, 'nationale');$n$);
SELECT pg_temp.patcher('public.compromis_expire_resoudre(text,text)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_acompte WHERE name = v_par;$a$,
  $n$PERFORM public.argent_crediter_interne(v_par, v_acompte, 'nationale');$n$);

SELECT pg_temp.patcher('public.cotisation_renouveler(text,text,integer)',
  $a$UPDATE public.personnages_donnees SET arg = v_arg - v_montant WHERE name = p_membre;$a$,
  $n$PERFORM public.argent_debiter_interne(p_membre, v_montant, 'liquide_puis_nationale');$n$);

-- Vol : seul l'argent de poche se vole, et le voleur ne reçoit que ce qui a été pris.
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$v_perte := floor(coalesce(m.arg, 0) * 0.5)::integer;$a$,
  $n$v_perte := floor(coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = v_moi), 0) * 0.5)::integer;$n$);
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_perte) WHERE name = v_moi;$a$,
  $n$v_perte := public.argent_debiter_interne(v_moi, v_perte, 'liquide');$n$);
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$IF v_genre = 'argent' AND c.arg > 0 THEN$a$,
  $n$IF v_genre = 'argent' AND coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = p_cible), 0) > 0 THEN$n$);
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$v_montant := least(floor(random() * 150)::integer + 50, c.arg);$a$,
  $n$v_montant := least(floor(random() * 150)::integer + 50, coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = p_cible), 0));$n$);
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_montant) WHERE name = p_cible;$a$,
  $n$v_montant := public.argent_debiter_interne(p_cible, v_montant, 'liquide');$n$);
SELECT pg_temp.patcher('public.crime_voler(text,text,boolean,integer,integer)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_moi;$a$,
  $n$PERFORM public.argent_crediter_interne(v_moi, v_montant, 'liquide');$n$);

SELECT pg_temp.patcher('public.eviction_indemniser(text,text,text)',
  $a$UPDATE public.personnages_donnees SET arg = COALESCE(arg,0) + v_indemnite, updated_at = now() WHERE name = v_occupant;$a$,
  $n$PERFORM public.argent_crediter_interne(v_occupant, v_indemnite, 'nationale');$n$);

SELECT pg_temp.patcher('public.football_pari_engager(text,text,integer,text,integer)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) - p_mise, updated_at = now() WHERE name = v_moi RETURNING arg INTO v_arg;$a$,
  $n$PERFORM public.argent_debiter_interne(v_moi, p_mise, 'liquide_puis_nationale');
  SELECT coalesce(arg, 0) INTO v_arg FROM public.personnages_donnees WHERE name = v_moi;$n$);
SELECT pg_temp.patcher('public.football_paris_resoudre(integer)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_gain WHERE name = v_p.data->>'joueur';$a$,
  $n$PERFORM public.argent_crediter_interne(v_p.data->>'joueur', v_gain, 'liquide');$n$);
SELECT pg_temp.patcher('public.football_primes_match(integer,text,jsonb)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_nom;$a$,
  $n$PERFORM public.argent_crediter_interne(v_nom, v_montant, 'nationale');$n$);

SELECT pg_temp.patcher('public.fraude_electorale_sanctionner(text,text)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_recompense WHERE name = v_contestataire RETURNING arg INTO v_arg_contest;$a$,
  $n$PERFORM public.argent_crediter_interne(v_contestataire, v_recompense, 'nationale');
  SELECT arg INTO v_arg_contest FROM public.personnages_donnees WHERE name = v_contestataire;$n$);

SELECT pg_temp.patcher('public.immobilier_acheter(text,text,text,numeric,uuid)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_prix_murs WHERE name = v_vendeur_murs;$a$,
  $n$PERFORM public.argent_crediter_interne(v_vendeur_murs, v_prix_murs, 'nationale');$n$);
SELECT pg_temp.patcher('public.immobilier_acheter(text,text,text,numeric,uuid)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg,0) + v_prix_fonds WHERE name = v_vendeur_fonds;$a$,
  $n$PERFORM public.argent_crediter_interne(v_vendeur_fonds, v_prix_fonds, 'nationale');$n$);

SELECT pg_temp.patcher('public.justice_indemnite_naitre(text,text,text,text,integer)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = p_beneficiaire;$a$,
  $n$PERFORM public.argent_crediter_interne(p_beneficiaire, v_montant, 'nationale');$n$);
SELECT pg_temp.patcher('public.justice_indemnites_payer_depuis_finances(text,boolean)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_verse WHERE name = v_c.beneficiaire;$a$,
  $n$PERFORM public.argent_crediter_interne(v_c.beneficiaire, v_verse, 'nationale');$n$);

SELECT pg_temp.patcher('public.regler_creances_helvetia_quotidien(text)',
  $a$UPDATE public.personnages_donnees SET arg = COALESCE(arg,0) + v_paye WHERE name = v_obl.beneficiaire;$a$,
  $n$PERFORM public.argent_crediter_interne(v_obl.beneficiaire, v_paye, 'nationale');$n$);
SELECT pg_temp.patcher('public.restituer_reliquats_chantier(text,text)',
  $a$UPDATE public.personnages_donnees SET arg = COALESCE(arg, 0) + v_montant WHERE name = p_beneficiaire;$a$,
  $n$PERFORM public.argent_crediter_interne(p_beneficiaire, v_montant, 'nationale');$n$);
SELECT pg_temp.patcher('public.subvention_citoyen_verser(text,integer)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_verse WHERE name = p_beneficiaire;$a$,
  $n$PERFORM public.argent_crediter_interne(p_beneficiaire, v_verse, 'nationale');$n$);
SELECT pg_temp.patcher('public.succession_regler(text)',
  $a$UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + (v_d ->> 'part_nette')::numeric WHERE name = v_benef;$a$,
  $n$PERFORM public.argent_crediter_interne(v_benef, (v_d ->> 'part_nette')::numeric, 'nationale');$n$);
SELECT pg_temp.patcher('public.taxe_fonciere_prelever(text)',
  $a$UPDATE public.personnages_donnees SET arg = v_arg - v_taxe WHERE name = v_proprio;$a$,
  $n$PERFORM public.argent_debiter_interne(v_proprio, v_taxe, 'liquide_puis_nationale');$n$);

-- Prêt national : la fiche est écrite avant le compte ; relire le total après le crédit du compte.
SELECT pg_temp.patcher('public.pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)',
  $a$UPDATE public.comptes_bancaires SET solde=solde+p_montant,updated_at=now() WHERE personnage=p_nom AND banque='nationale' RETURNING solde INTO v_solde;$a$,
  $n$UPDATE public.comptes_bancaires SET solde=solde+p_montant,updated_at=now() WHERE personnage=p_nom AND banque='nationale' RETURNING solde INTO v_solde;
  SELECT arg INTO v_arg FROM public.personnages_donnees WHERE name=p_nom;$n$);

-- ── 4. Recalcul unique ─────────────────────────────────────────────────────────────────────
UPDATE public.personnages_donnees p SET arg = arg
 WHERE EXISTS (SELECT 1 FROM public.comptes_bancaires c WHERE c.personnage = p.name AND c.banque = 'nationale');
