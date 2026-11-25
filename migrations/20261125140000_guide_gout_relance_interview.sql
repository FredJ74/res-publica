-- Mission de jour du 25/11/2026 (Claude), bloc 1.1 — APPLIQUÉE en production le 25/11/2026 au soir (feu vert de Fred, contrôlée en lecture). Après 20261124106000 (PNJ guide).
-- Réponses de Fred aux questions de la Purge (PNJ guide) :
--   1. Le « goût » du nouveau pour le tirage du commerce (et le choix de la piste) est le CHEMIN choisi à l'interview ;
--      à défaut de chemin, c'est sa CARRIÈRE (table guide_carrieres_criteres, réglable par le MJ) ; à défaut, 'defaut'.
--   2. Interview fermée sans réponse (encore « à faire » après son ouverture, ou ignorée) : la journaliste écrit quand même,
--      au plus tôt le lendemain, pour proposer de la reprendre (texte fixe, sans IA : accueil_parametres_textes
--      'guide_relance_interview'). Une seule fois. Son message mène à « Mes objectifs », où l'interview attend (une
--      interview ignorée y revient). Il compte comme le message de guide du jour et comme un message de la journaliste.
--   3. Ce message porte le choix « Ne plus me proposer d'interview d'accueil » (accueil_interview_refuser) : il coupe
--      définitivement la relance et retire l'interview d'accueil de « Mes objectifs ». Ce refus ne vaut QUE pour
--      l'interview d'accueil (colonne de accueil_personnages) : aucune autre interview (journal-interview, élu…) n'est touchée.
-- Sans cette migration, l'écran et /api/chat?mode=guide gardent le comportement actuel (aucune erreur pour le joueur).
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.guide_carrieres_criteres;                                                   -- 12
--   SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'accueil_personnages'
--    AND column_name IN ('interview_relancee_le', 'interview_refusee_le');                                  -- 2 lignes
--   SELECT valeur <> '' FROM public.accueil_parametres_textes WHERE cle = 'guide_relance_interview';        -- vrai
--   SELECT position('guide_relance_v1' in pg_get_functiondef('public.guide_reserver()'::regprocedure)) > 0;   -- vrai
--   SELECT has_function_privilege('authenticated', 'public.accueil_interview_refuser()', 'EXECUTE');         -- vrai
--   SELECT has_function_privilege('anon', 'public.accueil_interview_refuser()', 'EXECUTE');                  -- faux
BEGIN;

-- 1. Le goût par la carrière, quand le nouveau n'a pas choisi de chemin.
CREATE TABLE IF NOT EXISTS public.guide_carrieres_criteres (
  carriere text PRIMARY KEY,
  critere text NOT NULL CHECK (critere IN ('politique', 'affaires', 'influence', 'crime', 'uniforme', 'belle_vie', 'defaut'))
);
ALTER TABLE public.guide_carrieres_criteres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guide_carrieres_criteres FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.guide_carrieres_criteres TO service_role;
INSERT INTO public.guide_carrieres_criteres (carriere, critere) VALUES
  ('officer', 'uniforme'), ('intel', 'uniforme'), ('business', 'affaires'), ('doctor', 'affaires'),
  ('magistrat', 'politique'), ('worker', 'politique'), ('press', 'influence'), ('clergy', 'influence'),
  ('criminal_c', 'crime'), ('escort', 'belle_vie'), ('minor', 'defaut'), ('sans_experience', 'defaut')
ON CONFLICT (carriere) DO NOTHING;

-- 2. Relance de l'interview d'accueil.
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS interview_relancee_le timestamptz;
ALTER TABLE public.accueil_personnages ADD COLUMN IF NOT EXISTS interview_refusee_le timestamptz;
INSERT INTO public.accueil_parametres_textes (cle, valeur, libelle) VALUES
  ('guide_relance_interview', 'Vous m''avez filé entre les doigts l''autre jour… on reprend quand vous voulez ? Mon micro vous attend dans « Mes objectifs ».',
   'Message de la journaliste quand l''interview d''accueil a été fermée sans réponse (une seule fois, au plus tôt le lendemain)')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.guide_critere_interne(p_chemin text, p_carriere text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_chemin, (SELECT critere FROM public.guide_carrieres_criteres WHERE carriere = p_carriere), 'defaut') /* guide_gout_carriere_v1 */
$function$;

-- La journaliste peut-elle relancer l'interview aujourd'hui ? (fermée sans réponse, au plus tôt le lendemain, une fois)
CREATE OR REPLACE FUNCTION public.guide_relance_possible_interne(r public.accueil_personnages, p_jour date)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT r.etat_interview IN ('a_faire', 'ignoree') AND r.ouverte_auto_le IS NOT NULL
     AND r.interview_relancee_le IS NULL AND r.interview_refusee_le IS NULL
     AND (r.ouverte_auto_le AT TIME ZONE 'Europe/Paris')::date < p_jour /* guide_relance_v1 */
$function$;

