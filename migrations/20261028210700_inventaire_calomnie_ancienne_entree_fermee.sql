-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, avec 20261028210000, 210500 et 210600.
-- L'ecran distribue desormais par calomnie_distribuer_consommer (jet + PA + tract retires par le
-- serveur). L'ancienne entree laissait l'ecran retirer lui-meme le tract : elle est fermee.
CREATE OR REPLACE FUNCTION public.calomnie_distribuer(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer DEFAULT 10)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
 SELECT jsonb_build_object('ok', false, 'raison', 'contrat_versionne_requis'); $$;
