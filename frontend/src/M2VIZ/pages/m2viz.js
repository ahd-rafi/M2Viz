import React from 'react'
import { Outlet } from "react-router-dom";
import Navbar from "../components/navbar/navbar";
import Footer from '../components/footer/footer';
import Breadcrumbs from '../constants/breadcrumbs';
const lollipop=()=> {
  return (
    <>
            <div className="flex flex-col min-h-screen">
                <Navbar />
                <main className="flex-grow">
                  {/* <Breadcrumbs/> */}
                    <Outlet />
                </main>
                <Footer />
            </div>
        </>
  )
}

export default lollipop;
