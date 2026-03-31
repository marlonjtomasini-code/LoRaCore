# Invariantes do LoRaCore

1. US915 sub-band 1, OTAA, ChirpStack v4 — baseline inegociavel
2. Firmware deve compilar (`pio run`) antes de qualquer claim de conclusao
3. Operacao 100% offline — sem dependencia de internet
4. Docs-as-Code — mudanca de comportamento requer doc atualizada
5. Hardware-first — tarefas com hardware ficam blocked ate inspecao fisica
6. Templates genericos — placeholders, nunca valores hardcoded
7. Codecs JS seguem padrao `function decodeUplink(input)` do ChirpStack v4
