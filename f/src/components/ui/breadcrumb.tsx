import * as React from "react";

export function Breadcrumb({ children, className, ...props }: React.ComponentProps<"nav">) {
  return (
    <nav className={className} {...props}>
      {children}
    </nav>
  );
}

export function BreadcrumbList({ children, className, ...props }: React.ComponentProps<"ol">) {
  return (
    <ol className={className} {...props}>
      {children}
    </ol>
  );
}

export function BreadcrumbItem({ children, className, ...props }: React.ComponentProps<"li">) {
  return (
    <li className={className} {...props}>
      {children}
    </li>
  );
}

export function BreadcrumbLink({ children, className, ...props }: React.ComponentProps<"a">) {
  return (
    <a className={className} {...props}>
      {children}
    </a>
  );
}

export function BreadcrumbPage({ children, className, ...props }: React.ComponentProps<"span">) {
  return (
    <span className={className} {...props}>
      {children}
    </span>
  );
}

export function BreadcrumbSeparator({ children, className, ...props }: React.ComponentProps<"li">) {
  return (
    <li className={className} {...props}>
      {children}
    </li>
  );
}

export function BreadcrumbEllipsis({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span className={className} {...props}>
      ...
    </span>
  );
}
