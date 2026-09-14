-- REARMEMENT DES FIXTURES DU BANC DES COMMANDES D'ENTREPOT (chantier du 14 septembre 2026).
--
-- banc_entrepots_commandes.py consomme ses fixtures (il achete, vend, remplit des transits).
-- Elles vivent dans deux villes zztest afin que les TROIS ENTREPOTS REELS de Republia ne soient
-- jamais touches : entrepot_du_directeur et fixer_prix_entrepot resolvent le batiment depuis le
-- poste du personnage et la table entrepots_par_ville, on ne peut donc pas leur substituer un
-- batiment arbitraire -- il faut de vraies lignes, mais zztest de bout en bout.
--
-- Les lignes zzville sont inertes pour le jeu : le cron enumere ENTREPOTS_VILLES (code en dur,
-- trois villes reelles) et ne lit jamais cette table.

INSERT INTO public.entrepots_par_ville (ville, building_id) VALUES
  ('zzville-a', 'entrepot-zztest-a'),
  ('zzville-b', 'entrepot-zztest-b')
ON CONFLICT (ville) DO UPDATE SET building_id = EXCLUDED.building_id;

-- A : l'acheteur. Tresorerie confortable, aucun stock.
-- B : le fournisseur. Du stock, pas un franc, et un prix manuel de 4 FR sur les cereales
--     (volontairement different du prix de reference 3 FR, pour prouver que la commande achete
--     au prix AFFICHE par le vendeur et non au prix du catalogue).
INSERT INTO public.batiments_etat (id, country, city, building_id, data) VALUES
  ('republic_zzville-a_entrepot-zztest-a', 'republic', 'zzville-a', 'entrepot-zztest-a',
   to_jsonb('{"entrepot": {"stock": {}, "caisse": 100000, "prixManuel": {}}}'::text)),
  ('republic_zzville-b_entrepot-zztest-b', 'republic', 'zzville-b', 'entrepot-zztest-b',
   to_jsonb('{"entrepot": {"stock": {"cereales": 2000, "viande": 500}, "caisse": 0, "prixManuel": {"cereales": 4}}}'::text))
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;

DELETE FROM public.entrepot_transits WHERE destination_id LIKE 'republic_zzville%';
DELETE FROM public.entrepot_journal  WHERE entrepot_id   LIKE 'republic_zzville%';

SELECT id, public.batiment_etat_lire(data)->'entrepot' AS etat
  FROM public.batiments_etat WHERE id LIKE 'republic_zzville%' ORDER BY id;
