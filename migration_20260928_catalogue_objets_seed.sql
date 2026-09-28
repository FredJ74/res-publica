-- =====================================================================
-- L2 — SEED DU REFERENTIEL D'OBJETS
-- =====================================================================
-- Migrations appliquees en base, dans cet ordre, par ce fichier :
--   20260927234943 catalogue_objets_seed_referentiel      (types, familles,
--                                                          generiques)
--   20260927235118 catalogue_objets_seed_correspondances  (generique_type,
--                                                          variantes,
--                                                          correspondances)
-- 2e et 3e des 5 migrations du lot L2. A rejouer apres le socle et avant
-- migration_20260928_catalogue_objets_resolveur.sql, qui rebascule deux
-- motifs 'objet_id' de ce seed vers des motifs derivables.
--
-- Contenu valide avant ecriture. Aucune valeur mecanique inventee :
--   - les 84 generiques naissent avec effets/capacites/durabilite/conditions
--     a NULL (un generique sans effet est un etat legitime) ;
--   - les effets_effectifs des correspondances proviennent EXCLUSIVEMENT de
--     lectures de code etablies par l'audit, chacune citant sa source.
-- Idempotent : on conflict do nothing / do update, rejouable sans doublon.

-- ---------------------------------------------------------------------
-- 14 TYPES DE COMMERCE
-- ---------------------------------------------------------------------
insert into public.catalogue_types (id, libelle, ordre) values
  ('armurerie',                 'Armurerie',                  1),
  ('arts-culture',              'Arts & culture',             2),
  ('bar-restauration',          'Bar & restauration',         3),
  ('bien-etre-mode',            'Bien-être & mode',           4),
  ('bricolage-outillage',       'Bricolage & outillage',      5),
  ('commerce-alimentaire',      'Commerce alimentaire',       6),
  ('commerce-non-alimentaire',  'Commerce non alimentaire',   7),
  ('electronique-informatique', 'Électronique & informatique',8),
  ('garage-automobile',         'Garage automobile',          9),
  ('hotellerie-hebergement',    'Hôtellerie & hébergement',  10),
  ('maison-decoration',         'Maison & décoration',       11),
  ('pharmacie',                 'Pharmacie',                 12),
  ('sport-loisirs',             'Sport & loisirs',           13),
  ('vetements',                 'Vêtements',                 14)
on conflict (id) do update set libelle = excluded.libelle, ordre = excluded.ordre;

-- ---------------------------------------------------------------------
-- 40 FAMILLES  (liste plate ; « collection » absorbee par souvenirs-collections)
-- ---------------------------------------------------------------------
insert into public.catalogue_familles (id, libelle) values
  ('armes','Armes'),
  ('accessoires-armes','Accessoires d''armes'),
  ('protection','Protection'),
  ('edition-papeterie','Édition & papeterie'),
  ('arts','Arts'),
  ('musique-audiovisuel','Musique & audiovisuel'),
  ('spectacles','Spectacles'),
  ('restauration','Restauration'),
  ('boissons','Boissons'),
  ('coiffure-esthetique','Coiffure & esthétique'),
  ('tatouage-piercing','Tatouage & piercing'),
  ('bijoux-accessoires','Bijoux & accessoires'),
  ('outillage','Outillage'),
  ('materiaux-fournitures','Matériaux & fournitures'),
  ('securite-travail','Sécurité & travail'),
  ('produits-frais','Produits frais'),
  ('produits-transformes','Produits transformés'),
  ('fleurs-vegetaux','Fleurs & végétaux'),
  ('animaux','Animaux'),
  ('articles-quotidien','Articles du quotidien'),
  ('souvenirs-collections','Souvenirs & collections'),
  ('communication','Communication'),
  ('informatique','Informatique'),
  ('electronique','Électronique'),
  ('jeux-electroniques','Jeux électroniques'),
  ('vehicules','Véhicules'),
  ('pieces-accessoires','Pièces & accessoires'),
  ('entretien','Entretien'),
  ('hebergement','Hébergement'),
  ('mobilier','Mobilier'),
  ('decoration','Décoration'),
  ('equipement-domestique','Équipement domestique'),
  ('medicaments','Médicaments'),
  ('soins-premiers-secours','Soins & premiers secours'),
  ('produits-sante','Produits de santé'),
  ('sport','Sport'),
  ('plein-air','Plein air'),
  ('jeux-jouets','Jeux & jouets'),
  ('vetements-civils','Vêtements civils'),
  ('vetements-militaires','Vêtements militaires')
on conflict (id) do update set libelle = excluded.libelle;

