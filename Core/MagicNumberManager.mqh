//+------------------------------------------------------------------+
//|                                         MagicNumberManager.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Gestor Unificado de Números Mágicos (Magic Numbers) para los     |
//| motores de trading de la arquitectura EMPTY_VOID.                |
//+------------------------------------------------------------------+
#ifndef MAGIC_NUMBER_MANAGER_MQH
#define MAGIC_NUMBER_MANAGER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#define EV_MAGIC_BASE 111100
#define EV_MAGIC_MIN  111100
#define EV_MAGIC_MAX  111999

class CMagicNumberManager
{
public:
    // Retorna el Magic Number dinámico asignado a cada motor de trading (Ej: Motor 1 = 111101)
    static ulong GetMagicNumber(int engineId)
    {
        return (ulong)(EV_MAGIC_BASE + engineId);
    }

    // Valida si una posición u orden pertenece al bot EMPTY_VOID
    static bool IsEVTrade(ulong magic)
    {
        return (magic >= EV_MAGIC_MIN && magic <= EV_MAGIC_MAX);
    }
};

#endif
