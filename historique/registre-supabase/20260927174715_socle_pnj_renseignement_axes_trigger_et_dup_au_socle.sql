-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927174715
-- Nom original      : socle_pnj_renseignement_axes_trigger_et_dup_au_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:47:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b7cb36c3b9f5fd49bec7c6b627a7bf17
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
-- CONVERGENCE RENSEIGNEMENT, ETAPE 5 — LES LECTEURS DE DUP BASCULENT, LA MISSION SE RACCORDE SEULE
--
-- AXES. Seuls `pa` et `propriete` passent au socle, parce que ce sont les seuls que le socle porte
-- reellement : 12 PA jamais consommes, et la propriete institutionnelle du service. `position_leader`
-- RESTE au metier -- l'arbitrage sur les missions simultanees n'est pas rendu. `possessions` et
-- `argent` restent au metier aussi : aucun agent n'en a, et les declarer au socle affirmerait une
-- autorite sur un vide.
UPDATE public.pnj_axes_autorite SET autorite = 'socle',
       note = 'Au socle depuis le 27/09/2026 : 12 PA jamais consommes (classe beta), et propriete '
           || 'institutionnelle `renseignement` avec le pays pour perimetre.'
 WHERE famille = 'agent' AND axe IN ('pa', 'propriete');

UPDATE public.pnj_axes_autorite
   SET note = 'RESTE AU METIER, volontairement. agents_renseignement porte la position et le leader '
           || 'de chaque OCCURRENCE DE MISSION. Or le jeu autorise plusieurs cellules simultanees '
           || '(aucune garde de quota ; pool de 6 couvertures par sexe et par pays cible pour 3 H + '
           || '1 F par cellule, donc 2 cellules par pays et 4 pays = jusqu''a 8), et les 12 lignes '
           || 'historiques en portent la trace : deux cellules ont coexiste 13 h les 21-22/09, la '
           || 'meme identite y etant engagee deux fois, a deux positions. Une identite unique au '
           || 'socle ne peut avoir qu''UNE position : basculer exige un arbitrage.'
 WHERE famille = 'agent' AND axe = 'position_leader';

-- RACCORDEMENT AUTOMATIQUE DE TOUTE NOUVELLE MISSION. Un trigger plutot qu'une reecriture de
-- cellule_renseignement_creer : celle-ci fait 110 lignes et porte tout le tirage de couverture, que
-- l'arbitrage demande de preserver au mot. Le trigger est additif, il ne touche a aucune de ces
-- regles, et il tient l'invariant meme pour un ecrivain futur qui ignorerait le socle.
CREATE OR REPLACE FUNCTION public.renseignement_mission_raccorder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pnj text; v_dup integer;
BEGIN
  v_pnj := public.renseignement_pnj_id(NEW.role);
  SELECT m.car_dup INTO v_dup FROM public.pnj_membres m WHERE m.id = v_pnj;
  -- Si l'identite n'est pas au socle, on ne raccorde rien et on ne bloque rien : la mission vit
  -- comme avant. Fail-safe, pour qu'un socle incomplet n'empeche jamais de convoquer une cellule.
  IF v_dup IS NULL THEN RETURN NEW; END IF;
  NEW.pnj_id := v_pnj;
  -- La DUP de l'occurrence recopie celle du socle, qui fait desormais autorite : les quatre roles
  -- partagent 13. Recopiee plutot que lue a chaque fois, pour que les lignes HISTORIQUES gardent la
  -- DUP qu'elles avaient reellement au moment de leur mission -- l'historique ne se reecrit pas.
  NEW.dup := v_dup;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_renseignement_mission_raccorder ON public.agents_renseignement;
CREATE TRIGGER trg_renseignement_mission_raccorder
  BEFORE INSERT ON public.agents_renseignement
  FOR EACH ROW EXECUTE FUNCTION public.renseignement_mission_raccorder();

-- LES DEUX LECTEURS MECANIQUES DE LA DUP BASCULENT SUR LE SOCLE. Les FORMULES sont recopiees a
-- l'identique -- `max(5, 30 - DUP)` et `3*(PER - DUP) + (IS-50)/2` -- seule la SOURCE de la DUP
-- change. COALESCE sur l'ancienne colonne : si une ligne n'est pas raccordee, le comportement
-- d'avant s'applique, donc aucune regression possible.
CREATE OR REPLACE FUNCTION public.agent_trace_deposer(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a record; v_risque integer; v_jet integer; v_jour integer; v_id text;
BEGIN
  SELECT ag.id, COALESCE(m.car_dup, ag.dup) AS dup, ag.nom_couverture, ag.statut,
         c.statut AS statut_cellule,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN public.pnj_membres m ON m.id = ag.pnj_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id;

  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;

  v_risque := greatest(5, 30 - coalesce(a.dup, 8));
  v_jet    := floor(random() * 100)::integer + 1;
  IF v_jet > v_risque THEN
    RETURN jsonb_build_object('ok', true, 'trace', false, 'risque', v_risque);
  END IF;

  v_jour := public.jour_de_jeu_pays(a.pays_eff);
  v_id   := 'agent-' || a.id || '-j' || v_jour;

  -- La trace porte la COUVERTURE, jamais le vrai nom. Invariant de confidentialite conserve.
  INSERT INTO public.actions_tracables
    (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES (v_id, a.nom_couverture, NULL, 'presence_suspecte',
          a.pays_eff, a.ville_eff, v_jour, v_jour + 7, false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'trace', true, 'risque', v_risque, 'reference', v_id);
END; $$;