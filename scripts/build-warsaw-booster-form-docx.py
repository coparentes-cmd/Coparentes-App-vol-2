#!/usr/bin/env python3
"""Generate Warsaw Booster'26 advanced form answers as Word document."""

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt, RGBColor

OUTPUT = Path("/Users/kingastaszewska/Desktop/coparentes_odpowiedzi_warsaw_booster_zaawansowany.docx")

SECTIONS = [
    (
        "Strona 1 — Projekt i rynek",
        [
            (
                "Nazwa Projektu (wskazana w Formularzu Podstawowym)",
                "Coparentes",
            ),
            (
                "Numer rejestracyjny KRS / numer identyfikujący w CEIDG firmy",
                "0",
            ),
            (
                "Numer NIP",
                "0",
            ),
            (
                "Opis problemu, którego dotyczy Twoje rozwiązanie.",
                "W Polsce i w UE co druga para po rozwodzie wychowuje nieletnie dzieci, a coraz więcej dzieci "
                "rodzi się w związkach nieformalnych. W 2023 roku w Polsce sądy orzekły wspólne wychowywanie "
                "w 74% rozwodów — rodzice muszą więc współpracować przez lata, mimo konfliktu i rozpadu relacji.\n\n"
                "Rozwód to jednak dopiero początek. Codzienność „na dwa domy” wiąże się z chaosem: kalendarzem "
                "opieki, przekazaniami dzieci, kosztami, dokumentami medycznymi i szkolnymi oraz napiętą komunikacją. "
                "Ustalenia z mediacji szybko zanikają, jeśli nie ma narzędzi, które je utrwalają — praktyka mediatorów "
                "pokazuje, że brak takiego wsparcia obniża trwałość ugody nawet o ok. 80%.\n\n"
                "Skutki to eskalacja konfliktów, postępowania sądowe, obciążenie psychiczne dzieci oraz koszty "
                "społeczne, zdrowotne i sądowe. Rodziny w miastach — w tym w Warszawie — szczególnie potrzebują "
                "skalowalnego, cyfrowego wsparcia w codziennej organizacji współrodzicielstwa, a nie tylko "
                "jednorazowej mediacji.",
            ),
            (
                "Szczegółowy opis Twojego rozwiązania (innowacyjność technologii/produktu/usługi)",
                "Coparentes to platforma cyfrowa wspierająca rodziców po rozstaniu w organizacji współrodzicielstwa "
                "na dwa domy. Łączy codzienne narzędzia operacyjne z dostępem do zweryfikowanych specjalistów "
                "— mediatorów, prawników i psychoterapeutów — i pomaga przekształcić chaos codzienności "
                "w uporządkowaną współpracę.\n\n"
                "W produkcie działają m.in.: tematyczny komunikator z kategoryzacją wiadomości i systemem akceptacji, "
                "współdzielony kalendarz opieki z prośbami o zamianę terminów, moduł finansów współrodzicielskich "
                "z raportami i wsparciem AI, archiwum dokumentów, panel dziecka (plan dnia, kanał Rodzina, "
                "prywatna lista zadań), AI Coach do neutralnego formułowania wiadomości, AI Shield do analiz "
                "i raportów, baza wiedzy z modułem prawa rodzinnego oraz katalog specjalistów z konsultacjami online.\n\n"
                "Innowacyjność polega na połączeniu codziennej operacyjności — kalendarza, finansów, komunikacji "
                "i konta dziecka — z AI oraz siecią ekspertów dostosowaną do prawa UE. Amerykańskie rozwiązania "
                "nie są adaptowane do polskiego prawa rodzinnego ani lokalnego ekosystemu mediacji.",
            ),
            (
                "Obecny etap rozwoju firmy/Projektu (dojrzałość technologiczna i produktowa)",
                "Projekt jest na etapie MVP / wczesnego produktu komercyjnego. Działa aplikacja web/PWA "
                "(getcoparentes.app) z backendem REST, wdrożona produkcyjnie. Zaimplementowano m.in. rejestrację "
                "rodziny, zaproszenia drugiego rodzica i dzieci, panel rodzica (Start, Czat, Kalendarz, Finanse, "
                "Dokumenty), panel dziecka, kanał Rodzina, AI Coach/Shield oraz tryb demo.\n\n"
                "Produkt testujemy z użytkownikami i ekspertami — w tym z mediatorką Bożeną Stajniak "
                "(12 lat praktyki) — oraz prowadzimy badania jakościowe z rodzicami. Przygotowaliśmy pitch, "
                "materiały onboardingowe i dokumentację wdrożeniową. Model biznesowy opiera się na freemium "
                "(3 miesiące free) i subskrypcji; trwają pilotaże z pierwszymi użytkownikami i walidacja kanału B2B "
                "przez mediatorów.",
            ),
            (
                "Czy Projekt odpowiada na wyzwania miejskie Warsaw Booster'26? Kategoria:",
                "Pomoc Społeczna i Integracja\n\n"
                "Coparentes wspiera integrację rodzin po rozstaniu, angażuje dziecko w codzienne ustalenia, "
                "ułatwia dostęp do mediacji i pomocy specjalistycznej oraz ogranicza obciążenie instytucji "
                "— sądów, pomocy społecznej i szkół — poprzez prewencję konfliktów.",
            ),
            (
                "Jaki następny etap rozwoju (cel 2026–2027)?",
                "W latach 2026–2027 chcemy osiągnąć skalę w Warszawie i Polsce: minimum 1 000 aktywnych rodzin "
                "oraz 50 partnerów B2B (kancelarie mediacyjne, psychologowie, sądy polubowne). Równolegle "
                "walidujemy monetyzację — konwersję z 3-miesięcznego okresu próbnego na subskrypcję 39,99 PLN/m-c — "
                "oraz rozwijamy moduł ekspertów i integracje z polskim ekosystemem mediacji.\n\n"
                "Przygotowujemy też ekspansję na wybrane rynki UE (Niemcy, Francja, Hiszpania, Holandia) "
                "z lokalizacją prawa i języka. Będziemy mierzyć wpływ: trwałość ugód, skrócenie czasu "
                "komunikacji konfliktowej oraz satysfakcję rodziców i dzieci. Długoterminowo chcemy pomóc "
                "100 000 par po rozstaniu w porozumieniu się i codziennym życiu na dwa domy.",
            ),
            (
                "Uzasadnij wielkość i kierunki rozwoju rynku docelowego",
                "W UE co roku dochodzi do ok. 720 000 rozwodów; ok. 50% par rozwodzących się ma nieletnie dzieci, "
                "a 41% dzieci rodzi się w związkach pozamałżeńskich. Przy założeniu 30% pobrania aplikacji "
                "i 5% konwersji na płatność, TAM w UE wynosi ok. 7 mln EUR rocznie przy ARPU ~20 EUR/m-c.\n\n"
                "SAM obejmuje rynki o wysokiej dojrzałości mediacji i digitalizacji (DE, FR, NL, SE, PL, ES) "
                "— ok. 2–4 mln EUR/rok. Realistyczny SOM w perspektywie 3 lat to 200–600 tys. EUR/rok.\n\n"
                "Wzrost napędzają kanał B2C (rodzice w miastach), B2B2C (mediatorzy i prawnicy polecający aplikację), "
                "trend regulacyjny zachęcający do mediacji oraz rosnące zapotrzebowanie na narzędzia utrwalające "
                "efekt ugody.",
            ),
            (
                "Czy rynek jest gotowy natychmiast przyjąć rozwiązanie?",
                "Tak — rynek jest gotowy już teraz, choć skalowanie wymaga dalszych warunków.\n\n"
                "Popyt wspierają rosnąca liczba rozwodów i wspólnego wychowywania (74% w PL), presja państwa "
                "na mediację i ugody, brak europejskiego lidera w kategorii narzędzi współrodzicielskich "
                "z AI i ekspertami, dojrzałość płatności cyfrowych oraz przyspieszona digitalizacja usług "
                "rodzinnych po pandemii.\n\n"
                "Dalszy wzrost w latach 2026–2027 uwarunkowany będzie integracjami z kancelariami mediacyjnymi "
                "i programami miejskimi (np. pilotaże w Warszawie), lokalizacją prawną modułu AI dla kolejnych "
                "krajów UE oraz case studies pokazującymi realne korzyści dla rodziców — krótsze spory "
                "i niższe koszty prawne.",
            ),
        ],
    ),
    (
        "Strona 2 — Model biznesowy i konkurencja",
        [
            (
                "Model Biznesowy i przewagi konkurencyjne",
                "Stosujemy model hybrydowy B2C + B2B2C. Rodzice po rozstaniu płacą subskrypcję SaaS, "
                "a mediatorzy, prawnicy i psychoterapeuci współpracują z nami w modelu prowizji, abonamentu PRO "
                "lub widoczności w katalogu.\n\n"
                "Nasze przewagi to niski próg wejścia (3 miesiące free), AI Coach i AI Shield, dopasowanie "
                "do lokalnego prawa rodzinnego, panel dziecka, kompleksowość rozwiązania (komunikacja, kalendarz, "
                "finanse, eksperci) oraz zespół z 12-letnim doświadczeniem mediacyjnym.",
            ),
            (
                "Określ model biznesowy i uzasadnij skalowalność",
                "Model freemium przechodzi w subskrypcję: 3 miesiące free trial, potem 39,99 PLN/m-c "
                "lub 460 PLN/rok. Skalowalność wynika z niskich kosztów krańcowych (aplikacja web/cloud, "
                "jeden core produktu z lokalizacją prawną), efektu sieci w rodzinie (drugi rodzic i dzieci "
                "dołączają kodem zaproszenia), kanału B2B (jeden mediator obsługuje dziesiątki rodzin) "
                "oraz rosnącego TAM. Moduły AI i raporty zwiększają ARPU bez liniowego wzrostu kosztów operacyjnych.",
            ),
            (
                "Główna konkurencja (z linkami)",
                "OurFamilyWizard (https://www.ourfamilywizard.com) — lider globalny, bez adaptacji do prawa UE/PL. "
                "AppClose (https://appclose.com) — komunikacja i kalendarz, rynek amerykański. "
                "2houses (https://www.2houses.com) — kalendarz i komunikacja w UE, ograniczony AI "
                "i brak ekosystemu ekspertów w Polsce. Mediacja tradycyjna — usługa jednorazowa, "
                "bez narzędzia utrwalającego ugodę na lata. Ogólne narzędzia (WhatsApp, Google Calendar, Excel) "
                "— brak audytu, zgód, AI Coach i perspektywy dziecka.\n\n"
                "W Europie brakuje kompleksowego rozwiązania łączącego codzienną operacyjność, AI "
                "i sieć zweryfikowanych specjalistów.",
            ),
            (
                "Główna przewaga konkurencyjna",
                "Coparentes łączy mediację i ugodę z wieloletnią codziennością na dwa domy — w jednej platformie "
                "z AI Coach, panelem dziecka, finansami, dokumentami i katalogiem ekspertów dopasowanym "
                "do lokalnego prawa. Niski próg wejścia oraz zespół founderski łączący mediację, finanse, "
                "technologię i marketing B2B tworzą trudną do szybkiego skopiowania przewagę.",
            ),
            (
                "Przewagi IP i know-how",
                "Kluczowe IP to know-how mediacyjne i procesowe (Bożena Stajniak — 12 lat praktyki, "
                "Stowarzyszenie Mediatorów Pactus), metodologia kategoryzacji komunikacji i workflow ugód "
                "w sytuacjach wysokiego konfliktu, prompty i logika AI Coach/Shield dostosowane do języka "
                "współrodzicielstwa, baza treści prawno-edukacyjnych (PL → lokalizacja UE) oraz doświadczenia "
                "z pilotażu i badań jakościowych. Rejestracja znaków towarowych i patentów jest w planie; "
                "core IP opiera się na know-how, danych treningowych AI i UX.",
            ),
            (
                "Bariery wejścia dla konkurentów",
                "Bariery to zaufanie rodzin w sytuacji kryzysowej (wymaga ekspertyzy mediacyjnej i reputacji), "
                "lokalizacja prawa rodzinnego i języka, sieć partnerów B2B budowana latami, efekt sieci "
                "w obrębie rodziny (oboje rodzice i dzieci w jednym workspace) oraz złożoność produktu — "
                "komunikacja, finanse, kalendarz, konto dziecka i AI — co podnosi koszt replikacji MVP.",
            ),
            (
                "Pozytywne oddziaływanie na Warszawę i gospodarkę metropolitalną",
                "Społecznie Coparentes ogranicza eskalację konfliktów rodzinnych i obciążenie psychiki dzieci, "
                "wspiera integrację rodzin po rozstaniu oraz ułatwia dostęp do mediacji i specjalistów online — "
                "także dla rodzin o niższych dochodach, np. w pilotażach miejskich.\n\n"
                "Ekonomicznie redukuje koszty postępowań sądowych i powtarzalnych wizyt u prawników, "
                "zwiększa produktywność rodziców (mniej czasu na koordynację „na dwa domy”), rozwija ekosystem "
                "usług B2B w Warszawie (mediatorzy, terapeuci, legal tech) oraz otwiera potencjał eksportu "
                "produktu na rynki UE — z nowymi miejscami pracy w product, AI i customer success.",
            ),
        ],
    ),
    (
        "Strona 3 — Zespół, finansowanie, akceleracja",
        [
            (
                "Opisz kompetencje i doświadczenie zespołu (LinkedIn)",
                "Bożena Stajniak — Founderka, mediatorka (12 lat doświadczenia), sekretarz Zarządu "
                "Stowarzyszenia Mediatorów Pactus. Odpowiada za wizję produktu, badania jakościowe "
                "z użytkownikami, rozwój produktu i partnerstwa mediacyjne. LinkedIn: [UZUPEŁNIJ LINK]\n\n"
                "Kinga Staszewska — Co-founderka, audytorka finansowa (10 lat), doświadczenie "
                "w zarządzaniu zespołami międzynarodowych organizacji i kierowaniu biurem audytu "
                "dla globalnych spółek. Zarządzanie projektem, finanse, rozwój produktu, partnerzy. "
                "LinkedIn: [UZUPEŁNIJ LINK]\n\n"
                "Basia Jagoda — Co-founderka, 12 lat komunikacji usług technologicznych B2B "
                "(SAP, GFT, Benefit Systems, theprotocol.it). Sprzedaż, marketing, PR, badania jakościowe, "
                "partnerzy. LinkedIn: [UZUPEŁNIJ LINK]",
            ),
            (
                "Główny deficyt Projektu i brakujące kompetencje",
                "Do uzupełnienia w pierwszej kolejności brakuje CTO / lead developera na pełen etat "
                "(skalowanie architektury, mobile native, bezpieczeństwo, RODO, AI Act), specjalisty "
                "growth / performance marketing B2C oraz eksperta ds. compliance prawnego międzynarodowego "
                "przed ekspansją UE. Akceleracja Warsaw Booster pomoże zamknąć luki w go-to-market, "
                "metrykach wpływu i partnerstwach miejskich.",
            ),
            (
                "Finansowanie dotychczas pozyskane",
                "Projekt finansujemy z własnych środków zespołu founderskiego w modelu bootstrapping. "
                "Rozwój MVP i wdrożenie produkcji (aplikacja web, backend) opierają się na wkładzie w naturze "
                "i środkach własnych w latach 2024–2026. Wartość: [UZUPEŁNIJ KWOTĘ JEŚLI DEKLAROWANA PUBLICZNIE]. "
                "Źródło: founders / wkład w naturze.",
            ),
            (
                "Poszukiwane finansowanie i wykorzystanie środków",
                "Szukamy wsparcia akceleracyjnego Warsaw Booster oraz finansowania rozwoju "
                "rzędu 500 000 – 1 000 000 PLN (grant / inwestycja seed — do uzgodnienia z programem). "
                "Środki planujemy przeznaczyć na product & engineering (40%), marketing i pozyskanie "
                "użytkowników w Warszawie (30%), partnerstwa B2B (20%) oraz operacje, compliance "
                "i badania wpływu (10%).",
            ),
            (
                "Linki do prezentacji / pitch deck",
                "Pitch deck: COPARENTES_Pitch Deck.pdf\n"
                "Aplikacja: https://getcoparentes.app\n"
                "Instrukcja onboarding: https://getcoparentes.app/downloads/instrukcja-nowa-rodzina.pptx\n"
                "Video (pitch): https://youtu.be/V7WwPZUMF0o",
            ),
            (
                "Linki do dodatkowych materiałów",
                "https://getcoparentes.app\n"
                "https://youtu.be/V7WwPZUMF0o\n"
                "https://getcoparentes.app/downloads/\n\n"
                "Wideo-wizytówka 60 s: [DO NAGRANIA / LINK DO UZUPEŁNIENIA PRZED WYSYŁKĄ]",
            ),
            (
                "Obszary koncentracji podczas akceleracji",
                "Chcemy skupić się na go-to-market B2C i B2B w Warszawie (mediatorzy, sądy polubowne, "
                "instytucje pomocy rodzinom), metrykach wpływu społecznego (trwałość ugód, dobrostan dzieci), "
                "skalowaniu produktu i monetyzacji (konwersja free → paid), przygotowaniu do rundy seed "
                "i ekspansji UE oraz pitchingu inwestorskim i strukturze spółki.",
            ),
            (
                "Ile osób z zespołu zaangażowanych w akcelerator",
                "3 osoby — Bożena Stajniak, Kinga Staszewska, Basia Jagoda (founders).",
            ),
            (
                "Zgoda na zajęcia w języku angielskim",
                "Tak — wyrażamy zgodę na prowadzenie zajęć w języku angielskim.",
            ),
            (
                "Skąd dowiedzieliście się o akceleratorze",
                "Startup Hub Poland / program Warsaw Booster'26 — strona programu i proces kwalifikacji "
                "po Formularzu Podstawowym.",
            ),
            (
                "Akceptuję regulamin",
                "Tak — akceptujemy regulamin programu Warsaw Booster'26.",
            ),
        ],
    ),
]


def build() -> None:
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    title = doc.add_paragraph("Odpowiedzi do formularza Warsaw Booster")
    title.runs[0].bold = True
    title.runs[0].font.size = Pt(14)

    sub = doc.add_paragraph("Formularz Zaawansowany — wersja dopasowana do akceleratora")
    sub.runs[0].italic = True
    sub.runs[0].font.color.rgb = RGBColor(0x55, 0x55, 0x55)

    doc.add_paragraph("Formularz: https://forms.gle/LeMZJKGswXW26MBe6")
    doc.add_paragraph()

    q_num = 1
    for section_title, items in SECTIONS:
        doc.add_paragraph(section_title).runs[0].bold = True
        doc.add_paragraph()

        for question, answer in items:
            q = doc.add_paragraph()
            q_run = q.add_run(f"{q_num}. {question}")
            q_run.bold = True
            q_num += 1

            doc.add_paragraph(answer)
            doc.add_paragraph()

    doc.add_paragraph("Gotowe do skopiowania do formularza.").runs[0].italic = True

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(OUTPUT))
    print(f"Saved {OUTPUT}")


if __name__ == "__main__":
    build()
