import { useEffect } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import Landing from './pages/Landing.jsx';
import MobileApp from './pages/MobileApp.jsx';
import './App.css';

function HashRedirect() {
  const navigate = useNavigate();
  useEffect(() => {
    if (window.location.hash === '#app') {
      navigate('/app', { replace: true });
    }
  }, [navigate]);
  return null;
}

function App() {
  return (
    <BrowserRouter>
      <HashRedirect />
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/app/*" element={<MobileApp />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
