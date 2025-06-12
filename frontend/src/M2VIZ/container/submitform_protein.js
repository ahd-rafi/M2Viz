
import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import Papa from "papaparse";
import { API_ENDPOINTS } from "../../constants/apiconfig/apiconfig";
import Loadingspinner from "../components/UI/Loading";
import { AlertCircle, X, Download, UploadCloud } from "lucide-react";
import Breadcrumbs from '../constants/breadcrumbs';

const SubmissionFormProtein = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [fileName, setFileName] = useState("");
  const [isHovered, setIsHovered] = useState(false);
  const [tableData, setTableData] = useState([]);
  const [headers, setHeaders] = useState([]);
  const [errorMessage, setErrorMessage] = useState("");
  const [showErrorModal, setShowErrorModal] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedEndpoint, setSelectedEndpoint] = useState(null);
  const [downloadBlob, setDownloadBlob] = useState(null);
  const [downloadFilename, setDownloadFilename] = useState("");

  const [formData, setFormData] = useState({
    ACCESSION: "",
    file: null,
  });

  const [selectedFeatures, setSelectedFeatures] = useState([]);

const [selectedOption, setSelectedOption] = useState(location.state?.selectedOption || "protein");


  const closeErrorModal = () => {
    setShowErrorModal(false);
    setErrorMessage("");
  };

useEffect(() => {
  const savedState = location.state ?? (() => {
    try {
      return JSON.parse(localStorage.getItem("submissionFormState"));
    } catch {
      return null;
    }
  })();

  if (savedState) {
    setSelectedOption(savedState.selectedOption || "protein");

    const { selectedType } = savedState;
    const determineEndpoint = (selectedType) =>
      selectedType === "profile"
        ? API_ENDPOINTS.POST_PROTEIN_P_OUTPUT
        : API_ENDPOINTS.POST_PROTEIN_D_OUTPUT;

    setSelectedEndpoint({ endpoint: determineEndpoint(selectedType) });

    // ✅ Save state to localStorage to ensure it persists after navigating back
    localStorage.setItem("submissionFormState", JSON.stringify(savedState));
  }
}, [location.state]);



  const handleFeatureChange = (feature) => {
    setSelectedFeatures((prev) =>
      prev.includes(feature) ? prev.filter((f) => f !== feature) : [...prev, feature]
    );
  };


