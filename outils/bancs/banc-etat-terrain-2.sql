-- BANC DE L'ETAT D'UN TERRAIN -- 2/2 : LES LOTS, LE CHANTIER, LE REAMENAGEMENT
-- Chantier 5, les 22 ecritures de `terrains_etat` (10 octobre 2026).
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION.
--
-- CE QU'IL ETABLIT :
--
--   * LE DERNIER-ECRIVAIN-GAGNANT SUR LE TABLEAU DE LOTS. Un lot cree par un autre acteur entre
--     la lecture et l'ecriture n'est plus perdu : la porte fusionne par `lot.id`. La
--     contre-epreuve refait l'ancien chemin -- un UPDATE du tableau ENTIER depuis un cache
--     perime. Elle montrait deux lots disparaitre ; depuis le registre 634, qui a revoque INSERT
--     et UPDATE a `authenticated` sur `terrains_etat`, le meme UPDATE conserve mot pour mot LEVE
--     `42501 permission denied` au lieu d'ecraser. La contre-epreuve attrape ce refus -- et lui
--     seul, jamais `others` -- et c'est l'ABSENCE d'exception qui est desormais l'echec : la
--     garantie mesuree est plus forte, le chemin client n'est plus seulement perdant, il est
--     ferme.
--
--   * LE PROPRIETAIRE NOTE `pj:<nom>`. `estTitulaire` reconnait trois formes de reference ; la
--     premiere version de la porte du permis comparait au nom nu et aurait refuse un proprietaire
--     prefixe. `titulaire_est_moi` est le jumeau SQL exact, et l'epreuve 2 le verifie.
--
--   * L'ACCELERATION DE CHANTIER NE TOUCHE PAS LE TRAVAIL DU CRON. `totalVerse`, `heuresFaites`,
--     `stockMateriaux` et `tresorerie` vivent dans le MEME objet que `progressionJours` : la
--     porte calcule la progression elle-meme et ne reecrit rien d'autre. La valeur attendue --
--     3 jours pour une duree de 6 financee a 100 % -- vient de la grille de 184 chantiers
--     comparee aux formules du jeu par `comparer-progression-chantier.py`.
--
--   * LE VOL DE MATERIAUX EST REPLAFONNE SUR LE STOCK REEL. Deux voleurs emportaient chacun tout
--     le stock ; le second repart maintenant les mains vides, et l'evenement consigne la quantite
--     reelle sans jamais nommer le voleur.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE.
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0; v jsonb; d jsonb; lots jsonb;
  -- Vrai quand l'ecriture cliente directe a bien ete refusee par le PRIVILEGE (registre 634).
  v_refuse boolean;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  T constant text := 'zzbanc-terrain';
