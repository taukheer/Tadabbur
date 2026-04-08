export default function Footer() {
  return (
    <footer className="border-t border-border-subtle">
      <div className="mx-auto max-w-6xl px-6 py-12">
        <div className="flex flex-col md:flex-row items-center justify-between gap-8">
          {/* Logo */}
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-gold to-gold-dark flex items-center justify-center">
              <span className="text-bg-primary font-bold text-base font-arabic">
                ت
              </span>
            </div>
            <span className="text-text-primary font-semibold tracking-tight">
              Tadabbur
            </span>
          </div>

          {/* Links */}
          <div className="flex items-center gap-8 text-sm">
            <a
              href="#features"
              className="text-text-secondary hover:text-gold transition-colors"
            >
              Features
            </a>
            <a
              href="#how-it-works"
              className="text-text-secondary hover:text-gold transition-colors"
            >
              How It Works
            </a>
            <a
              href="#reflection"
              className="text-text-secondary hover:text-gold transition-colors"
            >
              Reflection
            </a>
            <a
              href="#download"
              className="text-text-secondary hover:text-gold transition-colors"
            >
              Download
            </a>
          </div>

          {/* Hackathon badge */}
          <div className="text-center md:text-right">
            <p className="text-text-muted text-xs leading-relaxed">
              Built with dedication for the
              <br />
              <span className="text-gold/70 font-medium">
                Quran Foundation Hackathon 2026
              </span>
            </p>
          </div>
        </div>

        <div className="geometric-divider mt-8 mb-6" />

        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-text-muted text-xs">
          <p>&copy; {new Date().getFullYear()} Tadabbur. All rights reserved.</p>
          <p className="flex items-center gap-1">
            Made with
            <span className="text-gold mx-0.5" aria-label="love">
              &#9829;
            </span>
            for the Ummah
          </p>
        </div>
      </div>
    </footer>
  );
}
