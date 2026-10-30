-- Banc : cle d'unicite des achats (migration 20261030180000), 30/10/2026.
-- A executer APRES le texte de la migration, dans la meme transaction :
--   BEGIN; <migration>; <ce banc>
-- Le banc se termine TOUJOURS par une exception portant le rapport : tout est annule,
-- y compris la migration. Compte de test : Arnie (personnage d'essai des agents).
BEGIN;  -- enveloppe : rien ne survit, meme lance seul
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  -- Comme un vrai appel PostgREST : le verrou d'inventaire n'admet que /rpc/.
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.empreinte(p text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('pa', d.pa, 'liquide', coalesce(d.liquide, 0), 'arg', coalesce(d.arg, 0),
    'nat', coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = p AND banque = 'nationale'), 0),
    'rev', d.inventory_revision, 'bois', coalesce((SELECT sum(coalesce((e->>'qty')::int, 1)) FROM jsonb_array_elements(d.inventory) e
       WHERE e->>'stackKey' = 'bois' OR e->>'cle' = 'bois' OR e->>'id' = 'bois'), 0),
    'objets', jsonb_array_length(coalesce(d.inventory, '[]')),
    'recus', (SELECT count(*) FROM public.inventaire_actions_recus WHERE acteur = p),
    'stock_bois', (SELECT public.batiment_etat_lire(data)->'entrepot'->'stock'->'bois' FROM public.batiments_etat
                    WHERE id = 'republic_ville_a_entrepot-logistique-psm'))
  FROM public.personnages_donnees d WHERE d.name = p $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.empreinte(text) TO PUBLIC;

DO $banc$
DECLARE
  U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  K1 uuid := gen_random_uuid(); K uuid; v jsonb; e0 jsonb; e1 jsonb; r text := ''; n int := 0; ko int := 0;
  s record; inv0 jsonb; w jsonb;
