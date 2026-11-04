-- PAIE DES EMPLOYES PNJ (HORS ESCORTS) : DECIDEE PAR LE SERVEUR (04/11/2026, Claude, reste hors #379).
--
-- Avant : payerEmployes (plateau-multijoueur.js), au réveil, faisait `state.arg -= emp.cout` puis
-- comptait sur la sauvegarde de la fiche. Depuis que `arg` est un total calculé (20261104013000), ce
-- débit n'atteignait plus aucune poche : les employés étaient payés sans que rien ne sorte.
--
-- Règle existante de l'écran, reprise sans changement (même forme que escorts_payer_jour, #379 3b) :
--   * chaque employé actif du PJ (hors escorts, payées par escorts_payer_jour) reçoit son salaire
--     du jour (`pnj_employes_metier.cout_jour`) sur les fonds ordinaires (liquide puis Banque nationale) ;
--   * fonds insuffisants : il quitte le service (même départ que employe_liberer(…, 'impaye')) ;
--     aucun malus de popularité (l'écran n'en posait pas pour un employé ordinaire) ;
--   * salaire nul (stagiaire) : rien n'est prélevé, jamais de départ.
-- Un reçu par employé et par jour réel (Europe/Paris) : un second réveil le même jour ne repaie pas.

DO $prevol$
BEGIN
  IF to_regprocedure('public.debiter_fonds_ordinaires(text,numeric)') IS NULL
     OR to_regclass('public.pnj_employes_metier') IS NULL OR to_regclass('public.pnj_membres') IS NULL THEN
    RAISE EXCEPTION 'employes_paie : socle employes absent'; END IF;
END $prevol$;

CREATE TABLE IF NOT EXISTS public.employes_paies_recus(
  pnj_id text NOT NULL,
  jour date NOT NULL,
  employeur text NOT NULL,
  salaire integer NOT NULL,
  paye boolean NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(pnj_id, jour));
ALTER TABLE public.employes_paies_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.employes_paies_recus FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.employes_payer_jour()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, pg_temp AS $f$
DECLARE moi text := public.mon_personnage(); a public.personnages_donnees;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; e record; v_pay jsonb; v_paye boolean;
  v_paies jsonb := '[]'::jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO a FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  FOR e IN
    SELECT m.id, m.nom, greatest(0, coalesce(em.cout_jour,0))::integer salaire
      FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id = m.id
     WHERE m.famille = 'employe' AND m.proprietaire_pj = moi AND m.statut = 'actif'
       AND em.job IS DISTINCT FROM 'escort' AND coalesce(em.cout_jour,0) > 0
       AND NOT EXISTS (SELECT 1 FROM public.employes_paies_recus r WHERE r.pnj_id = m.id AND r.jour = v_jour)
     ORDER BY m.id FOR UPDATE OF m
  LOOP
    v_pay := public.debiter_fonds_ordinaires(moi, e.salaire);
    v_paye := coalesce((v_pay->>'ok')::boolean, false);
    IF NOT v_paye THEN
      UPDATE public.pnj_membres
         SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL,
             ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
       WHERE id = e.id;
    END IF;
    INSERT INTO public.employes_paies_recus(pnj_id, jour, employeur, salaire, paye) VALUES (e.id, v_jour, moi, e.salaire, v_paye);
    v_paies := v_paies || jsonb_build_array(jsonb_build_object('pnj_id', e.id, 'nom', e.nom, 'salaire', e.salaire, 'paye', v_paye));
  END LOOP;
  SELECT * INTO a FROM public.personnages_donnees WHERE name = moi;
  RETURN jsonb_build_object('ok',true,'acteur',moi,'jour',v_jour,'paies',v_paies,
    'arg',a.arg,'liquide',a.liquide,
    'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = moi AND banque = 'nationale'),0));
END;$f$;
REVOKE ALL ON FUNCTION public.employes_payer_jour() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.employes_payer_jour() TO authenticated;
NOTIFY pgrst, 'reload schema';
