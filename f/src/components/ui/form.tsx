import * as React from "react";

export function Form({ children }: { children: React.ReactNode }) {
  return <form>{children}</form>;
}

export function FormItem({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}

export function FormLabel({ children, className }: { children: React.ReactNode; className?: string }) {
  return <label className={className}>{children}</label>;
}

export function FormControl({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function FormDescription({ children, className }: { children: React.ReactNode; className?: string }) {
  return <p className={className}>{children}</p>;
}

export function FormMessage({ children, className }: { children?: React.ReactNode; className?: string }) {
  return <p className={className}>{children}</p>;
}

export function FormField({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function useFormField() {
  return {};
}
