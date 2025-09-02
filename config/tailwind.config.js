// config/tailwind.config.js
module.exports = {
  content: [
    "./app/views/**/*.{erb,haml,html,slim}",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.{css,scss,sass}",
    "./app/javascript/**/*.{js,ts,jsx,tsx}",
    "./app/assets/tailwind/**/*.{css}"
  ],
  safelist: [
    {
      pattern: /(bg|text)-(red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|gray|slate|zinc|neutral|stone)-(100|500)/,
    },
  ],
  theme: { extend: {} },
  plugins: [],
}