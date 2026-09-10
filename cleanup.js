import fs from 'fs';

const QUEUE_FILE = './urls/queue.txt';

console.log('Loading queue...');
const rawData = fs.readFileSync(QUEUE_FILE, 'utf-8');
const lines = rawData.split(/\r?\n/);
const initialCount = lines.length;

const filteredLines = lines.filter(line => {
  if (!line.trim()) return false;

  // Handle Difford's Guide specifically: strict keep-list for official recipes
  if (line.includes('diffordsguide.com')) {
    // Keep ONLY official cocktail recipe pages
    return line.includes('diffordsguide.com/cocktails/recipe/');
  }

  // Generic UGC/Community patterns for other domains
  const genericUgc = [
    /\/forum\//i,
    /\/forums\//i,
    /\/community\//i,
    /\/user-generated\//i,
    /\/user-recipe\//i,
    /\/user\//i
  ];

  return !genericUgc.some(pattern => pattern.test(line));
});

const removedCount = initialCount - filteredLines.length;

fs.writeFileSync(QUEUE_FILE, filteredLines.join('\n'));

console.log(`Cleanup complete!`);
console.log(`Removed: ${removedCount} entries`);
console.log(`New Queue Size: ${filteredLines.length}`);