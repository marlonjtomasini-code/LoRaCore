# Invariantes do LoRaCore

1. US915 sub-band 1, OTAA, ChirpStack v4 — baseline inegociavel
2. Firmware deve compilar (`pio run`) antes de qualquer claim de conclusao
3. Operacao 100% offline — sem dependencia de internet
4. Docs-as-Code — mudanca de comportamento requer doc atualizada
5. Hardware-first — tarefas com hardware ficam blocked ate inspecao fisica
6. Templates genericos — placeholders, nunca valores hardcoded
7. Codecs JS seguem padrao `function decodeUplink(input)` do ChirpStack v4

### Invariantes de Integracao

8. MQTT QoS 1 e `clean_session=false` para todos os subscribers — garante entrega at-least-once
9. ES5 JavaScript apenas nos codecs — sem features modernas de JS
10. Big-endian byte order para encoding de payload — exceto se explicitamente documentado de outra forma
11. Unconfirmed uplinks para telemetria — confirmed apenas para comandos criticos de atuadores
12. Erros de codec retornam `{ errors: [...] }` — nunca `{ data: {} }` silencioso
13. nwkKey e appKey com o mesmo valor ao registrar device keys (LoRaWAN 1.0.3)
