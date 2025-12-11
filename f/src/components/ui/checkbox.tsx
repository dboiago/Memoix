import * as React from "react";

export function Checkbox({ className, ...props }: React.ComponentProps<"input">) {
  return (
    <input type="checkbox" className={className} {...props} />
  );
}
