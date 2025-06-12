
import React from "react";

const Loadingspinner = () => {
  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="relative w-32 h-32">
        <div className="absolute inset-0 border-4 border-t-purple-500 border-r-pink-500 border-b-blue-500 border-l-transparent rounded-full animate-spin" />

        <div
          className="absolute inset-4 border-4 border-t-transparent border-r-purple-500 border-b-pink-500 border-l-blue-500 rounded-full animate-spin"
          style={{ animationDuration: "3s" }}
        />

        <div
          className="absolute inset-8 border-4 border-t-blue-500 border-r-transparent border-b-purple-500 border-l-pink-500 rounded-full animate-spin"
          style={{ animationDuration: "5s" }}
        />
      </div>

 
    </div>
  );
};

export default Loadingspinner;
