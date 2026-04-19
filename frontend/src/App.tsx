import { BrowserRouter, Routes, Route } from 'react-router';
import { AuthProvider, useAuth } from './context/AuthContext';
import Shell from './components/Shell';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Account from './pages/Account';
import EstablishmentList from './pages/modules/EstablishmentList';
import EstablishmentDetail from './pages/modules/EstablishmentDetail';
import EstablishmentForm from './pages/modules/EstablishmentForm';
import EmployeeList from './pages/modules/EmployeeList';
import EmployeeDetail from './pages/modules/EmployeeDetail';
import EmployeeForm from './pages/modules/EmployeeForm';
import IncidentList from './pages/modules/IncidentList';
import IncidentDetail from './pages/modules/IncidentDetail';
import IncidentForm from './pages/modules/IncidentForm';
import ChemicalList from './pages/modules/ChemicalList';
import ChemicalDetail from './pages/modules/ChemicalDetail';
import ChemicalForm from './pages/modules/ChemicalForm';
import TrainingList from './pages/modules/TrainingList';
import TrainingDetail from './pages/modules/TrainingDetail';
import InspectionList from './pages/modules/InspectionList';
import InspectionDetail from './pages/modules/InspectionDetail';
import InspectionForm from './pages/modules/InspectionForm';
import PermitList from './pages/modules/PermitList';
import PermitDetail from './pages/modules/PermitDetail';
import PermitForm from './pages/modules/PermitForm';
import WasteList from './pages/modules/WasteList';
import WasteDetail from './pages/modules/WasteDetail';
import PPEList from './pages/modules/PPEList';
import PPEDetail from './pages/modules/PPEDetail';
import UsersList from './pages/admin/UsersList';
import UserForm from './pages/admin/UserForm';
import { AdminOnly } from './components/AdminOnly';


function AppRoutes() {
  const { user, readonly, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[var(--color-bg)]">
        <span className="text-[var(--color-comment)] text-sm">Loading...</span>
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
          <Route path="establishments/new" element={<EstablishmentForm />} />
          <Route path="establishments/:id" element={<EstablishmentDetail />} />
          <Route path="establishments/:id/edit" element={<EstablishmentForm />} />

          <Route path="employees" element={<EmployeeList />} />
          <Route path="employees/new" element={<EmployeeForm />} />
          <Route path="employees/:id" element={<EmployeeDetail />} />
          <Route path="employees/:id/edit" element={<EmployeeForm />} />

          <Route path="incidents" element={<IncidentList />} />
          <Route path="incidents/new" element={<IncidentForm />} />
          <Route path="incidents/:id" element={<IncidentDetail />} />
          <Route path="incidents/:id/edit" element={<IncidentForm />} />

          <Route path="chemicals" element={<ChemicalList />} />
          <Route path="chemicals/new" element={<ChemicalForm />} />
          <Route path="chemicals/:id" element={<ChemicalDetail />} />
          <Route path="chemicals/:id/edit" element={<ChemicalForm />} />

          <Route path="training" element={<TrainingList />} />
          <Route path="training/:id" element={<TrainingDetail />} />

          <Route path="inspections" element={<InspectionList />} />
          <Route path="inspections/new" element={<InspectionForm />} />
          <Route path="inspections/:id" element={<InspectionDetail />} />
          <Route path="inspections/:id/edit" element={<InspectionForm />} />

          <Route path="permits" element={<PermitList />} />
          <Route path="permits/new" element={<PermitForm />} />
          <Route path="permits/:id" element={<PermitDetail />} />
          <Route path="permits/:id/edit" element={<PermitForm />} />

          <Route path="waste" element={<WasteList />} />
          <Route path="waste/:id" element={<WasteDetail />} />

          <Route path="ppe" element={<PPEList />} />
          <Route path="ppe/:id" element={<PPEDetail />} />

          <Route path="account" element={<Account />} />

          <Route path="admin/users" element={<AdminOnly><UsersList /></AdminOnly>} />
          <Route path="admin/users/new" element={<AdminOnly><UserForm /></AdminOnly>} />
          <Route path="admin/users/:id/edit" element={<AdminOnly><UserForm /></AdminOnly>} />
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
