-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927234943
-- Nom original      : catalogue_objets_seed_referentiel
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 23:49:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3513ebe2a2672f5e2bbb359c1ad2af01
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
insert into public.catalogue_types (id, libelle, ordre) values
  ('armurerie','Armurerie',1),
  ('arts-culture','Arts & culture',2),
  ('bar-restauration','Bar & restauration',3),
  ('bien-etre-mode','Bien-être & mode',4),
  ('bricolage-outillage','Bricolage & outillage',5),
  ('commerce-alimentaire','Commerce alimentaire',6),
  ('commerce-non-alimentaire','Commerce non alimentaire',7),
  ('electronique-informatique','Électronique & informatique',8),
  ('garage-automobile','Garage automobile',9),
  ('hotellerie-hebergement','Hôtellerie & hébergement',10),
  ('maison-decoration','Maison & décoration',11),
  ('pharmacie','Pharmacie',12),
  ('sport-loisirs','Sport & loisirs',13),
  ('vetements','Vêtements',14)
on conflict (id) do update set libelle = excluded.libelle, ordre = excluded.ordre;

insert into public.catalogue_familles (id, libelle) values
  ('armes','Armes'),('accessoires-armes','Accessoires d''armes'),('protection','Protection'),
  ('edition-papeterie','Édition & papeterie'),('arts','Arts'),
  ('musique-audiovisuel','Musique & audiovisuel'),('spectacles','Spectacles'),
  ('restauration','Restauration'),('boissons','Boissons'),
  ('coiffure-esthetique','Coiffure & esthétique'),('tatouage-piercing','Tatouage & piercing'),
  ('bijoux-accessoires','Bijoux & accessoires'),
  ('outillage','Outillage'),('materiaux-fournitures','Matériaux & fournitures'),
  ('securite-travail','Sécurité & travail'),
  ('produits-frais','Produits frais'),('produits-transformes','Produits transformés'),
  ('fleurs-vegetaux','Fleurs & végétaux'),('animaux','Animaux'),
  ('articles-quotidien','Articles du quotidien'),('souvenirs-collections','Souvenirs & collections'),
  ('communication','Communication'),('informatique','Informatique'),
  ('electronique','Électronique'),('jeux-electroniques','Jeux électroniques'),
  ('vehicules','Véhicules'),('pieces-accessoires','Pièces & accessoires'),('entretien','Entretien'),
  ('hebergement','Hébergement'),
  ('mobilier','Mobilier'),('decoration','Décoration'),('equipement-domestique','Équipement domestique'),
  ('medicaments','Médicaments'),('soins-premiers-secours','Soins & premiers secours'),
  ('produits-sante','Produits de santé'),
  ('sport','Sport'),('plein-air','Plein air'),('jeux-jouets','Jeux & jouets'),
  ('vetements-civils','Vêtements civils'),('vetements-militaires','Vêtements militaires')
on conflict (id) do update set libelle = excluded.libelle;

