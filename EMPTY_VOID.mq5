//+------------------------------------------------------------------+
//|                                                   EMPTY_VOID.mq5 |
//|                     EMPTY_VOID DESTRUCTIVE_CORE v2.2.0           |
//|                                     OPERADOR : NECRO_SILVER      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, EMPTY_VOID CORE | NECRO_SILVER"
#property link      "https://www.mql5.com"
#property version   "2.20"
#property strict
#property description "  EMPTY_VOID DESTRUCTIVE_CORE v2.2.0"
#property description "  OPERADOR: NECRO_SILVER"
#property description "  MOTOR INTEGRADO: TEMPEST MK5 (IFVG & Multi-TF)"
#property description "  MÓDULO INTEGRADO: SENTINEL MK1 (Escudo Noticias 12H)"

#include <Trade/Trade.mqh>
#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>
#include <EMPTY_VOID/Core/CommentTagBuilder.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>
#include <EMPTY_VOID/Security/BLACK_SCHOLES_MK13.mqh>
#include <EMPTY_VOID/Security/VoidSecurityHub.mqh>
#include <EMPTY_VOID/Risk/DrawdownGuard.mqh>
#include <EMPTY_VOID/Risk/VoidTrailingManager.mqh>
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

input group "=== ESCUDO DE NOTICIAS SENTINEL MK1 (USD) ==="
input bool     InpNewsEnable           = true;      // Habilitar SENTINEL MK1
input int      InpNewsPrePauseMins     = 30;        // Minutos Antes de Noticia para Congelar
input int      InpNewsPostPauseMins    = 30;        // Minutos Después de Noticia para Descongelar
input int      InpNewsPushAdvanceHours = 12;        // Horas de Anticipación para Alerta Push (12h)

input group "=== MÓDULO MOTOR TEMPEST MK5 ==="
sinput string  tempest_settings        = "--- Ajustes Motor TEMPEST MK5 ---";
input double   Inp_Tempest_RR          = 2.0;  // Relación Riesgo:Beneficio (Ej. 2.0 = 1:2)
input int      Inp_Tempest_SL_Buffer   = 20;   // Margen de ticks para el Stop Loss

input group "=== NOTIFICACIONES Y ALERTAS ==="
input bool     InpEnableAlerts         = true;      // Habilitar Alertas Visuales en Pantalla
input bool     InpEnablePush           = true;      // Habilitar Notificaciones Push MT5 (Por defecto TRUE)

// --- INCLUSIÓN DEL MOTOR TEMPEST MK5 ---
#include <EMPTY_VOID/Engines/Engine_Tempest.mqh>
CEngine_Tempest *EngineTempest;
const int TEMPEST_ENGINE_ID = 105;

// Instancia del ejecutor nativo de órdenes
CTrade   g_trade;

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

    // --- CHEQUEO DE SALUD DE 4 PUNTOS PARA DISPARO DE NOTIFICACIÓN ---
    bool isHealthOk = true;

    // Punto 1: Validación del Símbolo ORO
    string sym = _Symbol;
    if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0 && StringFind(sym, "Gold") < 0) isHealthOk = false;

    // Punto 2: Permisos de Trading en Bróker y Terminal
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) isHealthOk = false;

    // Punto 3: Instanciación e Inicialización del Motor Tempest
    EngineTempest = new CEngine_Tempest();
    if(!EngineTempest.Init(TEMPEST_ENGINE_ID, "TMPST_MK5")) isHealthOk = false;

    // Punto 4: Escritura de Memoria Persistente CVoidState
    CVoidState::SetState("LastInitTime", (double)TimeCurrent());
    CVoidState::SetState("BotVersion", 2.11);
    if(!CVoidState::HasState("LastInitTime")) isHealthOk = false;

    // Disparo de Alerta de Arranque ÚNICAMENTE si las 4 puertas de salud pasaron:
    if(isHealthOk)
    {
        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        double drawdown = CVoidProfitTracker::GetBotDrawdownPct();
        string newsSum  = CVoidNewsWatcher::GetTodayNewsSummary(6);

        CVoidTradeAlerts::NotifyStartup(balance, equity, drawdown, newsSum, InpEnablePush);
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
    
    PrintFormat("🧹 [%s]: Dashboard destruido, temporizador detenido y recursos liberados.", BOT_NAME);
}

