import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import React, { Suspense } from "react";
import Loadingspinner from "./M2VIZ/components/UI/Loading";
import { routesConfig } from "./routesConfig";

function renderRoutes(routes) {
  return routes.map(({ path, component: Component, children, index }, i) => (
    <Route key={i} path={path} element={<Component />}>
      {children && children.map((child, j) => (
        <Route
          key={j}
          index={child.index}
          path={child.path}
          element={<child.component />}
        />
      ))}
    </Route>
  ));
}


function App() {
  return (
    <Router>
      <Suspense fallback={<Loadingspinner />}>
      
        <Routes>{renderRoutes(routesConfig)}</Routes>
       
      </Suspense>
    </Router>
  );
}

export default App;





