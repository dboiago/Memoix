import * as React from "react";

export function Pagination({ children, className }: { children: React.ReactNode; className?: string }) {
  return <nav className={className}>{children}</nav>;
}

export function PaginationContent({ children, className }: { children: React.ReactNode; className?: string }) {
  return <ul className={className}>{children}</ul>;
}

export function PaginationItem({ children, className }: { children: React.ReactNode; className?: string }) {
  return <li className={className}>{children}</li>;
}

export function PaginationLink({ children, className }: { children: React.ReactNode; className?: string }) {
  return <a className={className}>{children}</a>;
}

export function PaginationPrevious({ children, className }: { children?: React.ReactNode; className?: string }) {
  return <a className={className}>{children || "Previous"}</a>;
}

export function PaginationNext({ children, className }: { children?: React.ReactNode; className?: string }) {
  return <a className={className}>{children || "Next"}</a>;
}

export function PaginationEllipsis({ className }: { className?: string }) {
  return <span className={className}>...</span>;
}
