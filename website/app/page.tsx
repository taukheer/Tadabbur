import Navbar from "@/components/navbar";
import Hero from "@/components/hero";
import Features from "@/components/features";
import HowItWorks from "@/components/how-it-works";
import ReflectionTiers from "@/components/reflection-tiers";
import VersePreview from "@/components/verse-preview";
import Stats from "@/components/stats";
import DownloadCTA from "@/components/download-cta";
import Footer from "@/components/footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <div className="geometric-divider max-w-2xl mx-auto" />
        <Features />
        <div className="geometric-divider max-w-2xl mx-auto" />
        <HowItWorks />
        <div className="geometric-divider max-w-2xl mx-auto" />
        <ReflectionTiers />
        <div className="geometric-divider max-w-2xl mx-auto" />
        <VersePreview />
        <Stats />
        <div className="geometric-divider max-w-2xl mx-auto" />
        <DownloadCTA />
      </main>
      <Footer />
    </>
  );
}
