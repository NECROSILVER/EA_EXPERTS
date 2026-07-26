//+------------------------------------------------------------------+
//|                                                  TradeAlerts.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Notificador Estandarizado de Eventos y Estados del Sistema        |
//| para Terminal, Alertas Visuales y Push MT5.                      |
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
        bool enablePush = false,
        string symbol = NULL
    )
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        string tag = CCommentTagBuilder::BuildTag(engineId, tier, gridLevel);
        string typeStr = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "BUY" : "SELL";
        string msg = StringFormat("🚀 [%s APERTURA]: %s | Símbolo: %s | Lote: %.2f | Precio: %.2f | SL: %.2f | TP: %.2f | Tag: %s", 
                                  BOT_NAME, typeStr, sym, lot, price, sl, tp, tag);
        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    static void NotifyTradeClose(
        ulong ticket, 
        double pnl, 
        string comment, 
        bool enableAlerts = true,
        bool enablePush = false,
        string symbol = NULL
    )
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        string pnlSign = (pnl >= 0.0) ? "+" : "";
        string msg = StringFormat("🏁 [%s CIERRE]: Ticket #%I64u | Símbolo: %s | PnL: %s$%.2f USD | Comentario: %s", 
                                  BOT_NAME, ticket, sym, pnlSign, pnl, comment);
        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    static void NotifySecurityLock(
        string reason, 
        bool enableAlerts = true,
        bool enablePush = false,
        string symbol = NULL
    )
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        string msg = StringFormat("🛡️ [%s BLOQUEO DE SEGURIDAD]: Activo en %s | Razón: %s", 
                                  BOT_NAME, sym, reason);
        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    static void NotifyNewsWarning(
        string newsDetail,
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string msg = StringFormat("📰 [%s PRECAUCIÓN DE NOTICIA]: Evento Próximo -> %s", BOT_NAME, newsDetail);
        Print(msg);
        if(enableAlerts) Alert(msg);
        if(enablePush)   SendNotification(msg);
    }

    static void NotifyInfo(string message)
    {
        PrintFormat("ℹ️ [%s]: %s", BOT_NAME, message);
    }
};

#endif