insert into public.catalogue_generiques
  (id, libelle, famille_id, regime, est_service, empilable, individualise,
   consommable, equipable, encombrement, note) values
  ('arme-blanche','Arme blanche','armes','reglemente',false,false,true,false,false,null,null),
  ('arme-de-poing','Arme de poing','armes','reglemente',false,false,true,false,false,null,null),
  ('arme-longue','Arme longue','armes','reglemente',false,false,true,false,false,null,null),
  ('accessoire-d-arme','Accessoire d''arme','accessoires-armes','reglemente',false,false,true,false,false,null,'Aucun antecedent.'),
  ('explosif','Explosif','accessoires-armes','reglemente',false,false,true,true,false,null,null),
  ('protection-corporelle','Protection corporelle','protection','reglemente',false,false,true,false,true,null,null),
  ('livre','Livre','edition-papeterie','libre',false,false,true,false,false,null,'Aucun antecedent : le « Livre publie » historique est une fonction sans appelant.'),
  ('imprime','Imprimé','edition-papeterie','reglemente',false,true,false,true,false,null,null),
  ('affiche','Affiche','edition-papeterie','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('oeuvre-d-art','Œuvre d''art','arts','libre',false,false,true,false,false,null,'Aucun antecedent : la table oeuvres est vide et ses RPC sont sans appelant.'),
  ('instrument-de-musique','Instrument de musique','musique-audiovisuel','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('support-culturel','Support culturel','musique-audiovisuel','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('spectacle','Spectacle','spectacles','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('encas','Encas','restauration','libre',false,false,false,true,false,null,'Consomme sur place aujourd''hui : c''est le mode de commercialisation actuel, pas une propriete du generique.'),
  ('plat-simple','Plat simple','restauration','libre',false,false,false,true,false,null,null),
  ('plat-elabore','Plat élaboré','restauration','libre',false,false,false,true,false,null,null),
  ('menu-gastronomique','Menu gastronomique','restauration','libre',false,false,false,true,false,null,null),
  ('boisson','Boisson','boissons','libre',false,false,false,true,false,null,'Au comptoir elle ne produit aucun objet ; en epicerie une bouteille en produirait un. Le generique est le meme : la difference releve du mode de commercialisation (L5).'),
  ('produit-cosmetique','Produit cosmétique','coiffure-esthetique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('coiffure','Coiffure','coiffure-esthetique','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('soin-esthetique','Soin esthétique','coiffure-esthetique','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('tatouage','Tatouage','tatouage-piercing','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('piercing','Piercing','tatouage-piercing','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('bijou','Bijou','bijoux-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-de-mode','Accessoire de mode','bijoux-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('outil-a-main','Outil à main','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('outil-electrique','Outil électrique','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('equipement-professionnel','Équipement professionnel','outillage','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('materiau-de-construction','Matériau de construction','materiaux-fournitures','libre',false,true,false,false,false,null,'Aucun antecedent : bois/minerai/metal restent des intrants (GD3).'),
  ('fourniture-de-bricolage','Fourniture de bricolage','materiaux-fournitures','libre',false,true,false,false,false,null,'Aucun antecedent.'),
  ('equipement-de-protection-professionnelle','Équipement de protection professionnelle','securite-travail','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('aliment-brut','Aliment brut','produits-frais','libre',false,true,false,false,false,null,'Raccorde aux 5 matieres alimentaires uniquement pour que la fiche sache repondre. Ce n''est PAS un produit commercial : les ressources restent des intrants (GD3).'),
  ('aliment-prepare','Aliment préparé','produits-transformes','libre',false,false,true,true,false,null,'Aucun antecedent. Regle deja arbitree : minimum 2 matieres premieres, a porter par le gabarit (L6).'),
  ('encas-a-emporter','Encas à emporter','produits-transformes','libre',false,false,true,true,true,null,'A la fois marchandise et consommable : c''est ce que la suppression de la « nature » exclusive permet de representer.'),
  ('vegetal','Végétal','fleurs-vegetaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('animal-de-compagnie','Animal de compagnie','animaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-pour-animal','Accessoire pour animal','animaux','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('article-du-quotidien','Article du quotidien','articles-quotidien','libre',false,false,true,false,false,null,'Generique de repli : aucun effet, aucune capacite empruntee a un autre generique.'),
  ('souvenir','Souvenir','souvenirs-collections','libre',false,false,true,false,false,null,null),
  ('carte-postale','Carte postale','souvenirs-collections','libre',false,false,true,false,false,null,'Individualisation necessaire a son contenu (etat vierge/ecrite, auteur, message, destinataire initial).'),
  ('article-de-supporter','Article de supporter','souvenirs-collections','libre',false,false,true,false,false,null,null),
  ('objet-de-collection','Objet de collection','souvenirs-collections','libre',false,false,true,false,false,null,'Aucun antecedent. La famille « Collection » de Sport & loisirs est absorbee ici.'),
  ('appareil-de-communication','Appareil de communication','communication','reglemente',false,false,true,false,true,null,'La capacite militaire est portee par la VARIANTE, jamais par le generique.'),
  ('ordinateur-complet','Ordinateur complet','informatique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('peripherique-informatique','Périphérique informatique','informatique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('appareil-electronique','Appareil électronique','electronique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('camera-de-surveillance','Caméra de surveillance','electronique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('console-de-jeu','Console de jeu','jeux-electroniques','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('jeu-video','Jeu vidéo','jeux-electroniques','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('voiture','Voiture','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('deux-roues','Deux-roues','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('vehicule-utilitaire','Véhicule utilitaire','vehicules','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('piece-automobile','Pièce automobile','pieces-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('accessoire-automobile','Accessoire automobile','pieces-accessoires','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('produit-d-entretien-automobile','Produit d''entretien automobile','entretien','libre',false,false,true,true,false,null,'Aucun antecedent.'),
  ('reparation','Réparation','entretien','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('installation-de-piece','Installation de pièce/accessoire','entretien','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('hebergement-standard','Hébergement standard','hebergement','libre',true,false,false,false,false,null,'Les trois hotels existants appliquent tous {moral:3, paBonus:2}.'),
  ('hebergement-superieur','Hébergement supérieur','hebergement','libre',true,false,false,false,false,null,'Aucun antecedent : aucun hebergement existant ne se situe entre les hotels et le palais. Non rattache a l''Hotel Republia, dont l''ecart n''existe que dans un affichage incoherent.'),
  ('hebergement-prestige','Hébergement prestige','hebergement','institutionnel',true,false,false,false,false,null,null),
  ('meuble-de-rangement','Meuble de rangement','mobilier','libre',false,false,true,false,false,3,'Seul generique de mobilier ayant un antecedent. Aucun bonus de mobilier n''est invente.'),
  ('meuble-de-repos','Meuble de repos','mobilier','libre',false,false,true,false,false,null,'Aucun antecedent. Les bonus de sommeil restent portes par les logements/baux.'),
  ('meuble-de-prestige','Meuble de prestige','mobilier','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('objet-decoratif','Objet décoratif','decoration','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('decoration-murale','Décoration murale','decoration','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('equipement-domestique','Équipement domestique','equipement-domestique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('luminaire','Luminaire','equipement-domestique','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('medicament','Médicament','medicaments','reglemente',false,false,true,false,false,null,'Aucun antecedent : la ressource historique `medicaments` est un intrant, pas ce generique (GD3).'),
  ('materiel-de-premiers-secours','Matériel de premiers secours','soins-premiers-secours','reglemente',false,false,true,true,true,null,null),
  ('soin-pharmaceutique','Soin pharmaceutique','soins-premiers-secours','libre',true,false,false,false,false,null,'Aucun antecedent : les soins de dispensaire et de clinique sont des prestations institutionnelles de structures medicales, hors catalogue commercial.'),
  ('produit-de-sante','Produit de santé','produits-sante','libre',false,false,true,false,false,null,'Aucun antecedent : la ressource historique `desinfectant` est un intrant.'),
  ('equipement-sportif','Équipement sportif','sport','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('activite-sportive','Activité sportive','sport','libre',true,false,false,false,false,null,'Aucun antecedent.'),
  ('equipement-de-plein-air','Équipement de plein air','plein-air','reglemente',false,false,true,false,true,null,null),
  ('tente','Tente','plein-air','reglemente',false,false,true,false,true,null,'Agit depuis l''inventaire du porteur : elle n''est installee nulle part aujourd''hui.'),
  ('jeu','Jeu','jeux-jouets','libre',false,false,true,false,false,null,'Aucun antecedent.'),
  ('jouet','Jouet','jeux-jouets','libre',false,false,true,false,false,null,'Aucun antecedent.'),
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