#!/usr/bin/env python3
"""
Correctif quete d'accueil :
1. creation.js : initialise explicitement queteAccueil a la creation d'un nouveau personnage
2. plateau-quete-accueil.js : ne se declenche que si l'etape vaut precisement 'non_commencee'
3. plateau-navigation.js : protege les ecritures localStorage contre le QuotaExceededError
A executer a la racine du repo res-publica.
"""

# --- 1. creation.js ---
PATH_CREATION = "creation.js"
with open(PATH_CREATION, "r", encoding="utf-8") as f:
    creation = f.read()

old_char = """    name:G.name, bio:G.bio, motto:G.motto,
    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString()
  };"""
new_char = """    name:G.name, bio:G.bio, motto:G.motto,
    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString(),
    queteAccueil:{ etape:'non_commencee' }
  };"""
assert creation.count(old_char) == 1, f"creation.js : trouvé {creation.count(old_char)} fois (attendu 1)"
creation = creation.replace(old_char, new_char)

with open(PATH_CREATION, "w", encoding="utf-8") as f:
    f.write(creation)

# --- 2. plateau-quete-accueil.js ---
PATH_QA = "plateau-quete-accueil.js"
with open(PATH_QA, "r", encoding="utf-8") as f:
    qa = f.read()

old_check = """function queteAccueilDoitDemarrer(pays, noeudId) {
  if (pays !== 'republic') return false;
  if (noeudId !== 'luthecia-palais-presidentiel') return false;
  if (typeof state === 'undefined' || !state.char) return false;
  if (state.char.queteAccueil && state.char.queteAccueil.etape) return false; // deja commencee, terminee ou refusee
  return true;
}"""
new_check = """function queteAccueilDoitDemarrer(pays, noeudId) {
  if (pays !== 'republic') return false;
  if (noeudId !== 'luthecia-palais-presidentiel') return false;
  if (typeof state === 'undefined' || !state.char) return false;
  if (!state.char.queteAccueil || state.char.queteAccueil.etape !== 'non_commencee') return false;
  return true;
}"""
assert qa.count(old_check) == 1, f"plateau-quete-accueil.js : trouvé {qa.count(old_check)} fois (attendu 1)"
qa = qa.replace(old_check, new_check)

with open(PATH_QA, "w", encoding="utf-8") as f:
    f.write(qa)

# --- 3. plateau-navigation.js ---
PATH_NAV = "plateau-navigation.js"
with open(PATH_NAV, "r", encoding="utf-8") as f:
    nav = f.read()

old_storage = """  if (state.char) {
    state.char.currentBuilding = buildingId;
    state.char.currentRoom = roomId;
    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    // Pousser aussi vers Supabase pour que la position survive a un rafraichissement avant la prochaine sauvegarde periodique
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }"""
new_storage = """  if (state.char) {
    state.char.currentBuilding = buildingId;
    state.char.currentRoom = roomId;
    try {
      localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }"""
assert nav.count(old_storage) == 1, f"plateau-navigation.js : trouvé {nav.count(old_storage)} fois (attendu 1)"
nav = nav.replace(old_storage, new_storage)

with open(PATH_NAV, "w", encoding="utf-8") as f:
    f.write(nav)

print("✅ Correctif appliqué : creation.js, plateau-quete-accueil.js et plateau-navigation.js mis a jour.")
