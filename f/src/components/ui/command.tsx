import * as React from "react";

export function Command({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CommandInput({ ...props }: any) {
  return <input {...props} />;
}

export function CommandList({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CommandEmpty({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CommandGroup({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CommandItem({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CommandSeparator() {
  return <hr />;
}

export function CommandShortcut({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}
