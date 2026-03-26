

import { useLocation } from "react-router-dom";
import { useState, useEffect } from "react";
import React from "react";
import Breadcrumbs from "../constants/breadcrumbs";

// ── Find tight bounding box of all non-background SVG content ───────────────
const getSvgContentBounds = (svgString, svgW, svgH) => {
  return new Promise((resolve) => {
    const scale = Math.min(1, 1200 / svgW); // downsample large SVGs for speed
    const cw = Math.round(svgW * scale);
    const ch = Math.round(svgH * scale);

    const canvas = document.createElement("canvas");
    canvas.width = cw;
    canvas.height = ch;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, cw, ch);

    const img = new Image();
    let b64;
    try {
      b64 = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgString)));
    } catch {
      b64 = "data:image/svg+xml;base64," + btoa(svgString);
    }
    img.src = b64;

    img.onload = () => {
      ctx.drawImage(img, 0, 0, cw, ch);
      const imageData = ctx.getImageData(0, 0, cw, ch);
      const data = imageData.data;

      let top = ch, bottom = 0, left = cw, right = 0;
      for (let y = 0; y < ch; y++) {
        for (let x = 0; x < cw; x++) {
          const i = (y * cw + x) * 4;
          const r = data[i], g = data[i + 1], b = data[i + 2];
          // anything not near-white is content
          if (!(r > 245 && g > 245 && b > 245)) {
            if (x < left)   left   = x;
            if (x > right)  right  = x;
            if (y < top)    top    = y;
            if (y > bottom) bottom = y;
          }
        }
      }

      if (top >= bottom || left >= right) {
        // nothing found, return full bounds
        resolve({ top: 0, left: 0, bottom: svgH, right: svgW });
        return;
      }

      const padding = 20 / scale; // 20px real-space padding
      resolve({
        left:   Math.max(0,    (left   / scale) - padding),
        top:    Math.max(0,    (top    / scale) - padding),
        right:  Math.min(svgW, (right  / scale) + padding),
        bottom: Math.min(svgH, (bottom / scale) + padding),
      });
    };

    img.onerror = () => resolve({ top: 0, left: 0, bottom: svgH, right: svgW });
  });
};

