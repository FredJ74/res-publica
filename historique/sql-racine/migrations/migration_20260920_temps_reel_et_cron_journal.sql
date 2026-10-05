-- =============================================================================
-- LE TEMPS REEL SERVEUR, LE JOURNAL DES CRONS, ET LA BASCULE DE FUSEAU
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- LE FUSEAU CANONIQUE DU JEU EST Europe/Paris. Les trois migrations reunies ici
-- sont les trois faces d'une meme decision : le serveur devient l'autorite
-- temporelle, il sait dire ce qu'il a fait chaque nuit, et les marqueurs herites
-- de l'epoque UTC sont traduits une bonne fois.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES :
--   20260920100857  temps_reel_jour_de_jeu
--       cree public.rp_epoques (+ sa ligne 'republic'), redefinit
--       jour_de_jeu_pays et cree jour_de_jeu_reel.
--   20260920101357  cron_journal_observabilite
--       cree public.cron_journal, ses deux index et cron_journal_ecrire.
--   20260920111104  bascule_fuseau_marqueurs_budgets
--       deux UPDATE ponctuels sur public.budgets_nationaux : traduction
--       UTC -> Europe/Paris des marqueurs de journee.
--
-- DEPENDANCES — a rejouer AVANT ce fichier :
--   * public.est_appel_serveur(), dans sa version fail-closed — migration de
--     production 20260919231313 est_appel_serveur_fail_closed. cron_journal_ecrire
--     en depend entierement : sans elle, la porte d'ecriture n'a plus de verrou.
--   * public.budgets_nationaux doit exister et porter ses cles
--     'derniereDistribJour' et 'dernierVirementCaserneJour' pour que la section 4
--     ait un sens (sinon les deux UPDATE ne touchent aucune ligne, ce qui est sans
--     danger).
--   * jour_de_jeu_pays PREEXISTAIT (elle valait max(day) sur les personnages du
--     pays) : ce fichier la REMPLACE. Aucun prerequis autre que le schema public.
--
-- AVERTISSEMENT : ce fichier reproduit l'etat final, pas l'historique. La version
-- « max(day) » de jour_de_jeu_pays n'y figure pas.
--
-- -----------------------------------------------------------------------------
-- COMMENTAIRE D'ORIGINE DE LA MIGRATION 20260920100857
-- -----------------------------------------------------------------------------
-- =====================================================================
-- §6.2 — LE JOUR DU MONDE DEVIENT LE TEMPS REEL SERVEUR
-- =====================================================================
-- CE QUI N'ALLAIT PAS. jour_de_jeu_pays() valait max(day) sur les personnages du
-- pays, et `day` est ecrit par le navigateur. L'audit l'a demontre : un seul
-- joueur ecrivant day = 9999 faisait basculer la date nationale de Republia pour
-- tout le monde -- et comme la fonction prend un maximum, elle ne redescendait
-- JAMAIS.
--
-- DECISION GD : 24 heures reelles = 24 heures. Le serveur est l'autorite
-- temporelle. personnage.day peut rester un compteur personnel ; il cesse d'etre
-- l'horloge du monde.
--
-- CONTINUITE. L'epoque est choisie pour que le basculement ne decale rien :
-- max(day) vaut 9 aujourd'hui (20/09/2026), et 2026-09-12 + 8 jours + 1 = 9.
-- Les detentions et traces en cours gardent donc exactement leur numerotation.
-- L'epoque est DECLAREE dans une table, pas enfouie dans du code.
--
-- LES SIX APPELANTS ne changent pas d'une ligne : agent_trace_deposer,
-- agent_traducteur_ecouter, arrestation_urgence, cellule_renseignement_clore,
-- detention_ouvrir_interne, detentions_pnj_liberer_echues. Tous s'en servent
-- comme horodatage de detention ou de trace -- le passage au temps reel les
-- rend tous corrects : une peine s'ecoule desormais meme si le detenu ne se
-- reconnecte pas, et personne ne peut l'accelerer en bougeant son compteur.

-- -----------------------------------------------------------------------------
-- 1. L'EPOQUE EST DECLAREE EN BASE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.rp_epoques (
  pays       text PRIMARY KEY,
  jour_un    date NOT NULL,
  note       text
);
ALTER TABLE public.rp_epoques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rp_epoques FROM PUBLIC, anon, authenticated;

-- ETAT FINAL CONSTATE : RLS active, AUCUNE politique, aucun trigger.

-- Donnees de reference — INSERT genere depuis la production (1 ligne).
INSERT INTO public.rp_epoques (pays, jour_un, note) VALUES ('republic','2026-09-13','Jour 1 = 13/09/2026, date de reinitialisation de la beta et de creation du premier personnage. Choisie pour que le passage de max(day) au temps reel ne decale aucune detention en cours.') ON CONFLICT (pays) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. LE JOUR DE JEU — definitions recopiees telles quelles depuis la production
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.jour_de_jeu_pays(p_pays text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1,
    ((now() AT TIME ZONE 'Europe/Paris')::date
      - coalesce((SELECT e.jour_un FROM public.rp_epoques e WHERE e.pays = p_pays),
                 DATE '2026-09-13')
    )::int + 1);
