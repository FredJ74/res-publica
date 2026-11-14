-- Combat contre les bêtes de la forêt de Krasnov (et gardes d'accès) : le moteur ne les tenait pas pour hostiles.
-- Constat (bataille 316, 14/11/2026) : cinq rounds contre l'ours sans un seul coup porté, puis l'ours décroche
-- au round 5 (groupe PNJ sans chef) et le combat est déclaré gagné, butin compris.
--
-- Cause : militaire_camps_hostiles ne reconnaît les camps d'une bataille hors guerre que pour les types
-- 'civil' et 'squatteurs'. Les types 'faune' et 'garde_acces' n'avaient donc aucun adversaire : aucune attaque.
--
-- Correctifs (patchs en place, ancrages vérifiés, rejouables) :
--   1. militaire_camps_hostiles : 'faune' et 'garde_acces' rejoignent 'civil' et 'squatteurs'.
--   2. militaire_bataille_combattants : même règle de corps-à-corps que les combats civils (VOL).
--   3. militaire_bataille_neutralisation_terminale_interne : un PJ tombé face à une bête part à l'hôpital
--      comme dans un combat civil, jamais à l'infirmerie de la caserne.
--   4. militaire_bataille_round : la phase passe à « combat » comme pour un combat civil.
--   5. combat_finaliser_interne : une bête qui décroche s'enfuit ; ce n'est pas une victoire (issue 'fuite').
--   6. sovarka_foret_issue_combat_interne : la fuite de la bête laisse le bois de la seconde coupe, sans butin.
--   7. militaire_bataille_etat : expose le type de combat, le nom de l'adversaire PNJ et l'issue civile,
--      pour que le panneau n'affiche ni « soldats » ni clé technique.
BEGIN;

DO $patch$
DECLARE d text; avant text; apres text; n integer;
BEGIN
  -- 1. Hostilité.
  d := pg_get_functiondef('public.militaire_camps_hostiles(bigint,text)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E'b.contexte->>''type'' IN (''squatteurs'',''civil'')';
    apres := E'b.contexte->>''type'' IN (''squatteurs'',''civil'',''faune'',''garde_acces'') /* combat_faune_hostilite_v1 */';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'militaire_camps_hostiles : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 2. Combattants : corps-à-corps civil (deux occurrences : PJ et PNJ hors soldats).
  d := pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E'b.contexte->>''type'' IN (''civil'',''squatteurs'')';
    apres := E'b.contexte->>''type'' IN (''civil'',''squatteurs'',''faune'',''garde_acces'')';
    n := (length(d) - length(replace(d, avant, ''))) / length(avant);
    IF n <> 2 THEN RAISE EXCEPTION 'militaire_bataille_combattants : % ancrages au lieu de 2', n; END IF;
    d := replace(d, avant, apres);
    d := replace(d, '-- combat_mode_ouverture_v1', E'-- combat_mode_ouverture_v1\n-- combat_faune_hostilite_v1');
    EXECUTE d;
  END IF;

  -- 3. PJ tombé : hôpital, pas caserne.
  d := pg_get_functiondef('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E'contexte->>''type'' IN (''civil'',''squatteurs'')';
    apres := E'contexte->>''type'' IN (''civil'',''squatteurs'',''faune'',''garde_acces'') /* combat_faune_hostilite_v1 */';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'neutralisation_terminale : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 4. Phase de combat engagée.
  d := pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E'AND contexte->>''type'' IN (''civil'',''squatteurs'');';
    apres := E'AND contexte->>''type'' IN (''civil'',''squatteurs'',''faune'',''garde_acces''); -- combat_faune_hostilite_v1';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'militaire_bataille_round : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 5. Une bête qui décroche s'enfuit : pas de victoire.
  d := pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E' ELSE issue:=''defaite'';END IF;\n';
    apres := E' ELSE issue:=''defaite'';END IF;\n'
          || E' -- combat_faune_hostilite_v1 : une bête qui décroche ou devient indisponible s''enfuit, elle n''est pas vaincue.\n'
          || E' IF b.contexte->>''type''=''faune'' AND issue=''neutralises'' AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND etat_final IS DISTINCT FROM ''replie'' AND etat_final IS DISTINCT FROM ''indisponible'') THEN issue:=''fuite'';END IF;\n';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_finaliser_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 7. État lisible par le panneau.
  d := pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure);
  IF position('combat_faune_hostilite_v1' IN d) = 0 THEN
    avant := E'''issue'', b.issue, ''rounds'', v_rounds));';
    apres := E'''issue'', b.issue, ''type'', b.contexte->>''type'', /* combat_faune_hostilite_v1 */\n'
          || E'    ''adversaire_nom'', CASE WHEN b.contexte->>''type'' IN (''faune'',''garde_acces'') THEN (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>''cible'') END,\n'
          || E'    ''resultat'', b.contexte->''resultat_civil''->>''issue'', ''rounds'', v_rounds));';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'militaire_bataille_etat : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $patch$;

-- 6. Issue côté forêt : la fuite de la bête laisse le bois, sans butin ni trophée.
CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e record; c jsonb; o jsonb; v_dep jsonb; v_livre jsonb := '[]'::jsonb; k integer := 0;
BEGIN
  -- combat_faune_hostilite_v1
  SELECT * INTO e FROM public.sovarka_foret_rencontres WHERE pnj_id = p_pnj FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue); END IF;
  UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = p_pnj AND statut = 'actif';
  IF e.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'deja', true); END IF;
  c := public.sovarka_foret_creature_interne(e.creature);
  IF p_issue IN ('tues', 'neutralises', 'fuite') THEN
    FOR o IN SELECT public.sovarka_matiere_objet_interne(b->>'cle', (b->>'qte')::integer, 'Butin : ' || lower(c->>'nom') || ' de la forêt de Krasnov.')
               FROM jsonb_array_elements(c->'butin') b WHERE p_issue <> 'fuite'
             UNION ALL
             SELECT public.sovarka_matiere_objet_interne('bois', (floor(random() * 2)::integer + 1) * 2, 'Seconde coupe dans la forêt profonde de Krasnov.')
             UNION ALL
             SELECT jsonb_build_object('name', 'Dent d''ours', 'icon', 'ti-trophy', 'stackable', true, 'stackKey', 'dent_ours',
                      'qty', (c->>'dents')::integer, 'legal', true, 'desc', 'Trophée de la forêt profonde de Krasnov : la preuve qu''on a vaincu un ours.')
              WHERE c ? 'dents' AND p_issue <> 'fuite' LOOP
      k := k + 1;
      v_dep := public.inventaire_deposer_interne(p_leader, o);
      IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN
        INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
        VALUES ('foret-krasnov-' || e.id || '-' || k, p_leader, 'Forêt de Krasnov', to_jsonb(o::text)) ON CONFLICT (id) DO NOTHING;
      END IF;
      v_livre := v_livre || o;
    END LOOP;
  END IF;
  IF p_issue IN ('tues', 'neutralises') THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'vaincu', clos_le = now() WHERE id = e.id;
    PERFORM public.mail_systeme_poser_interne('Événement', p_leader, 'Forêt de Krasnov',
      'Vous avez vaincu : ' || (c->>'nom') || '. Le bois de la seconde coupe et le butin (peaux, viande' || CASE WHEN c ? 'dents' THEN ', dents d''ours' ELSE '' END
      || ') vous revient, à partager avec votre groupe.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  ELSIF p_issue = 'fuite' THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'fuite', clos_le = now() WHERE id = e.id;
    PERFORM public.mail_systeme_poser_interne('Événement', p_leader, 'Forêt de Krasnov',
      'La bête (' || lower(c->>'nom') || ') a rompu le combat et s''est enfuie entre les arbres. Pas de butin, mais vous gardez le bois de la seconde coupe.',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  ELSE
    UPDATE public.sovarka_foret_rencontres SET statut = 'perdu', clos_le = now() WHERE id = e.id;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = e.bucheron;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'creature', e.creature, 'butin', v_livre);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- Contrôles structurels.
DO $$
BEGIN
  IF position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_camps_hostiles(bigint,text)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.sovarka_foret_issue_combat_interne(text,text,text)'::regprocedure)) = 0
     OR position('sovarka_foret_faune_v1' IN pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure)) = 0
     OR position('bataille_sorties_indisponibles_v1' IN pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'combat_faune_hostilite : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
