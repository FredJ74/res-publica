-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917230350
-- Nom original      : soldes_militaires_registre_et_dettes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 23:03:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b9838d55831a431019275948034d91ff
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
-- ==========================================================================================
-- SOLDES MILITAIRES : PAYEUR REEL, REGISTRE QUOTIDIEN ET DETTES DE CASERNE
--
-- CE QUI EXISTAIT. Les salaires de poste sont crees EX NIHILO par le client dans doDormir
-- (« state.arg += salaire »), sans qu'aucune caisse soit debitee. C'est vrai pour les 17 postes
-- du jeu. Ce lot ne refond PAS toutes les remunerations civiles -- il branche proprement le seul
-- circuit militaire, et le probleme transversal est signale a part.
--
-- LE PAYEUR EST LA CAISSE DE LA CASERNE de rattachement. Plus aucune creation monetaire.
--
-- PATRON REUTILISE, et il existait deja tel quel : assemblee_verser_indemnite. Registre quotidien
-- a cle unique « nom:jour » qui sert d'anti-rejeu (une unique_violation = deja verse), debit
-- PLAFONNE par la caisse, puis credit du joueur. On y ajoute seulement la part non versee, qui
-- devient la dette. Meme convention de jour que le refectoire : date reelle Europe/Paris, la
-- convention serveur canonique du projet -- aucun nouveau moteur de journee.
--
-- PAIEMENT PARTIEL RETENU plutot que tout-ou-rien : c'est ce que fait deja
-- caisse_institution_mouvement_plafonne, et laisser 100 FR dormir dans une caisse pendant qu'un
-- soldat n'est pas paye du tout serait moins coherent avec l'economie existante.
--
-- LES DETTES SURVIVENT A TOUT : changement de grade, demission, renvoi, depart de l'armee. Elles
-- sont nominatives et portent le grade au titre duquel elles sont nees.
-- ==========================================================================================
CREATE TABLE IF NOT EXISTS public.soldes_militaires (
  id          text PRIMARY KEY,           -- '<nom>:<jour>' : l'anti-rejeu EST la cle
  personnage  text NOT NULL,
  pays        text NOT NULL,
  grade       text NOT NULL,
  jour        date NOT NULL,
  du          integer NOT NULL,
  verse       integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  regle_le    timestamptz
);
CREATE INDEX IF NOT EXISTS soldes_militaires_perso ON public.soldes_militaires (personnage);
CREATE INDEX IF NOT EXISTS soldes_militaires_impayees
  ON public.soldes_militaires (pays, personnage) WHERE verse < du;

ALTER TABLE public.soldes_militaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS soldes_militaires_lecture ON public.soldes_militaires;
-- Lecture ouverte : le PJ doit voir ses arrieres, et l'autorite de la caserne le total des dettes.
CREATE POLICY soldes_militaires_lecture ON public.soldes_militaires
  FOR SELECT TO anon, authenticated USING (true);
REVOKE ALL ON TABLE public.soldes_militaires FROM anon, authenticated;
GRANT SELECT ON TABLE public.soldes_militaires TO anon, authenticated;

-- ---- Grade militaire effectif d'un PJ, depuis les sources canoniques ----
-- Un soldat PJ n'est PAS un poste nomme : il est une entree { pj:true, nom } dans une section.
-- On lit donc les deux sources, jamais une declaration du client.
CREATE OR REPLACE FUNCTION public.militaire_grade_effectif(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  SELECT COALESCE(
    (SELECT pd.poste->>'id' FROM public.personnages_donnees pd
      WHERE pd.name = p_nom AND pd.poste->>'id' IN ('lieutenant','capitaine','commandant')),
    (SELECT 'soldat' FROM public.compagnies_militaires c,
            jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
            jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
      WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = p_nom LIMIT 1));
$fn$;
REVOKE ALL ON FUNCTION public.militaire_grade_effectif(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_grade_effectif(text) TO authenticated, service_role;

-- ---- Perception de la solde du jour ----
CREATE OR REPLACE FUNCTION public.militaire_solde_percevoir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_pays text; v_grade text; v_du integer; v_jour date; v_id text;
  v_mvt jsonb; v_verse integer; v_credit jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;

  -- Baremes GD. Les PNJ n'ont aucune solde : ils ne passent jamais par ici.
  v_du := CASE v_grade WHEN 'soldat' THEN 50 WHEN 'lieutenant' THEN 150
                       WHEN 'capitaine' THEN 250 WHEN 'commandant' THEN 400 END;
  IF v_du IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_sans_solde'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- ANTI-REJEU PAR LA CLE : deux clics simultanes ne peuvent pas creer deux lignes.
  BEGIN
    INSERT INTO public.soldes_militaires (id, personnage, pays, grade, jour, du, verse)
    VALUES (v_id, v_moi, v_pays, v_grade, v_jour, v_du, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percue_aujourdhui', 'jour', v_jour);
  END;

  -- Debit PLAFONNE : la caserne verse ce qu'elle peut, le reste devient une dette.
  v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_du);
  v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));

  IF v_verse > 0 THEN
    v_credit := public.assemblee_crediter_joueur(v_moi, v_verse);
  END IF;
  UPDATE public.soldes_militaires
     SET verse = v_verse, regle_le = CASE WHEN v_verse >= v_du THEN now() END
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'grade', v_grade, 'du', v_du, 'verse', v_verse,
    'dette', v_du - v_verse, 'jour', v_jour,
    'liquide', v_credit->'liquide', 'arg', v_credit->'arg');
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_solde_percevoir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_solde_percevoir() TO authenticated, service_role;

-- ---- Reglement des arrieres, les plus anciens d'abord ----
-- Une dette ne disparait JAMAIS : ni au changement de grade, ni a la demission, ni au depart de
-- l'armee. Elle est nominative et porte le grade au titre duquel elle est nee.
CREATE OR REPLACE FUNCTION public.militaire_arrieres_regler()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_pays text; v_l record; v_mvt jsonb; v_manque integer;
  v_verse integer; v_total integer := 0; v_lignes integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  FOR v_l IN SELECT id, du, verse FROM public.soldes_militaires
              WHERE personnage = v_moi AND pays = v_pays AND verse < du
              ORDER BY jour FOR UPDATE LOOP
    v_manque := v_l.du - v_l.verse;
    v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_manque);
    v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));
    EXIT WHEN v_verse = 0;                 -- caisse vide : on s'arrete, rien n'est invente
    PERFORM public.assemblee_crediter_joueur(v_moi, v_verse);
    UPDATE public.soldes_militaires
       SET verse = v_l.verse + v_verse,
           regle_le = CASE WHEN v_l.verse + v_verse >= v_l.du THEN now() END
     WHERE id = v_l.id;
    v_total := v_total + v_verse; v_lignes := v_lignes + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'verse', v_total, 'lignes', v_lignes,
    'reste_du', (SELECT coalesce(sum(du - verse), 0) FROM public.soldes_militaires
                  WHERE personnage = v_moi AND pays = v_pays AND verse < du));
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_arrieres_regler() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_arrieres_regler() TO authenticated, service_role;