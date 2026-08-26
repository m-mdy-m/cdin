import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { faqs } from "@/consts/faqs";

export default function Faqs() {
  return (
    <div className="px-10 mt-14">
      <Accordion type="single" defaultValue="item-0">
        {faqs.map((faq, i) => (
          <AccordionItem
            className="md:not-last:border-b-0 md:min-w-0 md:w-fit"
            value={`item-${i}`}
            key={i}
          >
            <AccordionTrigger className="text-xl lg:text-2xl font-semibold cursor-pointer">
              {faq.question}
            </AccordionTrigger>
            <AccordionContent>{faq.answer}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}
