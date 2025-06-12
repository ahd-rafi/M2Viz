export const cards = [
  {
    type: "profile",
    title: "Profile dataset",
    description: "Visualization of upward lollipop plots, highlighting key data points with customizable color schemes, interactive hover effects, and annotation support.",
    image: require("../../Assets/M2Viz/upward.png"),

  },
  {
    type: "differential",
    title: "Differential dataset",
    description: "Dual-directional lollipop plots showcasing both upward and downward trends, useful for comparative analysis, enriched with tooltips, and dynamic styling options.",
    image: require("../../Assets/M2Viz/updownplot.png"),
    
  }
];

const getExampleTable = (selectedOption, selectedType) => {
  let tableData = [];

  if (selectedOption === "methylation") {
    if (selectedType === "profile") {
      tableData = [
        { id: 1, site: "S198", frequency: 18 },
        { id: 2, site: "S199", frequency: 41 },
        { id: 3, site: "S206", frequency: 126 },
        { id: 4, site: "S232", frequency: 12 },
        { id: 5, site: "S232", frequency: 1 },
      ];
    } else if (selectedType === "differential") {
      tableData = [
        { id: 1, site: "S198", frequency: 2, flowofdata: "Upstream" },
        { id: 2, site: "S199", frequency: 3, flowofdata: "Upstream" },
        { id: 3, site: "S206", frequency: 7, flowofdata: "Upstream" },
        { id: 4, site: "S206", frequency: 8, flowofdata: "Downstream" },
        { id: 5, site: "T202", frequency: 2, flowofdata: "Downstream" },
      ];
    }
  } else if (selectedOption === "mutation") {
    if (selectedType === "profile") {
      tableData = [
        { id: 1, mutation: "G10S", frequency: 15 },
        { id: 2, mutation: "C18T", frequency: 8 },
        { id: 3, mutation: "A30R", frequency: 16 },
        { id: 4, mutation: "A8315S", frequency: 22 },
        { id: 5, mutation: "T42A", frequency: 12 },
      ];
    } else if (selectedType === "differential") {
      tableData = [
        { id: 1, mutation: "G10S", frequency: 15, flowofdata: "Upstream" },
        { id: 2, mutation: "C18T", frequency: 8, flowofdata: "Upstream" },
        { id: 3, mutation: "A30R", frequency: 13, flowofdata: "Downstream" },
        { id: 4, mutation: "T42A", frequency: 12, flowofdata: "Upstream" },
        { id: 5, mutation: "C18T", frequency: 5, flowofdata: "Downstream" },
      ];
    }
  }

  return tableData;
};

export default getExampleTable;