-- ---------------------------------------------------------------------
-- 84 GENERIQUES
-- ---------------------------------------------------------------------
-- effets / capacites / durabilite / conditions / contraintes : NULL partout.
-- est_service = true pour les 12 prestations veritables (ne peuvent JAMAIS
--   produire un objet d'inventaire).
-- equipable = true uniquement la ou une affectation reelle existe aujourd'hui
--   (militaire_equiper_accessoire -> pnj_possessions).
insert into public.catalogue_generiques
  (id, libelle, famille_id, regime, est_service, empilable, individualise,
   consommable, equipable, encombrement, note) values

-- ARMURERIE
  ('arme-blanche','Arme blanche','armes','reglemente',false,false,true,false,false,null,null),
  ('arme-de-poing','Arme de poing','armes','reglemente',false,false,true,false,false,null,null),
  ('arme-longue','Arme longue','armes','reglemente',false,false,true,false,false,null,null),
  ('accessoire-d-arme','Accessoire d''arme','accessoires-armes','reglemente',false,false,true,false,false,null,'Aucun antecedent.'),
  ('explosif','Explosif','accessoires-armes','reglemente',false,false,true,true,false,null,null),
  ('protection-corporelle','Protection corporelle','protection','reglemente',false,false,true,false,true,null,null),

-- ARTS & CULTURE
  ('livre','Livre','edition-papeterie','libre',false,false,true,false,false,null,'Aucun antecedent : le « Livre publie » historique est une fonction sans appelant.'),
  ('imprime','Imprimé','edition-papeterie','reglemente',false,true,false,true,false,null,null),
  ('affiche','Affiche','edition-papeterie','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('oeuvre-d-art','Œuvre d''art','arts','libre',false,false,true,false,false,null,'Aucun antecedent : la table oeuvres est vide et ses RPC sont sans appelant.'),
  ('instrument-de-musique','Instrument de musique','musique-audiovisuel','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('support-culturel','Support culturel','musique-audiovisuel','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('spectacle','Spectacle','spectacles','libre',true,false,false,false,false,null,'Aucun antecedent.'),

-- BAR & RESTAURATION
  ('encas','Encas','restauration','libre',false,false,false,true,false,null,'Consomme sur place aujourd''hui : c''est le mode de commercialisation actuel, pas une propriete du generique.'),
  ('plat-simple','Plat simple','restauration','libre',false,false,false,true,false,null,null),
  ('plat-elabore','Plat élaboré','restauration','libre',false,false,false,true,false,null,null),
  ('menu-gastronomique','Menu gastronomique','restauration','libre',false,false,false,true,false,null,null),
  ('boisson','Boisson','boissons','libre',false,false,false,true,false,null,'Au comptoir elle ne produit aucun objet ; en epicerie une bouteille en produirait un. Le generique est le meme : la difference releve du mode de commercialisation (L5).'),

-- BIEN-ETRE & MODE
  ('produit-cosmetique','Produit cosmétique','coiffure-esthetique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('coiffure','Coiffure','coiffure-esthetique','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('soin-esthetique','Soin esthétique','coiffure-esthetique','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('tatouage','Tatouage','tatouage-piercing','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('piercing','Piercing','tatouage-piercing','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('bijou','Bijou','bijoux-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-de-mode','Accessoire de mode','bijoux-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),

-- BRICOLAGE & OUTILLAGE
  ('outil-a-main','Outil à main','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('outil-electrique','Outil électrique','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('equipement-professionnel','Équipement professionnel','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('materiau-de-construction','Matériau de construction','materiaux-fournitures','libre',false,true,false,false,false,null,'Aucun antecedent : bois/minerai/metal restent des intrants (GD3).'),
  ('fourniture-de-bricolage','Fourniture de bricolage','materiaux-fournitures','libre',false,true,false,false,false,null,'Aucun antecedent.'),
  ('equipement-de-protection-professionnelle','Équipement de protection professionnelle','securite-travail','libre',false,false,true,false,false,null,'Aucun antecedent.'),

-- COMMERCE ALIMENTAIRE
  ('aliment-brut','Aliment brut','produits-frais','libre',false,true,false,false,false,null,'Raccorde aux 5 matieres alimentaires uniquement pour que la fiche sache repondre. Ce n''est PAS un produit commercial : les ressources restent des intrants (GD3).'),
  ('aliment-prepare','Aliment préparé','produits-transformes','libre',false,false,true,true,false,null,'Aucun antecedent. Regle deja arbitree : minimum 2 matieres premieres, a porter par le gabarit (L6).'),
  ('encas-a-emporter','Encas à emporter','produits-transformes','libre',false,false,true,true,true,null,'A la fois marchandise et consommable : c''est ce que la suppression de la « nature » exclusive permet de representer.'),

-- COMMERCE NON ALIMENTAIRE
  ('vegetal','Végétal','fleurs-vegetaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('animal-de-compagnie','Animal de compagnie','animaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-pour-animal','Accessoire pour animal','animaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('article-du-quotidien','Article du quotidien','articles-quotidien','libre',false,false,true,false,false,null,'Generique de repli : aucun effet, aucune capacite empruntee a un autre generique.'),
  ('souvenir','Souvenir','souvenirs-collections','libre',false,false,true,false,false,null,null),
  ('carte-postale','Carte postale','souvenirs-collections','libre',false,false,true,false,false,null,'Individualisation necessaire a son contenu (etat vierge/ecrite, auteur, message, destinataire initial).'),
  ('article-de-supporter','Article de supporter','souvenirs-collections','libre',false,false,true,false,false,null,null),
  ('objet-de-collection','Objet de collection','souvenirs-collections','libre',false,false,true,false,false,null,'Aucun antecedent. La famille « Collection » de Sport & loisirs est absorbee ici.'),

-- ELECTRONIQUE & INFORMATIQUE
  ('appareil-de-communication','Appareil de communication','communication','reglemente',false,false,true,false,true,null,'La capacite militaire est portee par la VARIANTE, jamais par le generique.'),
  ('ordinateur-complet','Ordinateur complet','informatique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('peripherique-informatique','Périphérique informatique','informatique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('appareil-electronique','Appareil électronique','electronique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('camera-de-surveillance','Caméra de surveillance','electronique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('console-de-jeu','Console de jeu','jeux-electroniques','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('jeu-video','Jeu vidéo','jeux-electroniques','libre',false,false,true,false,false,null,'Aucun antecedent.'),

-- GARAGE AUTOMOBILE
  ('voiture','Voiture','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('deux-roues','Deux-roues','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('vehicule-utilitaire','Véhicule utilitaire','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('piece-automobile','Pièce automobile','pieces-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-automobile','Accessoire automobile','pieces-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('produit-d-entretien-automobile','Produit d''entretien automobile','entretien','libre',false,false,true,true,false,null,'Aucun antecedent.'),
  ('reparation','Réparation','entretien','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('installation-de-piece','Installation de pièce/accessoire','entretien','libre',true,false,false,false,false,null,'Aucun antecedent.'),

-- HOTELLERIE & HEBERGEMENT
  ('hebergement-standard','Hébergement standard','hebergement','libre',true,false,false,false,false,null,'Les trois hotels existants appliquent tous {moral:3, paBonus:2}.'),
  ('hebergement-superieur','Hébergement supérieur','hebergement','libre',true,false,false,false,false,null,'Aucun antecedent : aucun hebergement existant ne se situe entre les hotels et le palais. Non rattache a l''Hotel Republia, dont l''ecart n''existe que dans un affichage incoherent.'),
  ('hebergement-prestige','Hébergement prestige','hebergement','institutionnel',true,false,false,false,false,null,null),

-- MAISON & DECORATION
  ('meuble-de-rangement','Meuble de rangement','mobilier','libre',false,false,true,false,false,3,'Seul generique de mobilier ayant un antecedent. Aucun bonus de mobilier n''est invente.'),
  ('meuble-de-repos','Meuble de repos','mobilier','libre',false,false,true,false,false,null,'Aucun antecedent. Les bonus de sommeil restent portes par les logements/baux.'),
  ('meuble-de-prestige','Meuble de prestige','mobilier','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('objet-decoratif','Objet décoratif','decoration','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('decoration-murale','Décoration murale','decoration','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('equipement-domestique','Équipement domestique','equipement-domestique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('luminaire','Luminaire','equipement-domestique','libre',false,false,true,false,false,null,'Aucun antecedent.'),

-- PHARMACIE
  ('medicament','Médicament','medicaments','reglemente',false,false,true,false,false,null,'Aucun antecedent : la ressource historique `medicaments` est un intrant, pas ce generique (GD3).'),
  ('materiel-de-premiers-secours','Matériel de premiers secours','soins-premiers-secours','reglemente',false,false,true,true,true,null,null),
  ('soin-pharmaceutique','Soin pharmaceutique','soins-premiers-secours','libre',true,false,false,false,false,null,'Aucun antecedent : les soins de dispensaire et de clinique sont des prestations institutionnelles de structures medicales, hors catalogue commercial.'),
  ('produit-de-sante','Produit de santé','produits-sante','libre',false,false,true,false,false,null,'Aucun antecedent : la ressource historique `desinfectant` est un intrant.'),

-- SPORT & LOISIRS
  ('equipement-sportif','Équipement sportif','sport','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('activite-sportive','Activité sportive','sport','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('equipement-de-plein-air','Équipement de plein air','plein-air','reglemente',false,false,true,false,true,null,null),
  ('tente','Tente','plein-air','reglemente',false,false,true,false,true,null,'Agit depuis l''inventaire du porteur : elle n''est installee nulle part aujourd''hui.'),
  ('jeu','Jeu','jeux-jouets','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('jouet','Jouet','jeux-jouets','libre',false,false,true,false,false,null,'Aucun antecedent.'),

-- VETEMENTS
  ('costume-complet','Costume complet','vetements-civils','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('haut','Haut','vetements-civils','libre',false,false,true,false,false,null,'Le +1 ENT d''un tee-shirt historique reste une propriete de CET objet, jamais du generique.'),
  ('bas','Bas','vetements-civils','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('chaussures','Chaussures','vetements-civils','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-vestimentaire','Accessoire vestimentaire','vetements-civils','libre',false,false,true,false,false,null,null),
  ('tenue-militaire','Tenue militaire','vetements-militaires','reglemente',false,false,true,false,true,null,null),
  ('accessoire-militaire','Accessoire militaire','vetements-militaires','reglemente',false,false,true,false,false,null,'Aucun antecedent.')
on conflict (id) do update set
  libelle = excluded.libelle, famille_id = excluded.famille_id,
  regime = excluded.regime, est_service = excluded.est_service,
  empilable = excluded.empilable, individualise = excluded.individualise,
  consommable = excluded.consommable, equipable = excluded.equipable,
  encombrement = excluded.encombrement, note = excluded.note;

-- ---------------------------------------------------------------------
-- GENERIQUE <-> TYPE  (88 liens : 84 generiques, 4 rattaches a 2 types)
-- ---------------------------------------------------------------------
insert into public.catalogue_generique_type (generique_id, type_id) values
  ('arme-blanche','armurerie'),('arme-de-poing','armurerie'),('arme-longue','armurerie'),
  ('accessoire-d-arme','armurerie'),('explosif','armurerie'),
  ('protection-corporelle','armurerie'),('protection-corporelle','sport-loisirs'),
  ('livre','arts-culture'),('imprime','arts-culture'),('affiche','arts-culture'),
  ('oeuvre-d-art','arts-culture'),('instrument-de-musique','arts-culture'),
  ('support-culturel','arts-culture'),('spectacle','arts-culture'),
  ('encas','bar-restauration'),('plat-simple','bar-restauration'),
  ('plat-elabore','bar-restauration'),('menu-gastronomique','bar-restauration'),
  ('boisson','bar-restauration'),('boisson','commerce-alimentaire'),
  ('produit-cosmetique','bien-etre-mode'),('coiffure','bien-etre-mode'),
  ('soin-esthetique','bien-etre-mode'),('tatouage','bien-etre-mode'),
  ('piercing','bien-etre-mode'),('bijou','bien-etre-mode'),('accessoire-de-mode','bien-etre-mode'),
  ('outil-a-main','bricolage-outillage'),('outil-electrique','bricolage-outillage'),
  ('equipement-professionnel','bricolage-outillage'),('materiau-de-construction','bricolage-outillage'),
  ('fourniture-de-bricolage','bricolage-outillage'),('equipement-de-protection-professionnelle','bricolage-outillage'),
  ('aliment-brut','commerce-alimentaire'),('aliment-prepare','commerce-alimentaire'),
  ('encas-a-emporter','commerce-alimentaire'),('encas-a-emporter','bar-restauration'),
  ('vegetal','commerce-non-alimentaire'),('animal-de-compagnie','commerce-non-alimentaire'),
  ('accessoire-pour-animal','commerce-non-alimentaire'),('article-du-quotidien','commerce-non-alimentaire'),
  ('souvenir','commerce-non-alimentaire'),('carte-postale','commerce-non-alimentaire'),
  ('article-de-supporter','commerce-non-alimentaire'),('article-de-supporter','sport-loisirs'),
  ('objet-de-collection','commerce-non-alimentaire'),
  ('appareil-de-communication','electronique-informatique'),('ordinateur-complet','electronique-informatique'),
  ('peripherique-informatique','electronique-informatique'),('appareil-electronique','electronique-informatique'),
  ('camera-de-surveillance','electronique-informatique'),('console-de-jeu','electronique-informatique'),
  ('jeu-video','electronique-informatique'),
  ('voiture','garage-automobile'),('deux-roues','garage-automobile'),
  ('vehicule-utilitaire','garage-automobile'),('piece-automobile','garage-automobile'),
  ('accessoire-automobile','garage-automobile'),('produit-d-entretien-automobile','garage-automobile'),
  ('reparation','garage-automobile'),('installation-de-piece','garage-automobile'),
  ('hebergement-standard','hotellerie-hebergement'),('hebergement-superieur','hotellerie-hebergement'),
  ('hebergement-prestige','hotellerie-hebergement'),
  ('meuble-de-rangement','maison-decoration'),('meuble-de-repos','maison-decoration'),
  ('meuble-de-prestige','maison-decoration'),('objet-decoratif','maison-decoration'),
  ('decoration-murale','maison-decoration'),('equipement-domestique','maison-decoration'),
  ('luminaire','maison-decoration'),
  ('medicament','pharmacie'),('materiel-de-premiers-secours','pharmacie'),
  ('soin-pharmaceutique','pharmacie'),('produit-de-sante','pharmacie'),
  ('equipement-sportif','sport-loisirs'),('activite-sportive','sport-loisirs'),
  ('equipement-de-plein-air','sport-loisirs'),('tente','sport-loisirs'),
  ('jeu','sport-loisirs'),('jouet','sport-loisirs'),
  ('costume-complet','vetements'),('haut','vetements'),('bas','vetements'),
  ('chaussures','vetements'),('accessoire-vestimentaire','vetements'),
  ('tenue-militaire','vetements'),('accessoire-militaire','vetements')
on conflict (generique_id, type_id) do nothing;

-- ---------------------------------------------------------------------
-- 6 VARIANTES MILITAIRES  (aucune variante civile)
-- ---------------------------------------------------------------------
insert into public.catalogue_variantes (id, generique_id, cle, libelle, regime, capacites, note) values
  ('appareil-de-communication--militaire','appareil-de-communication','militaire','Radio de campagne','reglemente',
   '["transmettre_ordre_collectif_a_distance"]'::jsonb,
   'Exigee des DEUX cotes de la chaine de commandement (militaire_ordre_collectif, refus radio_manquante).'),
  ('tente--militaire','tente','militaire','Tente de campagne','reglemente',
   '["abriter_bivouac","reposer_section"]'::jsonb,
   'Abrite 13 personnes, leader compris. Non consommee, aucune usure.'),
  ('equipement-de-plein-air--militaire','equipement-de-plein-air','militaire','Jumelles','reglemente',
   '["observer_secteur"]'::jsonb,
   'Ordre « Observer » a 1 PA via militaire_observer. Le chemin passif d''entree de zone est actuellement casse (anomalie documentee, non corrigee ici).'),
  ('materiel-de-premiers-secours--militaire','materiel-de-premiers-secours','militaire','Trousse de premiers secours','reglemente',
   '["soigner_co_present"]'::jsonb,
   'Usage unique. Co-presence stricte exigee si la cible n''est pas soi.'),
  ('protection-corporelle--militaire','protection-corporelle','militaire','Gilet pare-balles réglementaire','reglemente',
   '["absorber_tir_en_bataille"]'::jsonb,
   'Une seule chance, definitive : un gilet fragilise reste inerte, aucun code ne le repare.'),
  ('encas-a-emporter--militaire','encas-a-emporter','militaire','Ration de combat','reglemente',
   '["nourrir_soldat_pnj"]'::jsonb,
   'Consommable par le PJ ou distribuable a des soldats PNJ menes.')
on conflict (id) do update set
  libelle = excluded.libelle, regime = excluded.regime,
  capacites = excluded.capacites, note = excluded.note;

-- ---------------------------------------------------------------------
-- 58 CORRESPONDANCES LEGACY
-- ---------------------------------------------------------------------
-- effets_effectifs = UNIQUEMENT ce que le moteur applique reellement.
-- NULL = aucun effet effectif -> la fiche affichera « Aucun effet ».
insert into public.catalogue_correspondance_legacy
  (motif, valeur, generique_id, variante_id, priorite, effets_effectifs, source_audit, note) values

-- ---- ARMURERIE (10)
  ('type_soustype','arme|blanche','arme-blanche',null,100,null,
   'plateau-actions-illegales-rumeurs.js:1478 (affichage seul) ; getStatEffective ne lit jamais item.bonus',
   'bonus {VOL,5} declare, affiche, JAMAIS applique : absent des effets effectifs.'),
  ('type_soustype','arme|poing','arme-de-poing',null,100,null,
   'plateau-actions-illegales-rumeurs.js:1478 ; getStatEffective',
   'bonus {PER,8} declare, jamais applique.'),
  ('type_soustype','arme|carabine','arme-longue',null,100,null,
   'plateau-actions-illegales-rumeurs.js:1478 ; getStatEffective',
   'bonus {PER,15} declare, jamais applique.'),
  ('produit_militaire','arme_de_poing','arme-de-poing',null,200,
   '{"bonus_combat_feu": 8}'::jsonb,
   'table militaire_armes_bonus, lue par militaire_bataille_combattants', null),
  ('produit_militaire','mitraillette','arme-longue',null,200,
   '{"bonus_combat_feu": 15}'::jsonb,
   'table militaire_armes_bonus, lue par militaire_bataille_combattants', null),
  ('type_produit_militaire','explosif|explosif_militaire','explosif',null,300,
   '{"ferme_batiment_jours": 5, "blesse_presents": true}'::jsonb,
   'confirmerUtiliserExplosifs, plateau-actions-illegales-rumeurs.js:2248-2330',
   'Exemplaire retire legalement.'),
  ('type_produit_militaire','arme|explosif_militaire','explosif',null,300,null,
   'doUtiliserExplosifs cherche type===''explosif'' (plateau-actions-illegales-rumeurs.js:2226) ; inventaire_consommer refuse objet_non_consommable',
   'ANOMALIE : exemplaire SUBTILISE, type ''arme''. Introuvable par le handler et refuse par la RPC. Objet inerte. Documente, non corrige.'),
  ('type','explosif','explosif',null,100,
   '{"ferme_batiment_jours": 5, "blesse_presents": true}'::jsonb,
   'confirmerUtiliserExplosifs', 'Explosif de chantier (marche noir).'),
  ('type','protection','protection-corporelle',null,100,null,
   'militaire_gilet_absorber cherche produitMilitaire=''gilet_pare_balles'', absent de cet objet',
   'Gilet civil a 600 FR : effet annonce, jamais cable. Documente, non corrige.'),
  ('produit_militaire','gilet_pare_balles','protection-corporelle','protection-corporelle--militaire',200,
   '{"absorption_tir_probabilite": 0.5, "une_seule_fois": true, "garantit_pa_minimum": 1, "condition": "bataille, mode feu uniquement"}'::jsonb,
   'militaire_gilet_absorber, appelee par militaire_bataille_appliquer', null),

-- ---- ARTS & CULTURE (4)
  ('type_tracttype','tract|pour','imprime',null,200,
   '{"voix_pnj": 1}'::jsonb,
   'tracts_electoraux_distribuer_interne', null),
  ('type_tracttype','tract|contre','imprime',null,200,
   '{"voix_pnj": -1, "plancher": 0}'::jsonb,
   'tracts_electoraux_distribuer_interne', null),
  ('type','tract_calomnieux','imprime',null,100,
   '{"pop_cible": -5, "inf_cible": -2}'::jsonb,
   'calomnie_distribuer, verrou PNJ x cible x jour (calomnies_actes_verrou)', null),
  ('objet_id','tract|origineQuete=jean_lou','imprime',null,300,
   '{"voix_pnj": 1}'::jsonb,
   'plateau-pnj.js:621-624 (enregistrerVotePNJ)',
   'Objet de QUETE : hors catalogue commercial. Mappe pour que la fiche sache repondre.'),

-- ---- RESTAURATION (19)
  ('recette_id','snack_buvette','encas',null,100,'{"hp": 2, "moral": 1}'::jsonb,
   'recettes_commerce.effets ; applique par plateau-actions-illegales-rumeurs.js:4779-4781', null),
  ('recette_id','petit_dejeuner','encas',null,100,'{"hp": 3, "moral": 1}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','sandwich_cheminots','plat-simple',null,100,'{"hp": 5, "moral": 1}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','boeuf_bourguignon','plat-elabore',null,100,'{"hp": 8, "moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','saucisse_puree','plat-elabore',null,100,'{"hp": 8, "moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','plat_de_poisson','plat-elabore',null,100,'{"hp": 8, "moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','carbonade_frites','plat-elabore',null,100,'{"hp": 8, "moral": 3}'::jsonb,
   'recettes_commerce.effets', 'Seul plat elabore a +3 Moral : specialite verrouillee sur ville_b.'),
  ('recette_id','menu_gastronomique_1','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,
   'recettes_commerce.effets ; PA differe atteste serveur par pa_bonus_differes', null),
  ('recette_id','menu_gastronomique_2','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes', null),
  ('recette_id','menu_gastronomique_3','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes', null),
  ('recette_id','menu_psm_1','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes', null),
  ('recette_id','menu_psm_2','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes', null),
  ('recette_id','menu_psm_3','menu-gastronomique',null,100,
   '{"hp": 10, "moral": 1, "pa_differe": 3}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes', null),
  ('recette_id','biere_pression','boisson',null,100,'{"moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','vin','boisson',null,100,'{"moral": 2}'::jsonb,
   'recettes_commerce.effets', 'Seule boisson exigee nommement par le diner d''affaires.'),
  ('recette_id','cafe_boisson','boisson',null,100,'{"moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','jus_de_fruits','boisson',null,100,'{"moral": 2}'::jsonb,
   'recettes_commerce.effets', null),
  ('recette_id','boisson_sans_alcool','boisson',null,100,'{"moral": 1}'::jsonb,
   'recettes_commerce.effets',
   'ANOMALIE : seule recette a materiaux vides. Ne fait pas jurisprudence pour le generique.'),
  ('recette_id','sandwich','plat-simple',null,100,
   '{"hp": 5, "moral": 1, "pa_differe": 1}'::jsonb,'recettes_commerce.effets ; pa_bonus_differes',
   'ANOMALIE : retire de toutes les cartes, non produisible. Recette conservee dans les deux registres.'),

-- ---- COMMERCE ALIMENTAIRE / NON ALIMENTAIRE (11)
  ('famille_produit_marche','aliment','encas-a-emporter',null,100,
   '{"pa_si_frais": 1, "pa_si_perime": -1, "fraicheur_jours_reels": 7}'::jsonb,
   'inventaire_consommer (RPC) ; DUREE_FRAICHEUR_ALIMENT_MS, plateau-personnage.js:3253',
   'Aucun hp ni moral : ces produits n''ont aucune valeur nutritive codee.'),
  ('famille_produit_marche','carte_postale','carte-postale',null,100,
   '{"moral_lecteur": 10, "moral_expediteur": 10, "plafond_quotidien_lecteur": 1, "plafond_quotidien_expediteur": 1}'::jsonb,
   'plateau-personnage.js:3583-3592 (lecteur) ; plateau-communication.js:1688-1697 (expediteur, file impacts_indices_attente) ; colonne persistee carte_postale_moral_jour',
   'Deux plafonds quotidiens distincts sur la meme colonne persistee.'),
  ('recette_id','porte_cle_palais_luthecia','souvenir',null,100,null,
   'recettes_commerce.bonus_integration_ville = null',
   'Classe integration_locale SANS bonus : distinction mecanique avec les 3 textiles.'),
  ('recette_id','garde_republien_plomb','souvenir',null,100,null,
   'recettes_commerce.bonus_integration_ville = null', null),
  ('recette_id','figurine_maxence_monfils','souvenir',null,100,null,
   'recettes_commerce.bonus_integration_ville = null', null),
  ('type','accessoire_sport','article-de-supporter',null,100,null,
   'plateau-organisations-quetes.js:9026 ; aucun lecteur du type accessoire_sport',
   'Aucune recette, aucun stock, aucun effet. Fonctionnement preserve tel quel.'),
  ('stack_key','cereales','aliment-brut',null,100,null,'ressources_economie','Intrant (GD3).'),
  ('stack_key','viande','aliment-brut',null,100,null,'ressources_economie','Intrant (GD3).'),
  ('stack_key','poisson','aliment-brut',null,100,null,'ressources_economie','Intrant (GD3).'),
  ('stack_key','fruits_legumes','aliment-brut',null,100,null,'ressources_economie','Intrant (GD3).'),
  ('stack_key','produits_exotiques','aliment-brut',null,100,null,'ressources_economie','Intrant (GD3).'),

-- ---- VETEMENTS (4)
  ('recette_id','tshirt_psm','haut',null,100,
   '{"ent": 1, "condition": "presence_ville_a", "non_cumulable": true}'::jsonb,
   'bonusEntIntegrationLocale, plateau-organisations-quetes.js:3341-3345 ; lu par getStatEffective',
   'SEUL bonus reellement calcule depuis l''inventaire. Reste une propriete de CET objet, pas du generique Haut.'),
  ('recette_id','casquette_montrouge','accessoire-vestimentaire',null,100,
   '{"ent": 1, "condition": "presence_ville_b", "non_cumulable": true}'::jsonb,
   'bonusEntIntegrationLocale ; getStatEffective', null),
  ('recette_id','echarpe_luthecia','accessoire-vestimentaire',null,100,
   '{"ent": 1, "condition": "presence_capitale", "non_cumulable": true}'::jsonb,
   'bonusEntIntegrationLocale ; getStatEffective', null),
  ('produit_militaire','tenue_camouflage','tenue-militaire',null,200,
   '{"camouflage_groupe": 20, "condition": "porte par un soldat PNJ via pnj_possessions (origine blob_accessoires) ; AUCUN effet sur un PJ"}'::jsonb,
   'militaire_camouflage_groupe, lue par militaire_observer',
   'La description annoncee (« protege celui qui la porte ») est fausse pour un PJ. Documente, non corrige.'),

-- ---- MILITAIRE / HEBERGEMENT / MOBILIER (10)
  ('produit_militaire','radio','appareil-de-communication','appareil-de-communication--militaire',200,
   null,'militaire_ordre_collectif (refus radio_manquante)',
   'Aucun delta : la capacite est portee par la variante.'),
  ('produit_militaire','tente','tente','tente--militaire',200,
   '{"pa_bivouac_par_soldat": 1, "pa_repos_section": 10, "pa_repos_nocturne_pj": 10, "capacite_personnes": 13, "consommee": false, "usure": null}'::jsonb,
   'militaire_ordre_collectif (bivouac) ; militaire_reposer_section ; pa_repos_nocturne ; plateau-multijoueur.js:2591', null),
  ('produit_militaire','jumelles','equipement-de-plein-air','equipement-de-plein-air--militaire',200,
   '{"bonus_detection": 30}'::jsonb,
   'militaire_observer -> militaire_chance_detection', null),
  ('produit_militaire','trousse_secours','materiel-de-premiers-secours','materiel-de-premiers-secours--militaire',200,
   '{"pa_formule": "2 + floor(min(100, secourisme)/25)", "pa_min": 2, "pa_max": 6, "plafond_pa": 30, "usage_unique": true, "condition": "co-presence exigee si la cible n''est pas soi"}'::jsonb,
   'militaire_trousse_utiliser',
   'competences_militaires est vide pour tous les personnages : le gain reel est aujourd''hui toujours +2.'),
  ('produit_militaire','ration_combat','encas-a-emporter','encas-a-emporter--militaire',200,
   '{"pa": 1, "max_par_jour": 2, "plafond_pa": 30, "usage_unique": true}'::jsonb,
   'militaire_ration_consommer ; militaire_ordre_collectif (action ration)',
   'Objet detruit dans la meme transaction que le gain. Refus non destructifs : pa_maximum, maximum_quotidien.'),
  ('ordre','hebergement|hotel-mineur','hebergement-standard',null,100,
   '{"pa_lendemain": 2, "moral": 3}'::jsonb,
   'pa_bonus_hotel (serveur) ; confortMap plateau-personnage.js:2943-2948', null),
  ('ordre','hebergement|hotel-port','hebergement-standard',null,100,
   '{"pa_lendemain": 2, "moral": 3}'::jsonb,
   'pa_bonus_hotel ; confortMap plateau-personnage.js:2943-2948', null),
  ('ordre','hebergement|hotel-republica','hebergement-standard',null,100,
   '{"pa_lendemain": 2, "moral": 3}'::jsonb,
   'pa_bonus_hotel = 2 ; confortMap plateau-personnage.js:2943-2948 applique {moral:3, paBonus:2}',
   'ANOMALIE A TRAITER SEPAREMENT : plateau-personnage.js:437 ANNONCE {moral:5, paBonus:5}. Trois sources divergentes. Seule la valeur APPLIQUEE est retenue ici.'),
  ('ordre','hebergement|palais-presidentiel','hebergement-prestige',null,100,
   '{"pa_lendemain": 8, "moral": 8}'::jsonb,
   'pa_bonus_hotel = 8 ; confortMap plateau-personnage.js:2947', null),
  ('objet_id','armoire_souvenirs','meuble-de-rangement',null,100,null,
   'creerExemplaireArmoireSouvenirs, plateau-justice-economie.js:5512-5528 ; seuls lecteurs : plateau-personnage.js:3338 et :3373 (affichage)',
   'Aucun effet mecanique hormis encombrement 3. contenu et verrouillee ne sont ni lus ni ecrits. AUCUN bonus de sommeil. Actuellement IMPOSSIBLE A OBTENIR : la ligne batiments_etat[republic_ville_a_zone-production] n''existe pas.')
on conflict (motif, valeur) do update set
  generique_id = excluded.generique_id, variante_id = excluded.variante_id,
  priorite = excluded.priorite, effets_effectifs = excluded.effets_effectifs,
  source_audit = excluded.source_audit, note = excluded.note;
