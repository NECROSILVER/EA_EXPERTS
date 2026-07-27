//+------------------------------------------------------------------+
//|                                                  TradeAlerts.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Notificador Estandarizado Institucional con Diseños Cyberpunk,   |
//| Análisis de Slippage, Comparativa de Balance y Alertas Push      |
//| Decoradas de Alta Densidad Informativa (Sin Notificaciones       |
//| Duplicadas).                                                     |
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
    // Notificación de Apertura de Posición Decorada (Diseño 2: Terminal Quant)
    //------------------------------------------------------------------
    static void NotifyTradeOpen(
        ulong ticket, string tag, ENUM_ORDER_TYPE type, double lot,
        double reqPrice, double realPrice, double sl, double tp,
        double bsProb, int bsTier, bool enableAlerts = true, bool enablePush = true
    )
    {
        if(enablePush)
        {
            double openSlippage = MathAbs(reqPrice - realPrice) / _Point;
            string orderEmoji   = (type == ORDER_TYPE_BUY) ? "🚀 🟢" : "🚀 🔴";
            
            string pushMsg = StringFormat(
                "%s [%s v2.2.0] NUEVA ORDEN (%s)\n──────────────────────────────────\n🎟️ TICKET   : #%I64u [%s]\n📊 OPERACION: %s | %s\n💰 ENTRADA  : %.2f Lotes @ $%.2f\n⚡ SLIPPAGE : %.1f pips\n🎯 SL / TP  : $%.2f / $%.2f\n📐 CUANT    : BS N(d2) %.1f%% | Tier %d\n💼 BALANCE  : $%.2f USD | EQ: $%.2f USD",
                orderEmoji, BOT_NAME, (type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                ticket, tag, _Symbol, (type == ORDER_TYPE_BUY ? "COMPRA (BUY)" : "VENTA (SELL)"),
                lot, realPrice, openSlippage, sl, tp, bsProb, bsTier,
                AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)
            );
            ResetLastError();
            SendNotification(pushMsg);
        }
    }

    //------------------------------------------------------------------
    // Notificación de Cierre de Operación Decorada (Diseño 3: Terminal Quant)
    //------------------------------------------------------------------
    static void NotifyTradeClose(
        ulong ticket, string tag, ENUM_ORDER_TYPE type, double lot,
        double entryPrice, double targetPrice, double realExitPrice,
        double rawPnL, double swapComm, double prevBalance, double currentBalance,
        string closeReason = "EJECUCION REGULAR", bool enableAlerts = true, bool enablePush = true
    )
    {
        if(enablePush)
        {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(point <= 0.0) point = 0.01;
            
            // Protección contra dividendo por cero o precios nulos en ejecuciones manuales
            double closeSlippage = (targetPrice > 0.0) ? MathAbs(targetPrice - realExitPrice) / point : 0.0;
            double netPnL        = rawPnL + swapComm;
            double netPct        = (prevBalance > 0) ? (netPnL / prevBalance) * 100.0 : 0.0;
            
            bool isProfit       = (netPnL >= 0);
            string headerEmoji = isProfit ? "🏁 🟢" : "🏁 🔴";
            string statusTitle = isProfit ? "CIERRE EN GANANCIA" : "CIERRE EN PERDIDA";
            string netSign     = isProfit ? "+" : "";
            
            string pushMsg = StringFormat(
                "%s [%s v2.2.0] %s\n──────────────────────────────────\n🎟️ TICKET   : #%I64u | %s\n💵 PnL NETO : %s$%.2f USD (%+.2f%%)\n🎯 MOTIVO   : %s\n⚡ SLIPPAGE : %.1f pips\n📈 BALANCE  : $%.2f USD\n📉 EQUIDAD  : $%.2f USD",
                headerEmoji, BOT_NAME, statusTitle,
                ticket, (type == ORDER_TYPE_BUY ? "COMPRA (BUY)" : "VENTA (SELL)"),
                netSign, netPnL, netPct, closeReason, closeSlippage, currentBalance, AccountInfoDouble(ACCOUNT_EQUITY)
            );
            ResetLastError();
            SendNotification(pushMsg);
        }
    }

    //------------------------------------------------------------------
    // Notificación de Bloqueo de Seguridad / Emergency Stop
    //------------------------------------------------------------------
    static void NotifySecurityLock(
        string reason,
        double todayLossUSD = 0.0,
        double todayLossPct = 0.0,
        bool enableAlerts = true,
        bool enablePush = true
    )
    {
        if(enablePush)
        {
            string msg = StringFormat(
                "🛡️ 🚨 [%s v2.2.0] BLOQUEO DE SEGURIDAD\n──────────────────────────────────\n🛑 RAZON   : %s\n🔤 ACTIVO  : %s\n📊 LOSS HOY: -$%.2f USD (-%.2f%%)\n⚙️ ESTADO  : OPERATIVA INTERRUMPIDA",
                BOT_NAME, reason, _Symbol, todayLossUSD, todayLossPct
            );
            ResetLastError();
            SendNotification(msg);
        }
    }

    static void NotifyInfo(string message, bool enablePush = true)
    {
        if(enablePush)
        {
            string msg = StringFormat("ℹ️ [%s]: %s", BOT_NAME, message);
            ResetLastError();
            SendNotification(msg);
        }
    }
};

#endif
