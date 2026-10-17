-- Retire la signature historique devenue ambigue pour les appels RPC sans p_round.
DROP FUNCTION IF EXISTS public.police_combat_resoudre(text,text,text,text);
