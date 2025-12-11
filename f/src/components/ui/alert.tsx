import * as React from "react";

export function Alert({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}

export function AlertTitle({ children, className, ...props }: React.ComponentProps<"h5">) {
  return (
    <h5 className={className} {...props}>
      {children}
    </h5>
  );
}

export function AlertDescription({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}
