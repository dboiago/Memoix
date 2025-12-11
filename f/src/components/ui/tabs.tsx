import * as React from "react";

export function Tabs({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function TabsList({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function TabsTrigger({ children, value }: { children: React.ReactNode; value: string }) {
  return <div data-value={value}>{children}</div>;
}

export function TabsContent({ children, value }: { children: React.ReactNode; value: string }) {
  return <div data-value={value}>{children}</div>;
}
