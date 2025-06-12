

import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import Papa from "papaparse";
import { API_ENDPOINTS } from "../../../src/constants/apiconfig/apiconfig";
import Loadingspinner from "../../M2VIZ/components/UI/Loading"
import { AlertCircle, X } from "lucide-react";
import Breadcrumbs from "../constants/breadcrumbs";
import { Download } from "lucide-react";
import { UploadCloud } from 'lucide-react';

const SubmissionForm_dna = () => {
  const [fileName, setFileName] = useState("");
  const [isHovered, setIsHovered] = useState(false);
  const [tableData, setTableData] = useState([]);
  const [headers, setHeaders] = useState([]);
  const [errorMessage, setErrorMessage] = useState("");
  const navigate = useNavigate();
  const location = useLocation();
  const [isLoading, setIsLoading] = useState(false);
  const [downloadBlob, setDownloadBlob] = useState(null);
  const [downloadFilename, setDownloadFilename] = useState("");
  const [showErrorModal, setShowErrorModal] = useState(false);

  const [formData, setFormData] = useState({
    ENSG: "",
    file: null,
  });

  const [selectedOption, setSelectedOption] = useState(location.state?.selectedOption || "dna");

   const closeErrorModal = () => {
    setShowErrorModal(false);
    setErrorMessage("");
  };


useEffect(() => {
  if (location.state) {
    localStorage.setItem("submissionFormState", JSON.stringify(location.state));
    setSelectedOption(location.state?.selectedOption || "dna");
  } else {
    const saved = JSON.parse(localStorage.getItem("submissionFormState") || "{}");
    setSelectedOption(saved.selectedOption || "dna");
  }
}, [location.state]);


  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage(""); // Clear previous error

    if (!formData.file) {
      setErrorMessage("Please upload a file before submitting.");
      setShowErrorModal(true);
      return;
    }
    if (!formData.ENSG || formData.ENSG.trim() === "") {
  setErrorMessage("Please enter an ENSG before submitting.");
  setShowErrorModal(true);
  return;
}



    setIsLoading(true);

    const reader = new FileReader();
    reader.onload = async ({ target }) => {
      Papa.parse(target.result, {
        header: true,
        skipEmptyLines: false,
        complete: async (result) => {
          const rows = result.data;

          if (!rows.length) {
            setErrorMessage("The uploaded CSV appears empty.");
            setShowErrorModal(true);
            setIsLoading(false);
            return;
          }

// Find last non-empty row index
const lastNonEmptyRowIndex = (() => {
  for (let i = rows.length - 1; i >= 0; i--) {
    const values = Object.values(rows[i]).map((val) => val?.trim?.() || "");
    if (!values.every((v) => v === "")) {
      return i;
    }
  }
  return -1; // all empty rows?
})();

for (let i = 0; i <= lastNonEmptyRowIndex; i++) {
  const row = rows[i];
  const values = Object.values(row).map((val) => val?.trim?.() || "");

  if (values.every((v) => v === "")) {
    setErrorMessage(`Row ${i + 2} is completely empty. Please remove it.`);
                  setShowErrorModal(true);

    setIsLoading(false);
    return;
  }

  if (values.some((v) => v === "")) {
    setErrorMessage(`Row ${i + 2} contains empty fields. Please fill or remove them.`);
                  setShowErrorModal(true);

    setIsLoading(false);
    return;
  }
}


          const data = new FormData();
          data.append("ENSG", formData.ENSG);
          data.append("csv_file", formData.file);

          try {
            const response = await fetch(API_ENDPOINTS.POST_DNA_OUTPUT, {
              method: "POST",
              body: data,
            });

            const contentType = response.headers.get("Content-Type");

            if (!response.ok) {
              if (contentType && contentType.includes("application/json")) {
                const errorJson = await response.json();
                setErrorMessage(errorJson.detail || "An error occurred during processing.");
              } else {
                const text = await response.text();
                setErrorMessage(" Please check your internet connection or try again later.");
                console.error("Server error:", text);
              }
            setShowErrorModal(true);

              return;
            }

            const result = await response.json();
          if (result.plot_img_base64) {
            const category = location.state?.category || "dna";
            
const savedState = JSON.parse(localStorage.getItem("submissionFormState") || "{}");
const selectedType = savedState.selectedType || "profile";

           navigate(`/m2viz/${category}/${selectedOption}/${selectedType}/${formData.ENSG}`, {
  state: {
    plotImage: result.plot_img_base64,
    selectedOption,
    selectedType,
    category
  },
});


             
            } else {
              setErrorMessage("No plot returned. Please check your input.");
            }
          } catch (err) {
            console.error("Network error:", err);
            setErrorMessage("Network error. Please try again later.");
            setShowErrorModal(true);
          } finally {
            setIsLoading(false);
          }
        },
      });
    };

    reader.readAsText(formData.file);
  };

  const handleFileUpload = (file) => {
    if (!file) return;
    setFileName(file.name);
    setFormData({ ...formData, file });
    setErrorMessage("");

   };

