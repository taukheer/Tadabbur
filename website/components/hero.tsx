import ScrollReveal from "./scroll-reveal";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center section-padding pt-32">
      {/* Central glow orb */}
      <div
        className="glow-orb w-[500px] h-[500px] top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{ background: "radial-gradient(circle, rgba(201,169,110,0.12) 0%, transparent 70%)" }}
        aria-hidden="true"
      />

      <div className="relative max-w-4xl mx-auto text-center">
        {/* Bismillah */}
        <ScrollReveal delay={0.1}>
          <p className="arabic-verse text-gold/70 text-2xl md:text-3xl mb-8">
            بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ
          </p>
        </ScrollReveal>

        {/* Main Headline */}
        <ScrollReveal delay={0.25}>
          <h1 className="text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[1.1] mb-8">
            <span className="text-text-primary">One Ayah.</span>
            <br />
            <span className="text-text-primary">Every Day.</span>
            <br />
            <span className="text-gold-gradient">For Life.</span>
          </h1>
        </ScrollReveal>

        {/* Subtitle */}
        <ScrollReveal delay={0.4}>
          <p className="text-text-secondary text-lg md:text-xl max-w-2xl mx-auto leading-relaxed mb-12">
            Begin a daily practice of Quranic contemplation. Receive one verse
            each morning, understand it deeply, and write reflections that
            transform your relationship with the Quran.
          </p>
        </ScrollReveal>

        {/* CTAs */}
        <ScrollReveal delay={0.55}>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a href="#download" className="btn-primary text-base">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <polyline points="7 10 12 15 17 10" />
                <line x1="12" y1="15" x2="12" y2="3" />
              </svg>
              Download Free
            </a>
            <a href="#features" className="btn-secondary text-base">
              Explore Features
            </a>
          </div>
        </ScrollReveal>

        {/* Scroll indicator */}
        <ScrollReveal delay={0.8}>
          <div className="mt-20 flex flex-col items-center gap-2 text-text-muted">
            <span className="text-xs uppercase tracking-widest">Scroll to explore</span>
            <svg
              width="16"
              height="24"
              viewBox="0 0 16 24"
              fill="none"
              className="animate-bounce"
            >
              <rect x="1" y="1" width="14" height="22" rx="7" stroke="currentColor" strokeWidth="1.5" />
              <circle cx="8" cy="8" r="2" fill="currentColor">
                <animate attributeName="cy" values="8;14;8" dur="2s" repeatCount="indefinite" />
              </circle>
            </svg>
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