const handleSubmit = async (e) => {
  e.preventDefault();
  setErrorMessage("");


  if (!formData.file) {
  setErrorMessage("Please upload a file before submitting.");
  setShowErrorModal(true);
  return;
}

if (selectedFeatures.length === 0) {
  setErrorMessage("Please select at least one feature before submitting.");
  setShowErrorModal(true);
  return;
}


if (!formData.ACCESSION || formData.ACCESSION.trim() === "") {
  setErrorMessage("Please enter an accession before submitting.");
  setShowErrorModal(true);
  return;
}
if (!selectedEndpoint || !selectedEndpoint.endpoint) {
  setErrorMessage("Submission endpoint not set. Please reload the page.");
  setShowErrorModal(true);
  setIsLoading(false);
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

        const lastNonEmptyRowIndex = (() => {
          for (let i = rows.length - 1; i >= 0; i--) {
            const values = Object.values(rows[i]).map((val) => val?.trim?.() || "");
            if (!values.every((v) => v === "")) return i;
          }
          return -1;
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
        data.append("ACCESSION", formData.ACCESSION);
        data.append("csv_file", formData.file);

        // NEW: convert selectedFeatures to a dictionary with true/false for all possible features
const allFeatures = ["Region", "Domain", "Repeat", "Compositional bias", "Coiled coil", "Motif"];

const featuresDict = allFeatures.reduce((acc, feature) => {
  acc[feature] = selectedFeatures.includes(feature);
  return acc;
}, {});


data.append("feature_type", JSON.stringify(featuresDict));

        console.log("Submitting features as dict:", featuresDict);


try {
  const response = await fetch(selectedEndpoint.endpoint, {
    method: "POST",
    body: data,
  });

  if (!response.ok) {
    const errorJson = await response.json();
    setErrorMessage(errorJson.error || "An error occurred during processing.");
    setShowErrorModal(true);
    return;
  }

  const result = await response.json();
  if (result.plot_img_base64) {
    const category = location.state?.category || "protein";

    const savedState = JSON.parse(localStorage.getItem("submissionFormState") || "{}");
    const selectedType = savedState.selectedType || "profile";

    navigate(`/m2viz/${category}/${selectedOption}/${selectedType}/${formData.ACCESSION}`, {
      state: {
        plotImage: result.plot_img_base64,
        selectedOption,
        selectedType,
        category
      },
    });
  } else {
    alert("Submission succeeded but no plot was returned.");
  }
} catch (error) {
  console.error("Network error:", error);
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
  const option = selectedOption;

  const savedState = (() => {
    try {
      return JSON.parse(localStorage.getItem("submissionFormState")) || {};
    } catch {
      return {};
    }
  })();

  const type = savedState.selectedType || "profile";

  if (!savedState.selectedType) {
    alert("Could not determine selected type (profile/differential). Please reload.");
    return;
  }

  let filePath = "";
  let accession = "Q14669";

  if (option === "ptm" && type === "profile") {
    filePath = "/assets/lollipop/PROT_ptm_profile.csv";
  } else if (option === "ptm" && type === "differential") {
    filePath = "/assets/lollipop/PROT_ptm_diff.csv";
  } else if (option === "saav" && type === "profile") {
    filePath = "/assets/lollipop/PROT_SAAVs_profile.csv";
  } else if (option === "saav" && type === "differential") {
    filePath = "/assets/lollipop/PROT_SAAVs_diff.csv";
  } else {
    alert("Invalid example selection.");
    return;
  }

  setSelectedEndpoint({
    endpoint:
      type === "profile"
        ? API_ENDPOINTS.POST_PROTEIN_P_OUTPUT
        : API_ENDPOINTS.POST_PROTEIN_D_OUTPUT,
  });

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

        setFormData({ ACCESSION: accession, file: csvFile });
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
                <AlertCircle className="h-6 w-6 text-purple-600" />
              </div>
              <div className="text-center">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Upload Error</h3>
                <p className="text-gray-600 mb-6">{errorMessage}</p>
              </div>
              <div className="flex justify-center">
                <button
                  onClick={closeErrorModal}
                  className="px-6 py-2 bg-purple-500 text-white rounded-md hover:bg-purple-700 focus:outline-none"
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

      <div className="fixed top-16 left-4 z-50 p-2 max-w-xs">
        <Breadcrumbs />
      </div>

    <div className="min-h-screen flex items-center justify-center bg-gray-100 p-4 pt-20 sm:pt-24 md:pt-28 lg:pt-32 xl:pt-32">
        <div className="bg-white shadow-lg rounded-lg p-8 w-full max-w-md">
          <h2 className="text-2xl font-bold text-center text-gray-800">Upload Your File</h2>
          <form onSubmit={handleSubmit} className="space-y-4 pt-8">
            <div>
              <label className="block text-sm font-medium text-gray-700">ACCESSION </label>
              <input
                type="text"
                name="ACCESSION"
                value={formData.ACCESSION}
                onChange={(e) => setFormData({ ...formData, ACCESSION: e.target.value })}
                placeholder="Enter ACCESSION"
                className="mt-1 block w-full p-2 border rounded-md"
              />
            </div>

            

            <div>
              <label className="block text-sm font-medium text-gray-700">Upload CSV File</label>
              <div
                className={`border-2 border-dashed rounded-lg p-6 text-center transition-all ${
                  isHovered ? "border-blue-500 bg-blue-50" : "border-gray-300"
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
  if (!file.name.endsWith(".csv")) {
    alert("Only CSV files are supported.");
    return;
  }
  handleFileUpload(file);
}}

              >
                <p className="text-gray-600">{fileName || "Drop your file here or click to upload"}</p>
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
            {/* Multiple Checkbox Input */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Select  Structural Features</label>
              <div className="grid grid-cols-2 gap-2">
                {["Region", "Domain", "Repeat", "Compositional bias", "Coiled coil", "Motif"].map((feature) => (
                  <label key={feature} className="flex items-center space-x-2 text-gray-700">
                    <input
                      type="checkbox"
                      value={feature}
                      checked={selectedFeatures.includes(feature)}
                      onChange={() => handleFeatureChange(feature)}
                      className="form-checkbox text-purple-600"
                    />
                    <span>{feature}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Table Preview */}
            {tableData.length > 0 && (
              <div className="mt-4 p-4 border border-gray-300 rounded-lg bg-white shadow-lg relative">
                <button
                  onClick={() => {
                    setFileName("");
                    setFormData({ ...formData, file: null });
                    setTableData([]);
                    setHeaders([]);
                    setDownloadBlob(null);
                    setDownloadFilename("");
                  }}
                  className="absolute top-2 right-2 text-gray-500 hover:text-red-600 text-xl font-bold"
                  aria-label="Close preview"
                >
                  &times;
                </button>

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

            {/* Submit + Example Buttons */}
            <div className="flex flex-col space-y-4 sm:flex-row sm:space-y-0 sm:space-x-4">
              <button
                type="button"
                className="w-full sm:w-1/2 py-2 bg-purple-100 text-purple-700 border border-purple-300 rounded-md hover:bg-purple-200"
                onClick={handleLoadExample}
              >
                Load Example
              </button>
              <button
                type="submit"
                className="w-full sm:w-1/2 py-2 bg-purple-600 text-white text-lg font-semibold rounded-md hover:bg-purple-700"
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

export default SubmissionFormProtein;
