import ScrollReveal from "./scroll-reveal";

const steps = [
  {
    number: "01",
    title: "Wake up to your verse",
    description:
      "Each morning, receive a new ayah with Arabic text, professional audio recitation, and a translation in your language.",
    icon: (
      <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2" /><path d="M12 20v2" />
        <path d="m4.93 4.93 1.41 1.41" /><path d="m17.66 17.66 1.41 1.41" />
        <path d="M2 12h2" /><path d="M20 12h2" />
        <path d="m6.34 17.66-1.41 1.41" /><path d="m19.07 4.93-1.41 1.41" />
      </svg>
    ),
  },
  {
    number: "02",
    title: "Understand deeply",
    description:
      "Explore word-by-word meanings, historical context, scholarly reflections, and tafsir commentary to build true understanding.",
    icon: (
      <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="11" cy="11" r="8" />
        <path d="m21 21-4.3-4.3" />
        <path d="M11 8v6" /><path d="M8 11h6" />
      </svg>
    ),
  },
  {
    number: "03",
    title: "Write your tadabbur",
    description:
      "Reflect at any tier — from simple acknowledgment to deep contemplation — and build a personal Quran journal over time.",
    icon: (
      <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        <path d="M8 10h8" /><path d="M8 14h4" />
      </svg>
    ),
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="section-padding relative">
      <div className="mx-auto max-w-5xl">
        <ScrollReveal>
          <div className="text-center mb-20">
            <span className="text-gold text-sm font-semibold uppercase tracking-widest mb-4 block">
              How It Works
            </span>
            <h2 className="text-4xl md:text-5xl font-bold text-text-primary">
              Simple. <span className="text-gold-gradient">Profound.</span> Daily.
            </h2>
          </div>
        </ScrollReveal>

        <div className="relative">
          {/* Connecting line */}
          <div
            className="absolute left-8 md:left-1/2 top-0 bottom-0 w-px hidden md:block"
            style={{
              background:
                "linear-gradient(to bottom, transparent, rgba(201,169,110,0.2) 15%, rgba(201,169,110,0.2) 85%, transparent)",
            }}
            aria-hidden="true"
          />

          <div className="space-y-16 md:space-y-24">
            {steps.map((step, i) => (
              <ScrollReveal
                key={step.number}
                delay={i * 0.15}
                direction={i % 2 === 0 ? "left" : "right"}
              >
                <div
                  className={`flex flex-col md:flex-row items-center gap-8 md:gap-16 ${
                    i % 2 !== 0 ? "md:flex-row-reverse" : ""
                  }`}
                >
                  {/* Content */}
                  <div className={`flex-1 ${i % 2 !== 0 ? "md:text-right" : ""}`}>
                    <span className="text-gold/40 text-6xl font-bold leading-none mb-4 block">
                      {step.number}
                    </span>
                    <h3 className="text-2xl md:text-3xl font-bold text-text-primary mb-4">
                      {step.title}
                    </h3>
                    <p className="text-text-secondary text-lg leading-relaxed max-w-md">
                      {step.description}
                    </p>
                  </div>

                  {/* Icon circle */}
                  <div className="relative flex-shrink-0 order-first md:order-none">
                    <div className="w-16 h-16 rounded-full bg-bg-card border border-border-card flex items-center justify-center text-gold shadow-lg">
                      {step.icon}
                    </div>
                    <div
                      className="absolute inset-0 rounded-full"
                      style={{
                        background: "radial-gradient(circle, rgba(201,169,110,0.1) 0%, transparent 70%)",
                        transform: "scale(2.5)",
                      }}
                      aria-hidden="true"
                    />
                  </div>

                  {/* Spacer for alternating layout */}
                  <div className="flex-1 hidden md:block" />
                </div>
              </ScrollReveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