BEGIN
  PERFORM pg_temp.serveur();
  -- Fonds confortables, PA pleins : seuls les refus voulus doivent apparaitre.
  UPDATE public.personnages_donnees SET liquide = 1000000, pa = greatest(pa, 10) WHERE name = A;

  -- E1 premier achat a l'Entrepot (2 bois, 1 PA)
  n := n + 1; e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K1, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":2}', 1, 0);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF (v->>'ok')::boolean IS NOT TRUE OR (e1->>'pa')::int <> (e0->>'pa')::int - 1 OR (e1->>'liquide')::numeric >= (e0->>'liquide')::numeric
     OR (e1->>'recus')::int <> (e0->>'recus')::int + 1 OR (e1->>'stock_bois')::int <> (e0->>'stock_bois')::int - 2
     OR NOT (v ? 'revision') OR NOT (v ? 'paie') THEN
    ko := ko + 1; r := r || E'\nE1 KO ' || v::text || ' ' || e0::text || ' -> ' || e1::text;
  ELSE r := r || E'\nE1 ok : achat paye une fois (PA -1, ' || ((e0->>'liquide')::numeric - (e1->>'liquide')::numeric) || ' FR, stock -2)'; END IF;

  -- E2 seconde tentative, meme cle (reponse perdue)
  n := n + 1; e0 := e1; PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K1, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":2}', 1, 0);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF (v->>'rejeu')::boolean IS NOT TRUE OR (v->>'ok')::boolean IS NOT TRUE OR e1 <> e0 OR (v->>'revision')::bigint <> (e1->>'rev')::bigint THEN
    ko := ko + 1; r := r || E'\nE2 KO ' || v::text || ' ' || e0::text || ' -> ' || e1::text;
  ELSE r := r || E'\nE2 ok : meme cle rejouee, rien de plus preleve ni livre'; END IF;

  -- E3 meme cle, autre panier
  n := n + 1; PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K1, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":3}', 1, 0);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF v->>'raison' IS DISTINCT FROM 'requete_reutilisee' OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nE3 KO ' || v::text;
  ELSE r := r || E'\nE3 ok : meme cle, autre panier -> requete_reutilisee, rien change'; END IF;

  -- E4 stock insuffisant APRES paiement des PA : la sous-transaction annule le PA
  n := n + 1; K := gen_random_uuid(); PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":999999}', 1, 0);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF v->>'raison' IS DISTINCT FROM 'stock_insuffisant' OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nE4 KO ' || v::text || ' ' || e1::text;
  ELSE r := r || E'\nE4 ok : stock insuffisant -> PA rendu, rien enregistre'; END IF;

  -- E5 inventaire plein : lest de 100 unites (plein sous toute regle de comptage), puis
  --    Entrepot et gilet refuses sans rien prelever ; le lest est ensuite retire.
  n := n + 1; K := gen_random_uuid();
  SELECT inventory INTO inv0 FROM public.personnages_donnees WHERE name = A;
  UPDATE public.personnages_donnees SET inventory = inventory || '[{"name":"Lest de banc","stackable":true,"stackKey":"lest-banc","qty":100}]'::jsonb WHERE name = A;
  e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":1}', 1, 0);
  w := public.objet_acheter(gen_random_uuid(), 'acheter_gilet', 'gilet', 1, 600);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF v->>'raison' IS DISTINCT FROM 'inventaire_plein' OR w->>'raison' IS DISTINCT FROM 'inventaire_plein' OR e1 <> e0 THEN
    ko := ko + 1; r := r || E'\nE5 KO ' || v::text || ' / ' || w::text || ' ' || e0::text || ' -> ' || e1::text;
  ELSE r := r || E'\nE5 ok : inventaire plein -> Entrepot et gilet refuses, PA et fonds intacts'; END IF;
  UPDATE public.personnages_donnees SET inventory = inv0 WHERE name = A;
  e0 := pg_temp.empreinte(A);

  -- E6 fonds insuffisants
  n := n + 1; K := gen_random_uuid();
  UPDATE public.personnages_donnees SET liquide = 0 WHERE name = A;
  UPDATE public.comptes_bancaires SET solde = 0 WHERE personnage = A AND banque = 'nationale';
  e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
  v := public.acheter_a_entrepot(K, A, 'republic', 'ville_a', 'entrepot-logistique-psm', '{"bois":1}', 1, 0);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF v->>'raison' IS DISTINCT FROM 'fonds_insuffisants' OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nE6 KO ' || v::text || ' ' || e1::text;
  ELSE r := r || E'\nE6 ok : fonds insuffisants -> refus, PA intact'; END IF;
  UPDATE public.personnages_donnees SET liquide = 1000000 WHERE name = A;

  -- O1/O2 objet_acheter (gilet) : achat puis seconde tentative
  n := n + 1; K := gen_random_uuid(); e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
  v := public.objet_acheter(K, 'acheter_gilet', 'gilet', 1, 600);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF (v->>'ok')::boolean IS NOT TRUE OR (e1->>'objets')::int <= (e0->>'objets')::int AND (e1->>'rev')::bigint = (e0->>'rev')::bigint
     OR (e0->>'liquide')::numeric - (e1->>'liquide')::numeric <> 600 THEN ko := ko + 1; r := r || E'\nO1 KO ' || v::text || ' ' || e0::text || ' -> ' || e1::text;
  ELSE r := r || E'\nO1 ok : gilet achete, 600 FR'; END IF;
  n := n + 1; e0 := e1; PERFORM pg_temp.je_suis(U);
  v := public.objet_acheter(K, 'acheter_gilet', 'gilet', 1, 600);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF (v->>'rejeu')::boolean IS NOT TRUE OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nO2 KO ' || v::text;
  ELSE r := r || E'\nO2 ok : seconde tentative du gilet rejouee, pas de second paiement'; END IF;

  -- P : passage sur chaque porte. Reussite => cle enregistree ; refus => aucune trace, rien change.
  FOR s IN SELECT * FROM (VALUES
    ('criee_vide',    $q$SELECT public.acheter_a_la_criee($1, 'Arnie', 'republic', 'port', 'port', '{}', 1, 0)$q$),
    ('usine_absente', $q$SELECT public.acheter_vente_directe_usine($1, 'Arnie', 'republic', 'ville_a', 'nulle-part', '{"bois":1}', 0, 0)$q$),
    ('manufacture',   $q$SELECT public.acheter_produit_manufacture($1, 'Arnie', 'republic', 'produit-inexistant')$q$),
    ('arme',          $q$SELECT public.arme_acheter($1, 'entreprise-inexistante', 'arme-inexistante')$q$),
    ('arme_noire',    $q$SELECT public.crime_acheter_arme_noire($1, 'entreprise-inexistante', 'arme-inexistante', false)$q$),
    ('explosifs',     $q$SELECT public.crime_acheter_explosifs($1, 1, 0)$q$),
    ('bois_imprimerie', $q$SELECT public.imprimerie_acheter_bois($1, 5)$q$)) t(nom, q)
  LOOP
    n := n + 1; K := gen_random_uuid(); e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
    BEGIN
      EXECUTE s.q INTO v USING K;
    EXCEPTION WHEN OTHERS THEN v := jsonb_build_object('exception', SQLERRM);
    END;
    PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
    IF v ? 'exception' THEN ko := ko + 1; r := r || E'\nP ' || s.nom || ' KO exception ' || (v->>'exception');
    ELSIF (v->>'ok')::boolean IS TRUE THEN
      IF NOT EXISTS (SELECT 1 FROM public.inventaire_actions_recus WHERE acteur = A AND requete = K) THEN
        ko := ko + 1; r := r || E'\nP ' || s.nom || ' KO reussite non enregistree';
      ELSE r := r || E'\nP ' || s.nom || ' ok : reussite enregistree (' || coalesce(v->>'reussi', 'oui') || ')'; END IF;
    ELSIF e1 <> e0 THEN ko := ko + 1; r := r || E'\nP ' || s.nom || ' KO mutation partielle ' || v::text || ' ' || e0::text || ' -> ' || e1::text;
    ELSE r := r || E'\nP ' || s.nom || ' ok : refus ' || coalesce(v->>'raison', '?') || ', rien change'; END IF;
  END LOOP;

  -- D : droits
  n := n + 1;
  IF has_function_privilege('anon', 'public.objet_acheter(uuid,text,text,integer,integer)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.acheter_a_entrepot(uuid,text,text,text,text,jsonb,integer,integer)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.achat_requete_clore_interne(text,uuid,text,jsonb,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.achat_requete_ouvrir_interne(text,uuid,text,jsonb)', 'EXECUTE') THEN
    ko := ko + 1; r := r || E'\nD KO droits';
  ELSE r := r || E'\nD ok : portes au seul joueur connecte, aides fermees'; END IF;

  -- C : contre-epreuve, l'ancienne porte sans cle fait bien payer deux fois (defaut d'origine)
  n := n + 1; e0 := pg_temp.empreinte(A); PERFORM pg_temp.je_suis(U);
  v := public.objet_acheter('acheter_gilet', 'gilet', 1, 600);
  v := public.objet_acheter('acheter_gilet', 'gilet', 1, 600);
  PERFORM pg_temp.serveur(); e1 := pg_temp.empreinte(A);
  IF (e0->>'liquide')::numeric - (e1->>'liquide')::numeric <> 1200 THEN ko := ko + 1; r := r || E'\nC KO contre-epreuve non reproduite';
  ELSE r := r || E'\nC ok : contre-epreuve, ancienne porte = deux paiements (1200 FR)'; END IF;

  RAISE EXCEPTION 'BANC achats-cle-unicite : % controles, % echec(s)%', n, ko, r;
END $banc$;
ROLLBACK;
