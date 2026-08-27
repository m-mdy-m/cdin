import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { faqs } from "@/consts/faqs";
import { Button } from "../ui/button";
import { ArrowRight } from "lucide-react";

export default function Faqs() {
  return (
    <div className="md:px-10 px-4 border-y py-10">
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
            <AccordionContent className="lg:text-base text-sm text-muted-foreground">
              {faq.answer}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
      <Button
        className="lg:text-xl lg:py-6 mt-8 flex flex-row items-center gap-1 w-fit"
        size={"lg"}
        asChild
      >
        <a href="docs">
          Read docs <ArrowRight />
        </a>
      </Button>
    </div>
  );
}
