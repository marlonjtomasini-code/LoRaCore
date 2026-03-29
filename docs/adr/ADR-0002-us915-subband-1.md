# ADR-0002: US915 Sub-band 1

## Status

Aceito (2026-03-28)

## Contexto

O plano de frequencias US915 define 72 canais de uplink divididos em 8 sub-bands de 8 canais cada (125 kHz) + 8 canais de 500 kHz. Um concentrador SX1302 com dois radios cobre no maximo 8 canais de 125 kHz + 1 canal de 500 kHz simultaneamente — ou seja, exatamente uma sub-band.

A escolha da sub-band afeta quais frequencias o gateway escuta e quais frequencias os devices transmitem. Gateway e devices devem usar a mesma sub-band.

## Opcoes Consideradas

1. **Sub-band 1** (canais 0-7: 902.3-903.7 MHz + canal 64: 903.0 MHz)
2. **Sub-band 2** (canais 8-15: 903.9-905.3 MHz + canal 65)
3. Outras sub-bands (3-8)

## Decisao

Adotar **Sub-band 1**.

## Justificativa

- **Padrao de facto**: a maioria dos gateways e redes LoRaWAN publicas nas Americas usa sub-band 2 (TTN, Helium). Ao usar sub-band 1, o LoRaCore evita interferencia com redes publicas em ambientes onde coexistam
- **Compatibilidade**: os firmwares Heltec CubeCell e RAK3172 suportam selecao de sub-band via channel mask. Sub-band 1 e a primeira opcao natural (canais 0-7)
- **Simplicidade**: canais numerados de 0 a 7 facilitam debug e correlacao com logs do concentrador
- **Sem vantagem tecnica entre sub-bands**: todas as sub-bands tem as mesmas caracteristicas de propagacao (mesmo BW, mesma potencia TX permitida)

## Consequencias

**Positivas:**
- Separacao de interferencia com redes publicas (TTN/Helium tipicamente em sub-band 2)
- Channel mask simples: `0x00FF,0x0000,0x0000,0x0000,0x0000,0x0000`
- Debug facilitado (canais 0-7 sao intuitivos)

**Negativas:**
- Devices comprados pre-configurados para TTN (sub-band 2) precisam de reconfiguracao de channel mask no firmware
- Para cobrir multiplas sub-bands, e necessario hardware adicional (segundo concentrador)

## Referencia

- [DOC_PROTOCOLO Secoes 10-11](../DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#10-configuracao-de-regiao-e-frequencias-us915) — configuracao de regiao e plano de frequencias
