//+------------------------------------------------------------------+
//|                                         BLACK_SCHOLES_MK13.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Módulo Cuantitativo Modelo Black-76, Auto-Cálculo Booleano de    |
//| Volatilidad Histórica, Probabilidad N(d2), Escudo Re-adaptativo, |
//| Guardia de Coherencia Direccional y Normalizador de Lotes.      |
//+------------------------------------------------------------------+
#ifndef BLACK_SCHOLES_MK13_MQH
#define BLACK_SCHOLES_MK13_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#define BS_SQRT_252 15.874507866387544     // Raíz cuadrada de 252 días de trading
#define BS_ANNUAL_TRADING_HOURS 5796.0    // 252 días * 23 horas operativas/día
#define BS_BASE_VOLATILITY_PCT 16.0       // Volatilidad base por defecto para escalado
#define BS_PI 3.14159265358979323846
#define BS_EPSILON 0.0000001              // Margen de precisión flotante MQL5

class CBlackScholesMK13
{
private:
    static double CND(double x)
    {
        const double a1 =  0.319381530;
        const double a2 = -0.356563782;
        const double a3 =  1.781477937;
        const double a4 = -1.821255978;
        const double a5 =  1.330274429;
        
        double L = MathAbs(x);
        double K = 1.0 / (1.0 + 0.2316419 * L);
        
        double K2 = K * K;
        double K3 = K2 * K;
        double K4 = K3 * K;
        double K5 = K4 * K;
        
        double cnd = 1.0 - 1.0 / MathSqrt(2.0 * BS_PI) * MathExp(-L * L / 2.0) * (a1 * K + a2 * K2 + a3 * K3 + a4 * K4 + a5 * K5);
        
        if(x < 0.0) return 1.0 - cnd;
        return cnd;
    }

    static double AdjustLotToBroker(string symbol, double targetLot)
    {
        double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        
        if(step <= 0.0) return targetLot;

        double steppedLot = MathFloor((targetLot / step) + BS_EPSILON) * step;
        double clampedLot = MathMin(maxLot, MathMax(minLot, steppedLot));
        
        int digits = 0;
        if(step == 0.01) digits = 2;
        else if(step == 0.1) digits = 1;
        else if(step == 1.0) digits = 0;
        else
        {
            for(digits = 2; digits <= 8; digits++)
            {
                double scaled = step * MathPow(10, digits);
                if(MathAbs(scaled - MathRound(scaled)) < 0.0001) break;
            }
            digits = MathMin(digits, 8);
        }
        
        return NormalizeDouble(clampedLot, digits);
    }

public:
    static bool CalculateHistoricalVol(
        string symbol, 
        ENUM_TIMEFRAMES timeframe, 
        int periodBars, 
        double &outVolPct
    )
    {
        outVolPct = 0.0;
        if(periodBars <= 2) return false;

        double annualFactor = 0.0;
        switch(timeframe)
        {
            case PERIOD_D1:  annualFactor = MathSqrt(252.0); break;
            case PERIOD_H4:  annualFactor = MathSqrt(252.0 * 5.75); break;
            case PERIOD_H1:  annualFactor = MathSqrt(BS_ANNUAL_TRADING_HOURS); break;
            default:         return false;
        }
        
        double closePrices[];
        ArraySetAsSeries(closePrices, true);
        
        if(CopyClose(symbol, timeframe, 0, periodBars + 1, closePrices) <= periodBars)
        {
            return false;
        }
            
        double logReturns[];
        ArrayResize(logReturns, periodBars);
        double sum = 0.0;
        
        for(int i = 0; i < periodBars; i++)
        {
            if(closePrices[i + 1] <= 0.0) return false;
            logReturns[i] = MathLog(closePrices[i] / closePrices[i + 1]);
            sum += logReturns[i];
        }
        
        double mean = sum / (double)periodBars;
        double varianceSum = 0.0;
        for(int i = 0; i < periodBars; i++)
        {
            double diff = logReturns[i] - mean;
            varianceSum += diff * diff;
        }
        
        double stdDev = MathSqrt(varianceSum / (double)(periodBars - 1));
        double annualVolPct = stdDev * annualFactor * 100.0;
        outVolPct = MathMin(150.0, MathMax(5.0, annualVolPct));
        return true;
    }

    static bool ProcessSpreadShield(
        double currentSpread, 
        double &emaSpread, 
        datetime &expansionStart, 
        double maxMultiplier = 2.0, 
        int timeoutSec = 900, 
        double fastAlpha = 0.05, 
        double slowAlpha = 0.005
    )
    {
        if(emaSpread <= 0.0)
        {
            emaSpread = currentSpread;
            expansionStart = 0;
            return false;
        }

        bool isExpanded = (currentSpread >= (emaSpread * maxMultiplier));

        if(isExpanded)
        {
            if(expansionStart == 0) expansionStart = TimeCurrent();

            if((TimeCurrent() - expansionStart) > timeoutSec)
            {
                emaSpread = (slowAlpha * currentSpread) + ((1.0 - slowAlpha) * emaSpread);
            }
            return true; 
        }
        else
        {
            expansionStart = 0;
            emaSpread = (fastAlpha * currentSpread) + ((1.0 - fastAlpha) * emaSpread);
            return false; 
        }
    }

