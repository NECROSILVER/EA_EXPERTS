//+------------------------------------------------------------------+
//|                                                  TradeAlerts.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Notificador Estandarizado Institucional con Diseños Cyberpunk,   |
//| Análisis de Slippage, Comparativa de Balance y Alertas Push.    |
//+------------------------------------------------------------------+
#ifndef TRADE_ALERTS_MQH
#define TRADE_ALERTS_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/CommentTagBuilder.mqh>

class CVoidTradeAlerts
{
public:
    //------------------------------------------------------------------
    // Notificación de Arranque del Sistema con Verificación de Salud
    //------------------------------------------------------------------
    static void NotifyStartup(
        double balance,
        double equity,
        double drawdown,
        string newsSummary,
        bool enablePush = false
    )
    {
        // 1. Formato extendido para el Journal de MT5
        string msg = StringFormat(
            "🚀 [%s] │ SISTEMA INICIALIZADO\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🤖 Bot        : %s\n"
            "⚙️ Versión    : DESTRUCTIVE_CORE v%s\n"
            "👑 Creador    : NECRO_SILVER\n"
            "📈 Símbolo    : %s (Gold)\n"
            "✅ Estado     : INICIADO CORRECTAMENTE\n\n"
            "💼 Telemetría de Cuenta:\n"
            "  ├─ Balance Inicial : $%.2f USD\n"
            "  ├─ Equidad Actual  : $%.2f USD\n"
            "  └─ Drawdown Bot    : %.2f%%\n\n"
            "🧠 Motores Activos:\n"
            "  └─ [M105] TEMPEST MK5 (iFVG Multi-TF) 🟢\n\n"
            "📰 Eventos Económicos:\n"
            "  └─ %s\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, BOT_NAME, BOT_VERSION, _Symbol,
            balance, equity, drawdown, newsSummary
        );
        Print(msg);

        // 2. Formato Push estricto (< 200 caracteres) con comillas y variables correctamente separadas
        if(enablePush)
        {
            string pushMsg = StringFormat(
                "🚀 %s v%s Inicializado\nSímbolo: %s\nBalance: $%.2f USD\nEquidad: $%.2f USD\nEstado: OPERATIVO 🟢",
                BOT_NAME, BOT_VERSION, _Symbol, balance, equity
            );
            SendNotification(pushMsg);
        }
    }

