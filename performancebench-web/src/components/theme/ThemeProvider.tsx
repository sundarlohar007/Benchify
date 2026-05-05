import { type ReactNode } from 'react';

interface ThemeProviderProps {
  children: ReactNode;
}

/**
 * v2.0 is VS Code Dark+ only (D-41: no theme toggle).
 * The theme is applied via CSS custom properties in index.css.
 * This provider exists for future extensibility.
 */
export function ThemeProvider({ children }: ThemeProviderProps) {
  return <>{children}</>;
}
