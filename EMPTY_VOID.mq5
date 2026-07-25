//+------------------------------------------------------------------+
//|                                                   EMPTY_VOID.mq5 |
//|                     EMPTY_VOID DESTRUCTIVE_CORE v2.0.0           |
//|                                     OPERADOR : NECRO_SILVER      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, EMPTY_VOID CORE | NECRO_SILVER"
#property link      "https://www.mql5.com"
#property version   "2.000"
#property strict
#property description "🏦 EMPTY_VOID DESTRUCTIVE_CORE v2.0.0 (FASE 5)"
#property description "👤 CREADOR: NECRO_SILVER"
#property description "------------------------------------------------"
#property description "ARQUITECTURA BASE Y MÓDULOS FASE 1 AL 5:"
#property description " 1. Core          :: Config, MagicNumber, State"
#property description " 2. Security      :: Black-Scholes MK13 & SecurityHub"
#property description " 3. Theme         :: Cyberpunk Neon Styling"
#property description " 4. ProfitTracker :: PnL & Drawdown Metrics"
#property description " 5. Notifications :: NewsWatcher & TradeAlerts"
#property description " 6. Risk Guard    :: DrawdownGuard & Kill-Switch"
#property description " 7. UI Dashboard  :: Cyberpunk Visual Panel (1s OnTimer)"

#include <Trade/Trade.mqh>
#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>
#include <EMPTY_VOID/Core/CommentTagBuilder.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>
#include <EMPTY_VOID/Security/BLACK_SCHOLES_MK13.mqh>
#include <EMPTY_VOID/Security/VoidSecurityHub.mqh>
#include <EMPTY_VOID/Risk/DrawdownGuard.mqh>
#include <EMPTY_VOID/Theme/Theme_Cyberpunk.mqh>
#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>
#include <EMPTY_VOID/Notifications/NewsWatcher.mqh>
#include <EMPTY_VOID/Notifications/StartupReport.mqh>
#include <EMPTY_VOID/Notifications/TradeAlerts.mqh>
#include <EMPTY_VOID/Engines/IEngine.mqh>
#include <EMPTY_VOID/Engines/Engine_Template.mqh>
#include <EMPTY_VOID/UI/Dashboard.mqh>

//=== CONFIGURACIÓN Y PARÁMETROS FASE 5 ===
input group "=== INTERRUPTOR DE EMERGENCIA Y CONTROL DE RIESGO ==="
input bool     InpEmergencyStop        = false;     // ⚠️ INTERRUPTOR DE EMERGENCIA (KILL-SWITCH)
input double   InpMaxDailyLossPct      = 5.0;       // Límite Máximo de Pérdida Diaria (%)

input group "=== MÓDULO CUANTITATIVO Y SEGURIDAD BLACK-SCHOLES MK13 ==="
input bool     InpBsEnabled            = true;      // Habilitar Módulo Black-Scholes MK13 & SecurityHub
input double   InpBsAnnualVol          = 16.0;      // Volatilidad Implícita Anualizada (%)
input double   InpBsTargetHours        = 4.0;       // Horizonte de tiempo de la orden (Horas)
input double   InpBsMinProb            = 40.0;      // Probabilidad Delta Mínima N(d2) (%)
input double   InpBsMaxSpreadMult      = 2.0;       // Multiplicador máximo de spread permitido

input group "=== NOTIFICACIONES Y ALERTAS ==="
input bool     InpEnableAlerts         = true;      // Habilitar Alertas Visuales en Pantalla
input bool     InpEnablePush           = false;     // Habilitar Notificaciones Push MT5

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
    // 1. Validar que el activo sea ORO (XAUUSD / GOLD)
    string sym = _Symbol;
    if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0 && StringFind(sym, "Gold") < 0)
    {
        PrintFormat("⚠️ [%s INICIALIZACIÓN FALLIDA]: El símbolo activo '%s' no es ORO (XAUUSD). Este bot está optimizado exclusivamente para %s.", BOT_NAME, sym, BOT_SYMBOL);
        return(INIT_FAILED);
    }

    // 2. Aplicar Tema de Colores Cyberpunk al gráfico actual
    CVoidThemeManager::ApplyCyberpunkTheme(ChartID());

    // 3. Inicializar ejecutor de órdenes
    g_trade.SetExpertMagicNumber(BOT_MAGIC_BASE);

    // 4. Inicializar variables del escudo de spread Black-Scholes MK13
    g_emaSpread      = 0.0;
    g_expansionStart = 0;

    // 5. Guardar Estado Persistente de Inicialización
    CVoidState::SetState("LastInitTime", (double)TimeCurrent());
    CVoidState::SetState("BotVersion", 2.0);

    // 6. Inicializar Dashboard Visual Cyberpunk Neón (HUD)
    CVoidDashboard::Init(_Symbol, 0, 15, 25);

    // 7. Iniciar Temporizador a 1 segundo para refrescar el Dashboard continuamente (incluso con mercado cerrado)
    EventSetTimer(1);

    // 8. Imprimir Reporte Consolidado Banner de Inicialización en el Journal de MT5
    CVoidStartupReport::PrintStartupBanner();

    // 9. Emitir Notificación de Inicialización del Sistema
    CVoidTradeAlerts::NotifyInfo(StringFormat("%s v%s FASE 5 (Infraestructura Core) Inicializada en %s.", BOT_NAME, BOT_VERSION, sym));

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    CVoidDashboard::Destroy();
    PrintFormat("🧹 [%s FASE 5]: Dashboard destruido, temporizador detenido y recursos liberados.", BOT_NAME);
}

//+------------------------------------------------------------------+
//| Evento OnTimer: Actualiza el Dashboard cada 1s sin recargar OnTick|
//+------------------------------------------------------------------+
void OnTimer()
{
    double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    bool isSpreadSafe = CVoidSecurityHub::CheckSpreadSafety(currentSpread, g_emaSpread, g_expansionStart, InpBsMaxSpreadMult);

    CVoidDashboard::Update(currentSpread, g_emaSpread, isSpreadSafe, _Symbol);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. GESTOR DE EMERGENCIA (KILL-SWITCH MANIFEST)
    if(InpEmergencyStop)
    {
        CloseAllBotPositions("INTERRUPTOR DE EMERGENCIA (KILL-SWITCH) ACTIVADO POR EL USUARIO");
        CVoidTradeAlerts::NotifySecurityLock("KILL-SWITCH ACTIVADO: OPERATIVA DETENIDA Y POSICIONES CERRADAS", InpEnableAlerts, InpEnablePush);
        return;
    }

    // 1. Monitoreo y Gobernador de Pérdida Diaria (DrawdownGuard)
    if(CVoidDrawdownGuard::CheckDailyLossLimit(InpMaxDailyLossPct, _Symbol))
    {
        // Bloqueo activo por superación de drawdown diario máximo
        return;
    }

    // 2. Monitoreo y actualización del Escudo de Spread vía VoidSecurityHub
    if(InpBsEnabled)
    {
        double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        bool isSafe = CVoidSecurityHub::CheckSpreadSafety(currentSpread, g_emaSpread, g_expansionStart, InpBsMaxSpreadMult);

        if(!isSafe)
        {
            // Bloqueo de seguridad defensivo por iliquidez o salto anómalo de spread
            return;
        }
    }

    // [Infraestructura Core FASE 5 Completada - Lista para vinculación de Motores Direccionales M1, M2, M3]
}
//+------------------------------------------------------------------+
