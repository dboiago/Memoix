import { useState, useEffect } from "react";
import {
  Menu,
  Moon,
  Sun,
  Settings,
  BarChart3,
  Scale,
  Coffee,
  Soup,
  UtensilsCrossed,
  Salad,
  Cake,
  Wine,
  Wheat,
  Droplet,
  Pizza,
  Flame,
  ChefHat,
  BookOpen,
  X,
  Heart,
  ShoppingCart,
  CalendarDays,
  StickyNote,
  ScanText,
  Link,
  QrCode,
  Share2,
  Sandwich,
} from "lucide-react";
import { CourseCard } from "./components/CourseCard";
import { CourseView } from "./components/CourseView";
import { MeasurementConverter } from "./components/MeasurementConverter";
import { Statistics } from "./components/Statistics";

// Course data with icons - all 18 courses
const courses = [
  { id: "apps", name: "Apps", icon: Coffee, recipeCount: 12 },
  { id: "soups", name: "Soups", icon: Soup, recipeCount: 8 },
  { id: "mains", name: "Mains", icon: UtensilsCrossed, recipeCount: 24 },
  { id: "vegn", name: "Veg'n", icon: Salad, recipeCount: 19 },
  { id: "sides", name: "Sides", icon: Salad, recipeCount: 15 },
  { id: "desserts", name: "Desserts", icon: Cake, recipeCount: 18 },
  { id: "brunch", name: "Brunch", icon: Coffee, recipeCount: 11 },
  { id: "drinks", name: "Drinks", icon: Wine, recipeCount: 7 },
  { id: "breads", name: "Breads", icon: Wheat, recipeCount: 9 },
  { id: "sauces", name: "Sauces", icon: Droplet, recipeCount: 8 },
  { id: "rubs", name: "Rubs", icon: Flame, recipeCount: 5 },
  { id: "pickles", name: "Pickles", icon: ChefHat, recipeCount: 4 },
  { id: "modernist", name: "Modernist", icon: ChefHat, recipeCount: 6 },
  { id: "pizzas", name: "Pizzas", icon: Pizza, recipeCount: 13 },
  { id: "sandwiches", name: "Sandwiches", icon: Sandwich, recipeCount: 10 },
  { id: "smoking", name: "Smoking", icon: Flame, recipeCount: 7 },
  { id: "cheese", name: "Cheese", icon: ChefHat, recipeCount: 5 },
  { id: "scratch", name: "Scratch", icon: BookOpen, recipeCount: 14 },
];

// Mock recipe data organized by continent and country
const mockRecipes = {
  apps: [
    { id: "1", name: "Bruschetta", continent: "European", country: "Italian", region: "", servings: 4, totalTime: "15m", isFavorite: false, isCooked: false },
    { id: "2", name: "Spring Rolls", continent: "Asian", country: "Vietnamese", region: "", servings: 6, totalTime: "20m", isFavorite: true, isCooked: false },
    { id: "3", name: "Guacamole", continent: "American", country: "Mexican", region: "", servings: 4, totalTime: "10m", isFavorite: false, isCooked: true },
    { id: "4", name: "Edamame", continent: "Asian", country: "Japanese", region: "", servings: 2, totalTime: "10m", isFavorite: false, isCooked: false },
    { id: "5", name: "Gyoza", continent: "Asian", country: "Japanese", region: "", servings: 4, totalTime: "30m", isFavorite: true, isCooked: true },
  ],
  mains: [
    { id: "6", name: "Pasta Carbonara", continent: "European", country: "Italian", region: "", servings: 4, totalTime: "25m", isFavorite: false, isCooked: false },
    { id: "7", name: "Tacos al Pastor", continent: "American", country: "Mexican", region: "", servings: 6, totalTime: "50m", isFavorite: true, isCooked: false },
    { id: "8", name: "Tonkatsu", continent: "Asian", country: "Japanese", region: "", servings: 4, totalTime: "35m", isFavorite: false, isCooked: false },
    { id: "9", name: "Bibimbap", continent: "Asian", country: "Korean", region: "", servings: 2, totalTime: "40m", isFavorite: false, isCooked: true },
    { id: "10", name: "Mapo Tofu", continent: "Asian", country: "Chinese", region: "Szechuan", servings: 4, totalTime: "30m", isFavorite: true, isCooked: false },
  ],
};

