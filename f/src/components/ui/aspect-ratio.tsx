import * as React from "react";

export function AspectRatio({ children, className, ...props }: React.ComponentProps<"div"> & { ratio?: number }) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}
