import { BrowserRouter, Routes, Route } from 'react-router';
import Shell from './components/Shell';
import Dashboard from './pages/Dashboard';
import Placeholder from './pages/Placeholder';

export default function App() {
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
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
