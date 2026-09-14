-- REARMEMENT DE LA FIXTURE DU BANC ENTREPRISES (chantier C).
-- Le banc CONSOMME sa fixture (il vend, produit, achete) : elle doit etre reposee avant chaque
-- passe. Les bancs ne peuvent plus l'armer eux-memes depuis que la table est fermee en ecriture.
--
-- Les PRIX ne sont pas choisis : ils sont calcules par le serveur lui-meme, a la borne basse de
-- sa propre fourchette (cout de revient x 1.10, commerce_fixer_parametres). Aucune valeur
-- inventee, aucune decision de game design dans une fixture de test.
UPDATE public.entreprises SET data = jsonb_build_object(
    'proprietaire',  'zztest-p3-proprio',
    'type',          'cafe',
    'caisse',        2000,
    'stockMatieres', jsonb_build_object('produits_exotiques', 10, 'fruits_legumes', 10, 'cereales', 2),
    'stockProduits', '{}'::jsonb,
    'carte',         jsonb_build_array('cafe_boisson', 'vin'))
 WHERE id = 'zztest-commerce-p3';

WITH d AS (SELECT data FROM public.entreprises WHERE id = 'zztest-commerce-p3')
UPDATE public.entreprises e
   SET data = e.data || jsonb_build_object('parametres', jsonb_build_object(
         'prixVente', jsonb_build_object(
            'cafe_boisson', round(public.commerce_cout_revient_portion((SELECT data FROM d), 'cafe_boisson') * 1.10, 2),
            'vin',          round(public.commerce_cout_revient_portion((SELECT data FROM d), 'vin') * 1.10, 2)),
         'prixAchatMatiere', '{}'::jsonb))
 WHERE e.id = 'zztest-commerce-p3';

SELECT data->>'caisse' AS caisse, data->'stockMatieres' AS stock, data->'parametres' AS parametres
  FROM public.entreprises WHERE id = 'zztest-commerce-p3';
