-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916135604
-- Nom original      : football_primes_versement_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 13:56:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ce8296ead7b27a1d30109d0169173ec3
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LES PRIMES DE MATCH SONT VERSEES PAR LE SERVEUR (16 septembre 2026).
--
-- LE DEFAUT. sbAppliquerSalaire verse une prime par un UPDATE direct sur la fiche d'un AUTRE
-- personnage. Depuis le chantier B, la vue personnages refuse cette ecriture
-- (personnage_non_possede) -- et l'appel est enveloppe dans un .catch() muet. La prime etait
-- donc perdue en silence, sauf dans le cas fortuit ou le beneficiaire etait justement le joueur
-- dont le navigateur drainait l'effet : il se creditait alors lui-meme. Un versement qui depend
-- de QUI a un onglet ouvert n'est pas un versement.
--
-- LA REGLE, retrouvee dans le code et NON MODIFIEE :
--   titulaire  : salaires.titulaire + (salaires.primeVictoire si SON club a gagne)
--   remplacant : salaires.remplacant
--   non retenu : rien
--   les salaires sont ceux du club (budgets_clubs), 100 / 50 / 150 par defaut -- memes valeurs
--   de repli que chargerBudgetClub cote client ;
--   le total reellement verse est debite de la caisse du club, comme avant.
--
-- CE QUE LE SERVEUR ATTESTE LUI-MEME, sans rien croire de l'appelant :
--   * le match existe dans le calendrier et porte played = true ;
--   * le beneficiaire figure dans la composition FIGEE de ce match ;
--   * il detient une licence ACTIVE dans le club pour lequel il est paye ;
--   * le montant est recalcule depuis budgets_clubs et le score persiste -- jamais lu d'un
--     parametre, jamais lu de effetsRestants (que le client ecrit) ;
--   * la prime n'a pas deja ete versee.
-- L'appelant ne choisit donc ni le beneficiaire, ni le montant, ni le nombre de versements : il
-- ne designe qu'une journee, et le serveur fait le reste.
--
-- IDEMPOTENCE : la reference est DETERMINISTE -- saison, journee, affiche, beneficiaire, role.
-- Elle ne doit rien a l'identifiant aleatoire que le client fabrique dans effetsRestants, qui
-- serait rejouable a volonte en changeant son suffixe. Cle primaire : un second versement est
-- impossible, y compris entre appels simultanes (la ligne du championnat est verrouillee).