$function$;

-- Meme verite, sans parametre, pour les usages nationaux : evite qu'un futur
-- appelant reinvente le calcul.
CREATE OR REPLACE FUNCTION public.jour_de_jeu_reel()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.jour_de_jeu_pays('republic');
$function$;

REVOKE ALL ON FUNCTION public.jour_de_jeu_reel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.jour_de_jeu_reel() TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- COMMENTAIRE D'ORIGINE DE LA MIGRATION 20260920101357
-- -----------------------------------------------------------------------------
-- §6.12 CRONS : OBSERVABILITE DURABLE
-- ---------------------------------------------------------------------------
-- LE DEFAUT CONSTATE. La passe nocturne sait deja detecter ses echecs
-- (ECHECS_PASSE + HTTP 500), mais cette trace est VOLATILE : elle ne vit que
-- dans la reponse HTTP rendue a l'ordonnanceur Vercel. Personne, ni le GD ni le
-- jeu, ne peut repondre a la question « la taxe fonciere a-t-elle tourne la nuit
-- du 18 ? ». Pire : tacheQuotidienne() pose son marqueur de journee AVANT
-- d'appeler fn() -- choix deliberi et correct contre le double debit -- si bien
-- qu'une exception dans fn() BRULE la journee sans laisser la moindre trace
-- consultable. Une tache peut donc etre perdue toutes les nuits sans que rien
-- ne le dise.
--
-- LE PRINCIPE. Un journal en base, une ligne par (tache, jour). L'anti-rejeu EST
-- la cle : id = tache || ':' || jour. Un rejeu de la passe ne duplique pas, il
-- met a jour -- en conservant le premier debut, ce qui rend les reessais
-- lisibles au lieu de les effacer.
--
-- AUTORITE. Table fermee a anon/authenticated (RLS active SANS politique = close,
-- plus REVOKE explicite contre les DEFAULT PRIVILEGES du schema public). Ecriture
-- par une seule porte SECURITY DEFINER qui exige est_appel_serveur() -- devenue
-- fail-closed au lot precedent. Le journal est une observation, pas une surface
-- de jeu : aucun joueur n'y ecrit, aucun joueur n'y lit.

