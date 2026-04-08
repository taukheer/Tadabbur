import ScrollReveal from "./scroll-reveal";

export default function DownloadCTA() {
  return (
    <section id="download" className="section-padding relative">
      {/* Background glow */}
      <div
        className="glow-orb w-[700px] h-[500px] top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          background:
            "radial-gradient(circle, rgba(201,169,110,0.1) 0%, transparent 60%)",
        }}
        aria-hidden="true"
      />

      <div className="mx-auto max-w-3xl relative text-center">
        <ScrollReveal>
          <p className="arabic-verse text-gold/50 text-xl md:text-2xl mb-8">
            أَفَلَا يَتَدَبَّرُونَ ٱلْقُرْآنَ
          </p>
        </ScrollReveal>

        <ScrollReveal delay={0.1}>
          <h2 className="text-4xl md:text-6xl font-bold text-text-primary mb-6 leading-tight">
            Begin your journey
            <br />
            <span className="text-gold-gradient">today</span>
          </h2>
        </ScrollReveal>

        <ScrollReveal delay={0.2}>
          <p className="text-text-secondary text-lg md:text-xl max-w-lg mx-auto mb-12 leading-relaxed">
            Start with one verse. Just one. Tomorrow there will be another. And
            slowly, the Quran will become a daily companion.
          </p>
        </ScrollReveal>

        <ScrollReveal delay={0.3}>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-8">
            {/* App Store */}
            <a
              href="#"
              className="group flex items-center gap-3 bg-bg-card border border-border-card rounded-2xl px-6 py-4 hover:border-gold/30 hover:shadow-lg transition-all duration-300"
            >
              <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor" className="text-text-primary">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              <div className="text-left">
                <p className="text-text-muted text-[10px] uppercase tracking-wider leading-none">
                  Download on the
                </p>
                <p className="text-text-primary text-lg font-semibold leading-tight">
                  App Store
                </p>
              </div>
            </a>

            {/* Google Play */}
            <a
              href="#"
              className="group flex items-center gap-3 bg-bg-card border border-border-card rounded-2xl px-6 py-4 hover:border-gold/30 hover:shadow-lg transition-all duration-300"
            >
              <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor" className="text-text-primary">
                <path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 01-.61-.92V2.734a1 1 0 01.609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.199l2.302 2.302a1 1 0 010 1.38l-2.302 2.302L15.395 12l2.303-2.492zM5.864 3.658L16.8 9.99l-2.302 2.302L5.864 3.658z" />
              </svg>
              <div className="text-left">
                <p className="text-text-muted text-[10px] uppercase tracking-wider leading-none">
                  Get it on
                </p>
                <p className="text-text-primary text-lg font-semibold leading-tight">
                  Google Play
                </p>
              </div>
            </a>
          </div>
        </ScrollReveal>

        <ScrollReveal delay={0.4}>
          <p className="text-text-muted text-sm">
            Free to download. No ads. No subscriptions. Just Quran.
          </p>
        </ScrollReveal>
      </div>
    </section>
  );
}
