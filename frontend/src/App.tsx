import { BrowserRouter, Routes, Route } from 'react-router';
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
import ChemicalDetail from './pages/modules/ChemicalDetail';
import TrainingList from './pages/modules/TrainingList';
import TrainingDetail from './pages/modules/TrainingDetail';
import InspectionList from './pages/modules/InspectionList';
import InspectionDetail from './pages/modules/InspectionDetail';
import PermitList from './pages/modules/PermitList';
import PermitDetail from './pages/modules/PermitDetail';
import WasteList from './pages/modules/WasteList';
import WasteDetail from './pages/modules/WasteDetail';
import PPEList from './pages/modules/PPEList';
import PPEDetail from './pages/modules/PPEDetail';


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
          <Route path="chemicals/:id" element={<ChemicalDetail />} />

          <Route path="training" element={<TrainingList />} />
          <Route path="training/:id" element={<TrainingDetail />} />

          <Route path="inspections" element={<InspectionList />} />
          <Route path="inspections/:id" element={<InspectionDetail />} />

          <Route path="permits" element={<PermitList />} />
          <Route path="permits/:id" element={<PermitDetail />} />

          <Route path="waste" element={<WasteList />} />
          <Route path="waste/:id" element={<WasteDetail />} />

          <Route path="ppe" element={<PPEList />} />
          <Route path="ppe/:id" element={<PPEDetail />} />

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
