-- =============================================================================
-- GUERRE ET TREVE — LA CHAINE COMPLETE PASSE AU SERVEUR
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session. Trois migrations ont
-- ete appliquees ce jour-la ; deux d'entre elles ont successivement defini les
-- memes fonctions. Seule la DERNIERE definition figure ici.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES :
--   20260920132657  guerres_autorite_serveur
--       cree guerre_acteur_poste, guerre_declarer, guerre_treve_proposer,
--       guerre_cessez_le_feu_activer.
--   20260920132755  fermeture_guerres
--       RLS sur public.guerres, lecture publique conservee, ecriture revoquee.
--   20260920144606  guerre_treve_chaine_complete
--       REDEFINIT guerre_treve_proposer et guerre_cessez_le_feu_activer,
--       ajoute guerre_treve_repondre.
--
-- NE FIGURENT PAS ICI, VOLONTAIREMENT : les versions du 132657 de
-- guerre_treve_proposer et guerre_cessez_le_feu_activer. Elles ont ete
-- remplacees le jour meme et rejouer les deux etapes n'apporterait rien.
--
-- -----------------------------------------------------------------------------
-- ETAT CONSTATE AVANT CE CHANTIER
-- -----------------------------------------------------------------------------
-- La table public.guerres etait absente des migrations du depot (creee hors
-- depot), RLS desactivee, trois politiques en USING(true), et DEUX ecritures
-- directes depuis le navigateur -- la seule table du chantier militaire dans ce
-- cas, alors que trois RPC militaires lisent son contenu pour decider si un
-- combat est legal.
--
-- -----------------------------------------------------------------------------
-- LES QUATRE AUTORITES
-- -----------------------------------------------------------------------------
--   * DECLARER LA GUERRE ......... president, pour le pays de sa fiche.
--   * PROPOSER UNE TREVE ......... min_ae d'un des deux belligerants.
--   * REPONDRE A LA TREVE ........ min_ae du pays DESTINATAIRE, et lui seul.
--   * ACTIVER LE CESSEZ-LE-FEU ... min_def, pour SON pays. Quand les deux cotes
--     l'ont active, la guerre se termine.
--
-- CHAINE CANONIQUE ARBITREE LE 20 SEPTEMBRE 2026 :
--   MAE du pays A propose  ->  MAE du pays B (DESTINATAIRE) accepte ou refuse
--                          ->  Ministre de la Defense met en oeuvre.
--
-- CE QUI MANQUAIT AU DEPART. L'etape d'acceptation etait ISOLEE : la fonction
-- cliente accepterTreve() n'avait ni appelant ni garde. Deux consequences :
--   1. LA PROPOSITION DOIT DIRE DE QUEL PAYS ELLE VIENT. Le cessez-le-feu ne
--      portait que `proposePar`, un NOM DE PERSONNE. Le destinataire n'etait
--      donc pas calculable, et « seul le MAE du pays destinataire peut
--      repondre » etait inapplicable. `proposePays` est renseigne par le
--      serveur.
--   2. L'ACTIVATION EXIGE DESORMAIS UNE TREVE ACCEPTEE. Elle se contentait
--      d'une proposition, faute d'etape d'acceptation atteignable.
--
-- AUCUNE REGLE DIPLOMATIQUE N'EST MODIFIEE PAR AILLEURS. Meme forme de donnees,
-- memes statuts, meme sequence. Seul change qui a le droit d'ecrire.
--
-- -----------------------------------------------------------------------------
-- DEPENDANCES — a rejouer AVANT ce fichier
-- -----------------------------------------------------------------------------
--   * public.mon_personnage()      — chantier B (identite et authentification).
--   * public.jour_de_jeu_pays()    — migration_20260920_temps_reel_et_cron_journal.sql,
--                                    meme journee, lot « temps reel ». guerre_declarer
--                                    l'appelle pour horodater le debut du conflit :
--                                    ce fichier DOIT etre rejoue apres celui-la.
--   * public.personnages_donnees   — table de base des fiches.
--   * public.guerres               — table creee hors depot, preexistante.
--
-- DEPENDANCE CLIENTE NON COMMITEE : les appels navigateur correspondants
-- (sbDeclarerGuerre, sbProposerTreve, sbRepondreTreve, sbActiverCessezLeFeu dans
-- supabase.js ; repondreTreve dans plateau-politique.js) vivent encore dans le
-- working tree. Tant qu'ils ne sont pas commites, le depot decrit un serveur que
-- le client du depot n'appelle pas.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. LE PAYS DE L'ACTEUR, DERIVE DE SA FICHE ET DE SON POSTE
-- -----------------------------------------------------------------------------
-- Le client n'annonce jamais son pays ni son poste : le serveur les lit.

