import { BrowserRouter, Routes, Route, useNavigate } from 'react-router';
import { AuthProvider, useAuth } from './context/AuthContext';
import Shell from './components/Shell';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Account from './pages/Account';
import EstablishmentList from './pages/modules/EstablishmentList';
import EstablishmentDetail from './pages/modules/EstablishmentDetail';
import EmployeeList from './pages/modules/EmployeeList';
import EmployeeDetail from './pages/modules/EmployeeDetail';
import IncidentList from './pages/modules/IncidentList';
import IncidentDetail from './pages/modules/IncidentDetail';
import ChemicalList from './pages/modules/ChemicalList';
import TrainingList from './pages/modules/TrainingList';
import InspectionList from './pages/modules/InspectionList';
import PermitList from './pages/modules/PermitList';
import WasteList from './pages/modules/WasteList';
import PPEList from './pages/modules/PPEList';

/** Temporary stub rendered for /:module/:id routes until detail pages are built (Tasks 6-8). */
function DetailStub() {
  const navigate = useNavigate();
  return (
    <div className="flex flex-col items-center justify-center gap-4 p-12 text-[var(--color-text-muted)]">
      <span className="text-3xl">⬡</span>
      <p className="text-sm">Detail view loading…</p>
      <button
        onClick={() => navigate(-1)}
        className="text-xs text-[var(--color-accent-light)] hover:underline"
      >
        ← Back
      </button>
    </div>
  );
}

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

          <Route path="establishments" element={<EstablishmentList />} />
          <Route path="establishments/:id" element={<EstablishmentDetail />} />

          <Route path="employees" element={<EmployeeList />} />
          <Route path="employees/:id" element={<EmployeeDetail />} />

          <Route path="incidents" element={<IncidentList />} />
          <Route path="incidents/:id" element={<IncidentDetail />} />

          <Route path="chemicals" element={<ChemicalList />} />
          <Route path="chemicals/:id" element={<DetailStub />} />

          <Route path="training" element={<TrainingList />} />
          <Route path="training/:id" element={<DetailStub />} />

          <Route path="inspections" element={<InspectionList />} />
          <Route path="inspections/:id" element={<DetailStub />} />

          <Route path="permits" element={<PermitList />} />
          <Route path="permits/:id" element={<DetailStub />} />

          <Route path="waste" element={<WasteList />} />
          <Route path="waste/:id" element={<DetailStub />} />

          <Route path="ppe" element={<PPEList />} />
          <Route path="ppe/:id" element={<DetailStub />} />

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
