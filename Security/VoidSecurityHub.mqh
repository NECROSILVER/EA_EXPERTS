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

#include <EMPTY_VOID/Core/Config.mqh>
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
        string sideStr = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP) ? "BUY" : "SELL";

        // 1. Cálculo probabilístico N(d2) vía Black-Scholes MK13
        double probPct = 0.0;
        bool probCalculated = CBlackScholesMK13::CalculateBSProbabilityToTarget(spotPrice, takeProfitPrice, targetTimeHours, annualVolatilityPct, probPct);
        
        if(probCalculated)
        {
            if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)
            {
                probPct = 100.0 - probPct;
            }
            outAssignedTier = GetTierFromProbability(probPct);
        }

        // 2. Validar Entrada con el Módulo Cuantitativo
        bool isValid = CBlackScholesMK13::ValidateEntry(
            orderType, 
            spotPrice, 
            takeProfitPrice, 
            annualVolatilityPct, 
            targetTimeHours, 
            minRequiredProbPct, 
            baseLot, 
            outAdjustedLot, 
            sym
        );

        // 3. Emitir Log de Auditoría en Vivo en la pestaña Expertos de MT5
        if(isValid)
        {
            PrintFormat("🛡️ [%s - SECURITY HUB]: Señal APROBADA | Tipo: %s | Probabilidad N(d2): %.2f%% | Tier Asignado: T%d | Lote Base: %.2f -> Lote Ajustado: %.2f",
                        BOT_NAME, sideStr, probPct, outAssignedTier, baseLot, outAdjustedLot);
        }
        else
        {
            PrintFormat("⚠️ [%s - SECURITY HUB]: Señal RECHAZADA por MK13 | Tipo: %s | Probabilidad N(d2): %.2f%% (Mínima: %.2f%%) | Entrada Bloqueada.",
                        BOT_NAME, sideStr, probPct, minRequiredProbPct);
        }

        return isValid;
    }
};

#endif
