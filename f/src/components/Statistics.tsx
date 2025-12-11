const mockData = [
  { name: "Appetizers", count: 12 },
  { name: "Main Courses", count: 24 },
  { name: "Desserts", count: 18 },
  { name: "Soups", count: 8 },
  { name: "Salads", count: 10 },
  { name: "Beverages", count: 6 },
];

const countryData = [
  { name: "Italian", count: 15 },
  { name: "Mexican", count: 12 },
  { name: "Japanese", count: 10 },
  { name: "Korean", count: 8 },
  { name: "American", count: 14 },
];

export function Statistics() {
  const maxCount = Math.max(...mockData.map(d => d.count));
  
  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-foreground mb-4">Recipe Statistics</h2>
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-muted-foreground text-sm">Total Recipes</p>
            <p className="text-3xl mt-2 text-foreground">78</p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-muted-foreground text-sm">Countries</p>
            <p className="text-3xl mt-2 text-foreground">12</p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-muted-foreground text-sm">Avg Cook Time</p>
            <p className="text-3xl mt-2 text-foreground">35m</p>
          </div>
          <div className="bg-card border border-border rounded-xl p-4">
            <p className="text-muted-foreground text-sm">Favorites</p>
            <p className="text-3xl mt-2 text-foreground">23</p>
          </div>
        </div>
      </div>

      <div>
        <h3 className="text-foreground mb-4">Recipes by Course</h3>
        <div className="bg-card border border-border rounded-xl p-4">
          <div className="space-y-3">
            {mockData.map((item) => (
              <div key={item.name}>
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm text-foreground">{item.name}</span>
                  <span className="text-sm text-muted-foreground">{item.count}</span>
                </div>
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary rounded-full transition-all"
                    style={{ width: `${(item.count / maxCount) * 100}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div>
        <h3 className="text-foreground mb-4">Top Countries</h3>
        <div className="space-y-3">
          {countryData.map((country, index) => (
            <div key={country.name} className="flex items-center gap-3">
              <div className="w-6 h-6 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm">
                {index + 1}
              </div>
              <div className="flex-1">
                <div className="flex justify-between items-center mb-1">
                  <span className="text-foreground">{country.name}</span>
                  <span className="text-muted-foreground text-sm">{country.count} recipes</span>
                </div>
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary rounded-full transition-all"
                    style={{ width: `${(country.count / 24) * 100}%` }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
