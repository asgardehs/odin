import { BrowserRouter, Routes, Route } from 'react-router';
import { AuthProvider, useAuth } from './context/AuthContext';
import { FacilityProvider } from './context/FacilityContext';
import Shell from './components/Shell';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Account from './pages/Account';
import DevNullPreview from './pages/DevNullPreview';
import Documents from './pages/Documents';
import AdminLanding from './pages/admin/AdminLanding';
import EstablishmentList from './pages/modules/EstablishmentList';
import EstablishmentDetail from './pages/modules/EstablishmentDetail';
import EstablishmentForm from './pages/modules/EstablishmentForm';
import EstablishmentsHub from './pages/modules/EstablishmentsHub';
import EmployeeList from './pages/modules/EmployeeList';
import EmployeeDetail from './pages/modules/EmployeeDetail';
import EmployeeForm from './pages/modules/EmployeeForm';
import EmployeesHub from './pages/modules/EmployeesHub';
import IncidentList from './pages/modules/IncidentList';
import IncidentDetail from './pages/modules/IncidentDetail';
import IncidentForm from './pages/modules/IncidentForm';
import ChemicalList from './pages/modules/ChemicalList';
import ChemicalDetail from './pages/modules/ChemicalDetail';
import ChemicalForm from './pages/modules/ChemicalForm';
import TrainingList from './pages/modules/TrainingList';
import TrainingDetail from './pages/modules/TrainingDetail';
import TrainingForm from './pages/modules/TrainingForm';
import InspectionList from './pages/modules/InspectionList';
import InspectionDetail from './pages/modules/InspectionDetail';
import InspectionForm from './pages/modules/InspectionForm';
import InspectionsHub from './pages/modules/InspectionsHub';
import AuditList from './pages/modules/AuditList';
import AuditDetail from './pages/modules/AuditDetail';
import AuditForm from './pages/modules/AuditForm';
import EmissionUnitList from './pages/modules/EmissionUnitList';
import EmissionUnitDetail from './pages/modules/EmissionUnitDetail';
import EmissionUnitForm from './pages/modules/EmissionUnitForm';
import PermitList from './pages/modules/PermitList';
import PermitDetail from './pages/modules/PermitDetail';
import PermitForm from './pages/modules/PermitForm';
import DischargePointList from './pages/modules/DischargePointList';
import DischargePointDetail from './pages/modules/DischargePointDetail';
import DischargePointForm from './pages/modules/DischargePointForm';
import WaterSampleEventList from './pages/modules/WaterSampleEventList';
import WaterSampleEventDetail from './pages/modules/WaterSampleEventDetail';
import WaterSampleEventForm from './pages/modules/WaterSampleEventForm';
import SWPPPList from './pages/modules/SWPPPList';
import SWPPPDetail from './pages/modules/SWPPPDetail';
import SWPPPForm from './pages/modules/SWPPPForm';
import PermitListNPDES from './pages/modules/PermitListNPDES';
import WasteList from './pages/modules/WasteList';
import WasteDetail from './pages/modules/WasteDetail';
import WasteForm from './pages/modules/WasteForm';
import StorageLocationList from './pages/modules/StorageLocationList';
import StorageLocationDetail from './pages/modules/StorageLocationDetail';
import StorageLocationForm from './pages/modules/StorageLocationForm';
import PPEList from './pages/modules/PPEList';
import PPEDetail from './pages/modules/PPEDetail';
import PPEForm from './pages/modules/PPEForm';
import GenericRecordList from './pages/custom/GenericRecordList';
import GenericRecordDetail from './pages/custom/GenericRecordDetail';
import GenericRecordForm from './pages/custom/GenericRecordForm';
import UsersList from './pages/admin/UsersList';
import UserForm from './pages/admin/UserForm';
import SchemaList from './pages/admin/SchemaList';
import SchemaNew from './pages/admin/SchemaNew';
import SchemaDesigner from './pages/admin/SchemaDesigner';
import ImportPage from './pages/admin/ImportPage';
import ExportPage from './pages/osha-ita/ExportPage';
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

          <Route path="establishments" element={<EstablishmentsHub />} />
          <Route path="establishments/full" element={<EstablishmentList />} />
          <Route path="establishments/new" element={<EstablishmentForm />} />
          <Route path="establishments/:id" element={<EstablishmentDetail />} />
          <Route path="establishments/:id/edit" element={<EstablishmentForm />} />

          <Route path="employees" element={<EmployeesHub />} />
          <Route path="employees/full" element={<EmployeeList />} />
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
          <Route path="training/new" element={<TrainingForm />} />
          <Route path="training/:id" element={<TrainingDetail />} />
          <Route path="training/:id/edit" element={<TrainingForm />} />

          <Route path="inspections" element={<InspectionsHub />} />
          <Route path="inspections/full" element={<InspectionList />} />
          <Route path="inspections/new" element={<InspectionForm />} />
          <Route path="inspections/:id" element={<InspectionDetail />} />
          <Route path="inspections/:id/edit" element={<InspectionForm />} />

          <Route path="audits" element={<AuditList />} />
          <Route path="audits/new" element={<AuditForm />} />
          <Route path="audits/:id" element={<AuditDetail />} />
          <Route path="audits/:id/edit" element={<AuditForm />} />

          <Route path="emission-units" element={<EmissionUnitList />} />
          <Route path="emission-units/new" element={<EmissionUnitForm />} />
          <Route path="emission-units/:id" element={<EmissionUnitDetail />} />
          <Route path="emission-units/:id/edit" element={<EmissionUnitForm />} />

          <Route path="permits" element={<PermitList />} />
          <Route path="permits/npdes" element={<PermitListNPDES />} />
          <Route path="permits/new" element={<PermitForm />} />
          <Route path="permits/:id" element={<PermitDetail />} />
          <Route path="permits/:id/edit" element={<PermitForm />} />

          <Route path="discharge-points" element={<DischargePointList />} />
          <Route path="discharge-points/new" element={<DischargePointForm />} />
          <Route path="discharge-points/:id" element={<DischargePointDetail />} />
          <Route path="discharge-points/:id/edit" element={<DischargePointForm />} />

          <Route path="ww-sample-events" element={<WaterSampleEventList />} />
          <Route path="ww-sample-events/new" element={<WaterSampleEventForm />} />
          <Route path="ww-sample-events/:id" element={<WaterSampleEventDetail />} />
          <Route path="ww-sample-events/:id/edit" element={<WaterSampleEventForm />} />

          <Route path="swpps" element={<SWPPPList />} />
          <Route path="swpps/new" element={<SWPPPForm />} />
          <Route path="swpps/:id" element={<SWPPPDetail />} />
          <Route path="swpps/:id/edit" element={<SWPPPForm />} />

          <Route path="waste" element={<WasteList />} />
          <Route path="waste/new" element={<WasteForm />} />
          <Route path="waste/:id" element={<WasteDetail />} />
          <Route path="waste/:id/edit" element={<WasteForm />} />

          <Route path="ppe" element={<PPEList />} />
          <Route path="ppe/new" element={<PPEForm />} />
          <Route path="ppe/:id" element={<PPEDetail />} />
          <Route path="ppe/:id/edit" element={<PPEForm />} />

          <Route path="storage-locations" element={<StorageLocationList />} />
          <Route path="storage-locations/new" element={<StorageLocationForm />} />
          <Route path="storage-locations/:id" element={<StorageLocationDetail />} />
          <Route path="storage-locations/:id/edit" element={<StorageLocationForm />} />

          {/* Custom (user-built) tables — a single set of metadata-driven
              components serves every cx_* table. */}
          <Route path="custom/:slug" element={<GenericRecordList />} />
          <Route path="custom/:slug/new" element={<GenericRecordForm />} />
          <Route path="custom/:slug/:id" element={<GenericRecordDetail />} />
          <Route path="custom/:slug/:id/edit" element={<GenericRecordForm />} />

          <Route path="account" element={<Account />} />

          <Route path="documents" element={<Documents />} />

          <Route path="admin" element={<AdminOnly><AdminLanding /></AdminOnly>} />

          <Route path="admin/users" element={<AdminOnly><UsersList /></AdminOnly>} />
          <Route path="admin/users/new" element={<AdminOnly><UserForm /></AdminOnly>} />
          <Route path="admin/users/:id/edit" element={<AdminOnly><UserForm /></AdminOnly>} />

          <Route path="admin/schema" element={<AdminOnly><SchemaList /></AdminOnly>} />
          <Route path="admin/schema/new" element={<AdminOnly><SchemaNew /></AdminOnly>} />
          <Route path="admin/schema/:id" element={<AdminOnly><SchemaDesigner /></AdminOnly>} />

          <Route path="admin/import" element={<AdminOnly><ImportPage /></AdminOnly>} />

          <Route path="osha-ita" element={<AdminOnly><ExportPage /></AdminOnly>} />

          {/* Phase 2 component preview — not in nav, not user-facing.
              Delete once Phase 3 wires the real top-level Dashboard. */}
          <Route path="devnull" element={<AdminOnly><DevNullPreview /></AdminOnly>} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <FacilityProvider>
        <AppRoutes />
      </FacilityProvider>
    </AuthProvider>
  );
}