//+------------------------------------------------------------------+
//| Evento OnTimer: Actualiza el Dashboard cada 1s                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    bool isSpreadSafe = CVoidSecurityHub::CheckSpreadSafety(currentSpread, g_emaSpread, g_expansionStart, InpBsMaxSpreadMult);

    EngineSignal currentSignal;
    if(CheckPointer(EngineTempest) != POINTER_INVALID)
    {
        currentSignal = EngineTempest.Evaluate();
    }

    // Cálculo de telemetría Black-Scholes MK13 para el gráfico
    double bsCurrentProb = 0.0;
    int bsTier = 0;
    if(currentSignal.hasSignal || currentSignal.takeProfit > 0.0)
    {
        double spot = (currentSignal.orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        CBlackScholesMK13::CalculateBSProbabilityToTarget(spot, currentSignal.takeProfit, InpBsTargetHours, InpBsAnnualVol, bsCurrentProb);
        if(currentSignal.orderType == ORDER_TYPE_SELL) bsCurrentProb = 100.0 - bsCurrentProb;
        bsTier = CVoidSecurityHub::GetTierFromProbability(bsCurrentProb);
    }

    CVoidNewsWatcher::ProcessAdvanceNewsPush(InpNewsPushAdvanceHours, InpEnablePush);
    bool isNewsLockout = InpNewsEnable && CVoidNewsWatcher::IsNewsLockoutActive(InpNewsPrePauseMins, InpNewsPostPauseMins);
    
    string nextNewsName = "Sin eventos < 12h";
    double hoursToNextNews = 99.0;
    CVoidNewsWatcher::GetNextHighImpactNews(InpNewsPushAdvanceHours, nextNewsName, hoursToNextNews);

    CVoidDashboard::Update(
        currentSpread, 
        g_emaSpread, 
        isSpreadSafe, 
        _Symbol, 
        currentSignal.proximityPct, 
        currentSignal.direction,
        InpBsAnnualVol,
        InpBsTargetHours,
        InpBsMinProb,
        bsCurrentProb,
        bsTier,
        isNewsLockout,
        nextNewsName,
        hoursToNextNews
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

    // 1.5 Monitoreo y Escudo de Noticias SENTINEL MK1
    CVoidNewsWatcher::ProcessAdvanceNewsPush(InpNewsPushAdvanceHours, InpEnablePush);
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

    // 2.5 Gestión Cuantitativa Continua de Posiciones (Break Even & Trailing Stop Volátil)
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

    // 3. EVALUACIÓN Y EJECUCIÓN DEL MOTOR TEMPEST MK5
    EngineSignal signal = EngineTempest.Evaluate();

    if(signal.hasSignal) 
    {
        PrintFormat("⚡ [%s - TEMPEST MK5]: Nueva Señal Detectada | Dirección: %s | Precio Entrada: %.2f | SL: %.2f | TP: %.2f | Proximidad: %.0f%%",
                    BOT_NAME, signal.direction, signal.entryPrice, signal.stopLoss, signal.takeProfit, signal.proximityPct);

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

        // B. Asignar Magic Number dinámico y Comment Tag
        ulong magic = CMagicNumberManager::GetMagicNumber(TEMPEST_ENGINE_ID);
        g_trade.SetExpertMagicNumber(magic);

        string comment_tag = CCommentTagBuilder::BuildTag(TEMPEST_ENGINE_ID, assignedTier, signal.gridLevel);

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
            CVoidTradeAlerts::NotifyTradeOpen(
                TEMPEST_ENGINE_ID,
                assignedTier,
                signal.gridLevel,
                signal.orderType,
                finalLot,
                signal.entryPrice,
                signal.stopLoss,
                signal.takeProfit,
                InpEnableAlerts,
                InpEnablePush
            );
        }
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
                        CVoidState::DeleteState(StringFormat("InitProb_%I64u", trans.position));
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
                        InpEnableAlerts,
                        InpEnablePush
                    );
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