BEGIN
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.terrains_etat WHERE building_id = T;
  INSERT INTO public.terrains_etat (id, country, building_id, proprietaire, data)
  VALUES ('republic_' || T, 'republic', T, 'May',
    '{"city":"ville_a","proprietaire":"May","subdivisions":[{"id":"lot-A","label":"A","surface":100,"locataire":null}]}');
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);

  -- 1. Creer un lot sur le terrain d'un autre.
  v := public.terrain_lots_acte(T, 'lot_ajouter', '[{"id":"lot-B","label":"B","surface":50}]'::jsonb, NULL);
  n := n+1; IF v->>'raison' <> 'pas_proprietaire' THEN ko := ko||('1 un tiers cree un lot : '||v::text); END IF;

  -- 2 et 3. Le proprietaire NOTE `pj:` est reconnu, et le lot deja la survit.
  PERFORM set_config('role','postgres',true);
  UPDATE public.terrains_etat SET data = (data::jsonb || '{"proprietaire":"pj:Ben"}'::jsonb)::text WHERE building_id = T;
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_lots_acte(T, 'lot_ajouter', '[{"id":"lot-B","label":"B","surface":50}]'::jsonb, NULL);
  n := n+1; IF v->>'ok' <> 'true' THEN ko := ko||('2 le proprietaire note pj: est refuse : '||v::text); END IF;
  n := n+1; IF jsonb_array_length(v->'lots') <> 2 THEN ko := ko||('3 le lot A a disparu : '||(v->'lots')::text); END IF;

  -- 4. UN AUTRE ACTEUR CREE UN LOT ENTRE-TEMPS : la porte ne le perd pas.
  PERFORM set_config('role','postgres',true);
  UPDATE public.terrains_etat SET data = (data::jsonb
    || jsonb_build_object('subdivisions', (data::jsonb->'subdivisions')
         || '[{"id":"lot-C","label":"C","surface":30}]'::jsonb))::text
   WHERE building_id = T;
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_lots_acte(T, 'lot_ajouter', '[{"id":"lot-D","label":"D","surface":20}]'::jsonb, NULL);
  PERFORM set_config('role','postgres',true);
  SELECT data::jsonb->'subdivisions' INTO lots FROM public.terrains_etat WHERE building_id = T;
  n := n+1; IF jsonb_array_length(lots) <> 4
    THEN ko := ko||('4 la porte a perdu un lot cree entre-temps : '||lots::text); END IF;

  -- 5. CONTRE-EPREUVE : l'ancien chemin, un UPDATE du tableau ENTIER depuis un cache perime. Il
  -- ecrasait les quatre lots par deux ; depuis le registre 634 -- qui a revoque INSERT et UPDATE a
  -- `authenticated` sur `terrains_etat` -- il n'ecrase plus rien : le refus ne vient plus de la
  -- policy mais du DROIT, et il LEVE au lieu de renvoyer 0 ligne. On attrape ce refus-la et lui
  -- seul ; c'est l'ABSENCE d'exception qui serait l'echec. L'UPDATE est conserve mot pour mot, et
  -- la lecture qui suit verifie que les quatre lots sont intacts.
  PERFORM set_config('role','authenticated',true);
  v_refuse := false;
  BEGIN
    UPDATE public.terrains_etat
       SET data = (data::jsonb || '{"subdivisions":[{"id":"lot-A"},{"id":"lot-E"}]}'::jsonb)::text
     WHERE building_id = T;
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role','postgres',true);
  SELECT data::jsonb->'subdivisions' INTO lots FROM public.terrains_etat WHERE building_id = T;
  n := n+1; IF NOT v_refuse OR jsonb_array_length(lots) <> 4 THEN
    ko := ko||('5 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : le tableau de lots a pu etre '
      ||'ecrase depuis un cache (refus de privilege '||v_refuse::text||') : '||lots::text);
  END IF;

  -- 6 et 7. Les deux refus propres aux actes du locataire.
  UPDATE public.terrains_etat SET data =
    '{"city":"ville_a","proprietaire":"pj:Ben","subdivisions":[{"id":"lot-A","locataire":"May","propositionAgrandissement":{"idVide":"lot-B"}},{"id":"lot-B"}]}'
   WHERE building_id = T;
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_lots_acte(T, 'lot_fusion_accepter', '[{"id":"lot-A","surface":150}]'::jsonb, '{lot-B}');
  n := n+1; IF v->>'raison' <> 'aucune_proposition_sur_mon_lot'
    THEN ko := ko||('6 un tiers accepte l agrandissement du lot d un autre : '||v::text); END IF;
  v := public.terrain_lots_acte(T, 'lot_bail_libere', '[{"id":"lot-A","locataire":"Ben"}]'::jsonb, NULL);
  n := n+1; IF v->>'raison' <> 'liberation_qui_installe'
    THEN ko := ko||('7 une liberation installe un locataire : '||v::text); END IF;

  -- 8 a 10. L'ACCELERATION DE CHANTIER.
  PERFORM set_config('role','postgres',true);
  UPDATE public.terrains_etat SET data = '{"city":"ville_a","proprietaire":"pj:Ben","chantier":{"type":"construction","dureeJours":6,"coutTotal":30000,"totalVerse":0,"progressionJours":0,"stockMateriaux":{"bois":10,"metal":0,"minerai":0},"heuresFaites":7,"tresorerie":500}}'
   WHERE building_id = T;
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_chantier_acte(T, 'chantier_accelerer', NULL, NULL, 9);
  n := n+1; IF v->>'raison' <> 'financement_insuffisant'
    THEN ko := ko||('8 un chantier non finance s accelere : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  UPDATE public.terrains_etat SET data = (data::jsonb
    || jsonb_build_object('chantier', (data::jsonb->'chantier') || '{"totalVerse":30000}'::jsonb))::text
   WHERE building_id = T;
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_chantier_acte(T, 'chantier_accelerer', NULL, NULL, 9);
  n := n+1; IF NOT (v->>'ok' = 'true' AND (v->>'progression')::numeric = 3)
    THEN ko := ko||('9 la progression serveur n est pas 3 pour d=6 finance a 100 pct : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT data::jsonb->'chantier' INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n+1; IF NOT ((d->>'totalVerse')::numeric = 30000 AND (d->>'heuresFaites')::numeric = 7
                    AND (d->'stockMateriaux'->>'bois')::numeric = 10 AND (d->>'tresorerie')::numeric = 500)
    THEN ko := ko||('10 l acceleration a touche le travail du cron : '||d::text); END IF;

  -- 11 a 15. LE VOL DE MATERIAUX.
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_chantier_acte(T, 'chantier_materiaux_voler', 'bois', 999, 9);
  n := n+1; IF NOT (v->>'ok' = 'true' AND (v->>'quantite')::integer = 10 AND (v->>'stock_restant')::integer = 0)
    THEN ko := ko||('11 le vol n est pas replafonne sur le stock reel : '||v::text); END IF;
  v := public.terrain_chantier_acte(T, 'chantier_materiaux_voler', 'bois', 5, 9);
  n := n+1; IF v->>'raison' <> 'stock_vide'
    THEN ko := ko||('12 un second voleur emporte un stock vide : '||v::text); END IF;
  v := public.terrain_chantier_acte(T, 'chantier_materiaux_voler', 'or', 5, 9);
  n := n+1; IF v->>'raison' <> 'matiere_inconnue' THEN ko := ko||('13 matiere hors liste close : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT data::jsonb->'chantier' INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n+1; IF jsonb_array_length(coalesce(d->'evenements','[]'::jsonb)) <> 1
    THEN ko := ko||('14 le vol n a pas consigne exactement un evenement : '||(d->'evenements')::text); END IF;
  n := n+1; IF (d->'evenements'->0) ? 'voleur' OR (d->'evenements'->0->>'quantite')::integer <> 10
    THEN ko := ko||('15 l evenement du vol nomme le voleur ou se trompe : '||(d->'evenements'->0)::text); END IF;

  -- 16 et 17. LE REAMENAGEMENT N'EFFACE PAS LE CHANTIER DE CONSTRUCTION.
  PERFORM set_config('role','authenticated',true);
  v := public.terrain_reamenagement_poser(T, '{"type":"reamenagement","coutTotal":5000}'::jsonb);
  n := n+1; IF v->>'ok' <> 'true' THEN ko := ko||('16 le proprietaire ne peut pas poser son reamenagement : '||v::text); END IF;
  PERFORM set_config('role','postgres',true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n+1; IF NOT ((d->'chantierReamenagement'->>'coutTotal')::numeric = 5000 AND (d->'chantier') IS NOT NULL)
    THEN ko := ko||('17 le reamenagement a efface le chantier de construction : '||d::text); END IF;

  DELETE FROM public.terrains_etat WHERE building_id = T;
  IF array_length(ko,1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DES LOTS ET DU CHANTIER SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %', array_length(ko,1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
