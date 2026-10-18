-- Interdire l'ancien RPC a quatre arguments qui contournerait l'anti-rejeu.
REVOKE ALL ON FUNCTION public.police_combat_resoudre(text,text,text,text) FROM PUBLIC,anon,authenticated;
