
// =====================
// ACTIONS TRACABLES (pour le systeme de rumeurs vraies)
// =====================
async function sbTracerAction(action) {
  return sbInsert('actions_tracables', action);
}

async function sbGetActionsTracables(country, city, jourActuel) {
  const filtre = `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&jour_expiration=gte.${jourActuel}`;
  return sbGet('actions_tracables', filtre) || [];
}