    static double CalculateD1(double forwardPrice, double strikePrice, double timeYears, double volatility)
    {
        if(volatility <= 0.0001 || timeYears <= 0.0001 || forwardPrice <= 0.0 || strikePrice <= 0.0) return 0.0;
        double sqrtT = MathSqrt(timeYears);
        return (MathLog(forwardPrice / strikePrice) + (0.5 * volatility * volatility) * timeYears) / (volatility * sqrtT);
    }

    static double CalculateD2(double d1, double volatility, double timeYears)
    {
        if(volatility <= 0.0001 || timeYears <= 0.0001) return 0.0;
        return d1 - (volatility * MathSqrt(timeYears));
    }

    static void GetExpectedDailyRange(double spotPrice, double annualVolatilityPct, double &upperBound1Sigma, double &lowerBound1Sigma)
    {
        if(spotPrice <= 0.0 || annualVolatilityPct <= 0.0)
        {
            upperBound1Sigma = spotPrice;
            lowerBound1Sigma = spotPrice;
            return;
        }

        double dailyVol = (annualVolatilityPct / 100.0) / BS_SQRT_252;
        double moveUSD  = spotPrice * dailyVol;
        
        upperBound1Sigma = spotPrice + moveUSD;
        lowerBound1Sigma = spotPrice - moveUSD;
    }

    static bool CalculateBSProbabilityToTarget(
        double currentPrice, 
        double targetPrice, 
        double timeHours, 
        double annualVolatilityPct, 
        double &outProbability
    )
    {
        outProbability = 0.0;

        if(currentPrice <= 0.0 || targetPrice <= 0.0 || timeHours <= 0.0 || annualVolatilityPct <= 0.0) 
        {
            return false; 
        }
        
        double timeYears = timeHours / BS_ANNUAL_TRADING_HOURS;
        double volDec = annualVolatilityPct / 100.0;
        
        double d1 = CalculateD1(currentPrice, targetPrice, timeYears, volDec);
        double d2 = CalculateD2(d1, volDec, timeYears);
        
        outProbability = MathMin(99.0, MathMax(1.0, CND(d2) * 100.0));
        return true;
    }

    static bool CheckBreakEvenDelta(double initialProb, double currentProb, double minDelta = 20.0)
    {
        if(initialProb <= 0.0 || currentProb <= 0.0) return false;
        return ((currentProb - initialProb) >= minDelta);
    }

    static double GetQuantTrailingDistance(string symbol, double annualVolatilityPct, double alphaFactor)
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        double spot = SymbolInfoDouble(sym, SYMBOL_BID);
        double point = SymbolInfoDouble(sym, SYMBOL_POINT);
        if(spot <= 0.0 || point <= 0.0 || annualVolatilityPct <= 0.0) return 0.0;

        double dailyVol = (annualVolatilityPct / 100.0) / BS_SQRT_252;
        double moveUSD  = spot * dailyVol * alphaFactor;
        
        return (moveUSD / point);
    }

    // Parámetro 'alreadyRiskSized = true' por defecto para evitar doble escalado
    static bool ValidateEntry(
        ENUM_ORDER_TYPE orderType,
        double spotPrice,
        double takeProfitPrice,
        double annualVolatilityPct,
        double targetTimeHours,
        double minRequiredProbPct,
        double baseLot,
        double &adjustedLot,
        string symbol = NULL,
        double baseVolPct = BS_BASE_VOLATILITY_PCT,
        bool alreadyRiskSized = true
    )
    {
        if(baseLot <= 0.0 || baseVolPct <= 0.0) return false;
        if(minRequiredProbPct < 0.0 || minRequiredProbPct > 100.0) return false;
        if(takeProfitPrice <= 0.0 || spotPrice <= 0.0) return false;

        bool isSellSide = (orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_STOP_LIMIT);
        bool isBuySide  = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT);

        if(!isSellSide && !isBuySide) return false;
        if(isSellSide && takeProfitPrice >= spotPrice) return false;
        if(isBuySide && takeProfitPrice <= spotPrice) return false;

        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        double rawProbability = 0.0;

        if(!CalculateBSProbabilityToTarget(spotPrice, takeProfitPrice, targetTimeHours, annualVolatilityPct, rawProbability)) return false;

        double finalProb = isSellSide ? (100.0 - rawProbability) : rawProbability;
        if(finalProb < minRequiredProbPct) return false;

        // Escalado por volatilidad (solo si el lote no viene ya calculado por riesgo flotante)
        double rawTargetLot = baseLot;
        if(!alreadyRiskSized)
        {
            double volFactor = baseVolPct / MathMax(1.0, annualVolatilityPct);
            rawTargetLot = baseLot * volFactor;
        }
        
        adjustedLot = AdjustLotToBroker(sym, rawTargetLot);
        if(adjustedLot <= 0.0) return false;

        return true;
    }
};

#endif
