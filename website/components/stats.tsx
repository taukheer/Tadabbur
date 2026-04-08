import { StaggerContainer, StaggerItem } from "./scroll-reveal";
import ScrollReveal from "./scroll-reveal";

const stats = [
  { value: "6,236", label: "Verses to contemplate", suffix: "" },
  { value: "21", label: "Languages supported", suffix: "" },
  { value: "3", label: "Reflection tiers", suffix: "" },
  { value: "∞", label: "Room for growth", suffix: "" },
];

export default function Stats() {
  return (
    <section className="section-padding relative">
      <div className="mx-auto max-w-5xl">
        <ScrollReveal>
          <div className="text-center mb-4">
            <span className="text-gold text-sm font-semibold uppercase tracking-widest mb-4 block">
              Built for Depth
            </span>
          </div>
        </ScrollReveal>

        <StaggerContainer className="grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8">
          {stats.map((stat) => (
            <StaggerItem key={stat.label}>
              <div className="text-center py-8">
                <p className="text-4xl md:text-5xl font-bold text-gold-gradient mb-3">
                  {stat.value}
                  {stat.suffix}
                </p>
                <p className="text-text-secondary text-sm">{stat.label}</p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}
