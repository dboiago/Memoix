import * as React from "react";

export function NavigationMenu({ children }: { children: React.ReactNode }) {
  return <nav>{children}</nav>;
}

export function NavigationMenuList({ children }: { children: React.ReactNode }) {
  return <ul>{children}</ul>;
}

export function NavigationMenuItem({ children }: { children: React.ReactNode }) {
  return <li>{children}</li>;
}

export function NavigationMenuTrigger({ children }: { children: React.ReactNode }) {
  return <button>{children}</button>;
}

export function NavigationMenuContent({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function NavigationMenuLink({ children }: { children: React.ReactNode }) {
  return <a>{children}</a>;
}

export function NavigationMenuIndicator() {
  return <div />;
}

export function NavigationMenuViewport() {
  return <div />;
}
