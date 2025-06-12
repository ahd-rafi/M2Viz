import React from "react";

const Loading = () => {
  return (
    <div className="flex items-center justify-center h-screen bg-gray-100">
      <div className="relative">
        {/* Rotating Loader Circle */}
        <div className="w-24 h-24 border-t-4 border-[#05949e] rounded-full animate-spin"></div>
        
        {/* Inner Nodes */}
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="w-12 h-12 border-4 border-dashed border-sky-500 rounded-full animate-pulse"></div>
        </div>

        {/* Text or Logo */}
        <div className="absolute inset-0 flex items-center justify-center">
          <p className="text-black text-lg font-semibold">CIODS</p>
        </div>
      </div>
    </div>
  );
};

export default Loading;
