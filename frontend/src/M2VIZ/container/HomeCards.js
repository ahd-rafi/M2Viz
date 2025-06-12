

import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { GiDna2 } from "react-icons/gi";
import { FaArrowRight } from "react-icons/fa6";
import Protein from "../../Assets/M2Viz/proteinn (2).png";
import Loadingspinner from "../components/UI/Loading";

const HomeCards = () => {
  const navigate = useNavigate();
  const [flipped, setFlipped] = useState({ dna: false, ptm: false });
  const [loading, setLoading] = useState(false);

  const handleFlip = (type) => {
    setFlipped((prev) => ({ ...prev, [type]: !prev[type] }));
  };

 const handleNavigate = (slug, label) => {
  const dnaOptions = ["dna-methylation", "snv"];
  const proteinOptions = ["ptm", "saav"];

  let category = "";

  if (dnaOptions.includes(slug)) {
    category = "dna";
  } else if (proteinOptions.includes(slug)) {
    category = "protein";
  } else {
    console.error("Unknown slug:", slug);
    return;
  }
    setLoading(true); 
//   navigate(`/m2viz/${category}/${slug}`, {
//     state: { label, category }, 
//   });
// };
setTimeout(() => {
      navigate(`/m2viz/${category}/${slug}`, {
        state: { label, category },
      });
    }); // Optional: adjust delay as needed
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <Loadingspinner />
      </div>
    );
  }


  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl w-full p-6">
      {/* DNA Card */}
      <div
        className="relative w-full h-64 cursor-pointer transition-transform duration-500 hover:scale-105"
        style={{ perspective: "1200px" }}
        onClick={() => handleFlip("dna")}
      >
        <div
          className="relative w-full h-full transition-transform duration-700"
          style={{
            transformStyle: "preserve-3d",
            transform: flipped.dna ? "rotateY(180deg)" : "rotateY(0deg)",
          }}
        >
          {/* Front Side */}
          <div
            //className="absolute w-full h-full bg-white/90 rounded-xl shadow-lg hover:shadow-xl flex flex-col justify-between p-6"
            className="absolute w-full h-full bg-[#F4EEFF] rounded-xl shadow-lg hover:shadow-xl flex flex-col justify-between p-6"

            style={{ backfaceVisibility: "hidden" }}
          >
            <div className="flex items-center">
              <div className="p-3 bg-purple-100 rounded-lg">
                <GiDna2 className="w-8 h-8 text-purple-600" />
              </div>
              <h2 className="text-2xl font-bold ml-3 text-purple-800">DNA</h2>
            </div>
            <p className="text-slate-600 mb-6">
              Visualize DNA methylation patterns and Single Nucleotide Variations from your data.

            </p>
            <div className="flex items-center text-purple-600 font-medium">
              Get started <FaArrowRight className="ml-2 w-4 h-4" />
            </div>
          </div>

          {/* Back Side */}
          <div
            className="absolute w-full h-full bg-gradient-to-br from-purple-500 to-pink-400 rounded-xl shadow-lg flex flex-col justify-center items-center gap-4 px-6"
            style={{ backfaceVisibility: "hidden", transform: "rotateY(180deg)" }}
          >
            <div
              className="w-full bg-white/90 p-6 rounded-xl text-center text-purple-800 font-semibold text-lg cursor-pointer shadow-md hover:shadow-lg hover:scale-105"
              onClick={() => handleNavigate("dna-methylation", "DNA Methylation")}
            >
              DNA Methylation
            </div>
            <div
              className="w-full bg-white/90 p-6 rounded-xl text-center text-pink-700 font-semibold text-lg cursor-pointer shadow-md hover:shadow-lg hover:scale-105"
              onClick={() => handleNavigate("snv", "Single Nucleotide Variations (SNVs)")}
            >
              Single Nucleotide Variations (SNVs)
            </div>
          </div>
        </div>
      </div>

      {/* Protein Card */}
      <div
        className="relative w-full h-64 cursor-pointer transition-transform duration-500 hover:scale-105"
        style={{ perspective: "1200px" }}
        onClick={() => handleFlip("ptm")}
      >
        <div
          className="relative w-full h-full transition-transform duration-700"
          style={{
            transformStyle: "preserve-3d",
            transform: flipped.ptm ? "rotateY(180deg)" : "rotateY(0deg)",
          }}
        >
          {/* Front Side */}
          <div
            className="absolute w-full h-full bg-[#F4EEFF] rounded-xl shadow-lg hover:shadow-xl flex flex-col justify-between p-6"
            style={{ backfaceVisibility: "hidden" }}
          >
            <div className="flex items-center">
              <div className="p-3 bg-purple-100 rounded-lg">
                <img src={Protein} alt="Protein" className="w-8 h-8 rotate-90" />
              </div>
              <h2 className="text-2xl font-bold ml-3 text-purple-800">PROTEIN</h2>
            </div>
            <p className="text-slate-600 mb-6">
              Visualize protein Post-Translational Modifications and Single Amino Acid Variations from your data.

            </p>
            <div className="flex items-center text-purple-600 font-medium">
              Get started <FaArrowRight className="ml-2 w-4 h-4" />
            </div>
          </div>

          {/* Back Side */}
          <div
            className="absolute w-full h-full bg-gradient-to-br from-purple-500 to-pink-400 rounded-xl shadow-lg flex flex-col justify-center items-center gap-4 px-6"
            style={{ backfaceVisibility: "hidden", transform: "rotateY(180deg)" }}
          >
            <div
              className="w-full bg-white/90 p-6 rounded-xl text-center text-purple-800 font-semibold text-lg cursor-pointer shadow-md hover:shadow-lg hover:scale-105"
              onClick={() => handleNavigate("ptm", "Post-Translational Modifications")}
            >
              Post-Translational Modifications
            </div>
            <div
              className="w-full bg-white/90 p-6 rounded-xl text-center text-pink-700 font-semibold text-lg cursor-pointer shadow-md hover:shadow-lg hover:scale-105"
              onClick={() => handleNavigate("saav", "Single Amino Acid Variations (SAAVs)")}
            >
              Single Amino Acid Variations (SAAVs)
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HomeCards;
