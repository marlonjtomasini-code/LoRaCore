# ADR-0004: Observabilidade via scripts shell vs Prometheus/Grafana

**Data:** 2026-03-29
**Status:** Aceito
**Contexto:** TASK-2026-0006

## Decisao

Usar **scripts shell + cron + logs textuais** para monitoramento e observabilidade da infraestrutura LoRaWAN, em vez de Prometheus + Grafana + Alertmanager.

## Contexto

O RPi5 executa 7 servicos em producao (lora-pkt-fwd, chirpstack-mqtt-forwarder, mosquitto, chirpstack, chirpstack-rest-api, postgresql, redis-server). Cada servico tem overrides systemd com limites de memoria (MemoryHigh/MemoryMax). O microSD e o recurso mais limitado (I/O e espaco).

### Opcao A: Prometheus + Grafana (descartada)

- Node Exporter + Prometheus + Grafana + Alertmanager
- RAM adicional: 200-400 MB (Prometheus 100-200 MB, Grafana 50-150 MB, Node Exporter 20 MB)
- Armazenamento: TSDB do Prometheus cresce continuamente
- I/O constante no microSD (escritas do TSDB)
- Complexidade: 4 servicos adicionais para configurar, manter e atualizar
- Beneficio: dashboards graficos, queries flexiveis (PromQL), alertas sofisticados

### Opcao B: Scripts shell + cron (aceita)

- 4 scripts bash, zero dependencias externas
- RAM adicional: ~0 MB (execucao transiente via cron)
- Armazenamento: logs textuais rotativos (logrotate semanal, 12 semanas)
- I/O minimo (append de poucas linhas por execucao)
- Complexidade: cron + logrotate (ja presentes em qualquer Linux)
- Beneficio: 90% da visibilidade operacional com 1% da complexidade

## Justificativa

1. **Restricao de recursos**: com 7 servicos e limites de memoria via systemd, adicionar 200-400 MB de stack de monitoramento comprometeria a margem operacional. Os stress tests (v2, v3) mostraram que o RPi5 ja opera proximo ao limite sob carga.

2. **Durabilidade do microSD**: o TSDB do Prometheus faz escritas constantes. O sysctl ja foi tunado (vm.swappiness=10, vm.dirty_ratio=10) para minimizar I/O — adicionar uma fonte persistente de escritas contraria essa decisao (ADR implicitoo no hardening).

3. **Operacao offline**: a infraestrutura opera 100% offline. Grafana dashboards sem acesso remoto (navegador local no RPi) tem utilidade limitada. Logs textuais sao consultaveis via SSH com `grep`/`tail -f`.

4. **Proporcionalidade**: para uma instalacao single-node com < 100 devices, a sofisticacao do Prometheus/Grafana nao se justifica. Scripts shell cobrem os cenarios criticos (servico caiu, gateway travou, device offline, disco cheio).

## Consequencias

- **Positivo**: zero overhead de RAM/CPU/I/O, deploy trivial, zero dependencias novas
- **Positivo**: formato de log identico ao script de backup — um unico `grep` pesquisa tudo
- **Negativo**: sem graficos historicos ou PromQL para queries ad-hoc
- **Negativo**: alertas limitados a log (sem notificacao push/email/Slack)
- **Mitigacao futura**: se escalar para multi-gateway ou > 100 devices, reavaliar Prometheus com armazenamento em SSD externo

## Referencia

- Stress test v2/v3: uso de recursos sob carga extrema
- Hardening systemd: limites MemoryHigh/MemoryMax por servico
- Sysctl tuning: vm.swappiness, vm.dirty_ratio
