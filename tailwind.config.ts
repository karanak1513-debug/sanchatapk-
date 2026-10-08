import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        obsidian: '#0F172A',
        deepNavy: '#111827',
        slateText: '#64748B',
        lightSlate: '#F8FAFC',
        cardBorder: '#E2E8F0',
        emeraldAccent: '#10B981',
        darkEmerald: '#047857',
        sanchat: {
          50: '#ecfdf5',
          100: '#d1fae5',
          200: '#a7f3d0',
          300: '#6ee7b7',
          400: '#34d399',
          500: '#10b981',
          600: '#059669',
          700: '#047857',
          800: '#065f46',
          900: '#064e3b',
          950: '#022c22',
        },
      },
      fontFamily: {
        sans: [
          'var(--font-inter)',
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          '"Segoe UI"',
          'Roboto',
          'sans-serif',
        ],
        mono: ['var(--font-mono)', 'monospace'],
      },
      backgroundImage: {
        'emerald-radial': 'radial-gradient(circle at 50% 0%, rgba(16, 185, 129, 0.08) 0%, transparent 70%)',
        'subtle-grid': 'radial-gradient(#E2E8F0 1px, transparent 1px)',
        'hero-glow': 'radial-gradient(600px circle at var(--x, 50%) var(--y, 50%), rgba(16, 185, 129, 0.06), transparent 80%)',
      },
      boxShadow: {
        'subtle': '0 1px 3px rgba(15, 23, 42, 0.04), 0 1px 2px rgba(15, 23, 42, 0.02)',
        'cockpit': '0 25px 60px -15px rgba(15, 23, 42, 0.12), 0 0 1px 1px rgba(15, 23, 42, 0.05)',
        'cockpit-glow': '0 20px 50px -10px rgba(16, 185, 129, 0.15)',
        'card-hover': '0 20px 35px -10px rgba(15, 23, 42, 0.08), 0 0 0 1px rgba(16, 185, 129, 0.15)',
      },
      animation: {
        'pulse-subtle': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float-slow': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-8px)' },
        },
      },
    },
  },
  plugins: [],
};

export default config;
