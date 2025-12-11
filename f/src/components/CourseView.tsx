import { useState, useMemo } from "react";
import { ArrowLeft, Search, Users, Clock, Heart, CheckCircle, Plus } from "lucide-react";

interface Recipe {
  id: string;
  name: string;
  continent: string;
  country: string;
  region?: string;
  servings: number;
  totalTime: string;
  isFavorite: boolean;
  isCooked: boolean;
}

interface CourseViewProps {
  courseName: string;
  recipes: Recipe[];
  onBack: () => void;
}

export function CourseView({ courseName, recipes, onBack }: CourseViewProps) {
  const [selectedContinent, setSelectedContinent] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  // Get unique continents from recipes, sorted alphabetically
  const continents = useMemo(() => {
    const continentSet = new Set(recipes.map((r) => r.continent));
    return ["all", ...Array.from(continentSet).sort()];
  }, [recipes]);

  // Sort recipes by continent, then country, then region (if present)
  const sortedRecipes = useMemo(() => {
    return [...recipes].sort((a, b) => {
      // First by continent
      if (a.continent !== b.continent) {
        return a.continent.localeCompare(b.continent);
      }
      // Then by country
      if (a.country !== b.country) {
        return a.country.localeCompare(b.country);
      }
      // Then by region if present
      if (a.region && b.region) {
        return a.region.localeCompare(b.region);
      }
      return 0;
    });
  }, [recipes]);

  // Filter recipes by continent and search
  const filteredRecipes = useMemo(() => {
    return sortedRecipes.filter((recipe) => {
      const matchesContinent = selectedContinent === "all" || recipe.continent === selectedContinent;
      const matchesSearch = recipe.name.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesContinent && matchesSearch;
    });
  }, [sortedRecipes, selectedContinent, searchQuery]);

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="sticky top-0 bg-background/95 backdrop-blur-sm border-b border-border z-10">
        <div className="px-4 py-4">
          <button
            onClick={onBack}
            className="flex items-center gap-2 text-foreground hover:text-primary transition-colors mb-4"
          >
            <ArrowLeft className="w-5 h-5" />
            <span>Back</span>
          </button>
          <h1 className="text-foreground mb-4">{courseName}</h1>
          
          {/* Search */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search recipes..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 px-3 py-2 rounded-lg border border-border bg-card text-foreground placeholder:text-muted-foreground"
            />
          </div>

          {/* Continent Filter */}
          <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
            {continents.map((continent) => (
              <button
                key={continent}
                onClick={() => setSelectedContinent(continent)}
                className={`px-4 py-2 rounded-full whitespace-nowrap transition-colors ${
                  selectedContinent === continent
                    ? "bg-secondary text-secondary-foreground"
                    : "bg-card border border-border hover:border-secondary"
                }`}
              >
                {continent.charAt(0).toUpperCase() + continent.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Recipe List */}
      <div className="px-4 py-6 relative pb-24">
        {filteredRecipes.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-muted-foreground">No recipes found</p>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredRecipes.map((recipe) => (
              <button
                key={recipe.id}
                className="w-full bg-card border border-border rounded-xl p-4 hover:border-primary transition-all text-left"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1">
                    <h3 className="text-foreground mb-2">{recipe.name}</h3>
                    <div className="flex flex-wrap gap-3 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-primary" />
                        {recipe.country}
                        {recipe.region && ` (${recipe.region})`}
                      </span>
                      <span className="flex items-center gap-1">
                        <Users className="w-3.5 h-3.5" />
                        {recipe.servings}
                      </span>
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {recipe.totalTime}
                      </span>
                    </div>
                  </div>
                  <div className="flex flex-col gap-2">
                    <button 
                      className={`p-1.5 rounded-lg transition-colors ${
                        recipe.isFavorite 
                          ? "text-red-500 bg-red-500/10" 
                          : "text-muted-foreground hover:bg-accent"
                      }`}
                      onClick={(e) => {
                        e.stopPropagation();
                        // Toggle favorite logic
                      }}
                    >
                      <Heart className={`w-4 h-4 ${recipe.isFavorite ? "fill-current" : ""}`} />
                    </button>
                    <button 
                      className={`p-1.5 rounded-lg transition-colors ${
                        recipe.isCooked 
                          ? "text-green-500 bg-green-500/10" 
                          : "text-muted-foreground hover:bg-accent"
                      }`}
                      onClick={(e) => {
                        e.stopPropagation();
                        // Toggle cooked logic
                      }}
                    >
                      <CheckCircle className={`w-4 h-4 ${recipe.isCooked ? "fill-current" : ""}`} />
                    </button>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}

        {/* Add Recipe FAB */}
        <button className="fixed bottom-6 right-6 bg-primary text-primary-foreground rounded-full p-4 shadow-lg hover:shadow-xl transition-shadow flex items-center gap-2">
          <Plus className="w-6 h-6" />
          <span className="pr-1">Add Recipe</span>
        </button>
      </div>
    </div>
  );
}