-- Réserve le message de guide du jour (ou rend celui déjà réservé). Reprise de 20261124106000 avec : la relance de
-- l'interview (publiée ici même, texte fixe) et le goût par la carrière à défaut de chemin.
CREATE OR REPLACE FUNCTION public.guide_reserver()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_el jsonb; r public.accueil_personnages; g public.guide_etat; d record;
        v_jour date := public.guide_jour_interne(); v_max integer := public.accueil_param('guide_max_par_voix', 3)::integer;
        v_interview date; v_j_ok boolean; v_h_ok boolean; v_voix text; v_pnj text; v_profil text; h record; jn record;
        v_critere text; p record; v_piste jsonb; v_ref text; v_com jsonb; m public.guide_messages; v_monde jsonb;
        v_txt text; v_conv text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_el := public.guide_eligible_interne(a);
  IF (v_el->>'ok')::boolean IS NOT TRUE THEN RETURN v_el; END IF;
  SELECT * INTO m FROM public.guide_messages WHERE personnage = a AND jour = v_jour ORDER BY id DESC LIMIT 1;
  IF FOUND AND m.statut = 'publie' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_ecrit_aujourdhui'); END IF;
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = a FOR UPDATE;
  SELECT country, current_city, career, archetype, stats INTO d FROM public.personnages_donnees WHERE name = a;
  INSERT INTO public.guide_etat (personnage) VALUES (a) ON CONFLICT (personnage) DO NOTHING;
  SELECT * INTO g FROM public.guide_etat WHERE personnage = a FOR UPDATE;
  IF g.dernier_jour = v_jour THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_ecrit_aujourdhui'); END IF;
  SELECT * INTO jn FROM public.accueil_journalistes WHERE pays = coalesce(r.pays, d.country);

  -- Relance de l'interview fermée sans réponse : la journaliste, texte fixe, publiée tout de suite (une seule fois).
  IF m.id IS NULL AND jn.journaliste IS NOT NULL AND g.nb_journaliste < v_max AND public.guide_relance_possible_interne(r, v_jour) THEN
    v_txt := nullif(btrim((SELECT valeur FROM public.accueil_parametres_textes WHERE cle = 'guide_relance_interview')), '');
    IF v_txt IS NOT NULL THEN
      v_profil := CASE jn.journaliste WHEN 'Vera Pravdina' THEN 'vera_pravdina' ELSE 'jodie_moitout' END;
      v_txt := replace(replace(replace(left(v_txt, 600), '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
      INSERT INTO public.guide_messages (personnage, voix, pnj, profil, piste, jour, statut, texte, publie_le)
      VALUES (a, 'journaliste', jn.journaliste, v_profil,
              jsonb_build_object('cle', 'relance_interview', 'type', 'relance_interview', 'activite', 'Reprendre l''interview d''accueil', 'lieu', 'Mes objectifs'),
              v_jour, 'publie', v_txt, now()) RETURNING * INTO m;
      v_conv := 'pnj:' || jn.journaliste || '__' || a;
      INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
      VALUES ('guide-relance-' || m.id, v_conv, 'pnj:' || jn.journaliste, v_txt, false, now()) ON CONFLICT DO NOTHING;
      UPDATE public.guide_etat SET dernier_jour = v_jour, nb_journaliste = nb_journaliste + 1, dernier_journaliste_jour = v_jour
       WHERE personnage = a;
      -- L'interview attend dans « Mes objectifs » (une interview ignorée y revient).
      UPDATE public.accueil_personnages SET interview_relancee_le = now(),
             etat_interview = CASE WHEN etat_interview = 'ignoree' THEN 'a_faire' ELSE etat_interview END, maj_le = now()
       WHERE personnage = a;
      RETURN jsonb_build_object('ok', true, 'publie', true, 'id', m.id, 'voix', 'journaliste', 'pnj', jn.journaliste,
        'conversation', v_conv, 'relance', true); /* guide_relance_v1 */
    END IF;
  END IF;

  IF m.id IS NULL THEN
    v_interview := (coalesce(r.publiee_le, r.chemin_choisi_le) AT TIME ZONE 'Europe/Paris')::date;
    SELECT * INTO h FROM public.pnj_guides_habitants WHERE pays = d.country AND ville = d.current_city;
    v_j_ok := g.nb_journaliste < v_max AND jn.journaliste IS NOT NULL AND v_interview IS NOT NULL AND v_interview < v_jour;
    v_h_ok := g.nb_habitant < v_max AND h.nom IS NOT NULL AND g.dernier_journaliste_jour IS DISTINCT FROM v_jour;
    IF v_j_ok AND (NOT v_h_ok OR g.nb_journaliste <= g.nb_habitant) THEN
      v_voix := 'journaliste'; v_pnj := jn.journaliste;
      v_profil := CASE jn.journaliste WHEN 'Vera Pravdina' THEN 'vera_pravdina' ELSE 'jodie_moitout' END;
    ELSIF v_h_ok THEN
      v_voix := 'habitant'; v_pnj := h.nom; v_profil := h.profil;
    ELSE
      RETURN jsonb_build_object('ok', false, 'raison', 'personne_n_ecrit');
    END IF;
    -- Le goût : le chemin de l'interview, sinon la carrière (guide_carrieres_criteres), sinon les pistes par défaut.
    v_critere := public.guide_critere_interne(r.chemin, d.career);
    SELECT * INTO p FROM public.guide_pistes WHERE pays = d.country AND critere IN (v_critere, 'defaut') AND NOT (cle = ANY (g.pistes))
     ORDER BY (critere = v_critere) DESC, rang LIMIT 1;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_de_piste'); END IF;
    v_piste := jsonb_build_object('cle', p.cle, 'type', p.type, 'activite', p.activite, 'lieu', p.lieu, 'gout', v_critere);
    IF p.type = 'referent' THEN
      SELECT referent_id INTO v_ref FROM public.pnj_referents WHERE pays = d.country AND domaine ~* p.referent_motif ORDER BY random() LIMIT 1;
      IF v_ref IS NOT NULL THEN v_piste := v_piste || jsonb_build_object('referent', v_ref);
      ELSE v_piste := v_piste || jsonb_build_object('type', 'lieu'); END IF;
    ELSIF p.type = 'commerce' THEN
      v_com := public.guide_commerce_tirer_interne(a, d.country, p.commerce_types, g.commerces);
      IF v_com IS NOT NULL THEN v_piste := v_piste || jsonb_build_object('commerce', v_com);
      ELSE v_piste := v_piste || jsonb_build_object('type', 'lieu'); END IF;
    END IF;
    INSERT INTO public.guide_messages (personnage, voix, pnj, profil, piste, jour)
    VALUES (a, v_voix, v_pnj, v_profil, v_piste, v_jour) RETURNING * INTO m;
  END IF;
  v_monde := jsonb_build_object(
    'elections_en_cours', (SELECT count(*) FROM public.cycles_electoraux c WHERE c.country = d.country AND c.data IS JSON OBJECT
                             AND c.data::jsonb->>'phase' IN ('candidatures', 'campagne', 'vote', 'second_tour', 'vote2')),
    'partis', (SELECT count(*) FROM public.organisations o WHERE o.data IS JSON OBJECT AND o.data::jsonb->>'type' = 'politique'
                 AND coalesce(o.data::jsonb->>'country', o.country_origine) = d.country));
  RETURN jsonb_build_object('ok', true, 'id', m.id, 'voix', m.voix, 'pnj', m.pnj, 'profil', m.profil, 'piste', m.piste,
    'personnage', a, 'pays', d.country, 'ville', d.current_city,
    'nouveau', jsonb_build_object('carriere', d.career, 'archetype', d.archetype, 'caracteristiques', d.stats,
      'chemin', r.chemin, 'mot', r.mot),
    'monde', v_monde); /* pnj_guide_v1 */ /* guide_gout_carriere_v1 */
END $function$;

-- « Ne plus me proposer d'interview d'accueil » : coupe la relance et retire l'interview d'accueil de « Mes objectifs ».
-- Ne touche à aucune autre interview.
CREATE OR REPLACE FUNCTION public.accueil_interview_refuser()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.accueil_personnages
     SET interview_refusee_le = coalesce(interview_refusee_le, now()),
         etat_interview = CASE WHEN etat_interview = 'a_faire' THEN 'ignoree' ELSE etat_interview END, maj_le = now()
   WHERE personnage = a;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_accueil'); END IF;
  RETURN jsonb_build_object('ok', true, 'refusee', true); /* guide_relance_v1 */
END $function$;

-- L'écran demande s'il y a lieu d'appeler le guide ; il apprend aussi si la relance a été refusée (boutons masqués).
CREATE OR REPLACE FUNCTION public.guide_etat_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_el jsonb; g public.guide_etat; v_ref timestamptz; v_etat text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_el := public.guide_eligible_interne(a);
  SELECT * INTO g FROM public.guide_etat WHERE personnage = a;
  SELECT interview_refusee_le, etat_interview INTO v_ref, v_etat FROM public.accueil_personnages WHERE personnage = a;
  RETURN jsonb_build_object('ok', true, 'arrete', g.arret_le IS NOT NULL,
    'a_ecrire', (v_el->>'ok')::boolean IS TRUE AND g.dernier_jour IS DISTINCT FROM public.guide_jour_interne(),
    'interview_refusee', v_ref IS NOT NULL,
    'interview_en_attente', v_etat IN ('a_faire', 'article_a_publier')); /* pnj_guide_v1 */ /* guide_relance_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.guide_critere_interne(text, text), public.guide_relance_possible_interne(public.accueil_personnages, date)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_interview_refuser(), public.guide_etat_lire(), public.guide_reserver() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_interview_refuser(), public.guide_etat_lire(), public.guide_reserver() TO authenticated;

COMMIT;
