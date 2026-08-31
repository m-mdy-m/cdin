import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import { BrowserRouter, Route, Routes } from "react-router";
import AboutPage from "./pages/AboutUs.tsx";
import DownloadPage from "./pages/DownloadPage.tsx";
import DocsPage from "./pages/DocsPage.tsx";
import NotFound from "./components/NotFound.tsx";
import Layout from "./pages/Layout.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter basename="/cdin">
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<App />} />
          <Route path="about-us" element={<AboutPage />} />
          <Route path="download" element={<DownloadPage />} />
          <Route path="docs" element={<DocsPage />} />

          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </StrictMode>,
);
