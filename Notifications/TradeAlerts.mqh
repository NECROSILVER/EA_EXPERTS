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
    // Notificación de Arranque del Sistema (Diseño Completo Push)
    //------------------------------------------------------------------
    static void NotifyStartup(
        double balance,
        double equity,
        double drawdown,
        string newsSummary,
        bool enablePush = false
    )
    {
        string msg = StringFormat(
            "🚀 [%s] │ SISTEMA INICIALIZADO\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🤖 Bot : %s v%s\n"
            "👑 Creador : NECRO_SILVER\n"
            "📈 Símbolo : %s (Gold)\n"
            "✅ Estado : OPERATIVO 🟢\n\n"
            "💼 Telemetría de Cuenta:\n"
            " ├ Balance: $%.2f USD\n"
            " ├ Equidad: $%.2f USD\n"
            " └ Drawdown: %.2f%%\n\n"
            "🧠 Motor: TEMPEST MK5 🟢\n"
            "📰 Noticias: %s\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, BOT_NAME, BOT_VERSION, _Symbol,
            balance, equity, drawdown, newsSummary
        );

        Print(msg);

        if(enablePush)
        {
            ResetLastError();
            if(!SendNotification(msg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Falló envío de notificación larga. Err: %d", BOT_NAME, GetLastError());
            }
            else
            {
                PrintFormat("📱 [%s PUSH EXITO]: Notificación larga enviada correctamente.", BOT_NAME);
            }
        }
    }

    //------------------------------------------------------------------
    // Notificación de Apertura de Posición (Diseño Completo Push)
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
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🏷️ Tag : %s\n"
            "📈 Orden : %s | %s\n"
            "⚖️ Lotaje : %.2f Lots\n\n"
            "📊 Parámetros:\n"
            " ├ Entrada : %.2f\n"
            " ├ SL : %.2f (%.0f pips)\n"
            " ├ TP : %.2f (%.0f pips)\n"
            " └ Ratio R:R : 1 : %.1f\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, tag, typeStr, _Symbol, lot,
            price, sl, pipsSL, tp, pipsTP, rrRatio
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        if(enablePush)
        {
            ResetLastError();
            if(!SendNotification(msg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Error enviando Apertura. Err: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // Notificación de Cierre de Posición (Diseño Completo Push)
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

        double slippagePips = (type == ORDER_TYPE_BUY) ? (realExitPrice - targetPrice) / point : (targetPrice - realExitPrice) / point;
        string slippageTag = (slippagePips >= 0) ? "🟢 [A Favor]" : "🔴 [En Contra]";
        double netPnL = rawPnL + swapComm;
        double netPct = (prevBalance > 0) ? (netPnL / prevBalance) * 100.0 : 0.0;
        string pnlSign = (netPnL >= 0) ? "+" : "";

        string msg = StringFormat(
            "💰 [%s] │ OPERACIÓN CERRADA\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "📌 Ticket : #%I64u | %s\n"
            "🏷️ Tag : %s\n"
            "⚖️ Lotaje : %.2f Lots\n\n"
            "📊 Ejecución & Slippage:\n"
            " ├ Entrada : %.2f\n"
            " ├ Salida Real : %.2f\n"
            " └ Slippage : %+.1f Pips %s\n\n"
            "💵 Resultado:\n"
            " ├ Neto : %s$%.2f USD (%+.2f%%)\n"
            " └ Balance Nuevo: $%.2f USD %s\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, ticket, typeStr, tag, lot,
            entryPrice, realExitPrice, slippagePips, slippageTag,
            pnlSign, netPnL, netPct, currentBalance, (netPnL >= 0 ? "🟢" : "🔴")
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        if(enablePush)
        {
            ResetLastError();
            if(!SendNotification(msg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Error enviando Cierre. Err: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // Notificación de Bloqueo de Seguridad
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
            "🛡️ [%s] │ BLOQUEO DE SEGURIDAD\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🚨 Evento : ESCUDO DEFENSIVO\n"
            "🔤 Símbolo : %s\n"
            "🛑 Razón : %s\n\n"
            "📊 Pérdida Hoy : -$%.2f USD (-%.2f%%)\n"
            "⚙️ Estado : Entradas congeladas\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, _Symbol, reason, todayLossUSD, todayLossPct
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        if(enablePush)
        {
            ResetLastError();
            if(!SendNotification(msg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Error enviando Bloqueo. Err: %d", BOT_NAME, GetLastError());
            }
        }
    }

    static void NotifyInfo(string message, bool enablePush = false)
    {
        string msg = StringFormat("ℹ️ [%s]: %s", BOT_NAME, message);
        Print(msg);
        if(enablePush) SendNotification(msg);
    }
};

#endif