CREATE OR REPLACE FUNCTION public.guerre_acteur_poste(p_poste text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT coalesce(d.country, 'republic')
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = p_poste
   LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.guerre_acteur_poste(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.guerre_acteur_poste(text) TO authenticated, service_role;


-- -----------------------------------------------------------------------------
-- 2. DECLARER LA GUERRE — le President, et son pays est celui de sa fiche.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guerre_declarer(p_pays_attaque text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_id text;
BEGIN
  v_pays := public.guerre_acteur_poste('president');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  IF p_pays_attaque IS NULL OR btrim(p_pays_attaque) = '' OR p_pays_attaque = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  -- Une seule guerre active entre deux memes pays, quel que soit le sens.
  IF EXISTS (SELECT 1 FROM public.guerres g
              WHERE g.statut = 'active'
                AND ((g.data ->> 'attaquant' = v_pays AND g.data ->> 'attaque' = p_pays_attaque)
                  OR (g.data ->> 'attaque' = v_pays AND g.data ->> 'attaquant' = p_pays_attaque))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_deja_active');
  END IF;

  v_id := 'guerre-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.guerres (id, statut, data)
  VALUES (v_id, 'active', jsonb_build_object(
    'attaquant', v_pays, 'attaque', p_pays_attaque,
    'jourDebut', public.jour_de_jeu_pays(v_pays), 'ceasefire', NULL));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'attaquant', v_pays, 'attaque', p_pays_attaque);
END;
$$;


-- -----------------------------------------------------------------------------
-- 3. PROPOSER UNE TREVE — le MAE d'un des deux belligerants.
-- -----------------------------------------------------------------------------
-- VERSION FINALE (20260920144606). La proposition porte desormais le PAYS du
-- proposant, ce qui rend le destinataire calculable.

CREATE OR REPLACE FUNCTION public.guerre_treve_proposer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  -- Une proposition deja en attente de reponse n'est pas remplacee en silence.
  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NOT NULL AND jsonb_typeof(v_cf) = 'object'
     AND (v_cf ->> 'accepteePar') IS NULL
     AND (v_cf ->> 'refuseePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_en_attente',
                              'proposePays', v_cf ->> 'proposePays');
  END IF;

  UPDATE public.guerres
     SET data = g.data || jsonb_build_object('ceasefire', jsonb_build_object(
           'proposePar',  v_moi,
           'proposePays', v_pays,          -- <- ce qui rend le destinataire calculable
           'accepteePar', NULL,
           'refuseePar',  NULL,
           'actifPar',    '{}'::jsonb))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'proposePar', v_moi, 'proposePays', v_pays,
    'destinataire', CASE WHEN v_pays = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END);
END;
$$;


-- -----------------------------------------------------------------------------
-- 4. REPONDRE — le MAE du pays DESTINATAIRE, et lui seul.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guerre_treve_repondre(p_guerre_id text, p_accepte boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb; v_destinataire text;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' OR (v_cf ->> 'proposePays') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_proposition');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NOT NULL OR (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_tranchee');
  END IF;

  -- LE DESTINATAIRE est l'autre belligerant, jamais celui qui a propose.
  v_destinataire := CASE WHEN (v_cf ->> 'proposePays') = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END;
  IF v_pays IS DISTINCT FROM v_destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_destinataire',
                              'destinataire', v_destinataire);
  END IF;

  IF coalesce(p_accepte, false) THEN
    v_cf := v_cf || jsonb_build_object('accepteePar', v_moi, 'accepteePays', v_pays);
  ELSE
    v_cf := v_cf || jsonb_build_object('refuseePar', v_moi, 'refuseePays', v_pays);
  END IF;

  UPDATE public.guerres SET data = g.data || jsonb_build_object('ceasefire', v_cf)
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'accepte', coalesce(p_accepte, false), 'par', v_moi);
END;
$$;


-- -----------------------------------------------------------------------------
-- 5. ACTIVER LE CESSEZ-LE-FEU — le Ministre de la Defense, pour SON pays.
-- -----------------------------------------------------------------------------
-- VERSION FINALE (20260920144606). Exige desormais une treve ACCEPTEE, et
-- refuse d'agir sur une treve refusee.

CREATE OR REPLACE FUNCTION public.guerre_cessez_le_feu_activer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; g record; v_cf jsonb; v_actif jsonb; v_tous boolean;
BEGIN
  v_pays := public.guerre_acteur_poste('min_def');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_defense');
  END IF;

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_treve_proposee');
  END IF;
  IF (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_refusee');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_non_acceptee');
  END IF;

  v_actif := coalesce(v_cf -> 'actifPar', '{}'::jsonb) || jsonb_build_object(v_pays, true);
  v_tous  := (v_actif ? (g.data ->> 'attaquant')) AND (v_actif ? (g.data ->> 'attaque'));

  UPDATE public.guerres
     SET statut = CASE WHEN v_tous THEN 'terminee' ELSE 'active' END,
         data   = g.data || jsonb_build_object('ceasefire', v_cf || jsonb_build_object('actifPar', v_actif))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'terminee', v_tous);
