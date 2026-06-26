
// =====================
// OBJETS ABANDONNES DANS UNE PIECE (visibles/ramassables par d'autres joueurs)
// =====================
async function sbAbandonnerObjet(objet, country, city, buildingId, roomId) {
  const data = { id: objet.id, country, city, building_id: buildingId, room_id: roomId, data: JSON.stringify(objet) };
  return sbInsert('objets_abandonnes', data);
}

async function sbGetObjetsAbandonnesDansPiece(country, city, buildingId, roomId) {
  const filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&building_id=eq.${encodeURIComponent(buildingId)}&room_id=eq.${encodeURIComponent(roomId)}`;
  const rows = await sbGet('objets_abandonnes', filtre);
  if (!rows) return [];
  return rows.map(r => { try { return JSON.parse(r.data); } catch(e) { return null; } }).filter(Boolean);
}

async function sbRamasserObjetAbandonne(objetId) {
  return sbDelete('objets_abandonnes', `id=eq.${encodeURIComponent(objetId)}`);
}
