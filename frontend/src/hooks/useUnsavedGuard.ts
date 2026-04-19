import { useEffect } from 'react';
import { useBlocker } from 'react-router';

/**
 * Warn the user before they navigate away while a form is dirty.
 *
 * Hooks into both the browser's beforeunload event (tab close / hard
 * navigation) and react-router's useBlocker (in-app navigation).
 */
export function useUnsavedGuard(dirty: boolean, message = 'You have unsaved changes. Leave anyway?') {
  useEffect(() => {
    if (!dirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [dirty]);

  const blocker = useBlocker(({ currentLocation, nextLocation }) =>
    dirty && currentLocation.pathname !== nextLocation.pathname
  );

  useEffect(() => {
    if (blocker.state === 'blocked') {
      if (window.confirm(message)) {
        blocker.proceed();
      } else {
        blocker.reset();
      }
    }
  }, [blocker, message]);
}
