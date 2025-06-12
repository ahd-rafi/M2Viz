



import React, { useState, useEffect } from "react";
import { Link, useLocation } from "react-router-dom";
import title from "../../../Assets/M2Viz/M2VIZ_PURPLE2.png"
import Loadingspinner from "../../components/UI/Loading";

const Navbar = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const location = useLocation();

  useEffect(() => {
    setLoading(false); 
  }, [location]);

  return (
    <>
      {loading && (
        <div className="fixed top-0 left-0 w-full h-full flex items-center justify-center bg-white bg-opacity-75 z-50">
          <Loadingspinner />
        </div>
      )}
      <nav className="flex items-center justify-between py-4 px-6 fixed top-0 left-0 right-0 z-20 bg-[#F4EEFF] shadow-lg">
      <Link
  to="/"
  className="flex items-center space-x-2 text-2xl font-semibold"
  onClick={() => {
    setLoading(true);
    setIsOpen(false);
  }}
>
  <img src={title} alt="Lollipop Logo" className="h-8 md:h-10 w-auto object-contain" />
</Link>


        <div className="lg:hidden">
          <button
            onClick={() => setIsOpen(!isOpen)}
            aria-label="Toggle menu"
            className="text-gray-900 focus:outline-none"
          ></button>
        </div>

        <div
          className={`${
            isOpen ? "block" : "hidden"
          } lg:flex lg:items-center lg:space-x-6 text-gray-900 text-sm mt-4 lg:mt-0`}
        >
          <Link to="/" className="block lg:inline-block text-pink hover:text-purple-800" onClick={() => { setLoading(true); setIsOpen(false); }}>
            Home
          </Link>
          <Link to="/contact" className="block lg:inline-block text-pink hover:text-purple-800" onClick={() => { setLoading(true); setIsOpen(false); }}>
            Contact Us
          </Link>
          <Link to="/faq" className="block lg:inline-block text-pink hover:text-purple-800" onClick={() => { setLoading(true); setIsOpen(false); }}>
            FAQs
          </Link>
        </div>
      </nav>
    </>
  );
};

export default Navbar;

