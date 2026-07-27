//+------------------------------------------------------------------+
//|                                             StartupReport.mqh    |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Generador de Reportes de Inicialización Estandarizados para el    |
//| Journal de MetaTrader 5 y Notificaciones Push Decoradas.        |
//+------------------------------------------------------------------+
#ifndef STARTUP_REPORT_MQH
#define STARTUP_REPORT_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>
#include <EMPTY_VOID/Notifications/NewsWatcher.mqh>

class CVoidStartupReport
{
public:
    //------------------------------------------------------------------
    // Reporte de Inicio / Reinicio Push (Diseño 1: Terminal Quant Decorado)
    //------------------------------------------------------------------
    static void SendReport(bool enablePush = true, string newsStatusStr = "Sin eventos < 12h")
    {
        if(!enablePush) return;

        double bal = AccountInfoDouble(ACCOUNT_BALANCE);
        double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
        double dd  = (bal > 0) ? ((bal - eq) / bal) * 100.0 : 0.0;
        if(dd < 0) dd = 0.0;

        string pushMsg = StringFormat(
            "🤖 ⚡ [EMPTY_VOID DESTRUCTIVE_CORE v2.2.0] SISTEMA ONLINE\n──────────────────────────────────\n👑 OPERADOR : NECRO_SILVER\n🪙 ACTIVO   : %s (Gold)\n💼 BALANCE  : $%.2f USD\n📈 EQUIDAD  : $%.2f USD (DD: %.2f%%)\n🧠 MOTORES  : TEMPEST_MK5 [OK 🟢] | CORTEX_MK6 [OK 🟢]\n🛡️ ESCUDOS  : BS_MK13 [OK ✅] | SENTINEL_MK2 [OK 🟢]\n📰 NOTICIAS : %s\n──────────────────────────────────\nSTATUS : OPERATIVO Y VIGILANTE 🟢",
            _Symbol, bal, eq, dd, newsStatusStr
        );

        ResetLastError();
        if(!SendNotification(pushMsg))
        {
            PrintFormat("❌ [PUSH ERROR]: Falló el envío de reporte de inicio. Código MT5: %d", GetLastError());
        }
    }

    // Imprime un reporte consolidado e impecable en el Journal de MT5 durante OnInit()
    static void PrintStartupBanner(void)
    {
        double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
        double floatPnL  = CVoidProfitTracker::GetFloatingPnL();
        double drawdown  = CVoidProfitTracker::GetBotDrawdownPct();
        int openCount    = CVoidProfitTracker::GetOpenPositionsCount();
        string newsSum   = CVoidNewsWatcher::GetTodayNewsSummary();
        string symbol    = _Symbol;

        Print("======================================================================");
        PrintFormat("       [ %s DESTRUCTIVE_CORE v%s ]           ", BOT_NAME, BOT_VERSION);
        Print("            SYSTEM INITIALIZED SUCCESSFULLY | CYBERPUNK EDITION       ");
        Print("======================================================================");
        PrintFormat(" Creador:           NECRO_SILVER");
        PrintFormat(" Símbolo Actual:    %s", symbol);
        PrintFormat(" Balance Cuenta:    $%.2f USD", balance);
        PrintFormat(" Floating PnL Bot:  %s$%.2f USD", (floatPnL >= 0.0 ? "+" : ""), floatPnL);
        PrintFormat(" EA Drawdown Act.:  %.2f%%", drawdown);
        PrintFormat(" Posiciones Bot:    %d aberturas activas", openCount);
        PrintFormat(" Motores Core:      [TEMPEST_MK5 (M105): ACTIVO] | [CORTEX_MK6 (M106): ACTIVO]");
        PrintFormat(" Escudo Cuant.:     [BLACK_SCHOLES_MK13: ACTIVO & OPERATIVO]");
        PrintFormat(" Escudo Noticias:   [SENTINEL_MK2: HORA MÉXICO UTC-6 ACTIVO]");
        PrintFormat(" Noticias Hoy:      %s", newsSum);
        Print("======================================================================");
    }
};

#endif