const handleLoadExample = async () => {
  const savedState = (() => {
    try {
      return JSON.parse(localStorage.getItem("submissionFormState")) || {};
    } catch {
      return {};
    }
  })();

  const type = savedState.selectedType;
  const option = selectedOption;

  if (!type) {
    alert("Could not determine selected type (profile/differential). Please reload.");
    return;
  }

  let filePath = "";
  const ensg = "ENSG00000149269"; 

  if (option === "dna-methylation" && type === "profile") {
    filePath = "/assets/lollipop/DNA_methylation_profile.csv";
  } else if (option === "dna-methylation" && type === "differential") {
    filePath = "/assets/lollipop/DNA_methylation_diff.csv";
  } else if (option === "snv" && type === "profile") {
    filePath = "/assets/lollipop/DNA_SNVs_profile.csv";
  } else if (option === "snv" && type === "differential") {
    filePath = "/assets/lollipop/DNA_SNVs_diff.csv";
  } else {
    alert("Invalid example selection.");
    return;
  }

  try {
    const response = await fetch(filePath);
    if (!response.ok) throw new Error("Failed to load example CSV");

    const csvText = await response.text();

    Papa.parse(csvText, {
      header: true,
      skipEmptyLines: true,
      complete: (result) => {
        if (!result.data.length) {
          alert("No data found in example CSV.");
          return;
        }

        const fileName = filePath.split("/").pop();
        const blob = new Blob([csvText], { type: "text/csv" });
        const csvFile = new File([blob], fileName, { type: "text/csv" });

        setFormData({ ENSG: ensg, file: csvFile });
        setFileName(fileName);
        setHeaders(Object.keys(result.data[0]));
        setTableData(result.data.slice(0, 5));
        setDownloadBlob(blob);
        setDownloadFilename(fileName);
      },
    });
  } catch (error) {
    console.error("Error loading example:", error);
    alert("Could not load example file.");
  }
};


  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <Loadingspinner />
      </div>
    );
  }

