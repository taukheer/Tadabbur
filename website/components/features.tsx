import ScrollReveal from "./scroll-reveal";
import { StaggerContainer, StaggerItem } from "./scroll-reveal";

const features = [
  {
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
        <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
      </svg>
    ),
    title: "Daily Ayah",
    description:
      "One verse delivered each morning with Arabic text, translation, audio recitation, and word-by-word breakdown.",
    accent: "from-[#6BA3BE] to-[#4A7FBF]",
  },
  {
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 20h9" />
        <path d="M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z" />
      </svg>
    ),
    title: "3-Tier Reflection",
    description:
      "A guided writing system: acknowledge the verse, respond with personal connection, then reflect with deep contemplation.",
    accent: "from-[#C9A96E] to-[#A68B4B]",
  },
  {
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20" />
      </svg>
    ),
    title: "Personal Journal",
    description:
      "Every reflection is saved to a searchable archive. Track your journey by surah, by day, or by tier.",
    accent: "from-[#9B7FD4] to-[#7B5FB4]",
  },
  {
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" />
      </svg>
    ),
    title: "Streaks & Growth",
    description:
      "Build consistency with daily streaks, milestone celebrations, and progress tracking across your Quran journey.",
    accent: "from-[#E8956A] to-[#D4724A]",
  },
];

export default function Features() {
  return (
    <section id="features" className="section-padding relative">
      <div className="mx-auto max-w-6xl">
        <ScrollReveal>
          <div className="text-center mb-16">
            <span className="text-gold text-sm font-semibold uppercase tracking-widest mb-4 block">
              Features
            </span>
            <h2 className="text-4xl md:text-5xl font-bold text-text-primary mb-6">
              Everything you need for
              <br />
              <span className="text-gold-gradient">daily tadabbur</span>
            </h2>
            <p className="text-text-secondary text-lg max-w-xl mx-auto">
              A complete contemplation experience designed with care, depth, and
              respect for the sacred text.
            </p>
          </div>
        </ScrollReveal>

        <StaggerContainer className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {features.map((feature) => (
            <StaggerItem key={feature.title}>
              <div className="card-sacred p-8 h-full group">
                <div
                  className={`w-12 h-12 rounded-xl bg-gradient-to-br ${feature.accent} flex items-center justify-center mb-6 text-white transition-transform duration-300 group-hover:scale-110`}
                >
                  {feature.icon}
                </div>
                <h3 className="text-xl font-semibold text-text-primary mb-3">
                  {feature.title}
                </h3>
                <p className="text-text-secondary leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}