-- -----------------------------------------------------------------------------
-- 3. LE JOURNAL DES CRONS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cron_journal (
  id          text PRIMARY KEY,
  tache       text        NOT NULL,
  jour        date        NOT NULL,
  statut      text        NOT NULL CHECK (statut IN ('demarree','ok','echec','ignoree')),
  debut       timestamptz NOT NULL DEFAULT now(),
  fin         timestamptz,
  duree_ms    integer,
  erreur      text,
  contexte    jsonb,
  tentatives  integer     NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS cron_journal_jour_idx   ON public.cron_journal (jour DESC);
CREATE INDEX IF NOT EXISTS cron_journal_statut_idx ON public.cron_journal (statut) WHERE statut <> 'ok';

ALTER TABLE public.cron_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cron_journal FROM anon, authenticated, public;

-- ETAT FINAL CONSTATE : RLS active, AUCUNE politique, aucun trigger ; index
-- cron_journal_jour_idx et cron_journal_statut_idx conformes a pg_get_indexdef.

-- Porte d'ecriture unique. Renvoie le statut reellement conserve en base, pas ce
-- qu'on a demande d'ecrire : un appelant ne doit jamais deduire d'une absence
-- d'exception que la ligne est passee.
CREATE OR REPLACE FUNCTION public.cron_journal_ecrire(p_tache text, p_jour date, p_statut text, p_erreur text DEFAULT NULL::text, p_contexte jsonb DEFAULT NULL::jsonb, p_duree_ms integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id  text;
  v_row public.cron_journal%ROWTYPE;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_tache IS NULL OR btrim(p_tache) = '' OR p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_incomplets');
  END IF;
  IF p_statut NOT IN ('demarree','ok','echec','ignoree') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide');
  END IF;

  v_id := p_tache || ':' || p_jour::text;

  INSERT INTO public.cron_journal (id, tache, jour, statut, debut, fin, duree_ms, erreur, contexte)
  VALUES (
    v_id, p_tache, p_jour, p_statut, now(),
    CASE WHEN p_statut = 'demarree' THEN NULL ELSE now() END,
    p_duree_ms, left(p_erreur, 2000), p_contexte
  )
  ON CONFLICT (id) DO UPDATE SET
    statut     = EXCLUDED.statut,
    -- Le premier debut est conserve : un reessai doit rester lisible comme un
    -- reessai, pas se maquiller en premiere execution.
    fin        = CASE WHEN EXCLUDED.statut = 'demarree' THEN NULL ELSE now() END,
    duree_ms   = coalesce(EXCLUDED.duree_ms, public.cron_journal.duree_ms),
    erreur     = EXCLUDED.erreur,
    contexte   = coalesce(EXCLUDED.contexte, public.cron_journal.contexte),
    tentatives = public.cron_journal.tentatives
                 + CASE WHEN EXCLUDED.statut = 'demarree' THEN 1 ELSE 0 END
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'ok', true, 'id', v_row.id, 'statut', v_row.statut, 'tentatives', v_row.tentatives
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.cron_journal_ecrire(text, date, text, text, jsonb, integer)
  FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.cron_journal_ecrire(text, date, text, text, jsonb, integer)
  TO service_role;

-- -----------------------------------------------------------------------------
-- 3 bis. DROITS — etat final constate en production (pg_proc.proacl)
-- -----------------------------------------------------------------------------
--   jour_de_jeu_pays ..... postgres, service_role
--       La migration d'origine ne revoquait RIEN sur cette fonction : elle
--       PREEXISTAIT, et CREATE OR REPLACE conserve les droits deja poses. Sur une
--       base neuve, le rejeu laisserait donc EXECUTE a PUBLIC. On retablit ici
--       l'etat final reellement observe.
--   jour_de_jeu_reel ..... postgres, authenticated, service_role  (deja pose plus haut)
--   cron_journal_ecrire .. postgres, service_role                 (deja pose plus haut)

REVOKE ALL ON FUNCTION public.jour_de_jeu_pays(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.jour_de_jeu_pays(text) TO service_role;

-- -----------------------------------------------------------------------------
-- 4. REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE
-- -----------------------------------------------------------------------------
-- Migration 20260920111104 bascule_fuseau_marqueurs_budgets, recopiee VERBATIM.
-- Donnee metier, non derivable du schema : elle traduit des marqueurs de journee
-- ecrits a l'epoque UTC vers le fuseau canonique Europe/Paris.
--
-- COMMENTAIRE D'ORIGINE :
--
-- BASCULE UTC -> EUROPE/PARIS DES MARQUEURS DE JOURNEE (arbitrage GD du 20/09/2026)
-- ---------------------------------------------------------------------------
-- Meme raisonnement que pour le registre joursCron du cron, applique aux seuls
-- marqueurs qui vivent hors de ce registre. Inventaire complet fait avant :
--
--   greves_generales.derniere_application_jour ............ 0 ligne
--   organisations.data->greve->derniereApplicationJour .... 0 ligne
--   terrains_etat.data->permis->jourInstruction ........... 0 ligne
--   prets.jour_dernier_prelevement ........................ 0 ligne
--   budgets_nationaux.data->derniereDistribJour ........... 1 ligne  <- seule a traduire
--
-- Les quatre premiers n'ayant aucune valeur heritee, leur code peut passer a
-- Europe/Paris sans traduction : toute valeur future naitra deja parisienne.
-- On ne s'autorise PAS a en conclure qu'ils sont « sans risque parce que vides »
-- -- c'est bien le code qui est rendu correct, la base n'a simplement rien a
-- rattraper.
--
-- LA REGLE DE TRADUCTION : ces marqueurs ont ete ecrits par le cron, a 23 h UTC.
-- A cette heure-la, la date parisienne vaut toujours UTC + 1, en heure d'hiver
-- comme en heure d'ete (verifie sur les deux changements d'heure 2026). La nuit
-- deja traitee garde donc son marqueur et ne sera pas rejouee ; la nuit suivante
-- porte une date differente et s'executera.
--
-- Idempotence : on ne traduit que les valeurs strictement anterieures a la date
-- parisienne du jour. Rejouer cette migration ne decale donc rien une seconde
-- fois, puisque la valeur traduite n'est plus anterieure.

UPDATE public.budgets_nationaux b
   SET data = b.data || jsonb_build_object(
                 'derniereDistribJour',
                 to_char((((b.data ->> 'derniereDistribJour')::date) + 1), 'YYYY-MM-DD'))
 WHERE (b.data ->> 'derniereDistribJour') ~ '^\d{4}-\d{2}-\d{2}$'
   AND ((b.data ->> 'derniereDistribJour')::date) < (now() AT TIME ZONE 'Europe/Paris')::date;

UPDATE public.budgets_nationaux b
   SET data = b.data || jsonb_build_object(
                 'dernierVirementCaserneJour',
                 to_char((((b.data ->> 'dernierVirementCaserneJour')::date) + 1), 'YYYY-MM-DD'))
 WHERE (b.data ->> 'dernierVirementCaserneJour') ~ '^\d{4}-\d{2}-\d{2}$'
   AND ((b.data ->> 'dernierVirementCaserneJour')::date) < (now() AT TIME ZONE 'Europe/Paris')::date;
