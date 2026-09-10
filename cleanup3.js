import fs from 'fs';

const QUEUE_FILE = './urls/queue.txt';

console.log('Loading queue...');
const rawData = fs.readFileSync(QUEUE_FILE, 'utf-8');
const lines = rawData.split(/\r?\n/);
const initialCount = lines.length;

const filteredLines = lines.filter(line => {
  if (!line.trim()) return false;

  // Drop Spanish site for now (English-only rule)
  if (line.includes('directoalpaladar.com')) {
    return false;
  }

  // Preserve chinasichuanfood collections explicitly
  if (line.includes('chinasichuanfood.com/collections/')) {
    return true;
  }

  // Generic category/tag/collection index pages to drop elsewhere
  const genericIndexPatterns = [
    /\/collections\//i,
    /\/category\//i,
    /\/tag\//i,
    /\/curso-de-cocina\//i
  ];

  return !genericIndexPatterns.some(pattern => pattern.test(line));
});

const removedCount = initialCount - filteredLines.length;

fs.writeFileSync(QUEUE_FILE, filteredLines.join('\n'));

console.log(`Cleanup complete!`);
console.log(`Removed: ${removedCount} entries`);
console.log(`New Queue Size: ${filteredLines.length}`);