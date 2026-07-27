//+------------------------------------------------------------------+
//|                                           VoidTrailingManager.mqh|
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Gestor Cuantitativo de Posiciones en Tiempo Real.                |
//| Integración de Break Even Dinámico por Delta N(d2) y Trailing    |
//| Stop Volátil 1-Sigma con Protección Anti-Spam del Bróker.        |
//+------------------------------------------------------------------+
#ifndef VOID_TRAILING_MANAGER_MQH
#define VOID_TRAILING_MANAGER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <Trade/Trade.mqh>
#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>
#include <EMPTY_VOID/Security/BLACK_SCHOLES_MK13.mqh>

class CVoidTrailingManager
{
public:
    static void ProcessQuantTrailing(
        CTrade &trade,
        double annualVolPct = 16.0,
        double targetHours = 4.0,
        bool enableQuantBE = true,
        double minDeltaProbPct = 20.0,
        bool enableQuantTrailing = true,
        double alphaFactor = 0.35,
        double trailingStepPips = 3.0,
        bool enableAlerts = true,
        bool enablePush = true
    )
    {
        int totalPositions = PositionsTotal();
        if(totalPositions == 0) return;

        string symbol = _Symbol;
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(point <= 0.0) point = 0.01;

        long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minStopDist = (stopsLevel > 0) ? (stopsLevel * point) : 0.0;

        double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

        for(int i = totalPositions - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            string posSymbol = PositionGetString(POSITION_SYMBOL);
            ulong posMagic   = (ulong)PositionGetInteger(POSITION_MAGIC);
            string posComment= PositionGetString(POSITION_COMMENT);

            if(posSymbol != symbol || (!CMagicNumberManager::IsEVTrade(posMagic) && StringFind(posComment, "EV_") < 0))
            {
                continue;
            }

            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double entryPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL   = PositionGetDouble(POSITION_SL);
            double currentTP   = PositionGetDouble(POSITION_TP);

            double currentSpot = (posType == POSITION_TYPE_BUY) ? askPrice : bidPrice;

            // --- MÓDULO A: BREAK EVEN DINÁMICO POR DELTA N(d2) (Requiere TP > 0) ---
            if(enableQuantBE && currentTP > 0.0)
            {
                double rawProbCurrent = 0.0;
                if(CBlackScholesMK13::CalculateBSProbabilityToTarget(currentSpot, currentTP, targetHours, annualVolPct, rawProbCurrent))
                {
                    double currentProb = (posType == POSITION_TYPE_SELL) ? (100.0 - rawProbCurrent) : rawProbCurrent;
                    string initProbKey = StringFormat("InitProb_%I64u", ticket);
                    double initialProb = 0.0;

                    if(CVoidState::HasState(initProbKey))
                    {
                        initialProb = CVoidState::GetState(initProbKey, currentProb);
                    }
                    else
                    {
                        initialProb = currentProb;
                        CVoidState::SetState(initProbKey, initialProb);
                    }

                    bool isBEAlreadyApplied = false;
                    if(posType == POSITION_TYPE_BUY && currentSL >= (entryPrice - BS_EPSILON)) isBEAlreadyApplied = true;
                    if(posType == POSITION_TYPE_SELL && currentSL > 0.0 && currentSL <= (entryPrice + BS_EPSILON)) isBEAlreadyApplied = true;

                    if(!isBEAlreadyApplied && CBlackScholesMK13::CheckBreakEvenDelta(initialProb, currentProb, minDeltaProbPct))
                    {
                        double marginPips = 2.0; 
                        double targetSL = (posType == POSITION_TYPE_BUY) ? (entryPrice + (marginPips * point)) : (entryPrice - (marginPips * point));

                        bool isSafeStopsLevel = false;
                        if(posType == POSITION_TYPE_BUY && (bidPrice - targetSL) >= minStopDist) isSafeStopsLevel = true;
                        if(posType == POSITION_TYPE_SELL && (targetSL - askPrice) >= minStopDist) isSafeStopsLevel = true;

                        if(isSafeStopsLevel)
                        {
                            targetSL = NormalizeDouble(targetSL, _Digits);
                            if(trade.PositionModify(ticket, targetSL, currentTP))
                            {
                                PrintFormat("🛡️ [%s BREAK EVEN BS]: ΔN(d2) = +%.1f%% (Inicial: %.1f%% -> Actual: %.1f%%). SL ajustado a %.2f", 
                                            BOT_NAME, (currentProb - initialProb), initialProb, currentProb, targetSL);
                                currentSL = targetSL;
                            }
                        }
                    }
                }
            }

            // --- MÓDULO B: TRAILING STOP VOLÁTIL 1-SIGMA (Independiente de TP) ---
            if(enableQuantTrailing)
            {
                double trailingPips = CBlackScholesMK13::GetQuantTrailingDistance(symbol, annualVolPct, alphaFactor);
                double stepPips     = MathMax(1.0, trailingStepPips);

                if(trailingPips > 0.0)
                {
                    double trailingDistUSD = trailingPips * point;
                    double stepUSD         = stepPips * point;

                    if(posType == POSITION_TYPE_BUY)
                    {
                        double newSL = NormalizeDouble(bidPrice - trailingDistUSD, _Digits);
                        if(newSL > (currentSL + stepUSD) && (bidPrice - newSL) >= minStopDist)
                        {
                            if(trade.PositionModify(ticket, newSL, currentTP))
                            {
                                PrintFormat("📈 [%s TRAILING 1-SIGMA]: Vol: %.1f%% | Dist: %.1f pips | Nuevo SL: %.2f",
                                            BOT_NAME, annualVolPct, trailingPips, newSL);
                            }
                        }
                    }
                    else if(posType == POSITION_TYPE_SELL)
                    {
                        double newSL = NormalizeDouble(askPrice + trailingDistUSD, _Digits);
                        if((currentSL <= 0.0 || newSL < (currentSL - stepUSD)) && (newSL - askPrice) >= minStopDist)
                        {
                            if(trade.PositionModify(ticket, newSL, currentTP))
                            {
                                PrintFormat("📉 [%s TRAILING 1-SIGMA]: Vol: %.1f%% | Dist: %.1f pips | Nuevo SL: %.2f",
                                            BOT_NAME, annualVolPct, trailingPips, newSL);
                            }
                        }
                    }
                }
            }
        }
    }
};

#endif
