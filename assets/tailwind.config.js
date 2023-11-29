// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: ["./js/**/*.js", "./lib/**/*.ex"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter"', ...defaultTheme.fontFamily.sans],
        fancy: ['"Rubik"', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [],
};
