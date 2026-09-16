# Protheus Integration Lab

[![ADVPL](https://img.shields.io/badge/Language-ADVPL%2FTL%2B%2B-005696?style=flat)](https://tdn.totvs.com/)
[![ERP](https://img.shields.io/badge/Platform-TOTVS%20Protheus%2012-ED1C24?style=flat)](https://www.totvs.com/protheus/)
[![Architecture](https://img.shields.io/badge/Pattern-Event--Driven%20%7C%20Reconciliation-success?style=flat)](#integration-patterns)
[![Security](https://img.shields.io/badge/Auth-OAuth2%20%7C%20HMAC-orange?style=flat)](#security--architectural-standards)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An enterprise architectural reference and code laboratory showcasing **integration patterns** between **TOTVS Protheus ERP** and external modern cloud services.

Includes complete, battle-tested ADVPL implementations for **Event-Driven Webhook Ingestion**, **Payment Gateway Reconciliation**, and **OAuth2-authenticated REST API consumption**.

---

> [!NOTE]
> **Educational & Security Disclaimer**:  
> All routines, schemas, endpoints, table names (`ZZ3`, `ZZ4`), and sample payloads in this repository are strictly educational and generic. No proprietary customer names, confidential ERP business rules, production IP addresses, or corporate credentials are used.

---

## Integration Patterns

```mermaid
graph TB
    subgraph External Cloud Services
        GW[Payment Gateway<br/>Stripe / PagSeguro / MercadoPago]
        EXP[Expense Cloud API<br/>SAP Concur / Expensify]
        EC[E-Commerce Platform<br/>VTEX / Shopify]
    end

    subgraph Protheus Integration Middleware
        subgraph Pattern 1: Webhook Ingestion
            WH[WSOBJ WebhookReceiver<br/>/api/webhook/events]
            Queue[(Staging Queue ZZ4)]
            Worker[Protheus Background Job<br/>Queue Consumer]
        end

        subgraph Pattern 2: Polling Reconciliation
            BatchJob[Scheduled Reconciliation Job<br/>PaymentGateway]
            State[(Local Ledger & Status SE1/SE2)]
        end

        subgraph Pattern 3: Outbound REST
            OAuth[OAuth2 Token Manager]
            Client[FWHttpRest Client<br/>ExpenseApiIntegration]
            Staging[(Expense Staging ZZ3)]
        end
    end

    subgraph TOTVS Protheus Core
        ExecAuto[ExecAuto / FWMVC Engine]
        SQLServer[(Microsoft SQL Server)]
    end

    EC -->|POST Event Payload| WH
    WH -->|Immediate ACK 200/202| EC
    WH -->|Stage Payload| Queue
    Queue --> Worker
    Worker --> ExecAuto

    BatchJob -->|GET /v1/payments?status=pending| GW
    BatchJob --> State
    BatchJob -->|POST /confirm| GW

    OAuth -->|POST /oauth/token| EXP
    Client -->|GET /v1/expenses| EXP
    Client --> Staging
    Staging --> ExecAuto

    ExecAuto --> SQLServer
```

---

## Pattern 1: Event-Driven Webhook Ingestion & Decoupled Queue

When external platforms notify Protheus of business events (e.g. order placed, payment settled, customer registered), synchronous execution inside the HTTP request thread creates thread pool exhaustion and timeout risks.

This pattern demonstrates **asynchronous staging**: the incoming webhook is validated, written immediately to a persistent queue table (`ZZ4`), and acknowledged with HTTP `200 OK` in milliseconds. A background worker job processes the queue asynchronously.

### Webhook Processing Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor External as External Service (E-Commerce / Gateway)
    participant WSOBJ as WebhookReceiver (WSOBJ REST)
    participant Queue as Staging Queue Table (ZZ4)
    participant Worker as Background Schedule Worker
    participant ERP as Protheus Core (MATA410 / FINA070)

    External->>WSOBJ: POST /api/webhook/events (JSON Event Body)
    Note over WSOBJ: WsGetPostContent() + JSON validation
    WSOBJ->>WSOBJ: Event router (Do Case: order.created, payment.received)
    WSOBJ->>Queue: RecLock("ZZ4", .T.) -> Write Event, RefID, Timestamp
    Queue-->>WSOBJ: Commit OK
    WSOBJ-->>External: HTTP 200 {"status": "processed", "event": "order.created"}
    
    Note over Worker: Asynchronous Schedule / Thread Execution
    Worker->>Queue: Read pending events (ZZ4_STATUS == 'P')
    Worker->>ERP: Execute business validation & ExecAuto
    alt Business Rule Succeeded
        ERP-->>Worker: Record inserted (SE1 / SC5)
        Worker->>Queue: Update ZZ4_STATUS = 'C' (Completed)
    else Validation Failed
        ERP-->>Worker: Error array returned
        Worker->>Queue: Update ZZ4_STATUS = 'E', ZZ4_ERROR = cLog
    end
```

#### Supported Event Types (`webhook-receiver.prw`)
- `order.created` — Stage e-commerce purchase order for sales order generation.
- `order.updated` — Track logistical or fulfillment status modifications.
- `payment.received` — Automatic receivable settlement (`Contas a Receber`).
- `customer.created` — Customer synchronization into the entity master (`SA1`).

---

## Pattern 2: Polling Reconciliation (Payment Gateway)

In financial integrations where webhooks are either unavailable or require dual-ledger verification, the system runs scheduled batch jobs using `FWHttpRest` to poll the external gateway for pending transactions and synchronize statuses.

### Reconciliation Workflow (`payment-gateway.prw`)

```mermaid
sequenceDiagram
    autonumber
    participant Job as Protheus Scheduled Task
    participant Gateway as Payment Gateway API
    participant DB as SQL Server (SE1 - Contas a Receber)

    Job->>Gateway: GET /v1/payments?status=pending&date_from=...
    Gateway-->>Job: 200 OK (JSON array with pending charges)
    loop For each pending transaction
        Job->>DB: Match transaction ID with financial title (E1_NUM / E1_IDTRANS)
        alt Title Found & Confirmed
            Job->>DB: Perform settlement (Baixa de Título - FINA070)
            Job->>Gateway: POST /v1/payments/{id}/confirm {"titulo_protheus": "...", "data": "..."}
            Gateway-->>Job: 200 OK Confirmation ACK
        else Title Not Found
            Job->>Job: Log discrepancy for manual auditing
        end
    end
```

---

## Pattern 3: OAuth2-Protected Outbound Consumption (`expense-api.prw`)

Enterprise systems frequently integrate with SaaS platforms (corporate travel, corporate cards, expense managers). This pattern implements:
1. **OAuth2 Client Credentials Grant**: Securely requests a Bearer token via `POST /oauth/token`.
2. **Authorized Data Retrieval**: Queries approved expense reports with `Authorization: Bearer <token>`.
3. **Staging Batch Ingestion**: Populates staging tables (`ZZ3`) prior to automated accounts payable (`SE2`) posting.

---

## Repository Map

```
protheus-integration-lab/
├── README.md
├── .gitattributes
└── examples/
    ├── payment-gateway/
    │   └── payment-gateway.prw     # Query pending gateway transactions, reconcile & callback
    ├── expense-api/
    │   └── expense-api.prw         # OAuth2 Client Credentials flow, JSON parsing & ZZ3 staging
    └── webhook/
        └── webhook-receiver.prw    # WSOBJ endpoint, JSON routing, event logging & queue dispatch
```

---

## Example JSON Payloads

### Webhook Event Payload (`POST /api/webhook/events`)

```json
{
  "event": "payment.received",
  "resource": "payment",
  "id": "PAY-89234710",
  "amount": 1450.75,
  "timestamp": "2026-09-16T15:30:00Z",
  "customer": {
    "name": "Acme Distribuidora Ltda",
    "document": "12345678000199"
  }
}
```

### Webhook Response Payload (`200 OK`)

```json
{
  "status": "processed",
  "event": "payment.received"
}
```

### Expense API Payload (`GET /v1/expenses?status=approved`)

```json
{
  "total": 1,
  "data": [
    {
      "id": "EXP-2026-0891",
      "employee_id": "000142",
      "description": "Viagem Técnica - Instalação de Equipamentos",
      "amount": 620.50,
      "date": "20260912",
      "category": "HOSPEDAGEM"
    }
  ]
}
```

---

## Security & Architectural Standards

1. **Idempotency**: All webhook events must be checked against duplicate event IDs (`ZZ4_REFID`) before processing.
2. **Credential Safety**: Never hardcode production API secrets or bearer tokens in `.prw` source files. Store sensitive parameters in encrypted Protheus parameter tables (`SX6`) or environment secret managers.
3. **Transactional Integrity**: Use `Begin Transaction` and `DisarmTransaction()` blocks when moving staged records into official ERP tables (`SC5`, `SE1`, `SE2`, `SA1`).
4. **Network Resilience**: Configure explicit timeouts (`oHttp:nTimeOut := 30`) on outbound calls to avoid holding AppServer worker threads indefinitely.

---

## License

This project is licensed under the [MIT License](LICENSE).
