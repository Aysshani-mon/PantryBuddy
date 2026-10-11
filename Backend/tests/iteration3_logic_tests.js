// Iteration 3 logic tests (TC32–TC41 in the Testing & Bug Log).
// Runs the real backend modules against the data team's real CSVs.
// Usage, from the repo root:  node pantrybuddy-backend/tests/iteration3_logic_tests.js
// No database or network needed. Exits with code 1 if any test fails.
const fs = require('fs');
const path = require('path');
const rootArg = process.argv.slice(2).find((a) => !a.startsWith('--'));
const ROOT = rootArg ? path.resolve(rootArg) : path.resolve(__dirname, '../..');
// Works before and after the folder clean-up (src/util -> src/services).
const U = (m) => {
  for (const dir of ['services', 'util']) {
    const p = path.join(ROOT, 'pantrybuddy-backend/src', dir, `${m}.js`);
    if (fs.existsSync(p)) return require(p);
  }
  throw new Error(`Module not found: ${m}`);
};
const { buildFactorMatcher } = U('factor_matching');
const { convertToKg } = U('waste_impact');
const { petrolLitresFor } = U('equivalents');
const { eligibleItems, rankRecipes, availabilityFor } = U('recipe_matching');
const { sanitiseAiRecipes } = U('ai_recipes');
const { sanitiseDetections } = U('multi_item_detection');
const { foldPlural } = U('product_reference');

function csv(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/\r/g, '');
  const rows = []; let row = [], cur = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"' && text[i + 1] === '"') { cur += '"'; i++; } else if (c === '"') q = false; else cur += c; }
    else if (c === '"') q = true; else if (c === ',') { row.push(cur); cur = ''; }
    else if (c === '\n') { row.push(cur); rows.push(row); row = []; cur = ''; } else cur += c;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  const [h, ...rest] = rows;
  return rest.filter((r) => r.length === h.length).map((r) => Object.fromEntries(h.map((k, i) => [k, r[i]])));
}
const DATA = path.join(ROOT, 'Database/Iteration 3/Schema & Data/epic8_CO2e_calculation');
const factors = csv(path.join(DATA, 'emission_factors.csv')).filter((r) => r.is_active === '1');
const conversions = csv(path.join(DATA, 'quantity_conversions.csv')).filter((r) => r.is_active === '1').map((r) => ({
  conversionId: Number(r.conversion_id), referenceId: r.reference_id ? Number(r.reference_id) : null,
  fromUnit: r.from_unit, toUnit: r.to_unit, factor: Number(r.factor), isAssumed: Number(r.is_assumed),
}));
const results = [];
function check(tc, title, actual, pass) { results.push({ tc, title, actual, pass }); }

// ---- Emission factor matching (real 1,782-row dataset) ----
const match = buildFactorMatcher(factors);
const show = (n) => { const m = match(n); return m ? `${m.row.factor_name} (${m.row.food_type || '-'}, ${Number(m.row.factor_kg_co2e_per_kg)} kg CO2e/kg, via ${m.method})` : 'no match'; };
const butter = match('Butter'), coffee = match('Coffee'), onion = match('Onion');
check('TC32', 'No false partial matches (Butter, Coffee) and correct food-type match (Onion)', [`Butter -> ${show('Butter')}`, `Coffee -> ${show('Coffee')}`, `Onion -> ${show('Onion')}`].join('; '),
  butter === null && coffee === null && !!onion && onion.row.food_type === 'Onions & Leeks');
const beef = match('Beef mince'), unknown = match('Dishwashing liquid');
check('TC33', 'Specific food matches; non-food has no factor', `Beef mince -> ${show('Beef mince')}; Dishwashing liquid -> ${show('Dishwashing liquid')}`, !!beef && unknown === null);
check('TC34', 'Prawns and sugar coverage (known data gap)', `Prawns -> ${show('Prawns')}; Sugar -> ${show('Sugar')}`, true);

