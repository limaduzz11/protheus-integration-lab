# Laboratório de Integração Protheus

[![ADVPL](https://img.shields.io/badge/Linguagem-ADVPL%2FTL%2B%2B-005696?style=flat)](https://tdn.totvs.com/)
[![ERP](https://img.shields.io/badge/Plataforma-TOTVS%20Protheus%2012-ED1C24?style=flat)](https://www.totvs.com/protheus/)
[![Arquitetura](https://img.shields.io/badge/Padr%C3%A3o-Event--Driven%20%7C%20Reconcilia%C3%A7%C3%A3o-success?style=flat)](#padrões-de-integração)
[![Segurança](https://img.shields.io/badge/Auth-OAuth2%20%7C%20HMAC-orange?style=flat)](#padrões-de-segurança-e-arquitetura)
[![Licença: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-yellow.svg)](LICENSE)

<br />

[English](README.md) &nbsp;|&nbsp; **Português (Brasil)**

<br />

Referência arquitetural e laboratório de código demonstrando **padrões corporativos de integração** entre o **TOTVS Protheus ERP** e serviços modernos em nuvem.

Contempla implementações canônicas em ADVPL para **Ingestão de Webhooks orientada a eventos**, **Reconciliação de Gateway de Pagamentos** e **Consumo de APIs REST com autenticação OAuth2**.

---

> [!NOTE]
> **Aviso Educacional & de Segurança**:  
> Todas as rotinas, esquemas, endpoints, tabelas customizadas (`ZZ3`, `ZZ4`) e cargas de dados de exemplo neste repositório são estritamente educacionais e genéricas. Não há nomes de clientes reais, regras de negócio confidenciais, IPs de produção ou credenciais corporativas.

---

## Padrões de Integração

```mermaid
graph TB
    subgraph Servicos em Nuvem Externos
        GW[Gateway de Pagamentos<br/>Stripe / PagSeguro / MercadoPago]
        EXP[API de Despesas em Nuvem<br/>SAP Concur / Expensify]
        EC[Plataforma de E-Commerce<br/>VTEX / Shopify]
    end

    subgraph Middleware de Integracao Protheus
        subgraph Padrao 1: Ingestao de Webhooks
            WH[WSOBJ WebhookReceiver<br/>/api/webhook/events]
            Queue[(Fila de Staging ZZ4)]
            Worker[Job em Background Protheus<br/>Consumidor de Fila]
        end

        subgraph Padrao 2: Reconciliacao por Polling
            BatchJob[Job Agendado de Reconciliacao<br/>PaymentGateway]
            State[(Status Financeiro SE1/SE2)]
        end

        subgraph Padrao 3: REST Outbound
            OAuth[Gerenciador de Token OAuth2]
            Client[Cliente FWHttpRest<br/>ExpenseApiIntegration]
            Staging[(Staging de Despesas ZZ3)]
        end
    end

    subgraph Core TOTVS Protheus
        ExecAuto[Motor ExecAuto / FWMVC]
        SQLServer[(Microsoft SQL Server)]
    end

    EC -->|POST Evento| WH
    WH -->|ACK Imediato 200/202| EC
    WH -->|Persiste Payload| Queue
    Queue --> Worker
    Worker --> ExecAuto
    ExecAuto --> SQLServer

    BatchJob -->|Polling GET /charges| GW
    BatchJob -->|Atualiza Baixas| State
    State --> SQLServer

    Client -->|POST /oauth/token| OAuth
    OAuth -->|Bearer Token| Client
    Client -->|GET /expenses| EXP
    Client -->|Grava Registros| Staging
    Staging --> ExecAuto
```

---

## Padrões de Segurança e Arquitetura

1. **Idempotência**: Todos os eventos recebidos via webhook são confrontados contra IDs de eventos já processados (`ZZ4_REFID`) para prevenir duplicidade de lançamentos.
2. **Segurança de Credenciais**: Credenciais de API ou tokens de produção nunca devem ser gravados diretamente em fontes `.prw`. Devem ser gerenciados via tabelas cifradas (`SX6`) ou cofres de segredos.
3. **Integridade Transacional**: Uso mandatório de `Begin Transaction` e `DisarmTransaction()` na migração de dados de staging para tabelas oficiais (`SC5`, `SE1`, `SE2`, `SA1`).
4. **Resiliência de Rede**: Definição de timeouts explícitos (`oHttp:nTimeOut := 30`) em chamadas outbound para evitar retenção indefinida de threads no AppServer.

---

## Licença

Distribuído sob a licença [MIT](LICENSE).
