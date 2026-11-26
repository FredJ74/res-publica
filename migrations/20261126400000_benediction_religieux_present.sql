-- Décisions du 26/11/2026 (Claude), bloc E — APPLIQUÉE en production le 26/11/2026 (feu vert de Fred, contrôlée en lecture). Après 20261125820000 (bénédiction tenue par le serveur, appliquée).
-- BÉNÉDICTION (décision technique du 26/11) : le serveur vérifie qu'un RELIGIEUX HABILITÉ est présent dans la pièce, comme
-- l'écran l'exigeait déjà (plateau-pnj.js : grand_pretre, pretre ou clerc, dans une église de son pays).
-- • religieux_habilites (pays, ville, batiment, piece, nom) : les religieux déclarés par data.js, Républia et Sovarka (le miroir
--   pnj_lieux_metiers ne couvre que Républia) ; le nom est comparé sans le suffixe « (PNJ) », sans casse ni espaces doubles.
-- • benediction_contact_demander : refus « pas_de_religieux_ici » si le religieux nommé n'est pas déclaré dans la pièce où se
--   trouve le joueur (avant toute dépense) ; le reste de la règle est inchangé (1 PA, 80 %, 24 h, excommunié refusé).
--   Remplacement complet, gardé par la marque benediction_serveur_v1 de la version de production ; nouvelle marque
--   benediction_religieux_v1.
-- Sans cette migration : comportement actuel (la présence n'est vérifiée que par l'écran).
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.religieux_habilites;                                                               -- 8
--   SELECT position('benediction_religieux_v1' in pg_get_functiondef('public.benediction_contact_demander(uuid,text)'::regprocedure)) > 0;  -- vrai
--   SELECT has_table_privilege('authenticated', 'public.religieux_habilites', 'SELECT');                            -- faux
BEGIN;

CREATE TABLE IF NOT EXISTS public.religieux_habilites (
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL, nom text NOT NULL,
  job text NOT NULL CHECK (job IN ('grand_pretre', 'pretre', 'clerc')),
  PRIMARY KEY (pays, ville, batiment, piece, nom));
ALTER TABLE public.religieux_habilites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.religieux_habilites FROM PUBLIC, anon, authenticated;
INSERT INTO public.religieux_habilites (pays, ville, batiment, piece, nom, job) VALUES
  ('republic', 'capitale', 'tabernacle-impots', 'nef_principale', 'Père Ception', 'grand_pretre'),
  ('republic', 'capitale', 'tabernacle-impots', 'nef_principale', 'Enfant de chœur Lacroix', 'clerc'),
  ('republic', 'capitale', 'tabernacle-impots', 'sacristie', 'Père Ception', 'grand_pretre'),
  ('republic', 'ville_a', 'notre-dame-mer', 'nef', 'Père Iscope', 'pretre'),
  ('republic', 'ville_b', 'eglise-montrouge', 'salle', 'Abbé Tonnière', 'pretre'),
  ('soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte', 'Camarade Pontife Tractorenko', 'grand_pretre'),
  ('soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte', 'Diacre laborieux', 'clerc'),
  ('soviet', 'ville_b', 'kolkhoze-spirituel', 'grange_sainte', 'Kouzma Lapchine', 'pretre')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.religieux_nom_normal_interne(p text)
 RETURNS text LANGUAGE sql IMMUTABLE AS $function$
  SELECT lower(regexp_replace(btrim(regexp_replace(coalesce(p, ''), '\s*\(PNJ\)\s*$', '', 'i')), '\s+', ' ', 'g'))
$function$;

CREATE OR REPLACE FUNCTION public.religieux_present_interne(p_nom text, p_religieux text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.religieux_habilites r JOIN public.personnages_donnees d ON d.name = p_nom
                  WHERE (r.pays, r.ville, r.batiment, r.piece) = (d.country, d.current_city, d.current_building, d.current_room)
                    AND public.religieux_nom_normal_interne(r.nom) = public.religieux_nom_normal_interne(p_religieux)) /* benediction_religieux_v1 */
$function$;
REVOKE ALL ON FUNCTION public.religieux_nom_normal_interne(text), public.religieux_present_interne(text, text) FROM PUBLIC, anon, authenticated;

DO $garde$
BEGIN
  IF position('benediction_religieux_v1' IN pg_get_functiondef('public.benediction_contact_demander(uuid,text)'::regprocedure)) = 0
     AND position('benediction_serveur_v1' IN pg_get_functiondef('public.benediction_contact_demander(uuid,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'benediction_contact_demander : version de production inattendue (marque benediction_serveur_v1 absente)';
  END IF;
END $garde$;

CREATE OR REPLACE FUNCTION public.benediction_contact_demander(p_requete uuid, p_pnj text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('pnj', left(coalesce(p_pnj, ''), 120)); v jsonb;
        v_excom jsonb; p jsonb; v_jet integer; v_ok boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'benediction_contact_demander', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT excommunie INTO v_excom FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF v_excom IS NOT NULL AND v_excom::text NOT IN ('null', 'false', '') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'excommunie'); END IF;
  -- Un religieux habilité doit être présent dans la pièce (décision du 26/11), avant toute dépense.
  IF NOT public.religieux_present_interne(a, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_religieux_ici'); END IF; /* benediction_religieux_v1 */
  p := public.jets_pa_prelever_interne(a, 'benediction_contact', 1);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= 80;
  IF v_ok THEN
    INSERT INTO public.benedictions (personnage, accordee_le, expire_le, consommee_le, par)
    VALUES (a, now(), now() + interval '1 day', NULL, left(coalesce(p_pnj, ''), 120))
    ON CONFLICT (personnage) DO UPDATE SET accordee_le = now(), expire_le = now() + interval '1 day', consommee_le = NULL, par = EXCLUDED.par;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'benediction_contact_demander', prm,
    jsonb_build_object('ok', true, 'benie', v_ok, 'jet', v_jet, 'taux', 80, 'pa', p -> 'pa')); /* benediction_serveur_v1 */
END $$;
REVOKE ALL ON FUNCTION public.benediction_contact_demander(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.benediction_contact_demander(uuid, text) TO authenticated;

COMMIT;
