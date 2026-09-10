-- =====================================================================
-- ASSEMBLEE NATIONALE — ACTIONS JOUEUR FAISANT FOI COTE SERVEUR (option A, 11 septembre 2026)
-- =====================================================================
-- A appliquer APRES migration_assemblee_nationale.sql et migration_assemblee_securisation_droits.sql
-- (toutes deux appliquees le 10/09/2026). Leve la quarantaine des actions joueur.
--
-- ARCHITECTURE (option A, arbitrage du 11 septembre 2026)
-- Chaque action joueur est UNE transaction serveur qui :
--   1. verrouille la ligne du personnage (SELECT ... FOR UPDATE) ;
--   2. relit elle-meme ses prerequis : lieu, PA, fonds ordinaires, inventaire, statistiques de
--      base, etat du siege, statut et echeance du scrutin ;
--   3. debite PA / argent / objet, tire le jet (random() cote serveur), applique l'effet ;
--   4. enregistre son resultat sous un identifiant de requete fourni par le client.
-- Le client ne transmet plus AUCUN resultat, montant, cout, caisse ou horaire. Il transmet son nom
-- (identite par nom : limite commune a tout le jeu, chantier d'authentification separe), sa cible
-- et un identifiant de requete.
--
-- IDEMPOTENCE (double-clic, reponse perdue)
-- assemblee_requetes.id est la cle de la requete. Un second appel portant le meme identifiant --
-- double envoi, ou rejeu apres une reponse perdue -- ne refait RIEN et renvoie le resultat deja
-- acquis. Deux appels concurrents portant le meme identifiant sont serialises par l'index unique :
-- le second attend la fin du premier, puis lit son resultat. Deux clics DISTINCTS sont deux
-- tentatives, serialisees par le verrou de la ligne du personnage : jamais de perte d'ecriture.
--
-- PAIEMENT : REPRODUCTION EXACTE DU CLIENT (deduireCoutOrdre / debiterFondsOrdinaires,
-- plateau-core.js) : PA verifies d'abord ; fonds ordinaires = liquide + solde du compte Banque
-- nationale (comptes_bancaires, banque='nationale') ; debit du liquide d'abord, complement sur le
-- compte national ; arg diminue du montant total. Credit (indemnite) = crediterFondsOrdinaires :
-- liquide et arg.
--
-- FORMULES : strictement celles du game design, sur les statistiques DE BASE (personnages.stats,
-- defaut 8 comme le client), sans bonus de formation, moyenne de groupe, bonus ENT local ni aucun
-- autre modificateur.
-- =====================================================================


-- =====================================================================
-- 1. JOURNAL DES REQUETES (idempotence)
-- =====================================================================
-- Jamais lisible par le client : il conserve l'auteur d'un marchandage, que §15 impose de garder
-- secret.
CREATE TABLE IF NOT EXISTS public.assemblee_requetes (
  id          text PRIMARY KEY,
  personnage  text        NOT NULL,
  action      text        NOT NULL,
  resultat    jsonb,
  cree_ts     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_assemblee_requetes_perso ON public.assemblee_requetes (personnage, cree_ts);
ALTER TABLE public.assemblee_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.assemblee_requetes FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.assemblee_requetes TO service_role;

-- Renvoie NULL si la requete est nouvelle (l'appelant poursuit), sinon le resultat a renvoyer.
CREATE OR REPLACE FUNCTION public.assemblee_requete_ouvrir(p_requete text, p_nom text, p_action text)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.assemblee_requetes%ROWTYPE;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^[A-Za-z0-9_-]{8,80}$' OR COALESCE(btrim(p_nom), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  -- L'insertion EST la garde : un doublon concurrent attend ici la fin de la premiere transaction.
  INSERT INTO public.assemblee_requetes (id, personnage, action)
  VALUES (p_requete, p_nom, p_action)
  ON CONFLICT (id) DO NOTHING;
  IF FOUND THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_row FROM public.assemblee_requetes WHERE id = p_requete;
  IF v_row.personnage IS DISTINCT FROM p_nom OR v_row.action IS DISTINCT FROM p_action THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  RETURN COALESCE(v_row.resultat, jsonb_build_object('ok', false, 'raison', 'requete_en_cours'))
         || jsonb_build_object('rejeu', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_requete_clore(p_requete text, p_resultat jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.assemblee_requetes SET resultat = p_resultat WHERE id = p_requete;
  RETURN p_resultat;
END;
$$;


-- =====================================================================
-- 2. PAIEMENT ET CREDIT : MIROIR DE deduireCoutOrdre / crediterFondsOrdinaires
-- =====================================================================
-- Aucune ecriture en cas de refus. L'appelant tient deja le verrou de la ligne du personnage ; le
-- compte national est verrouille ici. Ordre des verrous du chantier : personnage, siege, compte
-- national, caisse.
CREATE OR REPLACE FUNCTION public.assemblee_debiter_joueur(p_nom text, p_pa integer, p_fr integer)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pa       integer;
  v_liquide  integer;
  v_arg      integer;
  v_nat      numeric;
  v_a_compte boolean;
  v_pl       integer := 0;
  v_pn       integer := 0;
BEGIN
  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
    FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- A. PA d'abord (deduireCoutOrdre, etape A).
  IF COALESCE(v_pa, 0) < p_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa', COALESCE(v_pa, 0), 'pa_requis', p_pa);
  END IF;

  -- B. Fonds ordinaires = liquide + Banque nationale (getFondsDisponiblesOrdinaires).
  SELECT solde INTO v_nat FROM public.comptes_bancaires
   WHERE personnage = p_nom AND banque = 'nationale' FOR UPDATE;
  v_a_compte := FOUND;
  IF p_fr > 0 AND COALESCE(v_liquide, 0) + COALESCE(v_nat, 0) < p_fr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
      'fonds_disponibles', COALESCE(v_liquide, 0) + COALESCE(v_nat, 0), 'montant_requis', p_fr);
  END IF;

  -- C. debiterFondsOrdinaires : liquide d'abord, complement sur la Banque nationale.
  IF p_fr > 0 THEN
    v_pl := LEAST(COALESCE(v_liquide, 0), p_fr);
    v_pn := p_fr - v_pl;
  END IF;

  UPDATE public.personnages
     SET pa      = GREATEST(0, COALESCE(pa, 0) - p_pa),
         liquide = COALESCE(liquide, 0) - v_pl,
         arg     = COALESCE(arg, 0) - p_fr
   WHERE name = p_nom
  RETURNING pa, liquide, arg INTO v_pa, v_liquide, v_arg;

  IF v_pn > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pn, updated_at = now()
     WHERE personnage = p_nom AND banque = 'nationale'
    RETURNING solde INTO v_nat;
  END IF;

  RETURN jsonb_build_object('ok', true,
    'pa', v_pa, 'liquide', v_liquide, 'arg', v_arg,
    'solde_national', CASE WHEN v_a_compte THEN v_nat ELSE NULL END,
    'pa_preleves', p_pa, 'montant_preleve', p_fr,
    'preleve_liquide', v_pl, 'preleve_national', v_pn);
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_crediter_joueur(p_nom text, p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_liquide integer;
  v_arg     integer;
BEGIN
  UPDATE public.personnages
     SET liquide = COALESCE(liquide, 0) + GREATEST(0, p_montant),
         arg     = COALESCE(arg, 0) + GREATEST(0, p_montant)
   WHERE name = p_nom
  RETURNING liquide, arg INTO v_liquide, v_arg;
  RETURN jsonb_build_object('liquide', v_liquide, 'arg', v_arg);
END;
$$;


-- =====================================================================
-- 3. FORMULES DU GAME DESIGN
-- =====================================================================
-- Statistique de base, defaut 8 (meme defaut que getStatEffective : stats?.[stat] ?? 8). FOR
-- n'existe pas dans les statistiques des PJ : c'est donc toujours 8, exactement comme cote client.
CREATE OR REPLACE FUNCTION public.assemblee_stat_base(p_stats jsonb, p_cle text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN jsonb_typeof(p_stats -> p_cle) = 'number' THEN (p_stats ->> p_cle)::numeric ELSE 8 END;
$$;

-- Marchander : 50 + (CHA + ENT) / 2, maximum 66 ; +20 si le Lobbyiste a ete consulte, maximum 86.
CREATE OR REPLACE FUNCTION public.assemblee_taux_marchandage(p_stats jsonb, p_bonus_lobbyiste boolean)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT GREATEST(0, LEAST(66, round(50 + (public.assemblee_stat_base(p_stats, 'CHA')
                                           + public.assemblee_stat_base(p_stats, 'ENT')) / 2)::integer))
         + CASE WHEN p_bonus_lobbyiste THEN 20 ELSE 0 END;
$$;

-- Neutraliser un depute PNJ : base + stat*2 + bonus carriere - PER cible/2, plafonne par mode.
--   mains : 15 + FOR*2, cap 65 · arme (lame) : 25 + DUP*2, cap 75 · feu : 35 + PER*2, cap 85
-- Seul criminal_c apporte +15. PER des neuf deputes PNJ = 6 (PNJ_STATS_NOMMES, data.js).
CREATE OR REPLACE FUNCTION public.assemblee_taux_neutralisation(p_mode text, p_stats jsonb, p_career text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT GREATEST(0, LEAST(m.cap, round(m.base
           + public.assemblee_stat_base(p_stats, m.stat) * 2
           + CASE WHEN p_career = 'criminal_c' THEN 15 ELSE 0 END
           - 6 / 2.0)::integer))
    FROM (VALUES ('mains', 'FOR', 15, 65), ('arme', 'DUP', 25, 75), ('feu', 'PER', 35, 85))
         AS m(mode, stat, base, cap)
   WHERE m.mode = p_mode;
$$;

-- Retire UNE unite d'un empilable (miroir de confirmerReveillerDepute : lot.qty - 1, lot retire a 0).
CREATE OR REPLACE FUNCTION public.assemblee_retirer_une_unite(p_inventaire jsonb, p_stack_key text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  WITH e AS (
    SELECT t.v, t.o
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inventaire) = 'array' THEN p_inventaire ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(v, o)
  ), cible AS (
    SELECT min(o) AS o FROM e
     WHERE v ->> 'stackKey' = p_stack_key
       AND jsonb_typeof(v -> 'qty') = 'number' AND (v ->> 'qty')::numeric > 0
  )
  SELECT COALESCE(
           jsonb_agg(CASE WHEN e.o = cible.o
                          THEN jsonb_set(e.v, '{qty}', to_jsonb((e.v ->> 'qty')::numeric - 1))
                          ELSE e.v END
                     ORDER BY e.o)
             FILTER (WHERE NOT COALESCE(e.o = cible.o AND (e.v ->> 'qty')::numeric - 1 <= 0, false)),
           '[]'::jsonb)
    FROM e CROSS JOIN cible;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_compter_unites(p_inventaire jsonb, p_stack_key text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(sum((v ->> 'qty')::numeric), 0)
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inventaire) = 'array' THEN p_inventaire ELSE '[]'::jsonb END) v
   WHERE v ->> 'stackKey' = p_stack_key AND jsonb_typeof(v -> 'qty') = 'number';
$$;


-- =====================================================================
-- 4. SUPPRESSION DES ANCIENNES SIGNATURES
-- =====================================================================
-- Elles recevaient du client un resultat (p_reussi), un montant (p_montant), une caisse
-- (p_caisse_key), ou n'exigeaient aucun cout (endormir, reveiller). Aucune surcharge conservee.
DROP FUNCTION IF EXISTS public.assemblee_marchander(text, text, text, boolean, integer, text);
DROP FUNCTION IF EXISTS public.assemblee_endormir(text, text);
DROP FUNCTION IF EXISTS public.assemblee_reveiller(text);
DROP FUNCTION IF EXISTS public.assemblee_deposer(text, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.assemblee_amender(text, text, text);
DROP FUNCTION IF EXISTS public.assemblee_verser_indemnite(text, text, integer);


-- =====================================================================
-- 5. MARCHANDER UN VOTE (§15, §16)
-- =====================================================================
-- 1 PA + 100 FR a chaque tentative, reussie ou non ; les 100 FR vont a la caisse de l'Assemblee
-- du pays (<pays>_assemblee, soit republic_assemblee). Le bonus Lobbyiste est consomme par la
-- tentative, quelle qu'en soit l'issue. Un depute endormi reste marchandable (regle existante).
CREATE OR REPLACE FUNCTION public.assemblee_marchander(
  p_nom       text,
  p_id        text,
  p_siege_id  text,
  p_intention text,
  p_requete   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_fr      CONSTANT integer := 100;
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_prop    public.assemblee_propositions%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_bonus   boolean;
  v_taux    integer;
  v_jet     integer;
  v_reussi  boolean;
  v_applique boolean := false;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'marchander');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_intention IS NULL OR p_intention NOT IN ('POUR', 'CONTRE') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'intention_invalide'));
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  -- FOR SHARE : serialise avec la cloture (FOR UPDATE), aucun marchandage ne chevauche le depouillement.
  SELECT * INTO v_prop FROM public.assemblee_propositions WHERE id = p_id FOR SHARE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  IF v_prop.statut <> 'session' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_session'));
  END IF;
  IF v_prop.cloture_ts IS NULL OR now() >= v_prop.cloture_ts THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_clos'));
  END IF;

  IF NOT (v_perso.country = v_prop.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_prop.country) o WHERE o.siege_id = p_siege_id;
  IF v_est_pnj IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT v_est_pnj THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;

  -- Paiement AVANT le jet (convention du projet) ; refus = aucune ecriture.
  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, c_fr);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_bonus  := COALESCE(v_perso.bonus_lobbyiste, 0) > 0;
  v_taux   := public.assemblee_taux_marchandage(v_perso.stats, v_bonus);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_taux;

  IF v_bonus THEN
    UPDATE public.personnages SET bonus_lobbyiste = 0 WHERE name = p_nom;
  END IF;

  PERFORM public.assemblee_crediter_caisse(v_prop.country || '_assemblee', c_fr);

  IF v_reussi THEN
    UPDATE public.assemblee_intentions
       SET intention = p_intention, updated_at = now()
     WHERE proposition_id = p_id AND session_num = v_prop.session_num AND siege_id = p_siege_id;
    v_applique := FOUND;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reussi', v_reussi, 'applique', v_applique,
    'taux', v_taux, 'jet', v_jet, 'bonus_applique', v_bonus, 'bonus_lobbyiste', 0));
END;
$$;


-- =====================================================================
-- 6. CONSULTER LE LOBBYISTE (§16)
-- =====================================================================
-- 1 PA + 150 FR. +20 points sur la prochaine tentative de marchandage. Refuse SANS COUT si le bonus
-- est deja acquis (meme regle que le client). Les 150 FR ne vont a aucune caisse : comportement
-- economique actuel conserve. bonus_lobbyiste n'est plus ecrit par la sauvegarde client.
CREATE OR REPLACE FUNCTION public.assemblee_consulter_lobbyiste(p_nom text, p_requete text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_pa    CONSTANT integer := 1;
  c_fr    CONSTANT integer := 150;
  c_bonus CONSTANT integer := 20;
  v_rej   jsonb;
  v_perso public.personnages%ROWTYPE;
  v_debit jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'lobbyiste');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  IF NOT (v_perso.current_building = 'assemblee' AND v_perso.current_room = 'couloirs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF COALESCE(v_perso.bonus_lobbyiste, 0) > 0 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bonus_deja_acquis'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, c_fr);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  UPDATE public.personnages SET bonus_lobbyiste = c_bonus WHERE name = p_nom;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object('ok', true, 'bonus_lobbyiste', c_bonus));
END;
$$;


-- =====================================================================
-- 7. NEUTRALISER UN DEPUTE PNJ (§18, §20)
-- =====================================================================
-- PA : mains 1, arme blanche 1, arme a feu 2 (bareme depute). Arme a feu : -20 DIS, reussite ou
-- non (regle existante). Endormi UNIQUEMENT apres reussite. Un depute deja endormi est refuse SANS
-- COUT : un double-clic ou deux joueurs simultanes ne paient pas pour un effet deja acquis. Les
-- suites d'un echec (arrestation) et d'une reussite (trace, detection) restent appliquees par le
-- client, comme pour toute autre neutralisation.
CREATE OR REPLACE FUNCTION public.assemblee_neutraliser_depute(
  p_nom      text,
  p_siege_id text,
  p_mode     text,
  p_requete  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pa      integer;
  v_sous    text[];
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_siege   public.assemblee_sieges%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_dis     numeric;
  v_taux    integer;
  v_jet     integer;
  v_reussi  boolean;
BEGIN
  IF p_mode = 'mains' THEN v_pa := 1; v_sous := NULL;
  ELSIF p_mode = 'arme' THEN v_pa := 1; v_sous := ARRAY['blanche'];
  ELSIF p_mode = 'feu' THEN v_pa := 2; v_sous := ARRAY['poing', 'carabine'];
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;

  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'neutraliser');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  SELECT * INTO v_siege FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT (v_perso.country = v_siege.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_siege.country) o WHERE o.siege_id = p_siege_id;
  IF NOT COALESCE(v_est_pnj, false) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;
  IF v_siege.endormi THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_endormi'));
  END IF;

  -- Possession de l'arme relue dans l'inventaire persiste (neutraliserPossedeArme).
  IF v_sous IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_perso.inventory) = 'array'
                                            THEN v_perso.inventory ELSE '[]'::jsonb END) i
     WHERE i ->> 'type' = 'arme' AND i ->> 'sousType' = ANY (v_sous)
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'arme_manquante'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, v_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_dis := CASE WHEN jsonb_typeof(v_perso.resources -> 'dis') = 'number'
                THEN (v_perso.resources ->> 'dis')::numeric ELSE 0 END;
  IF p_mode = 'feu' THEN
    v_dis := GREATEST(0, v_dis - 20);
    UPDATE public.personnages
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                                 '{dis}', to_jsonb(v_dis))
     WHERE name = p_nom;
  END IF;

  v_taux   := public.assemblee_taux_neutralisation(p_mode, v_perso.stats, v_perso.career);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_taux;

  IF v_reussi THEN
    UPDATE public.assemblee_sieges
       SET endormi = true, endormi_ts = now(), endormi_par = NULL, updated_at = now()
     WHERE id = p_siege_id AND endormi = false;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reussi', v_reussi, 'endormi', v_reussi, 'mode', p_mode,
    'taux', v_taux, 'jet', v_jet, 'dis', v_dis));