    //------------------------------------------------------------------
    // Notificación de Apertura de Posición
    //------------------------------------------------------------------
    static void NotifyTradeOpen(
        int engineId,
        int tier,
        int gridLevel,
        ENUM_ORDER_TYPE type,
        double lot,
        double price,
        double sl,
        double tp,
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string tag = CCommentTagBuilder::BuildTag(engineId, tier, gridLevel);
        string typeStr = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "BUY 🟢" : "SELL 🔴";
        
        double pipsSL = MathAbs(price - sl) / _Point;
        double pipsTP = MathAbs(tp - price) / _Point;
        double rrRatio = (pipsSL > 0) ? (pipsTP / pipsSL) : 0.0;

        string msg = StringFormat(
            "🚀 [%s] │ NUEVA POSICIÓN\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🏷️ Tag        : %s\n"
            "📈 Operación  : %s\n"
            "🔤 Símbolo    : %s\n"
            "⚖️ Lotaje     : %.2f Lots\n\n"
            "📊 Parámetros de Entrada:\n"
            "  ├─ Precio Entrada : %.2f\n"
            "  ├─ Stop Loss      : %.2f (%.0f pips)\n"
            "  ├─ Take Profit    : %.2f (%.0f pips)\n"
            "  └─ Ratio R:R      : 1 : %.1f\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, tag, typeStr, _Symbol, lot,
            price, sl, pipsSL, tp, pipsTP, rrRatio
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        // Notificación PUSH compacta (< 200 caracteres) para el móvil
        if(enablePush)
        {
            string pushMsg = StringFormat("🚀 [%s] APERTURA %s\nSímbolo: %s | Lote: %.2f\nPrecio: %.2f | SL: %.2f | TP: %.2f",
                                          BOT_NAME, (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), _Symbol, lot, price, sl, tp);
            SendNotification(pushMsg);
        }
    }

    //------------------------------------------------------------------
    // Notificación de Cierre de Posición con Slippage y Balance
    //------------------------------------------------------------------
    static void NotifyTradeClose(
        ulong ticket,
        string tag,
        ENUM_ORDER_TYPE type,
        double lot,
        double entryPrice,
        double targetPrice,
        double realExitPrice,
        double rawPnL,
        double swapComm,
        double prevBalance,
        double currentBalance,
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string typeStr = (type == ORDER_TYPE_BUY) ? "BUY 🟢" : "SELL 🔴";
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(point <= 0) point = 0.01;

        // Cálculo exacto de Slippage
        double slippagePips = 0.0;
        if(type == ORDER_TYPE_BUY)
        {
            slippagePips = (realExitPrice - targetPrice) / point;
        }
        else
        {
            slippagePips = (targetPrice - realExitPrice) / point;
        }

        string slippageTag = (slippagePips >= 0) ? "🟢 [A Favor]" : "🔴 [En Contra]";
        double netPnL = rawPnL + swapComm;
        double netPct = (prevBalance > 0) ? (netPnL / prevBalance) * 100.0 : 0.0;
        string pnlSign = (netPnL >= 0) ? "+" : "";

        string msg = StringFormat(
            "💰 [%s] │ OPERACIÓN CERRADA\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "📌 Ticket     : #%I64u\n"
            "🏷️ Tag        : %s\n"
            "🔤 Operación  : %s\n"
            "⚖️ Lotaje     : %.2f Lots\n\n"
            "📊 Desglose de Ejecución & Slippage:\n"
            "  ├─ Precio Entrada : %.2f\n"
            "  ├─ Cierre Teórico : %.2f\n"
            "  ├─ Cierre Real    : %.2f\n"
            "  └─ Slippage       : %+.1f Pips %s\n\n"
            "💵 Resultado Financiero:\n"
            "  ├─ PnL Operativo  : %+$%.2f USD\n"
            "  ├─ Swap / Comisión: %+$%.2f USD\n"
            "  └─ Beneficio Neto : %s$%.2f USD (%+.2f%%)\n\n"
            "📈 Comparativa de Balance:\n"
            "  ├─ Balance Previo : $%.2f USD\n"
            "  └─ Balance Actual : $%.2f USD %s\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, ticket, tag, typeStr, lot,
            entryPrice, targetPrice, realExitPrice,
            slippagePips, slippageTag,
            rawPnL, swapComm, pnlSign, netPnL, netPct,
            prevBalance, currentBalance, (netPnL >= 0 ? "🟢" : "🔴")
        );

        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    //------------------------------------------------------------------
    // Notificación de Bloqueo de Seguridad / Emergency Stop
    //------------------------------------------------------------------
    static void NotifySecurityLock(
        string reason,
        double todayLossUSD = 0.0,
        double todayLossPct = 0.0,
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string msg = StringFormat(
            "🛡️ [%s] │ BLOQUEO DE SEGURIDAD ACTIVO\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🚨 Evento     : ACTIVACIÓN DE ESCUDO DEFENSIVO\n"
            "🔤 Símbolo    : %s\n"
            "🛑 Razón      : %s\n\n"
            "📊 Estado de la Intervención:\n"
            "  ├─ Pérdida Hoy    : -$%.2f USD (-%.2f%%)\n"
            "  ├─ Nuevas Entradas: CONGELADAS HASTA MAÑANA\n"
            "  └─ Posiciones     : CERRADAS / PROTEGIDAS\n\n"
            "⚙️ Acción     : Preservación estricta de capital.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, _Symbol, reason, todayLossUSD, todayLossPct
        );

        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    static void NotifyInfo(string message, bool enablePush = false)
    {
        string msg = StringFormat("ℹ️ [%s]: %s", BOT_NAME, message);
        Print(msg);
        if(enablePush) SendNotification(msg);
    }
};

#endif
