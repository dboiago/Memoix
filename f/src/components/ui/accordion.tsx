import * as React from "react";

export function Accordion({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function AccordionItem({ children, value }: { children: React.ReactNode; value: string }) {
  return <div data-value={value}>{children}</div>;
}

export function AccordionTrigger({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function AccordionContent({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}