return (
  <>
    {/* Error Modal */}
    {showErrorModal && (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
        <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 transform transition-all relative">
          <div className="p-6">
            <div className="flex items-center justify-center w-12 h-12 mx-auto bg-red-100 rounded-full mb-4">
              <AlertCircle className="h-6 w-6 text-purple-700" />
            </div>
            <div className="text-center">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Upload Error</h3>
              <p className="text-gray-600 mb-6">{errorMessage}</p>
            </div>
            <div className="flex justify-center">
              <button
                onClick={closeErrorModal}
                className="px-6 py-2 bg-purple-500 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
                Try Again
              </button>
            </div>
            <button
              onClick={closeErrorModal}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    )}

    {/* Breadcrumbs fixed top-left */}
    <div className="fixed top-16 left-4 z-50 p-2 max-w-xs">
      <Breadcrumbs />
    </div>

    <div className="min-h-screen flex items-center justify-center bg-gray-100 p-4 pt-20 sm:pt-24 md:pt-28 lg:pt-32 xl:pt-32">

      <div className="bg-white shadow-xl rounded-2xl p-8 w-full max-w-lg">
        <h2 className="text-3xl font-bold text-center text-gray-800 mb-6">Upload Your File</h2>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* ENSG Input */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">ENSG </label>
            <input
              type="text"
              name="ENSG"
              value={formData.ENSG}
              onChange={(e) => setFormData({ ...formData, ENSG: e.target.value })}
              placeholder="Enter ENSG "
              className="block w-full px-4 py-2 border rounded-lg shadow-sm focus:ring-purple-500 focus:border-purple-500"
            />
          </div>

          {/* File Upload */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Upload CSV File</label>
            <div
              className={`border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-all ${
                isHovered ? "border-purple-500 bg-purple-50" : "border-gray-300"
              }`}
              onDragOver={(e) => {
                e.preventDefault();
                setIsHovered(true);
              }}
              onDragLeave={() => setIsHovered(false)}
              onDrop={(e) => {
                e.preventDefault();
                setIsHovered(false);
                const file = e.dataTransfer.files[0];
                handleFileUpload(file);
              }}
              onClick={() => document.getElementById("file")?.click()}

            >
              <p className="text-gray-600">{fileName || "Drop file here or click to upload"}</p>
              <input
                id="file"
                type="file"
                accept=".csv"
                className="hidden"
                onChange={(e) => handleFileUpload(e.target.files?.[0])}
              />
           

<div className="flex justify-center">
  <UploadCloud
    className="mt-3 w-6 h-6 text-purple-600 cursor-pointer"
    onClick={() => document.getElementById("file")?.click()}

  />
</div>



            </div>
          </div>

          {/* Preview */}
        {tableData.length > 0 && (
  <div className="mt-4 p-4 border border-gray-300 rounded-lg bg-white shadow-lg relative">
    {/* Close preview button */}
    <button
      onClick={() => {
        setFileName("");
        setFormData({ ...formData, file: null });
        setTableData([]);
        setHeaders([]);
        setDownloadBlob(null);
        setDownloadFilename("");
      }}
      className="absolute top-2 right-2 text-gray-500 hover:text-red-600 text-xl font-bold focus:outline-none"
      aria-label="Close preview"
    >
      &times;
    </button>

    {/* Table */}
    <div className="overflow-x-auto mt-4">
      <table className="min-w-full border-collapse border border-gray-300 text-sm">
        <thead>
          <tr className="bg-gray-200">
            {headers.map((header) => (
              <th key={header} className="border border-gray-300 px-2 py-1 text-center">
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {tableData.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {headers.map((header) => (
                <td key={header} className="border px-2 py-1 text-center">
                  {row[header]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>

{downloadBlob && downloadFilename && (
  <div className="mt-3 flex justify-end pr-2">
    <a
      href={URL.createObjectURL(downloadBlob)}
      download={downloadFilename}
      title="Download Example CSV"
      className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-purple-100 transition-colors"
    >
      <Download className="w-5 h-5" />
    </a>
  </div>
)}

  </div>
)}

            

          {/* Buttons */}
            <div className="flex flex-col  sm:flex-row sm:space-y-0 sm:space-x-4">
              <button
                type="button"
                className="w-full sm:w-1/2 py-2 bg-purple-100 text-purple-700 border border-purple-300 rounded-md hover:bg-purple-200"
                onClick={handleLoadExample}
              >
                Load Example
              </button>
              <button
                type="submit"
                className="w-full sm:w-1/2 py-2 bg-purple-600 text-white text-lg font-semibold rounded-md hover:bg-purple-700 transition-colors focus:outline-none focus:ring-2 focus:ring-purple-400"
              >
                Submit
              </button>
            </div>
        </form>
      </div>
    </div>
  </>
);


};

export default SubmissionForm_dna;
