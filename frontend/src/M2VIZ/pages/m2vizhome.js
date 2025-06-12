
import HomeCards from "../container/HomeCards"; 
import logo from "../../Assets/M2Viz/M2VIZ_PURPLE2.png";
const LollipopHome = () => {
  return (
    <div className="pt-24 bg-[#FFFFF] flex flex-col items-center justify-start text-white px-6">
      


      {/* Logo */}
      <img
        src={logo}
        alt="Lollipop Plot Tool"
        className="mx-auto mb-2 w-300 mt-4" 
      />
      
      {/* <p className="text-xs md:text-xl mb-6 max-w-2xl text-purple-800">
        Your Tool for Visualising Genomic and Proteomic Modifications
      </p> */}
       <p className="text-xs pl-6 text-purple-800">
        Your Tool for Visualising Genomic and Proteomic Modifications
      </p>

      {/* About Section */}
      <div className="backdrop-blur-md text-purple-800 text-base md:text-lg mb-8 text-center mt-16">
        <p className="mb-2">
         M2Viz is an all-in-one tool for creating compelling high-quality lollipop plots of
          genomic and proteomic modifications and mutations (M2). Visualize expression data
           on Single Nucleotide Variations, 

        </p>
        <p className="mb-2">
          Post-Translational Modifications, Single Amino 
           Acid Variations, and DNA methylation to render publication-ready plots with effortlessly powerful visualization.
        </p>
   
      </div>

      <HomeCards />
    </div>
  );
};

 export default LollipopHome;

