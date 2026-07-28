//+------------------------------------------------------------------+
//|                                                   EMPTY_VOID.mq5 |
//|                     EMPTY_VOID DESTRUCTIVE_CORE v2.4.0           |
//|                                     OPERADOR : NECRO_SILVER      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, EMPTY_VOID CORE | NECRO_SILVER"
#property link      "https://www.mql5.com"
#property version   "2.40"
#property strict
#property description "  EMPTY_VOID DESTRUCTIVE_CORE v2.4.0"
#property description "  OPERADOR: NECRO_SILVER"
#property description "  MOTORES INTEGRADOS: TEMPEST MK5 (M105) & CORTEX MK6 / CRT SNIPER v7.0 (M106)"
#property description "  MÓDULO DE TRAILING: NYX MK1 (Trailing Stop por Fases Aceleradas)"
#property description "  MÓDULO DE SEGURIDAD: SENTINEL MK2 (Escudo Noticias 12H CDMX) & BLACK-SCHOLES MK13"

#include <Trade/Trade.mqh>
#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>
#include <EMPTY_VOID/Core/CommentTagBuilder.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>
#include <EMPTY_VOID/Security/BLACK_SCHOLES_MK13.mqh>
#include <EMPTY_VOID/Security/VoidSecurityHub.mqh>
#include <EMPTY_VOID/Risk/DrawdownGuard.mqh>
#include <EMPTY_VOID/Risk/VoidTrailingManager.mqh>
#include <EMPTY_VOID/Risk/NYX_MK1.mqh>
#include <EMPTY_VOID/Notifications/NewsWatcher.mqh>
#include <EMPTY_VOID/Notifications/StartupReport.mqh>
#include <EMPTY_VOID/Notifications/TradeAlerts.mqh>
#include <EMPTY_VOID/Engines/IEngine.mqh>
#include <EMPTY_VOID/Theme/Theme_Cyberpunk.mqh>
#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>
#include <EMPTY_VOID/Engines/Engine_Template.mqh>
#include <EMPTY_VOID/UI/Dashboard.mqh>

//=== CONFIGURACIÓN Y PARÁMETROS INTERRUPTOR DE EMERGENCIA Y RIESGO ===
input group "=== INTERRUPTOR DE EMERGENCIA Y CONTROL DE RIESGO ==="
input bool     InpEmergencyStop        = false;     // ⚠️ INTERRUPTOR DE EMERGENCIA (KILL-SWITCH)
input double   InpMaxDailyLossPct      = 5.0;       // Límite Máximo de Pérdida Diaria (%)

input group "=== MÓDULO CUANTITATIVO Y SEGURIDAD BLACK-SCHOLES MK13 ==="
input bool     InpBsEnabled            = true;      // Habilitar Módulo Black-Scholes MK13 & SecurityHub
input double   InpBsAnnualVol          = 16.0;      // Volatilidad Implícita Anualizada (%)
input double   InpBsTargetHours        = 4.0;       // Horizonte de tiempo de la orden (Horas)
input double   InpBsMinProb            = 40.0;      // Probabilidad Delta Mínima N(d2) (%)
input double   InpBsMaxSpreadMult      = 2.0;       // Multiplicador máximo de spread permitido
input bool     InpEnableQuantBE        = true;      // Habilitar Break Even Cuantitativo por Delta N(d2)
input double   InpBsBEDeltaProb        = 20.0;      // Incremento Relativo N(d2) para Break Even (%)
input bool     InpEnableQuantTrailing  = true;      // Habilitar Trailing Stop Volátil 1-Sigma
input double   InpQuantTrailingAlpha   = 0.35;      // Multiplicador 1-Sigma (Alpha Factor)
input double   InpTrailingStepPips     = 3.0;       // Paso Mínimo Trailing (Pips Anti-Spam)

input group "=== ESCUDO DE NOTICIAS SENTINEL MK2 (USD) ==="
input bool     InpNewsEnable           = true;      // Habilitar SENTINEL MK2
input int      InpNewsPrePauseMins     = 30;        // Minutos Antes de Noticia para Congelar
input int      InpNewsPostPauseMins    = 30;        // Minutos Después de Noticia para Descongelar
input int      InpNewsPushAdvanceHours = 12;        // Horas de Anticipación para Alerta Push (12h CDMX)

