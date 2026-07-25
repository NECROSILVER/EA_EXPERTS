//+------------------------------------------------------------------+
//|                                             Engine_Template.mqh  |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Plantilla Estándar y Base Documentada para Construir los         |
//| Futuros Motores Direccionales (M1, M2, M3) en EMPTY_VOID v2.0.   |
//+------------------------------------------------------------------+
#ifndef ENGINE_TEMPLATE_MQH
#define ENGINE_TEMPLATE_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Engines/IEngine.mqh>

class CEngineTemplate : public IEngine
{
private:
    string      m_symbol;
    double      m_defaultLot;

public:
    CEngineTemplate() : m_symbol(""), m_defaultLot(0.10) {}
    ~CEngineTemplate() {}

    //------------------------------------------------------------------
    // Inicializador del motor direccional
    //------------------------------------------------------------------
    virtual bool Init(int engineId, string name) override
    {
        m_engineId    = engineId;
        m_engineName  = name;
        m_symbol      = _Symbol;
        m_defaultLot  = 0.10;
        m_initialized = true;

        PrintFormat("⚡ [IEngine]: Motor #%d ('%s') Inicializado correctamente.", m_engineId, m_engineName);
        return true;
    }

    //------------------------------------------------------------------
    // Evaluación en tiempo real para generar señales de trading
    //------------------------------------------------------------------
    virtual EngineSignal Evaluate() override
    {
        EngineSignal signal;
        if(!m_initialized) return signal;

        // --- LÓGICA DEL MOTOR DIRECCIONAL (PRICE ACTION / SMC / SWEEPS) ---
        // Ejemplo de estructura de retorno cuando se detecta una entrada:
        /*
        signal.hasSignal  = true;
        signal.orderType  = ORDER_TYPE_BUY;
        signal.entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        signal.takeProfit = signal.entryPrice + 15.0;
        signal.stopLoss   = signal.entryPrice - 10.0;
        signal.baseLot    = m_defaultLot;
        signal.gridLevel  = 0;
        */

        return signal;
    }

    //------------------------------------------------------------------
    // Limpieza de recursos al desinstalar el motor
    //------------------------------------------------------------------
    virtual void OnDeinit() override
    {
        m_initialized = false;
        PrintFormat("🧹 [IEngine]: Motor #%d ('%s') Desactivado.", m_engineId, m_engineName);
    }
};

#endif
