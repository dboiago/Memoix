import * as React from "react";

export function InputOTP({ ...props }: any) {
  return <input {...props} />;
}

export function InputOTPGroup({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>;
}

export function InputOTPSlot({ index }: { index: number }) {
  return <div data-index={index} />;
}

export function InputOTPSeparator() {
  return <div>-</div>;
}