input group "=== MÓDULO MOTOR TEMPEST MK5 (M105) ==="
sinput string  tempest_settings        = "--- Ajustes Motor TEMPEST MK5 ---";
input double   Inp_Tempest_RR          = 2.0;       // Relación Riesgo:Beneficio (Ej. 2.0 = 1:2)
input int      Inp_Tempest_SL_Buffer   = 20;        // Margen de ticks para el Stop Loss

input group "=== MÓDULO MOTOR CORTEX MK6 / CRT SNIPER v7.0 (M106) ==="
input double   Inp_CRT_RR              = 2.5;       // Ratio Riesgo/Beneficio (1:2.5)
input int      Inp_CRT_SL_Buffer       = 20;        // Buffer de Stop Loss (Ticks)
input double   Inp_CRT_Min_Sweep_USD   = 1.50;      // Barrido Mínimo ($XAUUSD)
input double   Inp_CRT_Max_Sweep_USD   = 15.00;     // Barrido Máximo ($XAUUSD)

input group "=== NOTIFICACIONES Y ALERTAS ==="
input bool     InpEnableAlerts         = true;      // Habilitar Alertas Visuales en Pantalla
input bool     InpEnablePush           = true;      // Habilitar Notificaciones Push MT5

// --- INCLUSIÓN DE MOTORES EN ARQUITECTURA MULTI-MOTOR ---
#include <EMPTY_VOID/Engines/Engine_Tempest.mqh>
#include <EMPTY_VOID/Engines/Engine_CRT.mqh>

CEngine_Tempest *EngineTempest;
CEngine_CRT     *EngineCRT;

const int TEMPEST_ENGINE_ID = 105;
const int CRT_ENGINE_ID     = 106;

// Instancia del ejecutor nativo de órdenes y gestor NYX_MK1
CTrade   g_trade;
CNYX_MK1 g_nyxTrailing;

// Variables de memoria globales de estado
double   g_emaSpread      = 0.0;
datetime g_expansionStart = 0;

//------------------------------------------------------------------
// Función de Cierre Masivo de Emergencia para Posiciones del Bot
//------------------------------------------------------------------
void CloseAllBotPositions(string reason)
{
    int total = PositionsTotal();
    int closedCount = 0;
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            string posSym  = PositionGetString(POSITION_SYMBOL);
            ulong posMagic = (ulong)PositionGetInteger(POSITION_MAGIC);
            string posComm = PositionGetString(POSITION_COMMENT);
            
            if(posSym == _Symbol && (CMagicNumberManager::IsEVTrade(posMagic) || StringFind(posComm, "EV_") >= 0))
            {
                if(g_trade.PositionClose(ticket))
                {
                    closedCount++;
                }
            }
        }
    }
    
    if(closedCount > 0)
    {
        PrintFormat("⚠️ [%s KILL-SWITCH]: Se han cerrado masivamente %d posiciones activas. Razón: %s", BOT_NAME, closedCount, reason);
    }
}

