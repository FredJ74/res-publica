-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919172715
-- Nom original      : contre_espionnage_enquete_paliers
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:27:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 832bee82945e35a43a716fcf813256cf
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
-- LOT 3 — L'enquete du Commissaire demasque un agent, par paliers.
--
-- On GREFFE sur la chaine existante plutot que d'en creer une seconde :
-- plainte_instruire_interne est deja le coeur commun des trois chemins
-- d'instruction (commissaire_enqueter, plainte_deposer avec commissaire PNJ,
-- plainte_traiter). Le comportement PJ est STRICTEMENT inchange -- la branche
-- agent ne se declenche que si l'auteur de la trace decouverte est la
-- couverture d'un agent reel du pays.
--
-- LE JET EST DESORMAIS SERVEUR. Jusqu'ici le seul jet d'enquete du jeu etait un
-- Math.random() dans le navigateur, et cette fonction ne tirait rien du tout.

-- Anti-rejeu des approfondissements : la cle EST l'anti-rejeu, exactement comme
-- scandales_tentatives (PRIMARY KEY (auteur, jour_paris)). Date reelle : aucun
-- jour de jeu a deviner.
CREATE TABLE IF NOT EXISTS public.contre_espionnage_tentatives (
  pays        text NOT NULL,
  couverture  text NOT NULL,
  jour_paris  date NOT NULL,
  instructeur text,
  cree_le     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, couverture, jour_paris)
);
ALTER TABLE public.contre_espionnage_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.contre_espionnage_tentatives FROM PUBLIC, anon, authenticated;

-- --------------------------------------------------------------------------
-- Moteur commun : un jet, un palier, memorisation. Rend le niveau atteint.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.contre_espionnage_resoudre(
  p_pays text, p_couverture text, p_instructeur text, p_ref text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ag record; v_per numeric; v_is numeric;
  v_mod integer; v_de integer; v_score integer; v_palier integer;
  v_avant integer; v_apres integer;
BEGIN
  SELECT ag.dup, ag.vrai_nom, ag.nom_couverture, c.pays_proprietaire
    INTO v_ag
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.pays_couverture = p_pays
     AND ag.nom_couverture = p_couverture
     AND ag.statut IN ('actif', 'detenu')
     AND c.statut = 'active';
  IF v_ag.dup IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_agent');
  END IF;

  -- PER de l'instructeur. Un commissaire PNJ n'a pas de fiche : assemblee_stat_base
  -- rend alors 8, la valeur neutre deja utilisee partout ailleurs.
  SELECT public.assemblee_stat_base(d.stats, 'PER') INTO v_per
    FROM public.personnages_donnees d WHERE d.name = p_instructeur;
  v_per := coalesce(v_per, 8);
  v_is  := public.is_national(p_pays);

  v_mod    := public.contre_espionnage_modificateur(v_per, v_ag.dup, v_is);
  v_de     := floor(random() * 100)::integer + 1;            -- RNG SERVEUR
  v_score  := greatest(0, least(100, v_de + v_mod));
  v_palier := public.contre_espionnage_palier(v_score);

  v_avant := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  v_apres := public.contre_espionnage_memoriser(p_pays, p_couverture, v_palier,
               v_ag.vrai_nom, v_ag.pays_proprietaire, p_instructeur, p_ref);

  RETURN jsonb_build_object('ok', true, 'score', v_score, 'palier', v_palier,
    'niveau_avant', v_avant, 'niveau', v_apres,
    'progression', v_apres > v_avant);
END;
$function$;

-- --------------------------------------------------------------------------
-- Instruction : comportement PJ inchange, branche agent ajoutee.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plainte_instruire_interne(
  p_pays text, p_ville text, p_cible text, p_motif text, p_instructeur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acte   public.actions_tracables%ROWTYPE;
  v_jour   integer;
  v_det    jsonb;
  v_motifs jsonb;
  v_ce     jsonb;
BEGIN
  SELECT * INTO v_acte FROM public.actions_tracables a
   WHERE a.country = p_pays AND a.city = p_ville AND a.auteur = p_cible
     AND a.decouvert IS NOT TRUE
   ORDER BY a.jour DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'classee',
                              'motif_decision', 'aucun_element_a_charge');
  END IF;

  UPDATE public.actions_tracables SET decouvert = true WHERE id = v_acte.id;

  -- BRANCHE CONTRE-ESPIONNAGE. L'auteur de la trace est-il la couverture d'un
  -- agent reel ? Si oui, l'instruction produit un DEMASQUAGE, pas une garde a
  -- vue : detention_ouvrir_interne refuserait de toute facon (pas de fiche).
  v_ce := public.contre_espionnage_resoudre(p_pays, p_cible, p_instructeur,
            'actions_tracables:' || v_acte.id);
  IF coalesce((v_ce ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'contre_espionnage',
      'acte', coalesce(v_acte.type_action, 'acte illegal'),
      'couverture', p_cible, 'enquete', v_ce);
  END IF;

  -- ---- A partir d'ici, comportement historique STRICTEMENT inchange ----
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = p_cible;
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'),
    'cible', v_acte.cible,
    'jour_fait', v_acte.jour,
    'city', p_ville,
    'ref_type', 'action_tracee',
    'ref_id', v_acte.id,
    'jours', 2,
    'source', 'garde_a_vue',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_det := public.detention_ouvrir_interne(
    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,
    p_ville, p_pays, v_motifs, p_instructeur, 'garde_a_vue_enquete');

  RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte',
                            'acte', coalesce(v_acte.type_action, 'acte illegal'),
                            'detention', v_det);
END;
$function$;

-- --------------------------------------------------------------------------
-- Approfondissement sur un agent DETENU : meme moteur, une fois par jour.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.contre_espionnage_approfondir(p_couverture text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_statut text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('commissaire', 'juge') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT ag.statut INTO v_statut
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.pays_couverture = v_pays AND ag.nom_couverture = p_couverture
     AND c.statut = 'active';
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_inconnue');
  END IF;
  IF v_statut <> 'detenu' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  BEGIN
    INSERT INTO public.contre_espionnage_tentatives (pays, couverture, jour_paris, instructeur)
    VALUES (v_pays, p_couverture, (now() AT TIME ZONE 'Europe/Paris')::date, v_nom);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui');
  END;

  RETURN public.contre_espionnage_resoudre(v_pays, p_couverture, v_nom, 'detention');
END;
$function$;

REVOKE ALL ON FUNCTION public.contre_espionnage_resoudre(text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_resoudre(text,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION public.contre_espionnage_approfondir(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_approfondir(text) TO authenticated, service_role;
