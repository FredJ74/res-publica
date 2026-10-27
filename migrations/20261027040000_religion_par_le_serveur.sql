-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027101811.
-- Eprouvee avant application en transaction annulee (refus hors eglise et au mauvais prix, grade, conquete stricte de la charge et du Grand Pretre, piete forcee remise au registre, excommunie sans piete). Baseline NON reextrait.
-- ============================================================================
-- LA CARRIERE RELIGIEUSE DE REPUBLIA PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1. Prier et faire un don dans l'une des trois eglises de Republia
-- nourrit la piete de la ville et la carriere religieuse du fidele (grade, charge de pretre,
-- Grand Pretre). Tout cela etait decide par le navigateur :
--   * il inscrivait lui-meme sa contribution dans contributions_piete (quantite libre) ;
--   * il recalculait la piete de la ville et l'ecrivait dans indices_villes ;
--   * il comparait les scores et s'inscrivait lui-meme pretre titulaire ou Grand Pretre dans
--     titulaires_pnj (table ouverte en ecriture) -- et le Grand Pretre peut excommunier.
-- Desormais religion_agir(fn, pa, cost) fait tout dans une seule transaction : lieu, paiement
-- (prier : payer_ordre ; don : vente_structure_encaisser, qui credite la caisse de l'eglise),
-- moral ou popularite, contribution, piete de la ville, grade, conquete des charges, annonces.
-- Les regles sont celles d'avant (plateau-divers.js) :
--   * prier : +2 moral, +3 piete (rien si excommunie) ; don : +3 popularite, +5 piete ;
--   * piete de la ville = 40 + contributions des 7 derniers jours, plafonnee a 100 ;
--   * grade selon le total de toujours : 10 enfant de choeur, 25 clerc, 45 pretre ;
--   * un pretre prend la charge de sa ville s'il depasse STRICTEMENT le titulaire (PNJ : 50 a
--     Luthecia, 40 ailleurs ; joueur : son score des 7 jours dans la ville) ;
--   * un pretre titulaire devient Grand Pretre s'il depasse strictement le Grand Pretre (PNJ :
--     50 ; joueur : son score dans sa ville de charge).
-- La piete d'une ville n'est plus jamais ecrite par un navigateur : un declencheur la recalcule
-- depuis le registre a chaque ecriture de indices_villes. Les joueurs n'ecrivent plus dans
-- contributions_piete ni dans titulaires_pnj (la revocation passe par poste_revoquer).
-- Les trois autres empires gardent leur ancien fonctionnement (feuille de route : Republia d'abord).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.piete_score_actif_interne(p_auteur text, p_ville text)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT coalesce(sum(quantite), 0)::numeric FROM public.contributions_piete
       WHERE pays = 'republic' AND auteur = p_auteur AND ville = p_ville
         AND created_at >= now() - interval '7 days' $$;

CREATE OR REPLACE FUNCTION public.piete_ville_calculee_interne(p_ville text)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT least(100, greatest(0, 40 + coalesce(sum(quantite), 0)))::numeric FROM public.contributions_piete
       WHERE pays = 'republic' AND ville = p_ville AND created_at >= now() - interval '7 days' $$;

-- La piete d'une ville de Republia est toujours celle du registre, quel que soit l'auteur de
-- l'ecriture. Les autres indices de la ville ne sont pas touches ici.
CREATE OR REPLACE FUNCTION public.indices_villes_piete_du_registre()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.id IN ('republic_capitale', 'republic_ville_a', 'republic_ville_b') THEN
    NEW.data := CASE WHEN jsonb_typeof(NEW.data) = 'object' THEN NEW.data ELSE '{}'::jsonb END
      || jsonb_build_object('piete', public.piete_ville_calculee_interne(substr(NEW.id, length('republic_') + 1)));
  END IF;
  RETURN NEW;
END; $function$;
DROP TRIGGER IF EXISTS indices_villes_piete_du_registre ON public.indices_villes;
CREATE TRIGGER indices_villes_piete_du_registre BEFORE INSERT OR UPDATE ON public.indices_villes
  FOR EACH ROW EXECUTE FUNCTION public.indices_villes_piete_du_registre();

-- Rafraichit la piete des trois villes (les contributions expirent a 7 jours) et la renvoie.
-- Sans argument venant du joueur : n'importe qui peut l'appeler, le resultat ne depend que du registre.
CREATE OR REPLACE FUNCTION public.piete_villes_actualiser()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ville text; v_out jsonb := '{}'::jsonb;
BEGIN
  FOREACH v_ville IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
    INSERT INTO public.indices_villes (id, data, updated_at)
      VALUES ('republic_' || v_ville, '{"isn":30,"ie":50,"social":45,"moral":50}'::jsonb, now())
      ON CONFLICT (id) DO UPDATE SET updated_at = now();
    v_out := v_out || jsonb_build_object(v_ville, public.piete_ville_calculee_interne(v_ville));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'piete', v_out);
END; $function$;

-- Titulaire d'une charge religieuse : celui inscrit au registre, sinon le PNJ d'origine.
CREATE OR REPLACE FUNCTION public.religion_titulaire_interne(p_poste text, p_ville text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT coalesce(
  (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'republic_' || p_poste || '_' || coalesce(p_ville, 'national')),
  CASE WHEN p_poste = 'grand_pretre' THEN 'Père Ception'
       ELSE CASE p_ville WHEN 'capitale' THEN 'Père Ception' WHEN 'ville_a' THEN 'Père Iscope'
                         WHEN 'ville_b' THEN 'Abbé Tonnière' END END) $$;

CREATE OR REPLACE FUNCTION public.religion_titulaire_poser_interne(p_poste text, p_ville text, p_nom text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
      VALUES ('republic_' || p_poste || '_' || coalesce(p_ville, 'national'), 'republic', p_poste, p_ville, p_nom, now())
      ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj, updated_at = now() $$;

CREATE OR REPLACE FUNCTION public.religion_grade_interne(p_total numeric)
 RETURNS text LANGUAGE sql IMMUTABLE
AS $$ SELECT CASE WHEN p_total >= 45 THEN 'pretre' WHEN p_total >= 25 THEN 'clerc'
                  WHEN p_total >= 10 THEN 'enfant_de_choeur' END $$;

REVOKE ALL ON FUNCTION public.piete_score_actif_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.piete_ville_calculee_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.indices_villes_piete_du_registre() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.religion_titulaire_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.religion_titulaire_poser_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.religion_grade_interne(numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.piete_villes_actualiser() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.piete_villes_actualiser() TO authenticated, service_role;