END;
$$;


-- =====================================================================
-- 8. REVEILLER UN DEPUTE (§22, §23)
-- =====================================================================
-- 1 PA + 1 flacon de sels d'ammoniaque, reussite 100 %, consommes dans la meme transaction que le
-- reveil. Un depute deja eveille est refuse SANS COUT : deux appels concurrents ne consomment
-- jamais deux flacons pour un seul reveil.
CREATE OR REPLACE FUNCTION public.assemblee_reveiller_depute(
  p_nom      text,
  p_siege_id text,
  p_requete  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_sels    CONSTANT text := 'sels_ammoniaque';
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_siege   public.assemblee_sieges%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_inv     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'reveiller');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  SELECT * INTO v_siege FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT (v_perso.country = v_siege.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_siege.country) o WHERE o.siege_id = p_siege_id;
  IF NOT COALESCE(v_est_pnj, false) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;
  IF NOT v_siege.endormi THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_eveille'));
  END IF;

  IF public.assemblee_compter_unites(v_perso.inventory, c_sels) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'sels_manquants'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_inv := public.assemblee_retirer_une_unite(v_perso.inventory, c_sels);
  UPDATE public.personnages SET inventory = v_inv WHERE name = p_nom;

  UPDATE public.assemblee_sieges
     SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
   WHERE id = p_siege_id;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reveille', true,
    'sels_restants', public.assemblee_compter_unites(v_inv, c_sels)));
