// Removes exact duplicates (same content_hash) that arrived via different URLs.
// Dry run by default; keeps the alphabetically first slug of each group.
//   node dedupe_extracted.js [--dir extracted] [--apply]
import { readdirSync, readFileSync, unlinkSync } from 'fs';

const args = process.argv.slice(2);
const dirIdx = args.indexOf('--dir');
const dir = dirIdx !== -1 ? args[dirIdx + 1] : 'extracted';
const apply = args.includes('--apply');

const groups = new Map();
for (const file of readdirSync(dir).filter(f => f.endsWith('.json')).sort()) {
  let hash;
  try {
    hash = JSON.parse(readFileSync(`${dir}/${file}`, 'utf8'))?.recipe?.content_hash;
  } catch {
    console.warn(`Unreadable, skipped: ${file}`);
    continue;
  }
  if (!hash) continue;
  if (!groups.has(hash)) groups.set(hash, []);
  groups.get(hash).push(file);
}

let removed = 0;
for (const files of groups.values()) {
  if (files.length < 2) continue;
  console.log(`keep   ${files[0]}`);
  for (const dup of files.slice(1)) {
    console.log(`${apply ? 'delete' : 'would delete'} ${dup}`);
    if (apply) unlinkSync(`${dir}/${dup}`);
    removed++;
  }
}
console.log(`${removed} duplicate file(s) ${apply ? 'deleted' : 'found (dry run; pass --apply to delete)'}`);