END;
$$;


-- -----------------------------------------------------------------------------
-- 6. DROITS SUR LES QUATRE PORTES
-- -----------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.guerre_declarer(text)                     FROM public, anon;
REVOKE ALL ON FUNCTION public.guerre_treve_proposer(text)               FROM public, anon;
REVOKE ALL ON FUNCTION public.guerre_treve_repondre(text, boolean)      FROM public, anon;
REVOKE ALL ON FUNCTION public.guerre_cessez_le_feu_activer(text)        FROM public, anon;

GRANT EXECUTE ON FUNCTION public.guerre_declarer(text)                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.guerre_treve_proposer(text)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.guerre_treve_repondre(text, boolean)   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.guerre_cessez_le_feu_activer(text)     TO authenticated, service_role;


-- -----------------------------------------------------------------------------
-- 7. FERMETURE DE LA TABLE public.guerres
-- -----------------------------------------------------------------------------
-- SEQUENCEMENT RESPECTE : les portes serveur existent, le client est migre, et
-- les deux wrappers d'ecriture directe (sbCreerGuerre, sbMajGuerre) n'ont plus
-- aucun appelant.
--
-- LA LECTURE RESTE OUVERTE : l'etat de guerre entre deux empires est une
-- information publique, lue par les ecrans diplomatiques, l'effort de guerre et
-- l'immunite militaire. Le correctif du chargement de `statut` cote client
-- accompagne cette fermeture -- sans lui, le predicat de guerre resterait faux
-- en permanence et la fermeture n'aurait rien change a l'observabilite.

DROP POLICY IF EXISTS "Ecriture publique guerres" ON public.guerres;
DROP POLICY IF EXISTS "Lecture publique guerres"  ON public.guerres;
DROP POLICY IF EXISTS "Maj publique guerres"      ON public.guerres;

CREATE POLICY guerres_lecture ON public.guerres
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.guerres ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.guerres FROM anon, authenticated, public;
