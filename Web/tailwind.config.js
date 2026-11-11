/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./index.html'],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', '"SF Pro Display"', '"SF Pro Text"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      colors: {
        appleBlack: '#000000',
        appleSurface: '#0A0A0D',
        appleCard: '#121217',
        appleElevated: '#1A1A22',
        appleText: '#F5F5F7',
        appleBody: '#E4E4E7',
        appleMuted: '#A1A1AA',
        appleBlue: '#0071E3',
        appleBlueHover: '#0077ED',
        appleGreen: '#30D158',
      },
    },
  },
  safelist: [
    'hidden',
    'flex',
    'inline-flex',
    'items-center',
    'justify-center',
    'gal-tab-active',
    'cam-pill-active',
    'studio-ctrl-active',
    'chapter-card-active',
    'sm:inline',
    'lg:hidden',
    'lg:flex',
  ],
  plugins: [],
};
