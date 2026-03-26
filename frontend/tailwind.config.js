/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    screens: {
      'xs': '375px',
      'sm': '425px',
      'md': '768px',
      'lg': '1024px',
      'xl': '1440px',
      '2xl': '2160px',
    },
    container: {
      center: true,
    },
    extend: {
      clipPath: {
        'diagonal-left': 'polygon(0 0, 100% 0, 70% 100%, 0 100%)',
        'diagonal-right': 'polygon(30% 0, 100% 0, 100% 100%, 0 100%)',
      },
     
      transform: {},
    translate: {},
      animation: {
        scroll: "scroll 30s linear infinite", 
        float: "float 1s infinite ease-in-out alternate",
        fadeInUp: 'fadeInUp 1s ease-out',
        slideUp: 'slideUp 0.5s ease-out',
        zoomOut: 'zoomOut 1s ease-in-out',
        slideLeft: 'slideFromLeft 2s ease-out forwards',
        slideRight: 'slideFromRight 1s ease-out forwards',
        nodeBounce: "nodeBounce 1.5s ease-in-out infinite",
        connectionFade: "connectionFade 2s ease-in-out infinite",
      },
      keyframes: {
        
        
        float: {
          '100%': { transform: 'translateY(20px)' },
        },
        scroll: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(-100%)' }, // Adjust based on total content width
        },
        fadeInUp: {
          '0%': { opacity: 0, transform: 'translateY(20px)' },
          '100%': { opacity: 1, transform: 'translateY(0)' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        zoomOut: {
          '0%': { opacity: '0', transform: 'scale(0.6)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        slideFromLeft: {
          '0%': {
            transform: 'translateX(-100%)',
            opacity: '0',
          },
          '100%': {
            transform: 'translateX(0)',
            opacity: '1',
          },
        },
        slideFromRight: {
          '0%': {
            transform: 'translateX(100%)',
            opacity: '0',
          },
          '100%': {
            transform: 'translateX(0)',
            opacity: '1',
          },
        },
      },
      fontFamily: {
        sans: ["Poppins", "sans-serif"],
        san: ["Roboto", "sans-serif"], 
        sam: ["Helvetica", "Arial", "sans-serif"], 
        serif: ["Georgia", "serif"],

      },
    },
  },
  plugins: [
    require('@tailwindcss/line-clamp'),
  ],
};
