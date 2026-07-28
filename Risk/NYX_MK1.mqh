//+------------------------------------------------------------------+
//|                                                      NYX_MK1.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Módulo de Trailing Stop por Fases Aceleradas (NYX_MK1)           |
//| Fase 1: Break-Even Acelerado (+10% meta) al alcanzar 50% TP      |
//| Fase 2: Persecución dinámica (15% colchón) entre 50% y 79% TP    |
//| Fase 3: Ahorque final (8% colchón) al alcanzar >= 80% TP         |
//+------------------------------------------------------------------+
#ifndef NYX_MK1_MQH
#define NYX_MK1_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <Trade/Trade.mqh>
#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>

class CNYX_MK1
{
public:
    static void ProcessTrailing(CTrade &tradeExecutor)
    {
        int totalPos = PositionsTotal();
        if(totalPos == 0) return;

        string symbol = _Symbol;
        double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(point <= 0.0) point = 0.01;

        long stopsLevel    = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minStopDist = (stopsLevel > 0) ? (stopsLevel * point) : 0.0;

        for(int i = totalPos - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            string posSym  = PositionGetString(POSITION_SYMBOL);
            ulong posMagic = (ulong)PositionGetInteger(POSITION_MAGIC);
            string posComm = PositionGetString(POSITION_COMMENT);

            if(posSym != symbol || (!CMagicNumberManager::IsEVTrade(posMagic) && StringFind(posComm, "EV_") < 0))
            {
                continue;
            }

            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);

            if(currentTP <= 0.0) continue; // Requiere TP activo para calcular meta D_TP

            double dTP = MathAbs(currentTP - openPrice);
            if(dTP <= 0.0) continue;

            if(posType == POSITION_TYPE_BUY)
            {
                double distProfitUSD = bidPrice - openPrice;
                double pctTP = (distProfitUSD / dTP) * 100.0;

                // FASE 1: Break-Even Acelerado al 50% de la meta (+10% TP asegurado)
                if(pctTP >= 50.0)
                {
                    double targetSL1 = NormalizeDouble(openPrice + (dTP * 0.10), _Digits);
                    if(currentSL < targetSL1 && (bidPrice - targetSL1) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL1, currentTP))
                        {
                            PrintFormat("🚀 [NYX_MK1 FASE 1 BUY]: Ticket #%I64u | TP Alcanzado: %.1f%% | SL Mover a BE+10%% (%.2f)",
                                        ticket, pctTP, targetSL1);
                            currentSL = targetSL1;
                        }
                    }
                }

                // FASE 2: Persecución del 50% al 79% de la meta (Colchón del 15% D_TP)
                if(pctTP >= 50.0 && pctTP < 80.0)
                {
                    double buffer15 = dTP * 0.15;
                    double targetSL2 = NormalizeDouble(bidPrice - buffer15, _Digits);
                    if(targetSL2 > currentSL && (bidPrice - targetSL2) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL2, currentTP))
                        {
                            PrintFormat("📈 [NYX_MK1 FASE 2 BUY]: Ticket #%I64u | TP Alcanzado: %.1f%% | Nuevo SL: %.2f",
                                        ticket, pctTP, targetSL2);
                            currentSL = targetSL2;
                        }
                    }
                }

                // FASE 3: Ahorque Final >= 80% de la meta (Colchón estrecho del 8% D_TP)
                if(pctTP >= 80.0)
                {
                    double buffer8 = dTP * 0.08;
                    double targetSL3 = NormalizeDouble(bidPrice - buffer8, _Digits);
                    if(targetSL3 > currentSL && (bidPrice - targetSL3) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL3, currentTP))
                        {
                            PrintFormat("🎯 [NYX_MK1 FASE 3 BUY]: Ticket #%I64u | TP Alcanzado: %.1f%% | SL Ahorcado a: %.2f",
                                        ticket, pctTP, targetSL3);
                            currentSL = targetSL3;
                        }
                    }
                }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
                double distProfitUSD = openPrice - askPrice;
                double pctTP = (distProfitUSD / dTP) * 100.0;

                // FASE 1: Break-Even Acelerado al 50% de la meta (+10% TP asegurado)
                if(pctTP >= 50.0)
                {
                    double targetSL1 = NormalizeDouble(openPrice - (dTP * 0.10), _Digits);
                    if((currentSL <= 0.0 || currentSL > targetSL1) && (targetSL1 - askPrice) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL1, currentTP))
                        {
                            PrintFormat("🚀 [NYX_MK1 FASE 1 SELL]: Ticket #%I64u | TP Alcanzado: %.1f%% | SL Mover a BE+10%% (%.2f)",
                                        ticket, pctTP, targetSL1);
                            currentSL = targetSL1;
                        }
                    }
                }

                // FASE 2: Persecución del 50% al 79% de la meta (Colchón del 15% D_TP)
                if(pctTP >= 50.0 && pctTP < 80.0)
                {
                    double buffer15 = dTP * 0.15;
                    double targetSL2 = NormalizeDouble(askPrice + buffer15, _Digits);
                    if((currentSL <= 0.0 || targetSL2 < currentSL) && (targetSL2 - askPrice) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL2, currentTP))
                        {
                            PrintFormat("📉 [NYX_MK1 FASE 2 SELL]: Ticket #%I64u | TP Alcanzado: %.1f%% | Nuevo SL: %.2f",
                                        ticket, pctTP, targetSL2);
                            currentSL = targetSL2;
                        }
                    }
                }

                // FASE 3: Ahorque Final >= 80% de la meta (Colchón estrecho del 8% D_TP)
                if(pctTP >= 80.0)
                {
                    double buffer8 = dTP * 0.08;
                    double targetSL3 = NormalizeDouble(askPrice + buffer8, _Digits);
                    if((currentSL <= 0.0 || targetSL3 < currentSL) && (targetSL3 - askPrice) >= minStopDist)
                    {
                        if(tradeExecutor.PositionModify(ticket, targetSL3, currentTP))
                        {
                            PrintFormat("🎯 [NYX_MK1 FASE 3 SELL]: Ticket #%I64u | TP Alcanzado: %.1f%% | SL Ahorcado a: %.2f",
                                        ticket, pctTP, targetSL3);
                            currentSL = targetSL3;
                        }
                    }
                }
            }
        }
    }
};

#endif
