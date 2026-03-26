
import React, { useState, useRef } from "react";

import useSendEmail from "../../hooks/useSendEmail";
import { API_ENDPOINTS } from "../../constants/apiconfig/apiconfig";
import ReCAPTCHA from "react-google-recaptcha";

import Loading from "../../common/components/UI/Loading";


    
    const ContactPage = () => {
      const name = useRef();
      const email = useRef();
      const message = useRef();
      const url = API_ENDPOINTS.LOLLIPOP_CONTACT_US;
      const [showPopup, setShowPopup] = useState(false);
      const [errorMessage, setErrorMessage] = useState(""); 
      const { sendEmail ,loading} = useSendEmail(url);
     const [captchaValue, setCaptchaValue] = useState(null);
       const recaptchaRef = React.useRef();
      const [isLoading, setIsLoading] = useState(false);
    
    const handleSubmit = async (e) => {
      e.preventDefault();
      setIsLoading(true);
    
      const userName = name.current.value.trim();
      const userEmail = email.current.value.trim();
      const userMessage = message.current.value.trim();
    
      if (!userName || !userEmail || !userMessage) {
        setErrorMessage("Please fill in all fields before submitting.");
        return;
      }
    
      if (!captchaValue) {
        setErrorMessage("Please complete the reCAPTCHA.");
        return;
      }
    
      setErrorMessage(""); 
    
      try {
        const response = await sendEmail({
          name: userName,
          email: userEmail,
          message: userMessage,
          recaptcha_token: captchaValue,  
        });
    
        if (response && response.status === 200) {
          setShowPopup(true); 
          if (name.current) name.current.value = "";
          if (email.current) email.current.value = "";
          if (message.current) message.current.value = "";
           if (recaptchaRef.current) recaptchaRef.current.reset();  
          setCaptchaValue(null);         
        }
        else {
          console.error("Unexpected response status:", response?.status);
          setErrorMessage("Failed to send message. Please try again later.");
        }
      }catch (error) {
      console.error("API Error:", error);
      setErrorMessage("An error occurred. Please check your connection and try again.");
    }
      
      finally {
        setIsLoading(false);
      }
    };
    
      const handleCaptchaChange = (value) => {
        setCaptchaValue(value);
      };
      if (isLoading) {
        return (
          <div className="flex items-center justify-center min-h-screen bg-gray-100">
            <Loading />
          </div>
        );
      }
    
  return (
     <div className="bg-gray-100 min-h-screen flex items-center justify-center"> 
      

      {/* Centered Form Container */}
      <div className="flex justify-center">
        <div className="bg-white border border-gray-300 shadow-md rounded-lg p-6 w-full max-w-xl">
          {errorMessage && <p className="text-red-600 font-semibold mb-4">{errorMessage}</p>}

          <form onSubmit={handleSubmit} className="space-y-4">
                  <div className="text-center mb-8">
        <h1 className="text-3xl font-bold tracking-tighter sm:text-4xl md:text-5xl">Contact Us</h1>
        <p className="mx-auto max-w-[700px] text-gray-500 mt-4">
          Have questions? We'd love to hear from you. Send us a message and we'll respond as soon as possible.
        </p>
      </div>
            <div>
              <span className="block font-medium">Name</span>
              <input
                className="w-full p-2 border rounded"
                id="name"
                ref={name}
                placeholder="Enter your name"
              />
            </div>
            <div>
              <span className="block font-medium">Email</span>
              <input
                className="w-full p-2 border rounded"
                id="email"
                ref={email}
                type="email"
                placeholder="Enter your email"
              />
            </div>
            <div>
              <span className="block font-medium">Message</span>
              <textarea
                className="w-full p-2 border rounded min-h-[150px]"
                id="message"
                ref={message}
                placeholder="Enter your message"
              />
            </div>
             <div className="w-full flex justify-center mt-4 overflow-visible">
    <ReCAPTCHA
      sitekey="6LeWWlgpAAAAAG-XJmUWpfvD6Va16linzxbkobsa"
      onChange={handleCaptchaChange}
      ref={recaptchaRef}
      className="transform scale-90 sm:scale-60" 
    />
  </div> 
         
        
               <div className="text-center">
              <button
                type="submit"
                className={`text-white item-center font-bold py-2 px-4 rounded focus:outline-none focus:ring-2 focus:ring-purple-300 transition-all

                  ${
                    loading || !captchaValue
                      ? "bg-purple-400 cursor-not-allowed" 
                    : "bg-purple-700 hover:bg-purple-800"  
                  }`}
                disabled={loading  || !captchaValue}

             >
                Submit
              </button>
            </div>
          </form>
          {showPopup && (
        <div className="fixed inset-0 flex items-center justify-center bg-gray-900 bg-opacity-50">
          <div className="bg-white p-6 rounded-lg shadow-lg text-center">
            <h3 className="text-xl font-semibold text-gray-800">Message Sent!</h3>
            <p className="text-gray-600 mt-2">
              Thank you for reaching out. We'll get back to you soon.
            </p>
            <button
              onClick={() => setShowPopup(false)}
              className="mt-4 bg-purple-600 text-white font-bold py-2 px-4 rounded"
            >
              Close
            </button>
          </div>
        </div>
      )}
        </div>

       
      </div>
    </div>
  );
}

export default ContactPage;