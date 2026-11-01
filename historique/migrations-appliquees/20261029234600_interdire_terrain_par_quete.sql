-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029222857.
-- Archivage documentaire seulement ; ne pas rejouer.
-- #252 : interdire définitivement l'attribution d'un terrain par l'ancien générateur.
-- Préserver les autres titres (achat direct, compromis, serveur).
DO $migration$
DECLARE
  v_def text;
  v_source text := $src$  IF p_titre NOT IN ('compromis','achat_direct','recompense_quete','serveur') THEN$src$;
  v_cible text := $dst$  IF p_titre = 'recompense_quete' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quete_aleatoire_supprimee');
  END IF;
  IF p_titre NOT IN ('compromis','achat_direct','recompense_quete','serveur') THEN$dst$;
BEGIN
  v_def := pg_get_functiondef('public.terrain_proprietaire_muter(text,text,jsonb,text)'::regprocedure);
  IF position('quete_aleatoire_supprimee' IN v_def) = 0 THEN
    IF position(v_source IN v_def) = 0 THEN
      RAISE EXCEPTION 'terrain_proprietaire_muter : signature de corps inattendue';
    END IF;
    EXECUTE replace(v_def, v_source, v_cible);
  END IF;
END $migration$;
