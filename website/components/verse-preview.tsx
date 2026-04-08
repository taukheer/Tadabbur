import ScrollReveal from "./scroll-reveal";

export default function VersePreview() {
  return (
    <section className="section-padding relative">
      <div className="mx-auto max-w-4xl">
        <ScrollReveal>
          <div className="text-center mb-16">
            <span className="text-gold text-sm font-semibold uppercase tracking-widest mb-4 block">
              Experience
            </span>
            <h2 className="text-4xl md:text-5xl font-bold text-text-primary mb-6">
              What your mornings
              <br />
              <span className="text-gold-gradient">could look like</span>
            </h2>
          </div>
        </ScrollReveal>

        <ScrollReveal delay={0.2}>
          <div className="verse-card p-8 md:p-12 max-w-2xl mx-auto">
            {/* Header */}
            <div className="flex items-center justify-between mb-8">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-gold/10 border border-gold/20 flex items-center justify-center">
                  <span className="text-gold text-xs font-bold">1:1</span>
                </div>
                <div>
                  <p className="text-text-primary text-sm font-semibold">
                    Al-Fatiha
                  </p>
                  <p className="text-text-muted text-xs">The Opening</p>
                </div>
              </div>
              <div className="flex items-center gap-2 text-text-muted">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" />
                </svg>
                <span className="text-xs">Day 1</span>
              </div>
            </div>

            {/* Arabic text */}
            <div className="text-center mb-8">
              <p className="arabic-verse text-3xl md:text-4xl text-text-primary leading-[2.4] mb-6">
                بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ
              </p>
              <div className="geometric-divider mb-6" />
              <p className="text-text-secondary text-base md:text-lg italic leading-relaxed">
                &ldquo;In the name of God, the Most Gracious, the Most
                Merciful&rdquo;
              </p>
            </div>

            {/* Audio bar mock */}
            <div className="flex items-center gap-3 bg-bg-primary/50 rounded-xl p-4 mb-6">
              <button
                className="w-10 h-10 rounded-full bg-gold/10 border border-gold/20 flex items-center justify-center text-gold flex-shrink-0"
                aria-label="Play audio"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <polygon points="6 3 20 12 6 21 6 3" />
                </svg>
              </button>
              <div className="flex-1">
                <div className="h-1.5 bg-bg-card rounded-full overflow-hidden">
                  <div className="h-full w-1/3 bg-gradient-to-r from-gold to-gold-light rounded-full" />
                </div>
              </div>
              <span className="text-text-muted text-xs font-mono">0:06</span>
            </div>

            {/* Reflection prompt */}
            <div className="rounded-xl bg-[#9B7FD4]/5 border border-[#9B7FD4]/15 p-5">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-5 h-5 rounded-full bg-[#9B7FD4]/15 flex items-center justify-center">
                  <span className="text-[#9B7FD4] text-[10px] font-bold">3</span>
                </div>
                <span className="text-[#9B7FD4] text-xs font-semibold uppercase tracking-wider">
                  Reflect
                </span>
              </div>
              <p className="text-text-secondary text-sm leading-relaxed">
                Why does God choose mercy as the very first attribute we
                encounter in His Book? What does it mean to begin every act in
                the name of the Most Merciful?
              </p>
            </div>
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