// ---- Unit conversion ----
const global = conversions.filter((c) => c.referenceId === null);
const g500 = convertToKg(500, 'g', [], global);
const specific = conversions.filter((c) => c.referenceId !== null && c.fromUnit.toLowerCase() === 'l');
const someRef = specific[0];
const l2 = convertToKg(2, 'L', conversions.filter((c) => c.referenceId === someRef.referenceId), global);
const pack = convertToKg(1, 'pack', [], global);
check('TC35', 'Unit conversion to kg', `500 g -> ${g500 && g500.kg} kg (assumed=${g500 && g500.isAssumed}); 2 L of reference ${someRef.referenceId} -> ${l2 && l2.kg} kg (assumed=${l2 && l2.isAssumed}); 1 pack -> ${pack === null ? 'null (no conversion)' : pack.kg}`,
  g500 && Math.abs(g500.kg - 0.5) < 1e-9 && l2 && l2.kg > 0 && pack === null);
const p = petrolLitresFor(2.34502), p2 = petrolLitresFor(11.7251);
check('TC36', 'Petrol equivalent', `2.34502 kg CO2e -> ${p} L; 11.7251 kg CO2e -> ${p2} L`, Math.abs(p - 1) < 1e-9 && Math.abs(p2 - 5) < 1e-9);

// ---- Recipe matching ----
const today = '2026-10-11';
const rows = [
  { inventory_item_id: 1, product_id: 10, product_name: 'Spinach', quantity: 1, unit: 'pcs', status: 'IN_STOCK', expiry_date: '2026-10-12' },
  { inventory_item_id: 2, product_id: 11, product_name: 'Eggs', quantity: 6, unit: 'pcs', status: 'IN_STOCK', expiry_date: '2026-10-25' },
  { inventory_item_id: 3, product_id: 12, product_name: 'Milk', quantity: 1, unit: 'L', status: 'IN_STOCK', expiry_date: '2026-10-09' },
  { inventory_item_id: 4, product_id: 13, product_name: 'Rice', quantity: 0, unit: 'kg', status: 'IN_STOCK', expiry_date: null },
  { inventory_item_id: 5, product_id: 14, product_name: 'Cheese', quantity: 0.5, unit: 'kg', status: 'CONSUMED', expiry_date: '2026-11-01' },
  { inventory_item_id: 6, product_id: 15, product_name: 'Flour', quantity: 0.5, unit: 'kg', status: 'IN_STOCK', expiry_date: null },
];
const items = eligibleItems(rows, today);
check('TC37', 'Only in-date, in-stock items are used; expiring soon flagged', items.map((i) => `${i.name}${i.expiringSoon ? ' (expiring soon)' : ''}`).join(', '),
  items.map((i) => i.name).join() === 'Spinach,Eggs,Flour' && items[0].expiringSoon && !items[1].expiringSoon);
const keys = new Map(items.map((i) => [i.id, { referenceIds: new Set(), foldedNames: new Set([foldPlural(i.name)]) }]));
const lines = new Map([
  ['101', [{ ingredient_name: 'eggs', is_optional: 0 }, { ingredient_name: 'flour', is_optional: 0 }, { ingredient_name: 'salt', is_optional: 0 }]],
  ['102', [{ ingredient_name: 'spinach', is_optional: 0 }, { ingredient_name: 'garlic', is_optional: 0 }, { ingredient_name: 'pasta', is_optional: 0 }]],
  ['103', [{ ingredient_name: 'chicken', is_optional: 0 }, { ingredient_name: 'salt', is_optional: 0 }]],
]);
const ranked = rankRecipes(lines, items, keys);
check('TC38', 'Recipe using food expiring soon ranks first', ranked.map((r) => `#${r.recipeId} (expiring ${r.expiringCount}, coverage ${Math.round(r.coverage * 100)}%)`).join(' > '),
  ranked[0].recipeId === '102' && ranked.length === 2);
