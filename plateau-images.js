// Anciennes URL conservées dans des objets et journaux : même illustration,
// sous son chemin public actuel. Liste fermée, aucune substitution générique.
function imagePubliqueUrl(url) {
  if (typeof url !== 'string') return url;
  // Ces illustrations n'ont jamais été produites (voir l'inventaire des manques).
  // Aucun autre fichier n'est substitué à leur place.
  if (/^images\/(?:arme-(?:machette-narco|deserteagle-narco|ak47-narco|jambiya-khalija|pistolet-khalija|fusil-khalija)|armoire-a-souvenirs)\.png$/.test(url)) return '';
  const prefixe = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/';
  if (!url.startsWith(prefixe)) return url;
  const fichier = url.slice(prefixe.length);
  const convertis = ['arme-fusil-republic', 'arme-mitraillette-militaire',
    'arme-pistolet-militaire', 'calepin-enigme-musee',
    'stade-brise-mariannaise', 'stade-olympique-luthecia'];
  return convertis.some(nom => fichier === nom + '.png')
    ? 'images/' + fichier.slice(0, -4) + '.webp' : url;
}
