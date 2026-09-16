#include "protheus.ch"
#include "topconn.ch"

/*--------------------------------------------------------------------*
| Func:  ExpenseApiIntegration()
| Autor: Eduardo Paranhos
| Data:  10/08/2026
| Desc:  Integracao com API de despesas de viagem — consome servico
|        externo via FWRest para importar reembolsos no Protheus
| Obs.:  Exemplo generico — endpoints e dados ficticios
*---------------------------------------------------------------------*/

User Function ExpenseApiIntegration()

    Local cToken      := ""
    Local aDespesas   := {}
    Local nImportadas := 0

    // ---------- Autenticacao OAuth2 ----------
    cToken := GetOAuthToken()

    If Empty(cToken)
        MsgAlert("Falha na autenticação com a API de despesas", "Erro")
        Return
    EndIf

    // ---------- Buscar despesas pendentes ----------
    aDespesas := FetchPendingExpenses(cToken)
    ConOut("[ExpenseApi] Despesas pendentes: " + cValToChar(Len(aDespesas)))

    // ---------- Importar cada despesa ----------
    nImportadas := ImportExpenses(aDespesas)
    ConOut("[ExpenseApi] Despesas importadas com sucesso: " + cValToChar(nImportadas))

Return

/*--------------------------------------------------------------------*
| GetOAuthToken — Obtem token OAuth2 Client Credentials via FWRest
*---------------------------------------------------------------------*/
Static Function GetOAuthToken()

    Local oRest     := FWRest():New("https://auth.despesas-exemplo.com")
    Local aHeader   := {}
    Local cBody     := ""
    Local cToken    := ""
    Local cResponse := ""
    Local oJson     := JsonObject():New()

    oRest:SetPath("/oauth/token")

    AAdd(aHeader, "Content-Type: application/x-www-form-urlencoded")
    AAdd(aHeader, "Accept: application/json")

    cBody := "grant_type=client_credentials" + ;
             "&client_id=seu_client_id" + ;
             "&client_secret=seu_client_secret"

    oRest:SetPostParams(cBody)

    If oRest:Post(aHeader)
        cResponse := oRest:GetResult()
        If oJson:FromJson(cResponse) == Nil .And. oJson:HasProperty("access_token")
            cToken := cValToChar(oJson["access_token"])
        EndIf
    Else
        ConOut("[ExpenseApi] Erro na autenticacao: " + cValToChar(oRest:GetHTTPCode()))
    EndIf

Return cToken

/*--------------------------------------------------------------------*
| FetchPendingExpenses — Busca despesas na API externa
*---------------------------------------------------------------------*/
Static Function FetchPendingExpenses(cToken)

    Local oRest     := FWRest():New("https://api.despesas-exemplo.com")
    Local aHeader   := {}
    Local aResult   := {}
    Local cResponse := ""
    Local oJson     := JsonObject():New()

    oRest:SetPath("/v1/expenses?status=approved&imported=false")

    AAdd(aHeader, "Authorization: Bearer " + cToken)
    AAdd(aHeader, "Accept: application/json")

    If oRest:Get(aHeader)
        cResponse := oRest:GetResult()
        If oJson:FromJson(cResponse) == Nil .And. oJson:HasProperty("data")
            If ValType(oJson["data"]) == "A"
                aResult := oJson["data"]
            EndIf
        EndIf
    Else
        ConOut("[ExpenseApi] Falha ao buscar despesas: " + cValToChar(oRest:GetHTTPCode()))
    EndIf

Return aResult

/*--------------------------------------------------------------------*
| ImportExpenses — Importa despesas para tabela local (ZZ3) em transacao
*---------------------------------------------------------------------*/
Static Function ImportExpenses(aDespesas)

    Local nCount   := 0
    Local nI       := 0
    Local oExpense
    Local cId      := ""
    Local cDesc    := ""
    Local nValue   := 0.0
    Local cDate    := ""

    For nI := 1 To Len(aDespesas)
        oExpense := aDespesas[nI]

        If ValType(oExpense) == "J"
            cId    := Iif(oExpense:HasProperty("id"), cValToChar(oExpense["id"]), "")
            cDesc  := Iif(oExpense:HasProperty("description"), cValToChar(oExpense["description"]), "")
            nValue := Iif(oExpense:HasProperty("amount"), oExpense["amount"], 0.0)
            cDate  := Iif(oExpense:HasProperty("date"), cValToChar(oExpense["date"]), "")

            Begin Transaction
                DbSelectArea("ZZ3")
                RecLock("ZZ3", .T.)
                ZZ3->ZZ3_FILIAL := xFilial("ZZ3")
                ZZ3->ZZ3_CODIGO := cId
                ZZ3->ZZ3_DESC   := cDesc
                ZZ3->ZZ3_VALOR  := nValue
                ZZ3->ZZ3_DATA   := StoD(cDate)
                MsUnlock()
            End Transaction

            nCount++
            ConOut("[ExpenseApi] Importado: " + cId + " — " + cDesc + " — R$ " + cValToChar(nValue))
        EndIf
    Next nI

Return nCount
