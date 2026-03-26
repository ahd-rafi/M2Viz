export const endPoint = process.env.REACT_APP_API_ENDPOINT;
console.log("endPoint", endPoint);

// const BASE_URL = `${endPoint}/api/`;
const BASE_URL = `${endPoint}/api/m2viz`;


export const API_ENDPOINTS = {
  BASE_URL: BASE_URL,

  POST_DNA_OUTPUT:  `${BASE_URL}/dnaoutput/`,
  POST_PROTEIN_P_OUTPUT: `${BASE_URL}/protein_p_output/`,
  POST_PROTEIN_D_OUTPUT: `${BASE_URL}/protein_d_output/`,
  LOLLIPOP_CONTACT_US: `${BASE_URL}/contact_us/`,


};
 