import * as React from "react";

export function Badge({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}
