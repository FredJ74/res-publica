-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture, mission Purge).
-- Purge, bloc A, point A.2 (Fred, 24/11/2026) : nouvelle pop-up de bienvenue à la première connexion d'un nouveau
-- personnage. Elle remplace le contenu de la fenêtre de première connexion (l'interview d'accueil, qui arrive désormais
-- entre 5 et 10 minutes de jeu : point A.3, migration 20261124102000). NON APPLIQUÉE. Rejouable. Rien du goulag.
--
--  • accueil_parametres.calendrier_depuis (époque Unix, posée UNE fois à l'application) : un personnage créé à partir de
--    cet instant (rerolls compris) suit le calendrier du nouveau venu (A.2, A.3, A.8, A.10). Les autres gardent l'accueil
--    d'avant (aucune donnée de joueur réécrite).
--  • accueil_personnages : calendrier (booléen figé à la création de la ligne), ville_depart (ville de la fiche à ce
--    moment), bienvenue_vue_le (la bienvenue ne revient jamais une fois fermée par la croix).
--  • accueil_vue_interne rend « bienvenue » {a_voir, pays, ville} ; accueil_bienvenue_vue() la mémorise.
--  • La signature (PNJ dédié à l'accueil, que Fred créera) est lue dans accueil_parametres_textes (cle 'bienvenue_signataire',
--    'bienvenue_portrait') : vides aujourd'hui, l'écran laisse l'emplacement vide.

INSERT INTO public.accueil_parametres (cle, valeur, libelle)
VALUES ('calendrier_depuis', extract(epoch FROM now())::numeric,
        'Époque Unix : un personnage créé à partir de cet instant suit le calendrier du nouveau venu (bienvenue, interview entre 5 et 10 min, première heure sans fenêtre automatique)')
ON CONFLICT (cle) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.accueil_parametres_textes (
  cle text PRIMARY KEY,
  valeur text NOT NULL DEFAULT '',
  libelle text NOT NULL DEFAULT ''
);
ALTER TABLE public.accueil_parametres_textes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_parametres_textes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.accueil_parametres_textes TO service_role;
INSERT INTO public.accueil_parametres_textes (cle, valeur, libelle) VALUES
  ('bienvenue_signataire', '', 'Nom du PNJ dédié à l''accueil qui signe la bienvenue (en attente : Fred le créera)'),
  ('bienvenue_portrait', '', 'Portrait de ce PNJ (chemin d''image, en attente)')
ON CONFLICT (cle) DO NOTHING;

ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS calendrier boolean NOT NULL DEFAULT false;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS ville_depart text;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS bienvenue_vue_le timestamptz;

-- Ligne d'accueil du personnage, créée à la première lecture (jamais par la migration). Le calendrier est figé ici.
CREATE OR REPLACE FUNCTION public.accueil_ligne_interne(p_nom text)
 RETURNS public.accueil_personnages LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; v_pays text; v_ville text; v_cree timestamptz; v_j text; v_etat text := 'a_faire';
        v_cal boolean := false; v_depuis numeric;
BEGIN
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom;
  IF FOUND THEN RETURN r; END IF;
  SELECT country, current_city, created_at INTO v_pays, v_ville, v_cree FROM public.personnages_donnees WHERE name = p_nom;
  SELECT journaliste INTO v_j FROM public.accueil_journalistes WHERE pays = v_pays;
  IF v_j IS NULL THEN v_etat := 'sans_journaliste';
  ELSIF EXISTS (SELECT 1 FROM public.interviews_jodie i WHERE i.personnage = p_nom AND i.publie AND i.article_texte IS NOT NULL)
     OR EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.forum_id = 'presse' AND t.title = 'Un jour, un portrait : ' || p_nom) THEN
    v_etat := 'deja_interviewe';
  END IF;
  v_depuis := public.accueil_param('calendrier_depuis', NULL);
  v_cal := v_depuis IS NOT NULL AND v_cree IS NOT NULL AND extract(epoch FROM v_cree) >= v_depuis AND v_etat <> 'deja_interviewe';
  INSERT INTO public.accueil_personnages (personnage, pays, etat_interview, journaliste, calendrier, ville_depart)
  VALUES (p_nom, v_pays, v_etat, v_j, v_cal, v_ville) ON CONFLICT (personnage) DO NOTHING;
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom;
  RETURN r; /* accueil_interview_v1 accueil_bienvenue_v1 */
