/// Canonical ingredient alias table.
///
/// Each key is the canonical (preferred) group name. The corresponding value
/// is a list of known synonyms. Keys and values should use already-normalized
/// forms (lowercase, singular, no preparation adjectives) so they align with
/// the output of [IngredientService.normalize].
///
/// Used in two places:
/// - Shopping list aggregation: synonyms are folded into the same list entry.
/// - Recipe FTS search: a user query matching any alias expands to OR all
///   terms in the group.
const Map<String, List<String>> ingredientAliases = {

  // ── Vegetables & Produce ─────────────────────────────────────────────────

  'green onion': ['scallion', 'spring onion'],
  'eggplant': ['aubergine'],
  'courgette': ['zucchini'],
  'bell pepper': ['capsicum'],
  'arugula': ['rocket'],
  'beet': ['beetroot'],
  'romaine lettuce': ['cos lettuce'],
  'napa cabbage': ['wombok'],
  'celeriac': ['celery root'],
  'snow pea': ['mangetout', 'mange tout'], // Keeping, but noting the UK umbrella term caveat
  'rutabaga': ['swede'],
  'fava bean': ['broad bean'],
  'okra': ['ladys finger', 'lady\'s finger'],
  'garlic chive': ['chinese chive'],
  'wood ear mushroom': ['black fungus', 'wood ear'],
  'cassava': ['yuca', 'manioc'],
  'shallot': ['eschalot'],
  'japanese persimmon': ['kaki'],
  'bitter melon': ['bitter gourd', 'balsam pear'],
  'daikon': ['mooli'],
  'jicama': ['yam bean'],
  'dragon fruit': ['pitaya', 'pitahaya'],
  'cantaloupe': ['rockmelon'],

  // ── Legumes ───────────────────────────────────────────────────────────────

  'chickpea': ['garbanzo', 'garbanzo bean'],
  'chana dal': ['channa dal'],
  'toor dal': ['tuvar dal', 'arhar dal'],
  'moong dal': ['mung dal', 'mung bean dal'],
  'black-eyed pea': ['black-eyed bean'],
  'navy bean': ['haricot bean', 'haricot'],
  'cannellini bean': ['white kidney bean'],

  // ── Flours & Starches ─────────────────────────────────────────────────────

  'all-purpose flour': ['plain flour'],
  'whole-wheat flour': ['wholemeal flour'],
  'bread flour': ['strong flour', 'strong white flour'],
  'self-rising flour': ['self-raising flour'],
  'tapioca starch': ['tapioca flour'],
  'glutinous rice flour': ['sweet rice flour'],

  // ── Sweeteners & Sugar ───────────────────────────────────────────────────

  'caster sugar': ['superfine sugar', 'castor sugar'],
  'powdered sugar': ['icing sugar', 'confectioners sugar', 'confectioners\' sugar'],
  'golden raisin': ['sultana'], // Noting that UK/Aus actually uses Sultania grapes, but I think it's ok here
  'agave nectar': ['agave syrup'],

  // ── Dairy ─────────────────────────────────────────────────────────────────

  'whole milk': ['full cream milk', 'full fat milk'],
  'sour cream': ['soured cream'],

  // ── Nuts, Seeds & Dried Fruit ─────────────────────────────────────────────

  'hazelnut': ['filbert'],
  'pine nut': ['pignoli'],

  // ── Spices & Pantry (Indian) ──────────────────────────────────────────────

  'asafoetida': ['hing', 'asafetida'],
  'ajwain': ['carom seed'],
  'kalonji': ['nigella seed', 'black onion seed'],
  'amchur': ['amchoor'],
  'baking soda': ['bicarbonate of soda', 'sodium bicarbonate'],

  // ── Spices & Pantry (Middle Eastern / North African) ─────────────────────

  'sumac': ['sumach'],
  'halloumi': ['haloumi'],
  'labneh': ['labne', 'labaneh'],
  'freekeh': ['farik', 'frikeh'],

  // ── Spices & Pantry (Chinese) ─────────────────────────────────────────────

  'sichuan pepper': ['szechuan pepper', 'szechwan pepper', 'sichuan peppercorn', 'szechuan peppercorn'],
  'shaoxing wine': ['shaohsing wine', 'shao xing wine', 'shaoxing rice wine'],
  'bok choy': ['pak choi', 'bak choy', 'pok choi'],
  'doubanjiang': ['toban djan', 'douban jiang', 'tobanjiang'],

  // ── Spices & Pantry (Japanese) ───────────────────────────────────────────

  'kombu': ['konbu'],

  // ── Spices & Pantry (Korean) ─────────────────────────────────────────────

  'doenjang': ['dwenjang', 'doen jang'],
  'gochugaru': ['korean chili flake', 'korean red pepper flake', 'korean chilli flake'],

  // ── Spices & Pantry (Southeast Asian) ────────────────────────────────────

  'galangal': ['galangale', 'galingale'],
  'makrut lime': ['kaffir lime'],

  // ── Spices & Pantry (Latin American) ─────────────────────────────────────

  'achiote': ['annatto'],
  'chayote': ['choko', 'christophene'],

  // ── Meat (Regional naming only) ───────────────────────────────────────────

  'ground beef': ['beef mince', 'minced beef'],
  'ground pork': ['pork mince', 'minced pork'],
  'ground lamb': ['lamb mince', 'minced lamb'],
  'ground turkey': ['turkey mince', 'minced turkey'],
  'ground chicken': ['chicken mince', 'minced chicken'],

  // ── Seafood ───────────────────────────────────────────────────────────────

  'mahi-mahi': ['dolphinfish', 'mahi mahi'],
  'chilean sea bass': ['patagonian toothfish'],

};

/// Returns the canonical group key for [term], or [term] itself if no alias
/// group contains it.
///
/// Matching is case-insensitive. Call this after your existing normalization
/// pipeline so the incoming [term] is already in a clean, lowercase form.
///
/// ```dart
/// resolveIngredientAlias('scallion');      // → 'green onion'
/// resolveIngredientAlias('green onion');   // → 'green onion'
/// resolveIngredientAlias('chicken');       // → 'chicken'  (no alias group)
/// ```
String resolveIngredientAlias(String term) {
  final lower = term.toLowerCase();
  for (final entry in ingredientAliases.entries) {
    if (entry.key == lower) return entry.key;
    if (entry.value.any((alias) => alias.toLowerCase() == lower)) {
      return entry.key;
    }
  }
  return term;
}
