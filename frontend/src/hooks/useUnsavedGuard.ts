import { useEffect } from 'react';

/**
 * Warn the user before they close the tab or navigate away (hard
 * navigation) while a form is dirty.
 *
 * In-app route changes are not blocked here — that requires migrating
 * the app to react-router's data router (createBrowserRouter) so
 * useBlocker becomes available. For now this only covers the browser
 * beforeunload path, which is the more common loss-of-work scenario.
 */
export function useUnsavedGuard(dirty: boolean) {
  useEffect(() => {
    if (!dirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [dirty]);
}