type ViewType = "home" | "course" | "converter" | "stats" | "settings" | "favorites" | "mealplan" | "shopping" | "scratchpad";

export default function App() {
  const [isDark, setIsDark] = useState(true);
  const [currentView, setCurrentView] = useState<ViewType>("home");
  const [selectedCourse, setSelectedCourse] = useState<string | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  // Apply theme on mount and change
  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [isDark]);

  // Close menu on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") setIsMenuOpen(false);
    };
    window.addEventListener("keydown", handleEscape);
    return () => window.removeEventListener("keydown", handleEscape);
  }, []);

  const handleCourseClick = (courseId: string) => {
    setSelectedCourse(courseId);
    setCurrentView("course");
  };

  const handleBackToHome = () => {
    setCurrentView("home");
    setSelectedCourse(null);
  };

  const handleMenuItemClick = (view: ViewType) => {
    setCurrentView(view);
    setIsMenuOpen(false);
  };

  const menuItems = [
    // Navigate section
    { icon: UtensilsCrossed, label: "Recipes", view: "home" as ViewType, section: "Navigate" },
    { icon: CalendarDays, label: "Meal Plan", view: "mealplan" as ViewType, section: "Navigate" },
    { icon: ShoppingCart, label: "Shopping List", view: "shopping" as ViewType, section: "Navigate" },
    { icon: Heart, label: "Favourites", view: "favorites" as ViewType, section: "Navigate" },
    // Tools section
    { icon: StickyNote, label: "Scratch Pad", view: "scratchpad" as ViewType, section: "Tools" },
    { icon: Scale, label: "Unit Converter", view: "converter" as ViewType, section: "Tools" },
    { icon: BarChart3, label: "Statistics", view: "stats" as ViewType, section: "Tools" },
    // Share section (these would be modal actions in a real app)
    { icon: ScanText, label: "Scan Recipe (OCR)", view: "home" as ViewType, section: "Share" },
    { icon: Link, label: "Import From URL", view: "home" as ViewType, section: "Share" },
    { icon: QrCode, label: "Scan QR Code", view: "home" as ViewType, section: "Share" },
    { icon: Share2, label: "Share Recipe", view: "home" as ViewType, section: "Share" },
  ];

  const currentCourse = courses.find((c) => c.id === selectedCourse);
  const currentRecipes = selectedCourse ? mockRecipes[selectedCourse as keyof typeof mockRecipes] || [] : [];

  return (
    <div className="min-h-screen bg-background">
      {/* Sidebar Overlay */}
      {isMenuOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 transition-opacity"
          onClick={() => setIsMenuOpen(false)}
        />
      )}

      {/* Sidebar */}
      <div
        className={`fixed top-0 left-0 h-full w-[280px] sm:w-[320px] bg-sidebar border-r border-sidebar-border z-50 transition-transform duration-300 overflow-y-auto ${ 
          isMenuOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex items-center justify-between p-4 border-b border-sidebar-border">
          <h2 className="text-sidebar-foreground">Menu</h2>
          <button
            onClick={() => setIsMenuOpen(false)}
            className="p-2 hover:bg-sidebar-accent rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <nav className="p-4 space-y-6">
          {/* Navigate Section */}
          <div>
            <h3 className="text-xs uppercase tracking-wider text-muted-foreground mb-2 px-4">Navigate</h3>
            <div className="space-y-1">
              {menuItems.filter(item => item.section === "Navigate").map((item) => (
                <button
                  key={item.label}
                  onClick={() => handleMenuItemClick(item.view)}
                  className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg hover:bg-sidebar-accent transition-colors text-left text-sidebar-foreground"
                >
                  <item.icon className="w-5 h-5" />
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Tools Section */}
          <div>
            <h3 className="text-xs uppercase tracking-wider text-muted-foreground mb-2 px-4">Tools</h3>
            <div className="space-y-1">
              {menuItems.filter(item => item.section === "Tools").map((item) => (
                <button
                  key={item.label}
                  onClick={() => handleMenuItemClick(item.view)}
                  className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg hover:bg-sidebar-accent transition-colors text-left text-sidebar-foreground"
                >
                  <item.icon className="w-5 h-5" />
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Share Section */}
          <div>
            <h3 className="text-xs uppercase tracking-wider text-muted-foreground mb-2 px-4">Share</h3>
            <div className="space-y-1">
              {menuItems.filter(item => item.section === "Share").map((item) => (
                <button
                  key={item.label}
                  onClick={() => handleMenuItemClick(item.view)}
                  className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg hover:bg-sidebar-accent transition-colors text-left text-sidebar-foreground"
                >
                  <item.icon className="w-5 h-5" />
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Settings at bottom */}
          <div className="border-t border-sidebar-border pt-4">
            <button
              onClick={() => handleMenuItemClick("settings")}
              className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg hover:bg-sidebar-accent transition-colors text-left text-sidebar-foreground"
            >
              <Settings className="w-5 h-5" />
              <span>Settings</span>
            </button>
          </div>
        </nav>
      </div>

      {/* Top Bar */}
      <div className="sticky top-0 bg-background/95 backdrop-blur-sm border-b border-border z-20">
        <div className="flex items-center justify-between px-4 py-3">
          <button
            onClick={() => setIsMenuOpen(true)}
            className="p-2 hover:bg-accent rounded-lg transition-colors"
          >
            <Menu className="w-6 h-6" />
          </button>

          <h1 className="text-foreground">Recipe Book</h1>

          <button
            onClick={() => setIsDark(!isDark)}
            className="p-2 hover:bg-accent rounded-lg transition-colors"
          >
            {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="pb-6">
        {currentView === "home" && (
          <div className="px-4 py-6">
            <p className="text-muted-foreground mb-6">
              Browse recipes by course
            </p>
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
              {courses.map((course) => (
                <CourseCard
                  key={course.id}
                  name={course.name}
                  icon={course.icon}
                  recipeCount={course.recipeCount}
                  onClick={() => handleCourseClick(course.id)}
                />
              ))}
            </div>
          </div>
        )}

        {currentView === "course" && currentCourse && (
          <CourseView
            courseName={currentCourse.name}
            recipes={currentRecipes}
            onBack={handleBackToHome}
          />
        )}

        {currentView === "converter" && (
          <div className="px-4 py-6 max-w-2xl mx-auto">
            <button
              onClick={() => setCurrentView("home")}
              className="flex items-center gap-2 text-foreground hover:text-primary transition-colors mb-6"
            >
              <span>← Back</span>
            </button>
            <h1 className="text-foreground mb-6">Measurement Converter</h1>
            <MeasurementConverter />
          </div>
        )}

        {currentView === "stats" && (
          <div className="px-4 py-6 max-w-2xl mx-auto">
            <button
              onClick={() => setCurrentView("home")}
              className="flex items-center gap-2 text-foreground hover:text-primary transition-colors mb-6"
            >
              <span>← Back</span>
            </button>
            <Statistics />
          </div>
        )}

        {currentView === "settings" && (
          <div className="px-4 py-6 max-w-2xl mx-auto">
            <button
              onClick={() => setCurrentView("home")}
              className="flex items-center gap-2 text-foreground hover:text-primary transition-colors mb-6"
            >
              <span>← Back</span>
            </button>
            <h1 className="text-foreground mb-6">Settings</h1>
            <div className="space-y-4">
              <div className="bg-card border border-border rounded-xl p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-foreground">Dark Mode</h3>
                    <p className="text-sm text-muted-foreground mt-1">
                      Toggle between light and dark theme
                    </p>
                  </div>
                  <button
                    onClick={() => setIsDark(!isDark)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      isDark ? "bg-primary" : "bg-secondary"
                    }`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        isDark ? "translate-x-6" : "translate-x-1"
                      }`}
                    />
                  </button>
                </div>
              </div>
              <div className="bg-card border border-border rounded-xl p-4">
                <h3 className="text-foreground">About</h3>
                <p className="text-sm text-muted-foreground mt-2">
                  Recipe Book v1.0.0
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}