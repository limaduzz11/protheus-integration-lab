#include "PROTHEUS.CH"
#include "TOPCONN.CH"
#include "FWMVCDEF.CH"

/*--------------------------------------------------------------------*
| Func:  PaymentGateway()
| Autor: Eduardo Paranhos (clone educacional)
| Data:  10/08/2026
| Desc:  Monitor de pagamentos — consulta gateway externo via REST
|        para conciliar transacoes pendentes
| Obs.:  Exemplo generico — endpoints e dados ficticios
*---------------------------------------------------------------------*/

User Function PaymentGateway()

    Local oBrowse := FwBrowse():New()
    Local cTitulo := "Monitor de Pagamentos — Gateway"
    Local aPayments := {}
    Local oHttp
    Local cResponse := ""
    Local oJson
    Local nI := 0
    Local nTotal := 0

    // ---------- Etapa 1: Consultar gateway externo ----------
    ConOut("Consultando gateway de pagamentos...")

    oHttp := FWHttpRest():New("https://api.gateway-exemplo.com/v1/payments")
    oHttp:SetHeader("Accept", "application/json")
    oHttp:SetHeader("Authorization", "Bearer {seu-token-aqui}")
    oHttp:SetQueryParam("status", "pending")
    oHttp:SetQueryParam("date_from", DtoS(Date() - 7))
    oHttp:SetQueryParam("date_to", DtoS(Date()))
    oHttp:Get()

    If oHttp:GetStatus() == 200
        cResponse := oHttp:GetResult()
        oJson := JsonObject():New()
        oJson:FromJson(cResponse)

        nTotal := oJson:GetProperty("total"):GetNumber()
        ConOut("Pagamentos pendentes encontrados: " + cValToChar(nTotal))
    Else
        ConOut("Erro ao consultar gateway: " + cValToChar(oHttp:GetStatus()))
        Return
    EndIf

    // ---------- Etapa 2: Para cada pagamento, conciliar com banco local ----------
    // (Exemplo simplificado — em producao, iteraria sobre resultados e faria baixa)

Return

/*--------------------------------------------------------------------*
| ConsultaPagamento — Busca pagamento especifico por ID
*---------------------------------------------------------------------*/
Static Function ConsultaPagamento(cPaymentId)

    Local oHttp := FWHttpRest():New("https://api.gateway-exemplo.com/v1/payments/" + cPaymentId)
    Local oJsonResult := JsonObject():New()
    Local cResponse := ""

    oHttp:SetHeader("Accept", "application/json")
    oHttp:SetHeader("Authorization", "Bearer {seu-token-aqui}")
    oHttp:Get()

    If oHttp:GetStatus() == 200
        cResponse := oHttp:GetResult()
        oJsonResult:FromJson(cResponse)
    EndIf

Return oJsonResult

/*--------------------------------------------------------------------*
| ConfirmarPagamento — Confirma baixa via callback
*---------------------------------------------------------------------*/
Static Function ConfirmarPagamento(cPaymentId, cTitulo)

    Local oHttp := FWHttpRest():New("https://api.gateway-exemplo.com/v1/payments/" + cPaymentId + "/confirm")
    Local oBody := JsonObject():New()
    Local lOk := .F.

    oBody:SetProperty("titulo_protheus", cTitulo)
    oBody:SetProperty("data_confirmacao", DtoS(Date()) + " " + Time())

    oHttp:SetHeader("Content-Type", "application/json")
    oHttp:SetHeader("Authorization", "Bearer {seu-token-aqui}")
    oHttp:SetPostParams(oBody:ToJson())
    oHttp:Post()

    lOk := (oHttp:GetStatus() == 200)

Return lOk
