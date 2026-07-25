//+------------------------------------------------------------------+
//|                                           VoidSecurityHub.mqh    |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Envoltorio de Seguridad Central que integra Black-Scholes MK13,  |
//| Lógica de Tiers dinámicos N(d2), Escudo de Spread y Gobernadores |
//| de Seguridad para EMPTY_VOID v2.0.                               |
//+------------------------------------------------------------------+
#ifndef VOID_SECURITY_HUB_MQH
#define VOID_SECURITY_HUB_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Security/BLACK_SCHOLES_MK13.mqh>

class CVoidSecurityHub
{
public:
    //------------------------------------------------------------------
    // Determina el Tier dinámico (1, 2, 3) basado en la probabilidad N(d2)
    // T1 >= 80% (Alta Convicción)
    // T2 >= 60% (Convicción Media)
    // T3 >= 40% (Convicción Estándar)
    //------------------------------------------------------------------
    static int GetTierFromProbability(double probPct)
    {
        if(probPct >= 80.0) return 1;
        if(probPct >= 60.0) return 2;
        if(probPct >= 40.0) return 3;
        return 0; // Menor al mínimo requerido (Rechazado)
    }

    //------------------------------------------------------------------
    // Verifica si la salud del Spread es segura (Procesa Escudo de Spread)
    //------------------------------------------------------------------
    static bool CheckSpreadSafety(
        double currentSpread, 
        double &emaSpread, 
        datetime &expansionStart, 
        double maxMultiplier = 2.0
    )
    {
        return !CBlackScholesMK13::ProcessSpreadShield(currentSpread, emaSpread, expansionStart, maxMultiplier);
    }

    //------------------------------------------------------------------
    // MODO PRINCIPAL: Verifica si una entrada está permitida por todos
    // los escudos de seguridad (Spread, Black-Scholes MK13 y Tiers)
    //------------------------------------------------------------------
    static bool IsEntryAllowed(
        ENUM_ORDER_TYPE orderType,
        double spotPrice,
        double takeProfitPrice,
        double annualVolatilityPct,
        double targetTimeHours,
        double minRequiredProbPct,
        double baseLot,
        double &outAdjustedLot,
        int &outAssignedTier,
        string symbol = NULL
    )
    {
        outAdjustedLot  = baseLot;
        outAssignedTier = 0;

        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;

        // 1. Validación Cuantitativa por Modelo Black-Scholes MK13
        if(!CBlackScholesMK13::ValidateEntry(
            orderType, 
            spotPrice, 
            takeProfitPrice, 
            annualVolatilityPct, 
            targetTimeHours, 
            minRequiredProbPct, 
            baseLot, 
            outAdjustedLot, 
            sym
        ))
        {
            return false;
        }

        // 2. Cálculo de la Probabilidad Delta N(d2) y asignación de Tier
        double probPct = 0.0;
        if(CBlackScholesMK13::CalculateBSProbabilityToTarget(spotPrice, takeProfitPrice, targetTimeHours, annualVolatilityPct, probPct))
        {
            // Ajuste probabilístico para órdenes de venta
            bool isSellSide = (orderType == ORDER_TYPE_SELL || 
                               orderType == ORDER_TYPE_SELL_LIMIT || 
                               orderType == ORDER_TYPE_SELL_STOP || 
                               orderType == ORDER_TYPE_SELL_STOP_LIMIT);

            if(isSellSide) probPct = 100.0 - probPct;

            outAssignedTier = GetTierFromProbability(probPct);
        }
        else
        {
            outAssignedTier = 3; // Fallback seguro
        }

        // 3. Espacio preparado para encadenar futuros escudos (Drawdown, Swap, Noticias)
        return true;
    }
};

#endif