END;
$$;


-- =====================================================================
-- 9. DEPOT D'UN PROJET OU D'UNE ABROGATION (§5, §6, §9, §32)
-- =====================================================================
-- 1 PA. Eligibilite, lieu et categorie relus par le serveur. L'identifiant est genere par le
-- serveur. Pour une abrogation, le titre est construit par le serveur a partir de la loi visee.
CREATE OR REPLACE FUNCTION public.assemblee_deposer(
  p_nom          text,
  p_titre        text,
  p_type         text,
  p_texte        text,
  p_categorie    text,
  p_loi_cible_id text,
  p_requete      text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_pa      CONSTANT integer := 1;
  -- Miroir exact des cles de CATEGORIES_INTERDICTION (plateau-assemblee.js).
  c_categories CONSTANT text[] := ARRAY['viandes', 'poissons', 'denrees_animales', 'alcools', 'tabac',
    'medicaments', 'armes_blanches', 'armes_a_feu', 'armes', 'poisons', 'carburants', 'hydrocarbures',
    'bois_et_forets', 'textile', 'produits_exotiques'];
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_cible   public.assemblee_propositions%ROWTYPE;
  v_titre   text;
  v_texte   text;
  v_cat     text := NULL;
  v_cible_id text := NULL;
  v_debit   jsonb;
  v_id      text;
  v_row     public.assemblee_propositions%ROWTYPE;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'deposer');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  -- L'Assemblee n'existe que dans un pays qui a des sieges (Republia).
  IF NOT (v_perso.current_building = 'assemblee' AND v_perso.current_room = 'hemicycle'
          AND EXISTS (SELECT 1 FROM public.assemblee_sieges s WHERE s.country = v_perso.country)) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF NOT public.assemblee_peut_deposer(p_nom, v_perso.country) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'ineligible'));
  END IF;
  IF p_type IS NULL OR p_type NOT IN ('rp', 'mecanique', 'abrogation') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'type_invalide'));
  END IF;

  v_texte := btrim(COALESCE(p_texte, ''));
  IF v_texte = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
  END IF;
  IF length(v_texte) > 20000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'texte_trop_long'));
  END IF;

  IF p_type = 'abrogation' THEN
    SELECT * INTO v_cible FROM public.assemblee_propositions
     WHERE id = p_loi_cible_id AND statut = 'adoptee' AND country = v_perso.country;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'loi_cible_introuvable'));
    END IF;
    v_cible_id := v_cible.id;
    v_titre := left('Abrogation — ' || v_cible.titre, 200);
  ELSE
    v_titre := btrim(COALESCE(p_titre, ''));
    IF v_titre = '' THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
    END IF;
    IF length(v_titre) > 120 THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'titre_trop_long'));
    END IF;
    IF p_type = 'mecanique' THEN
      IF p_categorie IS NULL OR NOT (p_categorie = ANY (c_categories)) THEN
        RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'categorie_invalide'));
      END IF;
      v_cat := p_categorie;
    END IF;
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_id := 'prop-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint
          || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, categorie, loi_cible_id, texte_original, eligible_session_ts)
  VALUES
    (v_id, v_perso.country, p_nom, v_titre, p_type, v_cat, v_cible_id, v_texte, now() + interval '7 days')
  RETURNING * INTO v_row;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row)));
