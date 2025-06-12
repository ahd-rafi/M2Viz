
import { useLocation } from "react-router-dom";
import { useState, useEffect } from "react";
import React from "react";
import Breadcrumbs from "../constants/breadcrumbs";

const AutoCropImage = ({ base64Image, setLoadError }) => {
  const [croppedImage, setCroppedImage] = useState(null);

  useEffect(() => {
    const img = new Image();
    img.src = base64Image;

    img.onload = () => {
      const canvas = document.createElement("canvas");
      const ctx = canvas.getContext("2d");
      canvas.width = img.width;
      canvas.height = img.height;
      ctx.drawImage(img, 0, 0);

      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const data = imageData.data;

      let top = canvas.height, bottom = 0, left = canvas.width, right = 0;

      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          const i = (y * canvas.width + x) * 4;
          const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
          const isWhite = r > 240 && g > 240 && b > 240 && a > 0;

          if (!isWhite) {
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }

      // Add margin (~3cm ≈ 113px at 96dpi)
      const margin = 113;
      top = Math.max(0, top - margin);
      left = Math.max(0, left - margin);
      bottom = Math.min(canvas.height, bottom + margin);
      right = Math.min(canvas.width, right + margin);

      const croppedWidth = right - left;
      const croppedHeight = bottom - top;

      const croppedCanvas = document.createElement("canvas");
      croppedCanvas.width = croppedWidth;
      croppedCanvas.height = croppedHeight;

      const croppedCtx = croppedCanvas.getContext("2d");
      croppedCtx.drawImage(
        canvas,
        left, top,
        croppedWidth, croppedHeight,
        0, 0,
        croppedWidth, croppedHeight
      );

      const croppedDataUrl = croppedCanvas.toDataURL("image/png");
      setCroppedImage(croppedDataUrl);
    };

    img.onerror = () => {
      console.error(" Image failed to load! Check Base64.");
      setLoadError(true);
    };
  }, [base64Image, setLoadError]);

  return croppedImage ? (
    <img
      src={croppedImage}
      alt="Lollipop Plot"
      className="mx-auto border p-2 shadow-md"
    />
  ) : (
    <p className="text-gray-400 italic">Processing image...</p>
  );
};

const LollipopPlotDownload = () => {
  const location = useLocation();
  const [plotImage, setPlotImage] = useState(null);
  const [width, setWidth] = useState(1000);
  const [height, setHeight] = useState(600);
  const [loadError, setLoadError] = useState(false);
  const [error, setError] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    if (location.state?.plotImage) {
      const base64String = location.state.plotImage.trim();
      console.log(" Received Backend Image Data:", base64String);

      const base64Payload = base64String.split(",")[1] || "";
      const decodedPayload = atob(base64Payload || "");
      if (decodedPayload.startsWith("500") || decodedPayload.toLowerCase().includes("server error")) {
        console.error(" Backend Error Detected in Image Data:", decodedPayload);
        setError(true);
        setErrorMessage(decodedPayload);
        return;
      }

      if (base64String.startsWith("data:image/svg+xml;base64,")) {
        setPlotImage(base64String);
        console.log(" Valid base64 image with prefix");
      } else if (/^[A-Za-z0-9+/=]+$/.test(base64String)) {
        const formatted = "data:image/svg+xml;base64," + base64String;
        setPlotImage(formatted);
        console.log(" Raw base64 detected, prefix added");
      } else {
        console.error(" Invalid Image Format:", base64String.slice(0, 100));
        setError(true);
        setErrorMessage("Invalid image format.");
      }
    } else {
      console.error("No Image Data Found!");
      setError(true);
      setErrorMessage("No image data found.");
    }
  }, [location.state]);

  useEffect(() => {
    setLoadError(false);
  }, [plotImage]);

const handleDownload = () => {
 if (!plotImage) return;

 try {
  const svgData = atob(plotImage.split(",")[1]);
  const updatedSvg = svgData
   .replace(/width="[^"]+"/, `width="${width}"`)
   .replace(/height="[^"]+"/, `height="${height}"`);

  const updatedBase64 = "data:image/svg+xml;base64," + btoa(updatedSvg);

  const link = document.createElement("a");
  link.href = updatedBase64;

  // Extract the last part of the URL
  const urlPath = window.location.pathname.split('/');
  const fileName = urlPath[urlPath.length - 1] || 'lollipop_plot';

  // Use the extracted part as the file name
  link.download = `${fileName}.svg`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  console.log(" Download Successful!");
 } catch (error) {
  console.error(" Error downloading image:", error);
  alert("Error downloading plot. Try again.");
 }
};

  const updatePreview = () => {
    setLoadError(false);
    if (plotImage) {
      try {
        const svgData = atob(plotImage.split(",")[1]);
        const updatedSvg = svgData
          .replace(/width="[^"]+"/, `width="${width}"`)
          .replace(/height="[^"]+"/, `height="${height}"`);
        const updatedBase64 = "data:image/svg+xml;base64," + btoa(updatedSvg);
        setPlotImage(updatedBase64);
      } catch (error) {
        console.error(" Error updating preview:", error);
      }
    }
  };

  return (
    <div className="text-center pt-32 bg-gray-50 min-h-screen">
             <div className="fixed top-16 left-4 z-50 p-2 max-w-xs">
         <Breadcrumbs />
       </div>

      {/* Width & Height Form */}
      <div className=" p-4 rounded-md inline-block">
        <label className="mr-2">Width:</label>
        <input
          type="number"
          value={width}
          onChange={(e) => setWidth(Number(e.target.value))}
          min="600"
          max="2000"
          className="border p-1 rounded-md w-20 text-center"
        />
        <label className="ml-4 mr-2">Height:</label>
        <input
          type="number"
          value={height}
          onChange={(e) => setHeight(Number(e.target.value))}
          min="400"
          max="1200"
          className="border p-1 rounded-md w-20 text-center"
        />
        <button
          onClick={updatePreview}
          className="ml-4 px-4 py-2 bg-purple-500 text-white font-semibold rounded-md shadow-md hover:bg-purple-700 transition duration-200"
        >
          Update Preview
        </button>
      </div>

      {/* Lollipop Plot Display */}
      <div className="flex justify-center items-center p-8 rounded-md">
        {plotImage && !loadError && !error ? (
          <AutoCropImage base64Image={plotImage} setLoadError={setLoadError} />
        ) : error ? (
          <pre className="text-red-500 font-medium bg-white px-4 py-2 rounded shadow">
            {errorMessage || "Error loading plot. Invalid or missing image data."}
          </pre>
        ) : (
          <p className="text-gray-500">No plot available. Check your data.</p>
        )}
      </div>

      {/* Download Button */}
      <button
        onClick={handleDownload}
        className="mt-4 mb-4 px-6 py-2 bg-purple-500 text-white font-semibold rounded-md shadow-md hover:bg-purple-700 transition duration-200"
        disabled={!plotImage || error}
      >
        Download Plot
      </button>
    </div>
  );
};

export default LollipopPlotDownload;
