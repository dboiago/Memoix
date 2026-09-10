import fs from 'fs';

const QUEUE_FILE = './urls/queue.txt';

console.log('Loading queue...');
const rawData = fs.readFileSync(QUEUE_FILE, 'utf-8');
const lines = rawData.split(/\r?\n/);
const initialCount = lines.length;

// URL patterns to drop (Non-English paths)
const nonEnglishPatterns = [
  // Meilleur du Chef non-English paths
  /meilleurduchef\.com\/(fr|it|es|de)\//i,
  /meilleurduchef\.com\/mdc\/sitemap_(fr|it)\.xml/i,

  // Lyres non-English regional stores
  /lyres\.com\/(it-eu|de-eu|fr-eu|nl-eu|pl-eu|es-eu)\//i,

  // Seedlip non-English
  /seedlipdrinks\.com\/fr-ca\//i,

  // General language directory indicators
  /\/fr\//i,
  /\/it\//i,
  /\/de\//i,
  /\/es\//i
];

const filteredLines = lines.filter(line => {
  if (!line.trim()) return false;

  // Drop non-English URLs
  if (nonEnglishPatterns.some(pattern => pattern.test(line))) {
    return false;
  }

  return true;
});

const removedCount = initialCount - filteredLines.length;

fs.writeFileSync(QUEUE_FILE, filteredLines.join('\n'));

console.log(`Cleanup complete!`);
console.log(`Removed: ${removedCount} non-English entries`);
console.log(`New Queue Size: ${filteredLines.length}`);