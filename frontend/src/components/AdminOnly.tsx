import type { ReactNode } from 'react';
import { Navigate } from 'react-router';
import { useAuth } from '../context/AuthContext';

/**
 * Wraps admin-only routes. Redirects non-admin users back to the
 * dashboard. The backend enforces admin on the API side too; this is
 * just a UX nicety so non-admins don't see an empty/errored admin page.
 */
export function AdminOnly({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  if (!user || user.role !== 'admin') {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}
