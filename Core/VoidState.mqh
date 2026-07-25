//+------------------------------------------------------------------+
//|                                                    VoidState.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Gestor de Estado Persistente mediante GlobalVariables de MT5      |
//| Preserva niveles de grilla y estados de escudos ante reinicios   |
//| de VPS o reconexiones del Terminal.                              |
//+------------------------------------------------------------------+
#ifndef VOID_STATE_MQH
#define VOID_STATE_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>

class CVoidState
{
private:
    // Construye la clave de variable global con formato "EV_<Symbol>_<KeyName>"
    static string BuildVarKey(string keyName, string symbol = NULL)
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        return StringFormat("EV_%s_%s", sym, keyName);
    }

public:
    // Almacena un valor en una variable global persistente
    static void SetState(string keyName, double value, string symbol = NULL)
    {
        string fullKey = BuildVarKey(keyName, symbol);
        GlobalVariableSet(fullKey, value);
    }

    // Obtiene un valor almacenado en una variable global persistente
    static double GetState(string keyName, double defaultValue = 0.0, string symbol = NULL)
    {
        string fullKey = BuildVarKey(keyName, symbol);
        if(GlobalVariableCheck(fullKey))
        {
            return GlobalVariableGet(fullKey);
        }
        return defaultValue;
    }

    // Revisa si existe una variable global almacenada
    static bool HasState(string keyName, string symbol = NULL)
    {
        string fullKey = BuildVarKey(keyName, symbol);
        return GlobalVariableCheck(fullKey);
    }

    // Elimina una variable global almacenada
    static void DeleteState(string keyName, string symbol = NULL)
    {
        string fullKey = BuildVarKey(keyName, symbol);
        if(GlobalVariableCheck(fullKey))
        {
            GlobalVariableDel(fullKey);
        }
    }

    // Guarda el nivel de grilla activo para un motor de trading específico
    static void SaveGridLevel(int engineId, int level, string symbol = NULL)
    {
        string keyName = StringFormat("M%d_GridLevel", engineId);
        SetState(keyName, (double)level, symbol);
    }

    // Obtiene el nivel de grilla activo almacenado para un motor de trading
    static int GetGridLevel(int engineId, string symbol = NULL)
    {
        string keyName = StringFormat("M%d_GridLevel", engineId);
        return (int)GetState(keyName, 0.0, symbol);
    }
};

#endif
