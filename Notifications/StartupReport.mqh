//+------------------------------------------------------------------+
//|                                             StartupReport.mqh    |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Generador de Reportes de Inicialización Estandarizados para el    |
//| Journal de MetaTrader 5.                                         |
//+------------------------------------------------------------------+
#ifndef STARTUP_REPORT_MQH
#define STARTUP_REPORT_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>
#include <EMPTY_VOID/Notifications/NewsWatcher.mqh>

class CVoidStartupReport
{
public:
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
        Print("                   [ EMPTY_VOID EA CORE v1.00 ]                       ");
        Print("            SYSTEM INITIALIZED SUCCESSFULLY | CYBERPUNK EDITION       ");
        Print("======================================================================");
        PrintFormat(" Creador:           EMPTY_VOID CORE");
        PrintFormat(" Símbolo Actual:    %s", symbol);
        PrintFormat(" Balance Cuenta:    $%.2f USD", balance);
        PrintFormat(" Floating PnL Bot:  %s$%.2f USD", (floatPnL >= 0.0 ? "+" : ""), floatPnL);
        PrintFormat(" EA Drawdown Act.:  %.2f%%", drawdown);
        PrintFormat(" Posiciones Bot:    %d aberturas activas", openCount);
        PrintFormat(" Escudo Cuant.:     [BLACK_SCHOLES_MK13: ACTIVO & OPERATIVO]");
        PrintFormat(" Noticias Hoy:      %s", newsSum);
        Print("======================================================================");
    }
};

#endif
