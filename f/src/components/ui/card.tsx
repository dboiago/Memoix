import * as React from "react";

export function Card({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}

export function CardHeader({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}

export function CardTitle({ children, className, ...props }: React.ComponentProps<"h3">) {
  return (
    <h3 className={className} {...props}>
      {children}
    </h3>
  );
}

export function CardDescription({ children, className, ...props }: React.ComponentProps<"p">) {
  return (
    <p className={className} {...props}>
      {children}
    </p>
  );
}

export function CardContent({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}

export function CardFooter({ children, className, ...props }: React.ComponentProps<"div">) {
  return (
    <div className={className} {...props}>
      {children}
    </div>
  );
}
