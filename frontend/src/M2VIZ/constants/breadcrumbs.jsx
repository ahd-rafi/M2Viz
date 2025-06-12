import React from "react";
import { Link, useLocation } from "react-router-dom";

const breadcrumbNameMap = {
  m2viz: "M2Viz",
  profile: "Profile",
  differential: "Differential",
};

const customNameMap = {
  dna: "DNA",
  protein: "Protein",
  "dna-methylation": "DNA-Methylation",
  snv: "SNV",
  ptm: "PTM",
  saav: "SAAV",
};

export default function Breadcrumbs() {
  const location = useLocation();
  const pathnames = location.pathname.split("/").filter((x) => x);

  const excludePaths = ["contact", "help"];
  if (excludePaths.some((p) => pathnames.includes(p))) return null;
  if (pathnames.length === 0) return null;

  const items = [];

  for (let i = 0; i < pathnames.length; i++) {
    const value = pathnames[i].toLowerCase();

    if (value === "dna" || value === "protein") {
      const analysis = pathnames[i + 1]?.toLowerCase();
      const capitalized = customNameMap[value] || value;
      const analysisName = customNameMap[analysis] || analysis;

      const name = analysisName ? `${capitalized} (${analysisName})` : capitalized;
      const to = `/${pathnames.slice(0, i + 2).join("/")}`;
      items.push({ name, to, isClickable: false });
      i++; // Skip next since it's part of the label
    } else {
      const decoded = decodeURIComponent(pathnames[i]);
      const name =
        customNameMap[decoded.toLowerCase()] ||
        breadcrumbNameMap[decoded.toLowerCase()] ||
        decoded;

      const to = `/${pathnames.slice(0, i + 1).join("/")}`;
      items.push({ name, to, isClickable: true });
    }
  }

  return (
    <nav
      aria-label="breadcrumb"
      className="inline-block select-none pt-4"
    >
      <ol className="flex m-0 p-0 list-none text-sm font-medium">
        {items.map((item, index) => {
          const isLast = index === items.length - 1;

          return (
            <li key={item.to} className="flex items-center relative">
              <div className={`
                relative px-6 py-3 transition-all duration-300 whitespace-nowrap min-h-[44px] flex items-center
                ${isLast 
                  ? 'text-pink-600 bg-gradient-to-r from-purple-100 to-pink-100 shadow-lg' 
                  : 'text-gray-700 bg-white  shadow-md hover:shadow-lg'
                }
              `}
              style={{
                clipPath: 'polygon(0% 0%, calc(100% - 20px) 0%, 100% 50%, calc(100% - 20px) 100%, 0% 100%, 20px 50%)',
                marginRight: index === items.length - 1 ? '0' : '-10px'
              }}>
                {isLast ? (
                  <span className="relative z-10 font-semibold">
                    {item.name}
                  </span>
                ) : (
                  <Link to={item.to} className="relative z-10 hover:font-semibold">
                    {item.name}
                  </Link>
                )}
              </div>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}