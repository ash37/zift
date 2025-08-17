// config/tailwind.config.js
module.exports = {
  content: [
    "./app/views/**/*.{erb,haml,html,slim}",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.{css,scss,sass}",
    "./app/javascript/**/*.{js,ts,jsx,tsx}",
    "./app/assets/tailwind/**/*.{css}"
  ],
  theme: { extend: {} },
  plugins: [],
}