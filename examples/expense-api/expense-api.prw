#include "totvs.ch"
#include "restful.ch"
#include "TBICONN.CH"

/*--------------------------------------------------------------------*
| Func:  ExpenseApiIntegration()
| Autor: Eduardo Paranhos (clone educacional)
| Data:  10/08/2026
| Desc:  Integracao com API de despesas de viagem — consome servico
|        externo para importar reembolsos no Protheus
| Obs.:  Exemplo generico — endpoints e dados ficticios
*---------------------------------------------------------------------*/

User Function ExpenseApiIntegration()

    Local cToken := ""
    Local aDespesas := {}
    Local nImportadas := 0

    // ---------- Autenticacao OAuth2 ----------
    cToken := GetOAuthToken()

    If Empty(cToken)
        MsgAlert("Falha na autenticação com a API de despesas", "Erro")
        Return
    EndIf

    // ---------- Buscar despesas pendentes ----------
    aDespesas := FetchPendingExpenses(cToken)
    ConOut("Despesas pendentes: " + cValToChar(Len(aDespesas)))

    // ---------- Importar cada despesa ----------
    nImportadas := ImportExpenses(aDespesas)
    ConOut("Despesas importadas com sucesso: " + cValToChar(nImportadas))

Return

/*--------------------------------------------------------------------*
| GetOAuthToken — Obtem token OAuth2 Client Credentials
*---------------------------------------------------------------------*/
Static Function GetOAuthToken()

    Local oHttp := FWHttpRest():New("https://auth.despesas-exemplo.com/oauth/token")
    Local cToken := ""
    Local cResponse := ""
    Local oJson

    oHttp:SetHeader("Content-Type", "application/x-www-form-urlencoded")
    oHttp:SetPostParams("grant_type=client_credentials" + ;
                        "&client_id=seu_client_id" + ;
                        "&client_secret=seu_client_secret")
    oHttp:Post()

    If oHttp:GetStatus() == 200
        cResponse := oHttp:GetResult()
        oJson := JsonObject():New()
        oJson:FromJson(cResponse)
        cToken := oJson:GetProperty("access_token"):GetString()
    EndIf

Return cToken

/*--------------------------------------------------------------------*
| FetchPendingExpenses — Busca despesas na API externa
*---------------------------------------------------------------------*/
Static Function FetchPendingExpenses(cToken)

    Local oHttp := FWHttpRest():New("https://api.despesas-exemplo.com/v1/expenses")
    Local aResult := {}
    Local cResponse := ""
    Local oJson

    oHttp:SetHeader("Authorization", "Bearer " + cToken)
    oHttp:SetHeader("Accept", "application/json")
    oHttp:SetQueryParam("status", "approved")
    oHttp:SetQueryParam("imported", "false")
    oHttp:Get()

    If oHttp:GetStatus() == 200
        cResponse := oHttp:GetResult()
        oJson := JsonObject():New()
        oJson:FromJson(cResponse)
        aResult := oJson:GetProperty("data"):GetArray()
    EndIf

Return aResult

/*--------------------------------------------------------------------*
| ImportExpenses — Importa despesas para tabela local (ZZ3)
*---------------------------------------------------------------------*/
Static Function ImportExpenses(aDespesas)

    Local nCount := 0
    Local nI := 0
    Local oExpense
    Local cId := ""
    Local cDesc := ""
    Local nValue := 0.0
    Local cDate := ""

    For nI := 1 To Len(aDespesas)
        oExpense := aDespesas[nI]

        cId    := oExpense:GetProperty("id"):GetString()
        cDesc  := oExpense:GetProperty("description"):GetString()
        nValue := oExpense:GetProperty("amount"):GetNumber()
        cDate  := oExpense:GetProperty("date"):GetString()

        // Insere em tabela customizada
        DbSelectArea("ZZ3")
        RecLock("ZZ3", .T.)
        ZZ3->ZZ3_FILIAL := xFilial("ZZ3")
        ZZ3->ZZ3_CODIGO := cId
        ZZ3->ZZ3_DESC   := cDesc
        ZZ3->ZZ3_VALOR  := nValue
        ZZ3->ZZ3_DATA   := StoD(cDate)
        MsUnLock()

        nCount++

        ConOut("Importado: " + cId + " — " + cDesc + " — R$ " + cValToChar(nValue))
    Next nI

Return nCount
