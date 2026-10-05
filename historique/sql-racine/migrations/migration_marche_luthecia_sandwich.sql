-- Lot 5A (Faire des achats) -- a executer manuellement AVANT le prochain deploiement, sinon
-- l'ancien sandwich reste visible/achetable au marche de Luthecia (rattraperDotationCommerce est
-- purement additif : il ajoute les 5 nouveaux produits manquants, mais ne retire jamais une cle
-- deja presente comme "sandwich"). Cible UNIQUEMENT la ligne du marche de Luthecia
-- (id='marche-republic-capitale-marche', confirme par lecture directe -- carte:["sandwich"],
-- stockProduits.sandwich=6, parametres.stockMax.sandwich=20, parametres.prixVente.sandwich=15).
-- Ne touche ni stockMatieres ni coutMoyenMatieres (viande/cereales/fruits_legumes deja en stock
-- restent necessaires a croque_monsieur_luthecia, memes matieres). Ne supprime PAS la definition
-- generique RECETTES_ALIMENTAIRES.sandwich (conservee, plus reference par aucune dotation apres
-- ce lot). Le marche de Montrouge et celui de Port-Sainte-Marie n'ont encore aucune ligne
-- persistee (confirme par lecture directe, resultat vide) : rien a nettoyer pour eux.
UPDATE entreprises
SET data = (
  (data #- '{stockProduits,sandwich}' #- '{parametres,stockMax,sandwich}' #- '{parametres,prixVente,sandwich}')
  || jsonb_build_object('carte', (
       SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
       FROM jsonb_array_elements(data->'carte') elem
       WHERE elem <> '"sandwich"'
     ))
)
WHERE id = 'marche-republic-capitale-marche';
