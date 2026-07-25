//+------------------------------------------------------------------+
//|                                                DrawdownGuard.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Gobernador de Riesgo y Protección de Drawdown Diario y Global     |
//| Exclusivo para el Bot EMPTY_VOID v2.0.                           |
//+------------------------------------------------------------------+
#ifndef DRAWDOWN_GUARD_MQH
#define DRAWDOWN_GUARD_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>
#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>

class CVoidDrawdownGuard
{
private:
    // Retorna las ganancias/pérdidas cerradas exclusivamente del día de hoy
    static double GetTodayClosedProfit(string symbol = NULL)
    {
        double todayProfit = 0.0;
        string filterSym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

        MqlDateTime dt;
        TimeCurrent(dt);
        datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));

        if(HistorySelect(todayStart, TimeCurrent()))
        {
            int totalDeals = HistoryDealsTotal();
            for(int i = 0; i < totalDeals; i++)
            {
                ulong ticket = HistoryDealGetTicket(i);
                if(ticket > 0)
                {
                    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
                    if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
                    {
                        string dealSym  = HistoryDealGetString(ticket, DEAL_SYMBOL);
                        ulong dealMagic = (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC);
                        string dealComm = HistoryDealGetString(ticket, DEAL_COMMENT);

                        if(dealSym == filterSym && (CMagicNumberManager::IsEVTrade(dealMagic) || StringFind(dealComm, "EV_") >= 0))
                        {
                            double pnl  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                            double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                            todayProfit += (pnl + swap + comm);
                        }
                    }
                }
            }
        }
        return todayProfit;
    }

public:
    //------------------------------------------------------------------
    // Verifica si la pérdida diaria del bot ha superado el límite máximo %
    // Retorna TRUE si el bot está bloqueado por Drawdown Diario
    //------------------------------------------------------------------
    static bool CheckDailyLossLimit(double maxDailyLossPct, string symbol = NULL)
    {
        if(maxDailyLossPct <= 0.0) return false; // Límite desactivado

        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        MqlDateTime dt;
        TimeCurrent(dt);
        datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));

        // Reseteo automático de bloqueo al iniciar un nuevo día
        datetime lastLockDay = (datetime)CVoidState::GetState("LockoutDay", 0.0, sym);
        if(lastLockDay != todayStart)
        {
            CVoidState::DeleteState("DailyLockout", sym);
            CVoidState::SetState("LockoutDay", (double)todayStart, sym);
        }

        // Si ya existe un bloqueo activo guardado para hoy
        if(CVoidState::HasState("DailyLockout", sym))
        {
            return true;
        }

        // Obtener balance base al inicio del día
        double startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - GetTodayClosedProfit(sym);
        if(startBalance <= 0.0) startBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        // Calcular pérdida combinada de hoy (Cerrada + Flotante)
        double todayClosed = GetTodayClosedProfit(sym);
        double todayFloat  = CVoidProfitTracker::GetFloatingPnL(sym);
        double totalToday  = todayClosed + todayFloat;

        if(totalToday < 0.0 && startBalance > 0.0)
        {
            double lossPct = (MathAbs(totalToday) / startBalance) * 100.0;
            if(lossPct >= maxDailyLossPct)
            {
                // Activar bloqueo permanente por el resto del día
                CVoidState::SetState("DailyLockout", 1.0, sym);
                PrintFormat("🚨 [DRAWDOWN_GUARD]: Límite de Pérdida Diaria Activado! Pérdida: %.2f%% >= Max %.2f%%. Bot bloqueado hoy.",
                            lossPct, maxDailyLossPct);
                return true;
            }
        }

        return false;
    }
};

#endif