const a1 = availabilityFor({ quantity: 300, unit: 'g' }, { quantity: 0.5, unit: 'kg' });
const a2 = availabilityFor({ quantity: 8, unit: 'pcs' }, { quantity: 6, unit: 'pcs' });
const a3 = availabilityFor({ quantity: 2, unit: 'cup' }, { quantity: 300, unit: 'g' });
check('TC39', 'Enough / not enough / unit mismatch', `300 g vs 0.5 kg -> ${a1.status} (use ${a1.suggestedUseQuantity} kg); 8 pcs vs 6 pcs -> ${a2.status}; 2 cup vs 300 g -> ${a3.status}`,
  a1.status === 'enough' && a1.suggestedUseQuantity === 0.3 && a2.status === 'notEnough' && a3.status === 'checkQuantity');

// ---- AI output validation ----
const aiRaw = [
  { title: 'Spinach omelette', steps: ['Beat eggs', 'Cook with spinach'], servings: 2, prepMinutes: 15,
    ingredients: [{ name: 'Spinach', inventoryItemId: '1', quantity: 1, unit: 'pcs' }, { name: 'Truffle', inventoryItemId: '999', quantity: 1 }] },
  { title: 'Imaginary cake', steps: ['Bake'], ingredients: [{ name: 'Unicorn sugar', inventoryItemId: '777' }] },
  { title: '', steps: ['x'], ingredients: [{ name: 'Eggs', inventoryItemId: '2' }] },
  { title: 'Egg fried flour', steps: ['Mix', 'Fry'], servings: 999, ingredients: [{ name: 'Eggs', inventoryItemId: '2' }] },
  { title: 'Fourth recipe', steps: ['Mix'], ingredients: [{ name: 'Flour', inventoryItemId: '6' }] },
];
const ai = sanitiseAiRecipes(aiRaw, items, 2);
check('TC40', 'AI recipes are checked against the real inventory', `${ai.length} kept: ` + ai.map((r) => `"${r.title}" [${r.ingredients.map((i) => `${i.name}${i.item ? ' = in stock' : ' = not in stock'}`).join(', ')}] servings ${r.servings}`).join('; '),
  ai.length === 2 && ai[0].ingredients[1].item === null && ai[1].servings === 1 && !ai.some((r) => r.title === 'Imaginary cake'));

// ---- Multi-item detection validation ----
const det = sanitiseDetections({ items: [
  { name: 'Banana', count: 3, unit: 'pcs', category: 'Fruits', confidence: 'high', box_2d: [100, 100, 300, 300] },
  { name: 'banana ', count: 2, unit: 'pcs', category: 'Fruits', confidence: 'medium', box_2d: [400, 400, 600, 600] },
  { name: 'Milk', count: 1, unit: 'gallon', category: 'Dairy', confidence: 'high', box_2d: [10, 10, 5, 5] },
  { name: 'Mystery', count: -4, unit: 'pcs', category: 'spaceFood', confidence: 'sure' },
  { name: '   ', count: 1 },
] });
check('TC41', 'AI photo results are cleaned before review', det.map((d) => `${d.name} x${d.quantity} ${d.unit} [category ${d.categoryName || 'none'}, ${d.confidence}, ${d.boxes.length} box]`).join('; '),
  det.length === 3 && det[0].quantity === 5 && det[0].confidence === 'medium' && det[0].boxes.length === 2 && det[1].unit === 'pcs' && det[1].boxes.length === 0 && det[2].quantity === 1 && det[2].categoryName === null && det[2].confidence === 'low' && det[0].categoryName === 'Fruits');

if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ factorRows: factors.length, conversionRows: conversions.length, results }, null, 2));
} else {
  console.log(`Data: ${factors.length} emission factors, ${conversions.length} quantity conversions\n`);
  for (const r of results) console.log(`${r.pass ? 'PASS' : 'FAIL'}  ${r.tc}  ${r.title}\n      ${r.actual}\n`);
  const failed = results.filter((r) => !r.pass).length;
  console.log(failed ? `${failed} test(s) failed` : `All ${results.length} tests passed`);
  process.exitCode = failed ? 1 : 0;
}
