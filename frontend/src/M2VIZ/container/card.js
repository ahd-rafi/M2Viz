
import { useState } from "react";
import { useNavigate, useLocation, useParams } from "react-router-dom";
import { cards } from "../constants/index";
import { IoIosArrowForward } from "react-icons/io";
import Breadcrumbs from '../constants/breadcrumbs';
import Loadingspinner from "../../M2VIZ/components/UI/Loading";
const Cards = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const params = useParams(); 
const [loading, setLoading] = useState(false);

const category = params.category;
const selectedOptionFromURL = params.selectedOption;


  const selectedPlot = location.state?.plot || "dna";
  const selectedType = location.state?.selectedType || null;

  const [hoveredIndex, setHoveredIndex] = useState(null);



const handleNavigation = (type) => {
  if (!selectedPlot || !category) {
    console.error("Missing selectedPlot or category in navigation state.");
    return;
  }
  setLoading(true);

  const destinationPath = `/m2viz/${category}/${selectedOptionFromURL}/${type}`;

  console.log("Navigating to:", destinationPath);

  navigate(destinationPath, {
    state: {
      selectedPlot,
      selectedOption: selectedOptionFromURL,
      selectedType: type,
      category, 
    },
  });
};


  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-gray-100 overflow-hidden relative">
      {loading && (
  <div className="fixed inset-0 z-50 bg-white bg-opacity-75 flex items-center justify-center">
    <Loadingspinner />
  </div>
)}

      <div className="relative z-10 w-full max-w-7xl mx-auto px-4 py-16">
          <div className="fixed top-16 left-4 z-50   p-2 max-w-xs">
              <Breadcrumbs />
            </div>
        <div className="grid md:grid-cols-2 gap-8 mt-8">
          {cards.map((card, index) => (
            <div
              key={index}
              className="bg-white rounded-xl shadow-md overflow-hidden transition-transform duration-300 hover:shadow-lg hover:translate-y-[-4px]"
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
            >
              <div
                className="p-6 cursor-pointer h-full flex flex-col"
                onClick={() => handleNavigation(card.type)}
              >
                <h2 className="text-2xl font-bold text-pink-600 mb-4">
                  {card.title}
                </h2>
                <div className="relative w-full h-48 mb-4 overflow-hidden rounded-lg">
                  <img
                    src={card.image || "/placeholder.svg"}
                    alt={card.title}
                    className="object-cover object-center transition-transform duration-500 hover:scale-105 w-full h-full"
                  />
                </div>
                <p className="text-gray-700 mb-4 flex-grow">
                  {card.description}
                </p>
                <button className="flex items-center justify-center px-4 py-2 bg-violet-100 hover:bg-violet-200 text-violet-800 rounded-lg font-medium text-sm transition-colors">
                  Select
                  <IoIosArrowForward className="h-4 w-4 ml-1" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Cards;
