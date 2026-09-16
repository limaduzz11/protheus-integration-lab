#include "protheus.ch"
#include "topconn.ch"

/*--------------------------------------------------------------------*
| Func:  PaymentGateway()
| Autor: Eduardo Paranhos
| Data:  10/08/2026
| Desc:  Monitor de pagamentos — consulta gateway externo via FWRest
|        para conciliar transacoes pendentes
| Obs.:  Exemplo generico — endpoints e dados ficticios
*---------------------------------------------------------------------*/

User Function PaymentGateway()

    Local aPayments := {}
    Local oRest
    Local aHeader   := {}
    Local cResponse := ""
    Local oJson     := JsonObject():New()
    Local nTotal    := 0

    // ---------- Etapa 1: Consultar gateway externo ----------
    ConOut("[PaymentGateway] Consultando gateway de pagamentos...")

    oRest := FWRest():New("https://api.gateway-exemplo.com")
    oRest:SetPath("/v1/payments?status=pending&date_from=" + DtoS(Date() - 7) + "&date_to=" + DtoS(Date()))

    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "Authorization: Bearer {seu-token-aqui}")

    If oRest:Get(aHeader)
        cResponse := oRest:GetResult()

        If oJson:FromJson(cResponse) == Nil .And. oJson:HasProperty("total")
            nTotal := oJson["total"]
            ConOut("[PaymentGateway] Pagamentos pendentes encontrados: " + cValToChar(nTotal))
        EndIf
    Else
        ConOut("[PaymentGateway] Erro ao consultar gateway: " + cValToChar(oRest:GetHTTPCode()))
        Return
    EndIf

Return

/*--------------------------------------------------------------------*
| ConsultaPagamento — Busca pagamento especifico por ID via FWRest
*---------------------------------------------------------------------*/
Static Function ConsultaPagamento(cPaymentId)

    Local oRest       := FWRest():New("https://api.gateway-exemplo.com")
    Local aHeader     := {}
    Local oJsonResult := JsonObject():New()
    Local cResponse   := ""

    oRest:SetPath("/v1/payments/" + cPaymentId)

    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "Authorization: Bearer {seu-token-aqui}")

    If oRest:Get(aHeader)
        cResponse := oRest:GetResult()
        oJsonResult:FromJson(cResponse)
    EndIf

Return oJsonResult

/*--------------------------------------------------------------------*
| ConfirmarPagamento — Confirma baixa via callback POST via FWRest
*---------------------------------------------------------------------*/
Static Function ConfirmarPagamento(cPaymentId, cTitulo)

    Local oRest   := FWRest():New("https://api.gateway-exemplo.com")
    Local aHeader := {}
    Local oBody   := JsonObject():New()
    Local lOk     := .F.

    oRest:SetPath("/v1/payments/" + cPaymentId + "/confirm")

    oBody["titulo_protheus"] := cTitulo
    oBody["data_confirmacao"] := DtoS(Date()) + " " + Time()

    AAdd(aHeader, "Content-Type: application/json")
    AAdd(aHeader, "Authorization: Bearer {seu-token-aqui}")

    oRest:SetPostParams(oBody:ToJson())

    If oRest:Post(aHeader)
        lOk := (oRest:GetHTTPCode() == 200)
    EndIf

Return lOk
