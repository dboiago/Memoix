import * as React from "react";

export function Button({ children, className, ...props }: React.ComponentProps<"button">) {
  return (
    <button className={className} {...props}>
      {children}
    </button>
  );
}
