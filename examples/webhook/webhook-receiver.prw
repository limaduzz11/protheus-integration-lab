#include "protheus.ch"
#include "restful.ch"
#include "topconn.ch"

/*--------------------------------------------------------------------*
| Func:  WebhookReceiver()
| Autor: Eduardo Paranhos
| Data:  10/08/2026
| Desc:  Endpoint REST para receber webhooks de sistemas externos
|        Path configurado: "/api/webhook/events"
| Obs.:  Exemplo generico com gravacao transacionada em fila (ZZ4)
*---------------------------------------------------------------------*/

WSRESTFUL WebhookReceiver DESCRIPTION "Recebe notificacoes de webhook de sistemas externos" FORMAT APPLICATION_JSON

    WSMETHOD POST DESCRIPTION "Recebe webhook e processa evento" WSSYNTAX "/api/webhook/events"

END WSRESTFUL

/*--------------------------------------------------------------------*
| POST — Processa evento recebido via webhook
*---------------------------------------------------------------------*/
WSMETHOD POST WSSERVICE WebhookReceiver

    Local oBody      := JsonObject():New()
    Local oResponse  := JsonObject():New()
    Local cEvent     := ""
    Local cResource  := ""
    Local cId        := ""
    Local lProcessed := .F.
    Local cContent   := ::GetContent()

    ::SetContentType("application/json")

    If Empty(cContent) .Or. oBody:FromJson(cContent) != Nil
        SetRestFault(400, "Payload JSON invalido")
        Return .F.
    EndIf

    // Extrai propriedades de forma segura
    If oBody:HasProperty("event")
        cEvent := cValToChar(oBody["event"])
    EndIf

    If oBody:HasProperty("resource")
        cResource := cValToChar(oBody["resource"])
    EndIf

    If oBody:HasProperty("id")
        cId := cValToChar(oBody["id"])
    EndIf

    ConOut("[Webhook] Evento recebido: " + cEvent + " | Resource: " + cResource + " | ID: " + cId)

    // ---------- Roteamento por tipo de evento ----------
    Do Case
    Case cEvent == "order.created"
        lProcessed := ProcessOrderCreated(cId, oBody)
    Case cEvent == "order.updated"
        lProcessed := ProcessOrderUpdated(cId, oBody)
    Case cEvent == "payment.received"
        lProcessed := ProcessPaymentReceived(cId, oBody)
    Case cEvent == "customer.created"
        lProcessed := ProcessCustomerCreated(oBody)
    Otherwise
        ConOut("[Webhook] Evento nao tratado: " + cEvent)
        lProcessed := .T. // Reconhecido para nao reenfileirar no gateway externo
    EndCase

    // Resposta HTTP
    If lProcessed
        oResponse["status"] := "processed"
        oResponse["event"]  := cEvent
        ::SetResponse(oResponse:ToJson())
    Else
        SetRestFault(500, "Falha ao processar evento na fila interna")
        Return .F.
    EndIf

Return .T.

/*--------------------------------------------------------------------*
| ProcessOrderCreated — Processa evento de pedido criado (fila ZZ4)
*---------------------------------------------------------------------*/
Static Function ProcessOrderCreated(cId, oBody)

    Local lOk := .T.

    ConOut("[Webhook] Pedido criado: " + cId + " — enfileirando em transacao...")

    Begin Transaction
        DbSelectArea("ZZ4")
        RecLock("ZZ4", .T.)
        ZZ4->ZZ4_FILIAL := xFilial("ZZ4")
        ZZ4->ZZ4_EVENTO := "order.created"
        ZZ4->ZZ4_REFID  := cId
        ZZ4->ZZ4_DATA   := Date()
        ZZ4->ZZ4_HORA   := Time()
        ZZ4->ZZ4_STATUS := "PENDENTE"
        MsUnlock()
    End Transaction

Return lOk

/*--------------------------------------------------------------------*
| ProcessOrderUpdated — Processa evento de pedido atualizado
*---------------------------------------------------------------------*/
Static Function ProcessOrderUpdated(cId, oBody)
    ConOut("[Webhook] Pedido atualizado: " + cId)
Return .T.

/*--------------------------------------------------------------------*
| ProcessPaymentReceived — Processa confirmacao de pagamento
*---------------------------------------------------------------------*/
Static Function ProcessPaymentReceived(cId, oBody)

    Local nAmount := 0.0

    If oBody:HasProperty("amount")
        nAmount := oBody["amount"]
    EndIf

    ConOut("[Webhook] Pagamento recebido: " + cId + " — R$ " + cValToChar(nAmount))

Return .T.

/*--------------------------------------------------------------------*
| ProcessCustomerCreated — Processa novo cliente cadastrado
*---------------------------------------------------------------------*/
Static Function ProcessCustomerCreated(oBody)

    Local cName  := ""
    Local cEmail := ""
    Local oData

    If oBody:HasProperty("data") .And. ValType(oBody["data"]) == "J"
        oData := oBody["data"]
        If oData:HasProperty("name")
            cName := cValToChar(oData["name"])
        EndIf
        If oData:HasProperty("email")
            cEmail := cValToChar(oData["email"])
        EndIf
    EndIf

    ConOut("[Webhook] Novo cliente: " + cName + " <" + cEmail + ">")

Return .T.