CREATE TABLE IF NOT EXISTS public.football_primes_versees (
  reference    text PRIMARY KEY,
  saison       integer,
  journee      integer,
  affiche      text,
  beneficiaire text NOT NULL,
  club         text NOT NULL,
  role         text NOT NULL,
  montant      integer NOT NULL,
  au           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.football_primes_versees IS
  'Registre des primes de match versees (chantier du 16 septembre 2026). La cle primaire porte l''idempotence. Invisible aux clients.';

ALTER TABLE public.football_primes_versees ENABLE ROW LEVEL SECURITY;
-- Aucune policy : ni lecture ni ecriture pour anon/authenticated. Doctrine du projet.
REVOKE ALL ON public.football_primes_versees FROM PUBLIC, anon, authenticated;

-- Noms portes par une composition : le code existant stocke les titulaires en chaines et les
-- remplacants en objets (voir avancerFootballLive). On accepte les deux formes plutot que d'en
-- imposer une nouvelle -- ce lot ne reecrit pas le moteur.
CREATE OR REPLACE FUNCTION public.football_noms_composition(p_liste jsonb)
RETURNS TABLE (nom text)
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN jsonb_typeof(e) = 'string' THEN e #>> '{}' ELSE e ->> 'nom' END
    FROM jsonb_array_elements(coalesce(p_liste, '[]'::jsonb)) e
   WHERE coalesce(CASE WHEN jsonb_typeof(e) = 'string' THEN e #>> '{}' ELSE e ->> 'nom' END, '') <> ''
$$;

CREATE OR REPLACE FUNCTION public.football_primes_journee(p_journee integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb;
  v_cote text; v_club text; v_role text; v_nom text;
  v_sal jsonb; v_montant integer; v_victoire boolean;
  v_ref text; v_affiche text; v_total integer;
  v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0;
  v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  -- Verrou sur la ligne du championnat : deux clients qui reclament la meme journee au meme
  -- instant passent l'un apres l'autre, et le second ne trouve plus rien a verser.
  SELECT data INTO v_data FROM public.championnat WHERE id = 2 FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  FOR v_m IN SELECT m FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m LOOP
    CONTINUE WHEN NOT coalesce((v_m->>'played')::boolean, false);
    v_affiche := (v_m->>'home') || '-' || (v_m->>'away');
    v_total := 0;

    FOREACH v_cote IN ARRAY ARRAY['home', 'away'] LOOP
      v_club := v_m->>v_cote;
      CONTINUE WHEN coalesce(v_club, '') = '';
      v_victoire := CASE WHEN v_cote = 'home'
                         THEN coalesce((v_m->>'scoreHome')::int, 0) > coalesce((v_m->>'scoreAway')::int, 0)
                         ELSE coalesce((v_m->>'scoreAway')::int, 0) > coalesce((v_m->>'scoreHome')::int, 0) END;

      SELECT coalesce(data->'salaires', '{}'::jsonb) INTO v_sal
        FROM public.budgets_clubs WHERE id = v_club;
      -- Memes valeurs de repli que le client, pour un club dont le budget n'existe pas encore.
      v_sal := jsonb_build_object(
        'titulaire',    coalesce((v_sal->>'titulaire')::int, 100),
        'remplacant',   coalesce((v_sal->>'remplacant')::int, 50),
        'primeVictoire',coalesce((v_sal->>'primeVictoire')::int, 150));

      FOREACH v_role IN ARRAY ARRAY['titulaires', 'remplacants'] LOOP
        FOR v_nom IN
          SELECT n FROM public.football_noms_composition(
            coalesce(v_m #> ARRAY['compositions', v_cote, v_role],
                     v_m #> ARRAY['live', 'compositionFigee', v_cote, v_role])) n
        LOOP
          -- ELIGIBILITE : une licence ACTIVE dans CE club, verifiee en base.
          CONTINUE WHEN NOT EXISTS (
            SELECT 1 FROM public.personnages_donnees d
             WHERE d.name = v_nom
               AND d.licence_sportive ->> 'clubId' = v_club
               AND coalesce(d.licence_sportive ->> 'statut', '') = 'active');

          v_montant := CASE WHEN v_role = 'titulaires'
                            THEN (v_sal->>'titulaire')::int
                                 + CASE WHEN v_victoire THEN (v_sal->>'primeVictoire')::int ELSE 0 END
                            ELSE (v_sal->>'remplacant')::int END;
          CONTINUE WHEN coalesce(v_montant, 0) <= 0;

          v_ref := 's' || v_saison || '-j' || p_journee || '-' || v_affiche || '-'
                   || v_nom || '-' || v_role;
          BEGIN
            INSERT INTO public.football_primes_versees
              (reference, saison, journee, affiche, beneficiaire, club, role, montant)
            VALUES (v_ref, v_saison, p_journee, v_affiche, v_nom, v_club, v_role, v_montant);
          EXCEPTION WHEN unique_violation THEN
            v_ignores := v_ignores + 1;
            CONTINUE;                       -- deja versee : on ne paie pas deux fois
          END;

          UPDATE public.personnages_donnees
             SET arg = coalesce(arg, 0) + v_montant
           WHERE name = v_nom;

          v_verses := v_verses + 1;
          v_somme  := v_somme + v_montant;
          v_total  := v_total + v_montant;
          v_detail := v_detail || jsonb_build_object('nom', v_nom, 'club', v_club,
                                                     'role', v_role, 'montant', v_montant);
        END LOOP;
      END LOOP;

      -- La caisse du club supporte ce qu'elle a reellement paye, comme avant ce lot.
      IF v_total > 0 THEN
        UPDATE public.budgets_clubs
           SET data = jsonb_set(data, '{caisse}',
                        to_jsonb(greatest(0, coalesce((data->>'caisse')::int, 0) - v_total)))
         WHERE id = v_club;
        v_total := 0;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'journee', p_journee, 'verses', v_verses,
                            'total', v_somme, 'deja_versees', v_ignores, 'detail', v_detail);
END; $$;

REVOKE ALL ON FUNCTION public.football_primes_journee(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.football_primes_journee(integer) TO authenticated;