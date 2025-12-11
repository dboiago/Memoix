import * as React from "react";

export function Avatar({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}

export function AvatarImage({ className, ...props }: React.ComponentProps<"img">) {
  return <img className={className} {...props} />;
}

export function AvatarFallback({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}