//------------------------------------------------------------------
// Función Auxiliar de Procesamiento de Señal por Motor
//------------------------------------------------------------------
void ProcessEngineSignal(IEngine *engine, EngineSignal &signal)
{
    if(CheckPointer(engine) == POINTER_INVALID || !signal.hasSignal) return;

    int engineId = engine.GetEngineId();
    PrintFormat("⚡ [%s - %s (M%d)]: Nueva Señal Detectada | Dirección: %s | Entrada: %.2f | SL: %.2f | TP: %.2f | Prox: %.0f%%",
                BOT_NAME, engine.GetEngineName(), engineId, signal.direction, signal.entryPrice, signal.stopLoss, signal.takeProfit, signal.proximityPct);

    double finalLot = signal.baseLot;
    int assignedTier = signal.tierLevel;

    // A. Filtro Cuantitativo de Seguridad Black-Scholes MK13
    if(InpBsEnabled)
    {
        bool isAllowed = CVoidSecurityHub::IsEntryAllowed(
            signal.orderType,
            signal.entryPrice,
            signal.takeProfit,
            InpBsAnnualVol,
            InpBsTargetHours,
            InpBsMinProb,
            signal.baseLot,
            finalLot,
            assignedTier,
            _Symbol
        );

        if(!isAllowed) return; // Bloqueo defensivo registrado en log
    }

    // B. Asignar Magic Number dinámico y Comment Tag (EV_)
    ulong magic = CMagicNumberManager::GetMagicNumber(engineId);
    g_trade.SetExpertMagicNumber(magic);

    string comment_tag = CCommentTagBuilder::BuildTag(engineId, assignedTier, signal.gridLevel);

    // C. Ejecución de la orden
    bool tradeSuccess = false;
    if(signal.orderType == ORDER_TYPE_BUY) 
    {
        tradeSuccess = g_trade.Buy(finalLot, _Symbol, 0, signal.stopLoss, signal.takeProfit, comment_tag);
    }
    else if(signal.orderType == ORDER_TYPE_SELL) 
    {
        tradeSuccess = g_trade.Sell(finalLot, _Symbol, 0, signal.stopLoss, signal.takeProfit, comment_tag);
    }

    // D. Emisión de Notificación y Alerta de Entrada
    if(tradeSuccess)
    {
        double bsProbSignal = 0.0;
        double spotForBS = (signal.orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        CBlackScholesMK13::CalculateBSProbabilityToTarget(spotForBS, signal.takeProfit, InpBsTargetHours, InpBsAnnualVol, bsProbSignal);
        if(signal.orderType == ORDER_TYPE_SELL) bsProbSignal = 100.0 - bsProbSignal;

        ulong dealTicket = g_trade.ResultOrder();
        CVoidTradeAlerts::NotifyTradeOpen(
            dealTicket,
            comment_tag,
            signal.orderType,
            finalLot,
            signal.entryPrice,
            signal.entryPrice,
            signal.stopLoss,
            signal.takeProfit,
            bsProbSignal,
            assignedTier,
            InpEnableAlerts,
            InpEnablePush
        );
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. Aplicar Tema de Colores Cyberpunk al gráfico actual
    CVoidThemeManager::ApplyCyberpunkTheme(ChartID());

    // 2. Inicializar ejecutor de órdenes
    g_trade.SetExpertMagicNumber(BOT_MAGIC_BASE);

    // 3. Inicializar variables del escudo de spread Black-Scholes MK13
    g_emaSpread      = 0.0;
    g_expansionStart = 0;

    // 4. Inicializar Dashboard Visual Cyberpunk Neón (HUD)
    CVoidDashboard::Init(_Symbol, 0, 15, 25);

    // 5. Iniciar Temporizador a 1 segundo para refrescar el Dashboard
    EventSetTimer(1);

    // 6. Imprimir Reporte Consolidado Banner de Inicialización en el Journal de MT5
    CVoidStartupReport::PrintStartupBanner();

    // --- CHEQUEO DE SALUD DE PUERTAS DE SALUD Y ARRANQUE MULTI-MOTOR ---
    bool isHealthOk = true;

    // Punto 1: Validación del Símbolo ORO
    string sym = _Symbol;
    if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0 && StringFind(sym, "Gold") < 0) isHealthOk = false;

    // Punto 2: Permisos de Trading en Bróker y Terminal
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) isHealthOk = false;

    // Punto 3: Instanciación e Inicialización del Motor Tempest (M105)
    EngineTempest = new CEngine_Tempest();
    if(!EngineTempest.Init(TEMPEST_ENGINE_ID, "TMPST_MK5")) isHealthOk = false;

    // Punto 4: Instanciación e Inicialización del Motor CORTEX MK6 / CRT SNIPER v7.0 (M106)
    EngineCRT = new CEngine_CRT();
    if(!EngineCRT.Init(CRT_ENGINE_ID, "CORTEX_MK6")) isHealthOk = false;
    EngineCRT.SetParameters(Inp_CRT_RR, Inp_CRT_SL_Buffer, Inp_CRT_Min_Sweep_USD, Inp_CRT_Max_Sweep_USD);

    // Punto 5: Escritura de Memoria Persistente CVoidState
    CVoidState::SetState("LastInitTime", (double)TimeCurrent());
    CVoidState::SetState("BotVersion", 2.40);
    if(!CVoidState::HasState("LastInitTime")) isHealthOk = false;

    // Disparo de Alerta de Arranque ÚNICAMENTE si las puertas de salud pasaron:
    if(isHealthOk)
    {
        CVoidStartupReport::SendReport(InpEnablePush);
    }
    else
    {
        PrintFormat("❌ [%s INICIALIZACIÓN FALLIDA]: Se detectaron errores de salud en el bot. Notificación cancelada.", BOT_NAME);
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    CVoidDashboard::Destroy();
    
    if(CheckPointer(EngineTempest) != POINTER_INVALID) {
        EngineTempest.OnDeinit();
        delete EngineTempest;
    }
    
    if(CheckPointer(EngineCRT) != POINTER_INVALID) {
        EngineCRT.OnDeinit();
        delete EngineCRT;
    }
    
    PrintFormat("🧹 [%s]: Dashboard destruido, temporizador detenido y recursos Multi-Motor liberados.", BOT_NAME);
}

//+------------------------------------------------------------------+
//| Evento OnTimer: Actualiza el Dashboard cada 1s                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    bool isSpreadSafe = CVoidSecurityHub::CheckSpreadSafety(currentSpread, g_emaSpread, g_expansionStart, InpBsMaxSpreadMult);

    EngineSignal sigTempest;
    if(CheckPointer(EngineTempest) != POINTER_INVALID)
    {
        sigTempest = EngineTempest.Evaluate();
    }

    EngineSignal sigCRT;
    if(CheckPointer(EngineCRT) != POINTER_INVALID)
    {
        sigCRT = EngineCRT.Evaluate();
    }

    // Identificar señal activa o dominante para telemetría Black-Scholes MK13
    EngineSignal activeSignal = (sigCRT.hasSignal || sigCRT.proximityPct > sigTempest.proximityPct) ? sigCRT : sigTempest;

    double bsCurrentProb = 0.0;
    int bsTier = 0;
    if(activeSignal.hasSignal || activeSignal.takeProfit > 0.0)
    {
        double spot = (activeSignal.orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        CBlackScholesMK13::CalculateBSProbabilityToTarget(spot, activeSignal.takeProfit, InpBsTargetHours, InpBsAnnualVol, bsCurrentProb);
        if(activeSignal.orderType == ORDER_TYPE_SELL) bsCurrentProb = 100.0 - bsCurrentProb;
        bsTier = CVoidSecurityHub::GetTierFromProbability(bsCurrentProb);
    }

    CVoidNewsWatcher::ProcessAdvanceNewsPush(InpNewsPushAdvanceHours, InpEnablePush, InpNewsPrePauseMins, InpNewsPostPauseMins);
    bool isNewsLockout = InpNewsEnable && CVoidNewsWatcher::IsNewsLockoutActive(InpNewsPrePauseMins, InpNewsPostPauseMins);
    
    string nextNewsName = "Sin eventos < 12h";
    double hoursToNextNews = 99.0;
    string nextNewsCdmxTime = "";
    CVoidNewsWatcher::GetNextHighImpactNews(InpNewsPushAdvanceHours, nextNewsName, hoursToNextNews, nextNewsCdmxTime);

    CVoidDashboard::Update(
        currentSpread, 
        g_emaSpread, 
        isSpreadSafe, 
        _Symbol, 
        sigTempest.proximityPct, 
        sigTempest.direction,
        sigCRT.proximityPct,
        sigCRT.direction,
        InpBsAnnualVol,
        InpBsTargetHours,
        InpBsMinProb,
        bsCurrentProb,
        bsTier,
        isNewsLockout,
        nextNewsName,
        hoursToNextNews,
        nextNewsCdmxTime
    );
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. GESTOR DE EMERGENCIA (KILL-SWITCH)
    if(InpEmergencyStop)
    {
        CloseAllBotPositions("INTERRUPTOR DE EMERGENCIA (KILL-SWITCH) ACTIVADO POR EL USUARIO");
        CVoidTradeAlerts::NotifySecurityLock("KILL-SWITCH ACTIVADO: OPERATIVA DETENIDA Y POSICIONES CERRADAS", InpEnableAlerts, InpEnablePush);
        return;
    }

    // 1. Monitoreo y Gobernador de Pérdida Diaria (DrawdownGuard)
    if(CVoidDrawdownGuard::CheckDailyLossLimit(InpMaxDailyLossPct, _Symbol))
    {
        return; // Bloqueo por Drawdown Diario Máximo
    }

    // 1.5 Monitoreo y Escudo de Noticias SENTINEL MK2 (CDMX UTC-6)
    CVoidNewsWatcher::ProcessAdvanceNewsPush(InpNewsPushAdvanceHours, InpEnablePush, InpNewsPrePauseMins, InpNewsPostPauseMins);
    if(InpNewsEnable && CVoidNewsWatcher::IsNewsLockoutActive(InpNewsPrePauseMins, InpNewsPostPauseMins))
    {
        return; // Bloqueo defensivo preventivo por noticia USD de ALTO impacto (LOCKOUT_NEWS)
    }

    // 2. Monitoreo y actualización del Escudo de Spread
    if(InpBsEnabled)
    {
        double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        bool isSafe = CVoidSecurityHub::CheckSpreadSafety(currentSpread, g_emaSpread, g_expansionStart, InpBsMaxSpreadMult);
        if(!isSafe)
        {
            return; // Bloqueo defensivo por dilatación anómala de spread
        }
    }

    // 2.5 GESTIÓN DE TRAILING STOP ACELERADO POR FASES NYX_MK1 EN CADA TICK
    g_nyxTrailing.ProcessTrailing(g_trade);

    // 2.6 GESTIÓN CUANTITATIVA ADICIONAL (Break Even & Trailing Stop Volátil 1-Sigma)
    CVoidTrailingManager::ProcessQuantTrailing(
        g_trade,
        InpBsAnnualVol,
        InpBsTargetHours,
        InpEnableQuantBE,
        InpBsBEDeltaProb,
        InpEnableQuantTrailing,
        InpQuantTrailingAlpha,
        InpTrailingStepPips,
        InpEnableAlerts,
        InpEnablePush
    );

    // 3. EVALUACIÓN DE SEÑALES INDEPENDIENTES POR MOTOR (TEMPEST M105 & CORTEX MK6 M106)
    if(CheckPointer(EngineTempest) != POINTER_INVALID)
    {
        EngineSignal sigTempest = EngineTempest.Evaluate();
        ProcessEngineSignal(EngineTempest, sigTempest);
    }

    if(CheckPointer(EngineCRT) != POINTER_INVALID)
    {
        EngineSignal sigCRT = EngineCRT.Evaluate();
        ProcessEngineSignal(EngineCRT, sigCRT);
    }
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(
    const MqlTradeTransaction& trans,
    const MqlTradeRequest& request,
    const MqlTradeResult& result
)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong dealTicket = trans.deal;
        if(dealTicket > 0 && HistoryDealSelect(dealTicket))
        {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
            {
                string dealSym  = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                ulong dealMagic = (ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                string dealComm = HistoryDealGetString(dealTicket, DEAL_COMMENT);

                if(dealSym == _Symbol && (CMagicNumberManager::IsEVTrade(dealMagic) || StringFind(dealComm, "EV_") >= 0))
                {
                    // Limpieza de memoria de estado inicial usando el ticket de posición nativo trans.position
                    if(trans.position > 0)
                    {
                        CVoidState::DeleteState(StringFormat("InitProb_%I64u", (ulong)trans.position));
                    }
                    ulong dealPosID = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                    if(dealPosID > 0) CVoidState::DeleteState(StringFormat("InitProb_%I64u", dealPosID));

                    double lot         = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
                    double realExit    = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                    double rawPnL      = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    double swap        = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                    double comm        = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                    ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);

                    double currentBal = AccountInfoDouble(ACCOUNT_BALANCE);
                    double prevBal    = currentBal - (rawPnL + swap + comm);

                    CVoidTradeAlerts::NotifyTradeClose(
                        dealTicket,
                        dealComm,
                        type,
                        lot,
                        0.0,
                        realExit,
                        realExit,
                        rawPnL,
                        (swap + comm),
                        prevBal,
                        currentBal,
                        "EJECUCION REGULAR / NYX_MK1",
                        InpEnableAlerts,
                        InpEnablePush
                    );
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
