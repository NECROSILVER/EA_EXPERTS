//+------------------------------------------------------------------+
//|                                              ProfitTracker.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Rastreador de Métricas Financieras y Rendimiento Exclusivo para  |
//| las posiciones del bot EMPTY_VOID.                               |
//+------------------------------------------------------------------+
#ifndef PROFIT_TRACKER_MQH
#define PROFIT_TRACKER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/MagicNumberManager.mqh>

class CVoidProfitTracker
{
private:
    // Helper interno para verificar si una posición u orden pertenece a EMPTY_VOID
    static bool IsTradeBelongsToBot(ulong magic, string comment)
    {
        if(CMagicNumberManager::IsEVTrade(magic)) return true;
        if(StringFind(comment, "EV_") >= 0) return true;
        return false;
    }

public:
    //------------------------------------------------------------------
    // Retorna el beneficio flotante actual ($) solo de las posiciones del bot
    //------------------------------------------------------------------
    static double GetFloatingPnL(string symbol = NULL)
    {
        double floatPnL = 0.0;
        int total = PositionsTotal();
        string filterSym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

        for(int i = total - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                string posSym  = PositionGetString(POSITION_SYMBOL);
                ulong posMagic = (ulong)PositionGetInteger(POSITION_MAGIC);
                string posComm = PositionGetString(POSITION_COMMENT);

                if(posSym == filterSym && IsTradeBelongsToBot(posMagic, posComm))
                {
                    floatPnL += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
                }
            }
        }
        return floatPnL;
    }

    //------------------------------------------------------------------
    // Retorna el número de posiciones abiertas activas del bot
    //------------------------------------------------------------------
    static int GetOpenPositionsCount(string symbol = NULL)
    {
        int count = 0;
        int total = PositionsTotal();
        string filterSym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

        for(int i = total - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                string posSym  = PositionGetString(POSITION_SYMBOL);
                ulong posMagic = (ulong)PositionGetInteger(POSITION_MAGIC);
                string posComm = PositionGetString(POSITION_COMMENT);

                if(posSym == filterSym && IsTradeBelongsToBot(posMagic, posComm))
                {
                    count++;
                }
            }
        }
        return count;
    }

    //------------------------------------------------------------------
    // Retorna la ganancia/pérdida total acumulada ($) de operaciones cerradas
    //------------------------------------------------------------------
    static double GetClosedProfit(string symbol = NULL)
    {
        double totalProfit = 0.0;
        string filterSym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

        datetime fromTime = 0;
        datetime toTime   = TimeCurrent();

        if(HistorySelect(fromTime, toTime))
        {
            int totalDeals = HistoryDealsTotal();
            for(int i = 0; i < totalDeals; i++)
            {
                ulong ticket = HistoryDealGetTicket(i);
                if(ticket > 0)
                {
                    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

                    // Considerar solo operaciones de salida (Cierres)
                    if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
                    {
                        string dealSym  = HistoryDealGetString(ticket, DEAL_SYMBOL);
                        ulong dealMagic = (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC);
                        string dealComm = HistoryDealGetString(ticket, DEAL_COMMENT);

                        if(dealSym == filterSym && IsTradeBelongsToBot(dealMagic, dealComm))
                        {
                            double pnl  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                            double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);

                            totalProfit += (pnl + swap + comm);
                        }
                    }
                }
            }
        }
        return totalProfit;
    }

    //------------------------------------------------------------------
    // Retorna el Drawdown flotante actual % calculado respecto al pico de equidad del bot
    //------------------------------------------------------------------
    static double GetBotDrawdownPct(string symbol = NULL)
    {
        double floatPnL = GetFloatingPnL(symbol);
        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);

        if(balance <= 0.0) return 0.0;

        // Si hay flotante negativo, se calcula el porcentaje respecto al balance actual
        if(floatPnL < 0.0)
        {
            double ddPct = (MathAbs(floatPnL) / balance) * 100.0;
            return NormalizeDouble(ddPct, 2);
        }

        return 0.0;
    }
};

#endif
