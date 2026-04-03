# Regras de Resiliencia Firmware

Aplicar estas regras ao revisar ou escrever codigo de firmware para dispositivos LoRaWAN.

## Timeout obrigatorio

- Toda operacao de I/O (Wire, SPI, Serial, LoRa) deve ter timeout explicito
- Nunca bloquear indefinidamente esperando resposta de periferico
- Excecao: leituras periodicas nao-criticas (ciclo < 1 min) podem omitir timeout se watchdog estiver ativo

## Retry limitado

- Tentativas de reconexao devem ter maximo definido (ex: 3 tentativas)
- Retry infinito sem watchdog = dispositivo travado (anti-pattern)

## Fallback

- Definir comportamento quando periferico falha: usar ultimo valor valido, setar flag de erro, ou pular ciclo
- Nunca engolir erro silenciosamente

## Watchdog

- Loop principal deve alimentar watchdog periodicamente
- Se travado alem do timeout do watchdog, reset automatico do dispositivo
- `while(!begin())` na inicializacao e aceitavel se watchdog estiver configurado

## Observabilidade

- Registrar falhas em variavel de estado acessivel (serial, payload LoRa, LED)
- Nunca falhar silenciosamente — deve haver indicacao visivel ou transmitida

## Uplinks

- Telemetria usa unconfirmed uplink (economia de airtime; proximo uplink e retry natural)
- Confirmed uplink apenas para comandos criticos

## Anti-patterns

- `delay()` como timeout (bloqueia sistema inteiro)
- Engolir excecoes/erros sem registrar
- Retry infinito sem watchdog
- Loop principal sem alimentar watchdog
