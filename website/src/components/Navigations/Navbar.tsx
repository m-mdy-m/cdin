import logo from "../../../../scripts/icon.svg";

export default function Navbar() {
  return (
    <nav className="px-8 py-6 flex items-center justify-between">
      <a href="/" className="flex items-center ">
        <img src={logo} alt="cdin_logo" className="w-16 aspect-square" />
        <span>cdin</span>
      </a>
      <div>links</div>
    </nav>
  );
}
