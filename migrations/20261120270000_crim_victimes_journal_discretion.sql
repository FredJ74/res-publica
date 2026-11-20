-- Victimes prévenues par le JOURNAL D'ÉVÉNEMENTS ; statut de discrétion lisible par le joueur lui-même (décisions de Fred
-- du 20/11/2026, GAME-DESIGN-CRIMINALITE.md § Messages et § 1).
--  • Tout courrier système d'expéditeur « Événement » ou « Événement mystérieux » (crimes : vol, neutralisation,
--    empoisonnement, cambriolage, crochetage, explosion, incendie, rumeur, corruption, affrontement, enquête…) devient une
--    ligne du journal : aiguillage UNIQUE dans mail_systeme_poser_interne, aucun appelant à modifier. La ligne passe par
--    crim_evenements (type 'journal'), déjà relevée par l'écran (crim_evenements_lire), qui l'inscrit au journal ; un
--    joueur absent la retrouve à son retour (pas de limite des 3 jours pour ce type). Textes inchangés, donc mêmes règles
--    d'anonymat (« Un individu masqué vous a dérobé… »). Le destinataire reste celui de l'appelant (employeur d'un PNJ).
--  • crim_mon_statut_discretion() : mode (decouvert, masque, cache, cache_masque) et numéro d'individu masqué dans ma pièce.
-- Idempotente (marques crim_victimes_journal_v1).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.mail_systeme_poser_interne(text,text,text,text,text)'::regprocedure,
  $a$  v_id := 'mail-' || (extract(epoch from clock_timestamp())*1000)::bigint$a$,
  $b$  -- crim_victimes_journal_v1 (Fred, 20/11/2026) : un « Événement » s'inscrit au journal, plus jamais au courrier.
  IF p_expediteur IN ('Événement', 'Événement mystérieux') THEN
    INSERT INTO public.crim_evenements (personnage, type, donnees)
    VALUES (p_destinataire, 'journal', jsonb_build_object('sujet', p_sujet, 'texte', p_corps,
                                                          'mysterieux', p_expediteur = 'Événement mystérieux'));
    RETURN jsonb_build_object('ok', true, 'journal', true);
  END IF;
  v_id := 'mail-' || (extract(epoch from clock_timestamp())*1000)::bigint$b$,
  'crim_victimes_journal_v1');

SELECT pg_temp.rp_raccorder('public.crim_evenements_lire()'::regprocedure,
  $a$AND cree_le > now() - interval '3 days'$a$,
  $b$AND (cree_le > now() - interval '3 days' OR type = 'journal') /* crim_victimes_journal_v1 */$b$,
  'crim_victimes_journal_v1');

CREATE OR REPLACE FUNCTION public.crim_mon_statut_discretion()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_num integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  SELECT m.numero INTO v_num FROM public.crim_masques_piece_interne(d.country, d.current_city, d.current_building, d.current_room) m
   WHERE m.nom = a;
  RETURN jsonb_build_object('ok', true, 'mode', public.crim_mode_action_interne(a), 'numero', v_num);
END $$;
REVOKE ALL ON FUNCTION public.crim_mon_statut_discretion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crim_mon_statut_discretion() TO authenticated;

COMMIT;
