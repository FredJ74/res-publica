-- Forêt de Krasnov : l'issue d'un combat contre une bête va dans le journal d'événements, pas dans la boîte mail.
-- Décision de Fred (14/11/2026, 16 h 17) : « pourquoi la boîte mail alors que l'on a le journal d'événements ».
--   1. sovarka_foret_issue_combat_interne n'envoie plus de mail (victoire comme fuite).
--   2. militaire_bataille_etat expose le butin d'un combat contre une bête, pour que le client l'écrive au journal.
BEGIN;

CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e record; c jsonb; o jsonb; v_dep jsonb; v_livre jsonb := '[]'::jsonb; k integer := 0;
BEGIN
  -- combat_faune_hostilite_v1
  -- foret_combat_journal_v1 : l'issue s'écrit dans le journal du joueur, plus dans sa boîte mail.
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
  ELSIF p_issue = 'fuite' THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'fuite', clos_le = now() WHERE id = e.id;
  ELSE
    UPDATE public.sovarka_foret_rencontres SET statut = 'perdu', clos_le = now() WHERE id = e.id;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = e.bucheron;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'creature', e.creature, 'butin', v_livre);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

DO $patch$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure);
  IF position('foret_combat_journal_v1' IN d) = 0 THEN
    avant := E'''resultat'', b.contexte->''resultat_civil''->>''issue'', ''rounds'', v_rounds));';
    apres := E'''resultat'', b.contexte->''resultat_civil''->>''issue'',\n'
          || E'    ''butin'', CASE WHEN b.contexte->>''type'' = ''faune'' THEN (SELECT coalesce(jsonb_agg(jsonb_build_object(''nom'', x->>''name'', ''qte'', (x->>''qty'')::integer)), ''[]''::jsonb) FROM jsonb_array_elements(coalesce(b.contexte->''resultat_civil''->''butin'', ''[]''::jsonb)) x) END, /* foret_combat_journal_v1 */\n'
          || E'    ''rounds'', v_rounds));';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'militaire_bataille_etat : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $patch$;

DO $$
BEGIN
  IF position('mail_systeme_poser_interne' IN pg_get_functiondef('public.sovarka_foret_issue_combat_interne(text,text,text)'::regprocedure)) > 0
     OR position('foret_combat_journal_v1' IN pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure)) = 0
     OR position('combat_faune_hostilite_v1' IN pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'foret_combat_journal : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
