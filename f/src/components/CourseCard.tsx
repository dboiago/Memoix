import { LucideIcon } from "lucide-react";

interface CourseCardProps {
  name: string;
  icon: LucideIcon;
  recipeCount: number;
  onClick: () => void;
}

export function CourseCard({ name, icon: Icon, recipeCount, onClick }: CourseCardProps) {
  return (
    <button
      onClick={onClick}
      className="group relative bg-card border border-border rounded-xl p-6 hover:border-secondary transition-all duration-200 text-left w-full"
    >
      <div className="flex flex-col items-center gap-3">
        <div className="w-12 h-12 rounded-lg bg-accent flex items-center justify-center group-hover:bg-secondary group-hover:text-secondary-foreground transition-colors">
          <Icon className="w-6 h-6" />
        </div>
        <div className="text-center">
          <h3 className="text-foreground">{name}</h3>
          <p className="text-sm text-muted-foreground mt-1">
            {recipeCount} {recipeCount === 1 ? "recipe" : "recipes"}
          </p>
        </div>
      </div>
    </button>
  );
}