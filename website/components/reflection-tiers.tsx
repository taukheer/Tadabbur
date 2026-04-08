import ScrollReveal from "./scroll-reveal";
import { StaggerContainer, StaggerItem } from "./scroll-reveal";

const tiers = [
  {
    tier: 1,
    name: "Acknowledge",
    arabic: "إقرار",
    description:
      "Read the verse and its meaning. Mark that you have received and understood it today.",
    example: "I read and understood this verse about patience in hardship.",
    color: "#6BA3BE",
    bgGradient: "from-[#6BA3BE]/10 to-transparent",
    borderColor: "border-[#6BA3BE]/20",
    dotColor: "bg-[#6BA3BE]",
  },
  {
    tier: 2,
    name: "Respond",
    arabic: "استجابة",
    description:
      "Write how this verse connects to your life. Share a personal thought, memory, or commitment.",
    example:
      "This verse reminded me of my mother's patience during difficult times. It makes me want to embody that same grace when I face challenges at work.",
    color: "#C9A96E",
    bgGradient: "from-[#C9A96E]/10 to-transparent",
    borderColor: "border-[#C9A96E]/20",
    dotColor: "bg-[#C9A96E]",
  },
  {
    tier: 3,
    name: "Reflect",
    arabic: "تدبّر",
    description:
      "Deep contemplation. Explore the verse's layers, its context in the Quran, and how it reshapes your understanding.",
    example:
      "The scholars note this verse was revealed during the siege of Madinah, when the believers faced existential threat. The command to be patient here isn't passive — it's an active, conscious choice to trust the divine plan even when all evidence suggests despair...",
    color: "#9B7FD4",
    bgGradient: "from-[#9B7FD4]/10 to-transparent",
    borderColor: "border-[#9B7FD4]/20",
    dotColor: "bg-[#9B7FD4]",
  },
];

export default function ReflectionTiers() {
  return (
    <section id="reflection" className="section-padding relative">
      {/* Glow */}
      <div
        className="glow-orb w-[600px] h-[400px] top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{ background: "radial-gradient(circle, rgba(155,127,212,0.08) 0%, transparent 70%)" }}
        aria-hidden="true"
      />

      <div className="mx-auto max-w-6xl relative">
        <ScrollReveal>
          <div className="text-center mb-16">
            <span className="text-gold text-sm font-semibold uppercase tracking-widest mb-4 block">
              The Heart of Tadabbur
            </span>
            <h2 className="text-4xl md:text-5xl font-bold text-text-primary mb-6">
              Three tiers of
              <br />
              <span className="text-gold-gradient">contemplation</span>
            </h2>
            <p className="text-text-secondary text-lg max-w-2xl mx-auto">
              Not every day calls for deep reflection. Some days you acknowledge,
              some days you respond, and some days you go deep. Every tier is
              valid. Every tier is growth.
            </p>
          </div>
        </ScrollReveal>

        <StaggerContainer className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {tiers.map((tier) => (
            <StaggerItem key={tier.tier}>
              <div
                className={`card-sacred p-8 h-full relative overflow-hidden`}
              >
                {/* Top accent */}
                <div
                  className="absolute top-0 left-0 right-0 h-1"
                  style={{ background: tier.color }}
                />

                {/* Tier badge */}
                <div className="flex items-center gap-3 mb-6">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold"
                    style={{
                      background: `${tier.color}15`,
                      color: tier.color,
                      border: `1px solid ${tier.color}30`,
                    }}
                  >
                    {tier.tier}
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-text-primary">
                      {tier.name}
                    </h3>
                    <span
                      className="text-sm font-arabic"
                      style={{ color: tier.color }}
                    >
                      {tier.arabic}
                    </span>
                  </div>
                </div>

                <p className="text-text-secondary text-sm leading-relaxed mb-6">
                  {tier.description}
                </p>

                {/* Example card */}
                <div
                  className="rounded-xl p-4"
                  style={{
                    background: `${tier.color}08`,
                    border: `1px solid ${tier.color}15`,
                  }}
                >
                  <span
                    className="text-xs font-semibold uppercase tracking-wider mb-2 block"
                    style={{ color: tier.color }}
                  >
                    Example
                  </span>
                  <p className="text-text-secondary/80 text-sm italic leading-relaxed">
                    &ldquo;{tier.example}&rdquo;
                  </p>
                </div>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}