// ── Build final base64 SVG with cropped viewBox and transparent background ──
const buildBase64 = (svgString, bounds, displayW, displayH) => {
  if (!svgString) return null;
  try {
    const parser = new DOMParser();
    const doc = parser.parseFromString(svgString, "image/svg+xml");
    const svgEl = doc.querySelector("svg");

    const vbW = bounds.right  - bounds.left;
    const vbH = bounds.bottom - bounds.top;

    svgEl.setAttribute("width",  displayW);
    svgEl.setAttribute("height", displayH);
    svgEl.setAttribute("viewBox", `${bounds.left} ${bounds.top} ${vbW} ${vbH}`);
    svgEl.setAttribute("preserveAspectRatio", "xMidYMid meet");

    // Remove any white/opaque background rect elements
    const rects = svgEl.querySelectorAll("rect");
    rects.forEach((rect) => {
      const fill = rect.getAttribute("fill") || rect.style.fill || "";
      const isFullSize =
        (parseFloat(rect.getAttribute("width"))  || 0) >= vbW * 0.8 &&
        (parseFloat(rect.getAttribute("height")) || 0) >= vbH * 0.8;
      if (isFullSize && /^(white|#fff|#ffffff|rgb\(255,\s*255,\s*255\))$/i.test(fill.trim())) {
        rect.setAttribute("fill", "none");
      }
    });

    // Also strip background on the SVG root itself
    svgEl.style.background = "transparent";
    svgEl.setAttribute("style", (svgEl.getAttribute("style") || "") + ";background:transparent");

    const serialized = new XMLSerializer().serializeToString(doc);
    return "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(serialized)));
  } catch {
    return null;
  }
};

// ─────────────────────────────────────────────────────────────────────────────
const LollipopPlotDownload = () => {
  const location = useLocation();

  const [rawSvg,   setRawSvg]   = useState(null);
  const [bounds,   setBounds]   = useState(null);   // cropped content bounds
  const [originalW, setOriginalW] = useState(null);
  const [originalH, setOriginalH] = useState(null);

  const [inputW, setInputW] = useState(1000);
  const [inputH, setInputH] = useState(600);

  const [previewSrc, setPreviewSrc] = useState(null);
  const [appliedW,   setAppliedW]   = useState(1000);
  const [appliedH,   setAppliedH]   = useState(600);

  const [scanning, setScanning] = useState(false);
  const [error,    setError]    = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  // ── Decode + scan SVG on mount ─────────────────────────────────────────
  useEffect(() => {
    const raw = location.state?.plotImage;
    if (!raw) { setError(true); setErrorMessage("No image data found."); return; }

    const base64String = raw.trim();
    const base64Payload = base64String.startsWith("data:")
      ? base64String.split(",")[1]
      : base64String;

    let svgString;
    try {
      svgString = decodeURIComponent(escape(atob(base64Payload)));
    } catch {
      try { svgString = atob(base64Payload); }
      catch { setError(true); setErrorMessage("Invalid image format."); return; }
    }

    if (svgString.startsWith("500") || svgString.toLowerCase().includes("server error")) {
      setError(true); setErrorMessage(svgString); return;
    }

    const parser = new DOMParser();
    const doc = parser.parseFromString(svgString, "image/svg+xml");
    const svgEl = doc.querySelector("svg");
    if (!svgEl) { setError(true); setErrorMessage("Could not parse SVG."); return; }

    const w = parseFloat(svgEl.getAttribute("width"))  || 1000;
    const h = parseFloat(svgEl.getAttribute("height")) || 600;

    setOriginalW(w);
    setOriginalH(h);
    setInputW(w);
    setInputH(h);
    setAppliedW(w);
    setAppliedH(h);
    setRawSvg(svgString);

    // Scan for content bounds to auto-crop whitespace
    setScanning(true);
    getSvgContentBounds(svgString, w, h).then((b) => {
      setBounds(b);
      setScanning(false);
      const src = buildBase64(svgString, b, w, h);
      setPreviewSrc(src);
    });
  }, [location.state]);

  // ── Update Preview on button click ────────────────────────────────────
  const handleUpdatePreview = () => {
    if (!rawSvg || !bounds) return;
    const src = buildBase64(rawSvg, bounds, inputW, inputH);
    if (src) {
      setPreviewSrc(src);
      setAppliedW(inputW);
      setAppliedH(inputH);
    }
  };

  // ── Download ───────────────────────────────────────────────────────────
  const handleDownload = () => {
    if (!previewSrc) return;
    const link = document.createElement("a");
    link.href = previewSrc;
    const parts = window.location.pathname.split("/");
    link.download = `${parts[parts.length - 1] || "lollipop_plot"}.svg`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // ── Render ─────────────────────────────────────────────────────────────
  return (
    <div className="text-center pt-32 bg-gray-50 min-h-screen">
      <div className="fixed top-16 left-4 z-50 p-2 max-w-xs">
        <Breadcrumbs />
      </div>

      {/* Controls */}
      <div className="p-4 rounded-md inline-flex flex-wrap items-center gap-3 bg-white shadow mb-4">
        <label className="text-sm font-medium text-gray-600">Width (px):</label>
        <input
          type="number"
          value={inputW}
          onChange={(e) => setInputW(Number(e.target.value))}
          min="200"
          max="8000"
          className="border p-1 rounded-md w-24 text-center text-sm"
        />

        <label className="text-sm font-medium text-gray-600">Height (px):</label>
        <input
          type="number"
          value={inputH}
          onChange={(e) => setInputH(Number(e.target.value))}
          min="100"
          max="6000"
          className="border p-1 rounded-md w-24 text-center text-sm"
        />

        <button
          onClick={handleUpdatePreview}
          disabled={scanning || !rawSvg}
          className="ml-2 px-4 py-2 bg-purple-500 text-white font-semibold rounded-md shadow-md hover:bg-purple-700 transition duration-200 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {scanning ? "Processing…" : "Update Preview"}
        </button>
      </div>

      {/* Plot display — no white box wrapper, transparent bg */}
      <div className="flex justify-center items-start p-4 overflow-auto">
        {error ? (
          <pre className="text-red-500 font-medium bg-white px-4 py-2 rounded shadow text-left max-w-xl overflow-auto">
            {errorMessage || "Error loading plot. Invalid or missing image data."}
          </pre>
        ) : scanning ? (
          <p className="text-gray-400 italic">Scanning plot content…</p>
        ) : previewSrc ? (
          <img
            src={previewSrc}
            alt="Lollipop Plot"
            width={appliedW}
            height={appliedH}
            style={{ width: appliedW, height: appliedH, display: "block", background: "transparent" }}
            className="mx-auto"
          />
        ) : (
          <p className="text-gray-500">No plot available. Check your data.</p>
        )}
      </div>

      {/* Download */}
      <button
        onClick={handleDownload}
        disabled={!previewSrc || error || scanning}
        className="mt-4 mb-8 px-6 py-2 bg-purple-500 text-white font-semibold rounded-md shadow-md hover:bg-purple-700 transition duration-200 disabled:opacity-40 disabled:cursor-not-allowed"
      >
        Download Plot
      </button>
    </div>
  );
};

export default LollipopPlotDownload;
