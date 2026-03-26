
import React from 'react';
import { Link } from 'react-router-dom';
import logo from '../../../Assets/ciods/Yenepoya_University_logo.png';

const Footer = () => {
  return (
    <footer className="bg-[#F4EEFF] py-8 w-full">
      <div className="w-full max-w-screen-2xl px-4 mx-auto text-center">
        <div className="flex flex-col items-center justify-center space-y-4">


   <p className=" overflow-auto">
  M2Viz Tool is developed in Centre for Integrative Omics Data Science (CIODS) and supported by Yenepoya (Deemed to be University).
</p>

        </div>

        <div className="mt-6">
          <span className="text-xs">
            Copyright ©{' '}
            <Link to="/" className="hover:underline text-footerLink hover:text-footerLinkHover">
              CIODS
            </Link>{' '}
            All Rights Reserved by{' '}
            <Link
              to="https://www.yenepoya.edu.in/"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:underline text-footerLink hover:text-footerLinkHover"
            >
              Yenepoya
            </Link>{' '}
            (Deemed to be University).
          </span>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
