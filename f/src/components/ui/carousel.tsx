import * as React from "react";

export function Carousel({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CarouselContent({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CarouselItem({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function CarouselPrevious() {
  return <button>Previous</button>;
}

export function CarouselNext() {
  return <button>Next</button>;
}
