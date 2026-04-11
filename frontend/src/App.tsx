import { BrowserRouter, Routes, Route } from 'react-router';
import { AuthProvider, useAuth } from './context/AuthContext';
import Shell from './components/Shell';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Account from './pages/Account';
import Placeholder from './pages/Placeholder';

function AppRoutes() {
  const { user, readonly, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[var(--color-bg-primary)]">
        <span className="text-[var(--color-text-muted)] text-sm">Loading...</span>
      </div>
    );
  }

  if (!user && !readonly) {
    return <Login />;
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Shell />}>
          <Route index element={<Dashboard />} />
          <Route path="establishments" element={<Placeholder />} />
          <Route path="employees" element={<Placeholder />} />
          <Route path="incidents" element={<Placeholder />} />
          <Route path="chemicals" element={<Placeholder />} />
          <Route path="training" element={<Placeholder />} />
          <Route path="inspections" element={<Placeholder />} />
          <Route path="permits" element={<Placeholder />} />
          <Route path="waste" element={<Placeholder />} />
          <Route path="ppe" element={<Placeholder />} />
          <Route path="account" element={<Account />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}
