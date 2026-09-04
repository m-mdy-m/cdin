import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import { BrowserRouter, Route, Routes } from "react-router";
import AboutPage from "./pages/AboutUs.tsx";
import DownloadPage from "./pages/DownloadPage.tsx";
import DocsPage from "./pages/Docs/DocsPage.tsx";
import DocView from "./pages/Docs/DocView.tsx";
import NotFound from "./components/NotFound.tsx";
import Layout from "./pages/layouts/Layout.tsx";
import DocsLayout from "./pages/layouts/DocsLayout.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter basename="/cdin">
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<App />} />
          <Route path="about-us" element={<AboutPage />} />
          <Route path="download" element={<DownloadPage />} />
          <Route path="*" element={<NotFound />} />
        </Route>

        <Route element={<DocsLayout />}>
          <Route path="docs" element={<DocsPage />} />
          <Route path="docs/:slug" element={<DocView />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </StrictMode>,
);
