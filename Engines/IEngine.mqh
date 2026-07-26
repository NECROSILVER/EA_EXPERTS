//+------------------------------------------------------------------+
//|                                                      IEngine.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Interfaz Base / Clase Abstracta Pura para Motores de Trading     |
//| (Engines) en la arquitectura EMPTY_VOID v2.0.                   |
//+------------------------------------------------------------------+
#ifndef IENGINE_MQH
#define IENGINE_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

struct EngineSignal
{
    bool                hasSignal;
    ENUM_ORDER_TYPE     orderType;
    double              entryPrice;
    double              takeProfit;
    double              stopLoss;
    double              baseLot;
    int                 gridLevel;
    int                 tierLevel; // Clasificador de calidad de setup

    // Constructor por defecto para limpieza de memoria
    EngineSignal()
    {
        hasSignal  = false;
        orderType  = ORDER_TYPE_BUY;
        entryPrice = 0.0;
        takeProfit = 0.0;
        stopLoss   = 0.0;
        baseLot    = 0.0;
        gridLevel  = 0;
        tierLevel  = 0;
    }
};

class IEngine
{
protected:
    int         m_engineId;
    string      m_engineName;
    bool        m_initialized;

public:
    IEngine() : m_engineId(0), m_engineName(""), m_initialized(false) {}
    virtual ~IEngine() {}

    // Métodos virtuales puros
    virtual bool Init(int engineId, string name) = 0;
    virtual EngineSignal Evaluate() = 0;
    virtual void OnDeinit() = 0;

    // Getters de información
    int GetEngineId() const { return m_engineId; }
    string GetEngineName() const { return m_engineName; }
    bool IsInitialized() const { return m_initialized; }
};

#endif