END $function$;

-- Vue complète de l'accueil pour le navigateur (jamais un calcul du navigateur).
CREATE OR REPLACE FUNCTION public.accueil_vue_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; j record; v_pays text; v_etapes jsonb; v_chemins jsonb; v_lib text;
BEGIN
  r := public.accueil_ligne_interne(p_nom);
  v_pays := coalesce(r.pays, (SELECT country FROM public.personnages_donnees WHERE name = p_nom));
  SELECT * INTO j FROM public.accueil_journalistes WHERE pays = v_pays;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', c.chemin, 'libelle', c.libelle) ORDER BY c.rang), '[]'::jsonb)
    INTO v_chemins FROM public.accueil_chemins c WHERE c.pays = v_pays;
  SELECT libelle INTO v_lib FROM public.accueil_chemins WHERE pays = v_pays AND chemin = r.chemin;
  SELECT coalesce(jsonb_agg(jsonb_build_object('n', e.n, 'texte', e.texte, 'lieu', e.lieu, 'validation', e.validation,
           'pnj', e.pnj, 'faite', r.etapes_faites ? e.n::text, 'faite_le', r.etapes_faites ->> e.n::text) ORDER BY e.n), '[]'::jsonb)
    INTO v_etapes FROM public.accueil_etapes e WHERE e.pays = v_pays AND e.chemin = r.chemin;
  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'pays', v_pays,
    'interview', jsonb_build_object('etat', r.etat_interview, 'journaliste', j.journaliste, 'journal', j.journal,
      'question', j.question,
      -- Calendrier du nouveau venu : plus d'ouverture à la connexion (A.3 décide du moment).
      'ouvrir_auto', NOT r.calendrier AND r.etat_interview = 'a_faire' AND r.ouverte_auto_le IS NULL
                     AND public.accueil_param('interview_ouverture_auto', 1) >= 1),
    'bienvenue', jsonb_build_object('a_voir', r.calendrier AND r.bienvenue_vue_le IS NULL,
      'pays', coalesce(r.pays, v_pays), 'ville', r.ville_depart,
      'signataire', nullif((SELECT valeur FROM public.accueil_parametres_textes WHERE cle = 'bienvenue_signataire'), ''),
      'portrait', nullif((SELECT valeur FROM public.accueil_parametres_textes WHERE cle = 'bienvenue_portrait'), '')),
    'mot_max', public.accueil_param('mot_longueur_max', 280)::integer,
    'chemins', v_chemins,
    'chemin', CASE WHEN r.chemin IS NULL THEN NULL ELSE jsonb_build_object('id', r.chemin, 'libelle', v_lib) END,
    'mot', r.mot, 'etapes', v_etapes,
    'bulle_pa', jsonb_build_object('vue', r.bulle_pa_le IS NOT NULL, 'pa', r.bulle_pa_pa,
      'active', public.accueil_param('bulle_pa_active', 1) >= 1)); /* accueil_interview_v1 accueil_bienvenue_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.accueil_bienvenue_vue()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.accueil_ligne_interne(a);
  UPDATE public.accueil_personnages SET bienvenue_vue_le = coalesce(bienvenue_vue_le, now()), maj_le = now() WHERE personnage = a;
  RETURN jsonb_build_object('ok', true); /* accueil_bienvenue_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.accueil_ligne_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_vue_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_bienvenue_vue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_bienvenue_vue() TO authenticated;
