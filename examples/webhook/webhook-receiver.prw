#include "protheus.ch"

/*--------------------------------------------------------------------*
| Func:  WebhookReceiver()
| Autor: Eduardo Paranhos (clone educacional)
| Data:  10/08/2026
| Desc:  Endpoint REST para receber webhooks de sistemas externos
|        Configurar WSOBJ com path "/api/webhook/events"
| Obs.:  Exemplo generico — endpoints e dados ficticios
*---------------------------------------------------------------------*/

WSRESTFUL WebhookReceiver Description "Recebe notificacoes de sistemas externos"

    WsMethod POST Description "Recebe webhook e processa evento"

ENDWSRESTFUL

/*--------------------------------------------------------------------*
| POST — Processa evento recebido via webhook
*---------------------------------------------------------------------*/
WSMETHOD POST WsReceive JSON WsService WebhookReceiver

    Local oBody := JsonObject():New()
    Local oResponse := JsonObject():New()
    Local cEvent := ""
    Local cResource := ""
    Local cId := ""
    Local lProcessed := .F.

    // Le corpo da requisicao
    oBody:FromJson(WsGetPostContent())

    // Extrai campos
    If oBody:GetProperty("event") != Nil
        cEvent := oBody:GetProperty("event"):GetString()
    EndIf

    If oBody:GetProperty("resource") != Nil
        cResource := oBody:GetProperty("resource"):GetString()
    EndIf

    If oBody:GetProperty("id") != Nil
        cId := oBody:GetProperty("id"):GetString()
    EndIf

    // Log do evento
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
    EndCase

    // Resposta
    If lProcessed
        oResponse:SetProperty("status", "processed")
        oResponse:SetProperty("event", cEvent)
        WsSetResponse(200, "application/json", oResponse:ToJson())
    Else
        WsSetResponse(500, "application/json", '{ "status": "error", "message": "Falha ao processar evento" }')
    EndIf

Return .T.

/*--------------------------------------------------------------------*
| ProcessOrderCreated — Processa evento de pedido criado
*---------------------------------------------------------------------*/
Static Function ProcessOrderCreated(cId, oBody)

    // Insere na fila de processamento
    ConOut("[Webhook] Pedido criado: " + cId + " — enfileirando...")

    // DbSelectArea("ZZ4") // Tabela de fila
    // RecLock("ZZ4", .T.)
    // ZZ4->ZZ4_EVENTO := "order.created"
    // ZZ4->ZZ4_REFID := cId
    // MsUnLock()

Return .T.

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

    If oBody:GetProperty("amount") != Nil
        nAmount := oBody:GetProperty("amount"):GetNumber()
    EndIf

    ConOut("[Webhook] Pagamento recebido: " + cId + " — R$ " + cValToChar(nAmount))

    // Busca titulo relacionado e faz baixa
    // u_BaixaTitulo(cId, nAmount)

Return .T.

/*--------------------------------------------------------------------*
| ProcessCustomerCreated — Processa novo cliente cadastrado
*---------------------------------------------------------------------*/
Static Function ProcessCustomerCreated(oBody)

    Local cName := ""
    Local cEmail := ""

    If oBody:GetProperty("data"):GetProperty("name") != Nil
        cName := oBody:GetProperty("data"):GetProperty("name"):GetString()
    EndIf

    If oBody:GetProperty("data"):GetProperty("email") != Nil
        cEmail := oBody:GetProperty("data"):GetProperty("email"):GetString()
    EndIf

    ConOut("[Webhook] Novo cliente: " + cName + " <" + cEmail + ">")

Return .T.
