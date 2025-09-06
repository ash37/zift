// config/tailwind.config.js
const safelistColors = ['red','orange','amber','yellow','lime','green','emerald','teal','cyan','sky','blue','indigo','violet','purple','fuchsia','pink','rose','gray','slate','zinc','neutral','stone'];

module.exports = {
  content: [
    "./app/views/**/*.{erb,haml,html,slim}",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.{css,scss,sass}",
    "./app/javascript/**/*.{js,ts,jsx,tsx}",
    "./app/assets/tailwind/**/*.{css}"
  ],
  safelist: [
    ...safelistColors.flatMap(c => [
      `bg-${c}-100`,
      `text-${c}-500`,
    ]),
  ],
  theme: { extend: {} },
  plugins: [],
}