-- FAITS DIVERS du Journal du jour (décision de Fred du 20/11/2026). GAME-DESIGN-PRESSE.md.
-- journal_faits_divers(pays, début, fin) rend, DÉJÀ ANONYMISÉS, les crimes de la période (crim_affaires) qui
-- concernent ce pays (lieu dans le pays, ou victime de cette nationalité) : neutralisation, vol sur personne,
-- cambriolage, vol en commerce, empoisonnement, explosion, incendie. Un fait par acte réussi, plus les échecs
-- spectaculaires (explosion prématurée = échec critique ; auteur identifié).
-- ANONYMAT STRICT : le nom de l'auteur ne sort de cette fonction QUE s'il a été identifié par les voies du jeu
-- (crim_affaires.identifie : échec critique sans masque, enquête, arrestation, démasquage). Sinon l'auteur est
-- seulement « un individu masqué » (s'il était masqué) ou « un inconnu ». Aucun autre champ de l'auteur n'est rendu.
-- Les soins discrets en clinique privée ne sont pas des crimes : ils n'entrent jamais dans crim_affaires, donc jamais ici.
-- Réservée au serveur (clé service du générateur) : ni anon ni authenticated.
BEGIN;

-- Montant arrondi pour la presse : deux chiffres significatifs (2 340 → 2 300 ; 87 → 90).
CREATE OR REPLACE FUNCTION public.journal_arrondi_interne(p numeric)
RETURNS bigint LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p IS NULL THEN NULL WHEN abs(p) < 100 THEN round(p, -1)::bigint
              ELSE round(p, 2 - length(floor(abs(p))::bigint::text))::bigint END;
$$;

CREATE OR REPLACE FUNCTION public.journal_faits_divers(p_pays text, p_debut timestamptz, p_fin timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_agg(f ORDER BY f ->> 'date'), '[]'::jsonb) FROM (
    SELECT jsonb_strip_nulls(jsonb_build_object(
      'id', 'crim_affaires:' || a.id,
      'type', CASE a.acte WHEN 'neutraliser' THEN 'neutralisation' WHEN 'voler' THEN CASE WHEN a.cible_pnj IS NOT NULL AND a.employeur IS NOT NULL THEN 'vol_commerce' ELSE 'vol_personne' END
                          WHEN 'cambrioler' THEN 'cambriolage' WHEN 'empoisonner' THEN 'empoisonnement'
                          WHEN 'utiliser_explosifs' THEN 'explosion' WHEN 'incendier' THEN 'incendie' END,
      'date', a.cree_le,
      'lieu', jsonb_build_object('batiment', a.batiment, 'ville', a.ville, 'pays', a.pays),
      'victime', CASE
        WHEN a.cible IS NOT NULL AND v.name IS NOT NULL THEN jsonb_build_object(
          'nom', v.name, 'estPJ', true, 'poste', v.poste ->> 'name',
          'mandat', v.poste_depute ->> 'name', 'nationalite', coalesce(v.nationalite, v.country))
        WHEN coalesce(a.cible_pnj, a.cible) IS NOT NULL THEN jsonb_build_object(
          'nom', coalesce(a.cible_pnj, a.cible), 'estPJ', false, 'employeur', a.employeur)
        END,
      'estPJ', v.name IS NOT NULL,
      'auteur', CASE WHEN a.identifie AND a.auteur IS NOT NULL
                     THEN jsonb_build_object('identifie', true, 'nom', a.auteur)
                     ELSE jsonb_build_object('identifie', false,
                            'designation', CASE WHEN a.mode IN ('masque', 'cache_masque') THEN 'un individu masqué' ELSE 'un inconnu' END) END,
      'issue', CASE WHEN a.issue = 'reussite' THEN 'reussite'
                    WHEN a.acte = 'utiliser_explosifs' AND a.echec_critique THEN 'explosion_prematuree'
                    ELSE 'auteur_identifie' END,
      'consequence', CASE
        WHEN a.issue <> 'reussite' AND a.acte = 'utiliser_explosifs' AND a.echec_critique THEN 'explosion prématurée : poseur et présents blessés'
        WHEN a.issue <> 'reussite' THEN 'tentative déjouée, auteur identifié'
        WHEN a.acte IN ('neutraliser', 'empoisonner') THEN 'victime hospitalisée'
        WHEN a.acte IN ('voler', 'cambrioler') AND (a.details ->> 'montant_livre') ~ '^[0-9.]+$'
          THEN 'environ ' || public.journal_arrondi_interne((a.details ->> 'montant_livre')::numeric) || ' volés'
        WHEN a.acte IN ('voler', 'cambrioler') THEN 'des biens ont été dérobés'
        WHEN a.acte = 'utiliser_explosifs' THEN 'explosion : présents blessés'
        WHEN a.acte = 'incendier' THEN 'bâtiment incendié et fermé'
        END,
      'transfrontalier', (v.name IS NOT NULL AND coalesce(v.nationalite, v.country) IS DISTINCT FROM a.pays)
    )) AS f
      FROM public.crim_affaires a
      LEFT JOIN public.personnages_donnees v ON v.name = a.cible AND a.cible_pnj IS NULL
     WHERE a.cree_le >= p_debut AND a.cree_le < p_fin
       AND a.acte IN ('neutraliser', 'voler', 'cambrioler', 'empoisonner', 'utiliser_explosifs', 'incendier')
       AND (a.issue = 'reussite' OR (a.acte = 'utiliser_explosifs' AND a.echec_critique) OR a.identifie)
       AND (a.pays = p_pays OR coalesce(v.nationalite, v.country) = p_pays)
  ) x;
$$;
REVOKE ALL ON FUNCTION public.journal_faits_divers(text, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.journal_faits_divers(text, timestamptz, timestamptz) TO service_role;

COMMIT;