END;
$$;

-- Lien vers le sujet du forum (§10). Remplace l'ecriture REST directe, que la RLS refusait
-- silencieusement. Posee UNE fois, par l'auteur, vers un sujet du forum de l'Assemblee qu'il a
-- lui-meme ouvert.
CREATE OR REPLACE FUNCTION public.assemblee_lier_topic(p_nom text, p_id text, p_topic_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.auteur IS DISTINCT FROM p_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.forum_topic_id IS NOT NULL THEN
    IF v_row.forum_topic_id = p_topic_id THEN
      RETURN jsonb_build_object('ok', true, 'forum_topic_id', p_topic_id);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'topic_deja_lie');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.forum_topics t
     WHERE t.id = p_topic_id AND t.forum_id = 'assemblee' AND t.author = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'topic_invalide');
  END IF;

  UPDATE public.assemblee_propositions SET forum_topic_id = p_topic_id WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'forum_topic_id', p_topic_id);
END;
$$;


-- =====================================================================
-- 10. AMENDER (§7), RETIRER (§8), VOTER (§14)
-- =====================================================================
-- 0 PA. Lieu relu par le serveur (hemicycle). Amender : idempotent par requete (un double-clic
-- n'ajoute pas deux amendements). Retirer et voter sont idempotents par nature.
CREATE OR REPLACE FUNCTION public.assemblee_amender(p_nom text, p_id text, p_texte text, p_requete text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej   jsonb;
  v_perso public.personnages%ROWTYPE;
  v_row   public.assemblee_propositions%ROWTYPE;
  v_texte text;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'amender');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF v_row.auteur <> p_nom THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_auteur'));
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_debat'));
  END IF;
  v_texte := btrim(COALESCE(p_texte, ''));
  IF v_texte = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
  END IF;
  IF length(v_texte) > 20000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'texte_trop_long'));
  END IF;

  UPDATE public.assemblee_propositions
     SET amendements = amendements || jsonb_build_object(
           'num',   jsonb_array_length(amendements) + 1,
           'texte', v_texte,
           'ts',    to_jsonb(now()))
   WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row)));
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_retirer(p_id text, p_auteur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row   public.assemblee_propositions%ROWTYPE;
  v_perso public.personnages%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_auteur;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_lieu');
  END IF;
  IF v_row.auteur <> p_auteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'session_ouverte');
  END IF;

  UPDATE public.assemblee_propositions SET statut = 'retiree' WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row));
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_voter(p_id text, p_votant text, p_choix text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row   public.assemblee_propositions%ROWTYPE;
  v_perso public.personnages%ROWTYPE;
  v_city  text;
BEGIN
  IF p_choix IS NULL OR p_choix NOT IN ('POUR', 'CONTRE', 'ABSTENTION') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;

  -- FOR SHARE : un vote ne chevauche jamais le depouillement (qui prend FOR UPDATE).
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR SHARE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;
  IF v_row.cloture_ts IS NULL OR now() >= v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos');
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_votant;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_lieu');
  END IF;

  -- Le votant doit occuper reellement l'un des neuf sieges MAINTENANT.
  SELECT o.city INTO v_city
    FROM public.assemblee_occupation_sieges(v_row.country) o
   WHERE o.pj_nom = p_votant
   LIMIT 1;
  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  INSERT INTO public.assemblee_votes (id, proposition_id, session_num, votant, city, choix)
  VALUES (p_id || ':' || v_row.session_num || ':' || p_votant, p_id, v_row.session_num, p_votant, v_city, p_choix)
  ON CONFLICT (id) DO UPDATE SET choix = EXCLUDED.choix, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END;
$$;


-- =====================================================================
-- 11. INDEMNITE PARLEMENTAIRE (§47, §48, §49)
-- =====================================================================
-- Montant FIXE (250 FR), jamais fourni par le client. Garde anti-doublon par jour reel Paris.
-- Paiement partiel si la caisse ne suit pas, jamais de dette. Le versement est CREDITE par le
-- serveur (liquide et arg, comme crediterFondsOrdinaires) : le client ne fait que refleter.
CREATE OR REPLACE FUNCTION public.assemblee_verser_indemnite(p_nom text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_montant CONSTANT integer := 250;
  v_perso   public.personnages%ROWTYPE;
  v_jour    date;
  v_id      text;
  v_verse   integer := 0;
  v_credit  jsonb;
BEGIN
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable', 'montant', 0);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := p_nom || ':' || v_jour::text;

  IF NOT EXISTS (
    SELECT 1 FROM public.assemblee_occupation_sieges(v_perso.country) o WHERE o.pj_nom = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute', 'montant', 0);
  END IF;

  BEGIN
    INSERT INTO public.assemblee_indemnites (id, personnage, jour, montant)
    VALUES (v_id, p_nom, v_jour, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_verse_aujourdhui', 'montant', 0);
  END;

  v_verse := public.assemblee_debiter_caisse_plafonne(v_perso.country || '_assemblee', c_montant);
  UPDATE public.assemblee_indemnites SET montant = v_verse WHERE id = v_id;

  v_credit := public.assemblee_crediter_joueur(p_nom, v_verse);

  RETURN v_credit || jsonb_build_object('ok', true, 'montant', v_verse, 'vise', c_montant);
END;
$$;


-- =====================================================================
-- 12. TRACE VENDEUR : FONCTION INTERNE, JAMAIS APPELABLE PAR UN CLIENT
-- =====================================================================
-- Constat du 11 septembre 2026 : aucune vente reelle du jeu ne peut aujourd'hui produire une
-- transaction interdite -- les produits de commanderProduitCommerce n'appartiennent a aucune
-- categorie d'interdiction, et l'entrepot institutionnel refuse de vendre une matiere interdite.
-- La trace vendeur ne peut donc etre rattachee a une vente reelle que si elle est appelee DEPUIS
-- une transaction de vente serveur. Elle reste reservee au service_role jusqu'a ce qu'une telle
-- vente existe ; l'appel client, qui permettait de fabriquer une vente fictive, est supprime.
COMMENT ON FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text) IS
  'INTERNE : a appeler uniquement depuis une transaction de vente serveur. Jamais expose au client.';


-- =====================================================================
-- 13. DROITS D'EXECUTION
-- =====================================================================
-- Actions joueur : la cle anon les appelle, chacune revalide tout. Primitives : internes.
REVOKE ALL ON FUNCTION public.assemblee_requete_ouvrir(text, text, text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_requete_clore(text, jsonb)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_debiter_joueur(text, integer, integer)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_crediter_joueur(text, integer)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_stat_base(jsonb, text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_taux_marchandage(jsonb, boolean)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_taux_neutralisation(text, jsonb, text)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_retirer_une_unite(jsonb, text)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_compter_unites(jsonb, text)              FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_requete_ouvrir(text, text, text)       TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_requete_clore(text, jsonb)             TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_debiter_joueur(text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_crediter_joueur(text, integer)         TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_stat_base(jsonb, text)                 TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_taux_marchandage(jsonb, boolean)       TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_taux_neutralisation(text, jsonb, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_retirer_une_unite(jsonb, text)         TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_compter_unites(jsonb, text)            TO service_role;

REVOKE ALL ON FUNCTION public.assemblee_marchander(text, text, text, text, text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_consulter_lobbyiste(text, text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_neutraliser_depute(text, text, text, text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_reveiller_depute(text, text, text)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_deposer(text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_lier_topic(text, text, text)                     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_amender(text, text, text, text)                  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_retirer(text, text)                              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_voter(text, text, text)                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_verser_indemnite(text)                           FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_marchander(text, text, text, text, text)          TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_consulter_lobbyiste(text, text)                   TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_neutraliser_depute(text, text, text, text)        TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_reveiller_depute(text, text, text)               TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_deposer(text, text, text, text, text, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_lier_topic(text, text, text)                     TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_amender(text, text, text, text)                  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_retirer(text, text)                              TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_voter(text, text, text)                          TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_verser_indemnite(text)                           TO anon, authenticated, service_role;

-- =====================================================================
-- FIN
-- =====================================================================
