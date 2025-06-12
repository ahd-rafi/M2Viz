import React, { useState, useEffect } from "react";
import Loadingspinner from "../components/UI/Loading";

const Faqs = () => {
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simulate loading delay or replace with your data loading logic
    const timer = setTimeout(() => setLoading(false), 300);

    return () => clearTimeout(timer);
  }, []);

  if (loading) {
    return (
      <div className="fixed top-0 left-0 w-full h-full flex items-center justify-center bg-white bg-opacity-75 z-50">
        <Loadingspinner />
      </div>
    );
  }
  return (
    <div className="pt-12">
      <div className=" mt-10 mb-10 p-6 rounded-lg ">
        <div className="max-w-7xl mx-auto">
          <div className="space-y-6">
            <h4 className="text-2xl font-semibold">FAQs</h4>

            <div className="p-6 text-justify text-gray-800">
  {/* Section 1 */}
  <h4 className="text-xl font-bold mb-2">1. What is M2Viz?</h4>
  <p className="text-base mb-6 leading-relaxed">
M2Viz is a web-based application designed for creating publication-ready lollipop plots 
representing DNA methylation, Single Nucleotide Variations (SNVs), protein Post-Translational 
Modifications (PTMs), and Single Amino Acid Variations (SAAVs). Additionally, tool can be accessed to
 represent profiling and differential expression/regulation datasets, with options for visualizing numerical data. 

  </p>

  {/* Section 2 */}
  <h4 className="text-xl font-bold mb-2">2. Why M2Viz?</h4>
  <p className="text-base mb-6 leading-relaxed">
The tool provides end-to-end solution for uploading, processing, annotating and graphical representation.
 The system integrates a Python-Django backend for data handling, an R-based engine for advanced plotting, 
 and a React.js frontend for a responsive and interactive user experience. Nucleotide or amino acid sequences
  and respective structural features (introns, exons, proteins domains and regions) are retrieved through RESTful
   API from Ensembl and UniProt, respectively. 

  </p>

  {/* Section 3 */}
  <h4 className="text-xl font-bold mb-2">3. How to use M2Viz?</h4>
  <p className="text-base mb-6 leading-relaxed">
 Users can input the protein/gene identifier along with expression data to visualize the lollipop plots.
  Users will be able to download the input file formats on respective windows. Plots will be generated 
  and downloadable in SVG format.

  </p>

  {/* Section 4 */}
  <h4 className="text-xl font-bold mb-2">4. How do we cite M2Viz?</h4>
  <p className="text-base leading-relaxed">
    Please cite the following article:&nbsp;
    <a
      href="https://doi.org/10.xxxx/rafi2025" // Replace with actual DOI
      target="_blank"
      rel="noopener noreferrer"
      className="text-blue-600 underline hover:text-blue-800"
    >
      Rafi et al., (2025)
    </a>.
  </p>
</div>

          </div>
        </div>
      </div>
    </div>
  );
};

export default Faqs;


