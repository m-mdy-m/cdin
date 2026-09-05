import heroimage from "../../../../assets/CDIN-HOME.png";

export default function HeroImage() {
  return (
    <div className="px-4 md:px-10">
      <div className="border-4 border-secondary hover:border-primary duration-100 hover:scale-101 rounded-lg p-2 w-full">
        <img
          src={heroimage}
          alt="cdin home"
          className="w-full aspect-auto object-cover rounded"
        />
      </div>
    </div>
  );
}
