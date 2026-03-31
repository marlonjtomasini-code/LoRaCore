# ADR-0007: Acesso remoto via reverse SSH tunnel vs VPN

**Data:** 2026-03-31
**Status:** Aceito
**Contexto:** Plano de auto-recuperacao para operacao remota desassistida

## Decisao

Usar **autossh com reverse SSH tunnel** para acesso remoto ao RPi5, em vez de VPN (Tailscale, WireGuard, ZeroTier).

## Contexto

O RPi5 operara em local de dificil acesso, potencialmente atras de NAT, firewalls e com IP dinamico. O operador precisa acessar o RPi5 via SSH mesmo estando fora da LAN.

### Opcao A: Tailscale (descartada)

- ~40 MB de footprint em memoria
- Requer conta em servico terceiro (Tailscale Inc.)
- Depende de coordination servers na internet
- Contradiz invariante 3 (operacao 100% offline)
- Excellent UX mas overhead injustificavel para single-node

### Opcao B: WireGuard (descartada)

- Kernel module + userspace tools
- Requer servidor com IP fixo ja configurado como peer
- Configuracao de chaves e endpoints mais complexa
- Se o peer muda de IP, requer reconfiguracao manual
- Melhor para site-to-site, overkill para acesso SSH pontual

### Opcao C: ZeroTier (descartada)

- Similar ao Tailscale em conceito
- Requer conta em ZeroTier Central
- ~30 MB footprint
- Depende de root servers para coordenacao

### Opcao D: autossh reverse SSH tunnel (aceita)

- autossh e ~50 KB, SSH ja esta instalado
- Zero conta em servico terceiro
- Funciona atras de qualquer NAT/firewall (RPi5 inicia a conexao)
- Requer apenas um servidor SSH acessivel pela internet (VPS, home server)
- Auto-reconnect nativo via systemd + autossh
- ~3-5 MB RAM em uso

## Justificativa

1. **Footprint minimo**: autossh + SSH session usam ~3-5 MB RAM vs 30-40 MB de VPN. Em um RPi5 com 7 servicos e limites de memoria via systemd, cada MB conta.

2. **Zero dependencia externa**: nao requer conta em servico terceiro. O operador controla o servidor relay.

3. **Compatibilidade com offline-first**: o tunnel e best-effort. Se internet nao esta disponivel, o tunnel nao conecta mas a stack LoRaWAN continua operando normalmente.

4. **Seguranca**: chave SSH dedicada, revogavel independentemente. Usuario do relay restrito a port-forwarding (sem shell). Tunnel roda como usuario, nao root.

5. **Simplicidade operacional**: o operador ja sabe usar SSH. Nenhuma ferramenta nova ou conceito novo para aprender.

## Consequencias

- **Positivas**: acesso remoto com zero overhead; auto-reconnect; seguranca por isolamento
- **Negativas**: requer um servidor relay com SSH; a porta reversa pode colidir se multiplos gateways usam o mesmo relay
- **Riscos**: se o relay fica offline, perde-se acesso remoto — mitigado por acesso local via LAN

## Referencia

- https://www.harding.motd.ca/autossh/
- `templates/remote-access/README.md`
