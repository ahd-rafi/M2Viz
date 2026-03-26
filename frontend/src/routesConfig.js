import React, { Suspense } from "react";

//LOLLIPOP EXTERNAL ROUTES

const lollipop = React.lazy(() => import("./M2VIZ/pages/m2viz"))
const lollipop_Home = React.lazy(() => import("./M2VIZ/pages/m2vizhome"))
const lollipop__submit_form= React.lazy(() => import("./M2VIZ/container/submitform_protein"))
const lollipop_dna_submit_form= React.lazy(() => import("./M2VIZ/container/submitform_dna"))
const lollipop_download=React.lazy(() => import("./M2VIZ/container/plot"))
const lollipop_contact=React.lazy(() => import("./M2VIZ/pages/m2vizcontact"))
const lollipop_cards=React.lazy(() => import("./M2VIZ/container/card"))
const lollipop_Help=React.lazy(() => import("./M2VIZ/pages/m2viz_faq"))
// const lollipop_mut_met_cards=React.lazy(() => import("./lollipop_external/container/card_meth_mut"))





export const routesConfig = [
    {
        path: "/",
      
     
         component:lollipop,
        children: [
            { index: true, component: lollipop_Home },
{ path: "/m2viz/:category/:selectedOption", component: lollipop_cards },

            { path: "/m2viz/protein/:selectedOption/:selectedType", component: lollipop__submit_form },

             { path: "/m2viz/dna/:selectedOption/:selectedType", component: lollipop_dna_submit_form },


          
                        {path:"/m2viz/protein/:selectedOption/:selectedType/:ACCESSION",component: lollipop_download},
                        {path:"/m2viz/dna/:selectedOption/:selectedType/:ENSG",component: lollipop_download},



            {path: "contact",component:lollipop_contact},
            {path:"help",component:lollipop_Help}


        ],
     },

   



];

