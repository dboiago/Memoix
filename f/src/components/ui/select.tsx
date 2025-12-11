import * as React from "react";

export function Select({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function SelectTrigger({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function SelectValue({ children }: { children?: React.ReactNode }) {
  return <div>{children}</div>;
}

export function SelectContent({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function SelectItem({ children, value }: { children: React.ReactNode; value: string }) {
  return <div data-value={value}>{children}</div>;
}

export function SelectGroup({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function SelectLabel({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}
