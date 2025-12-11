import * as React from "react";

export function Label({ children, className, ...props }: React.ComponentProps<"label">) {
  return (
    <label className={className} {...props}>
      {children}
    </label>
  );
}
