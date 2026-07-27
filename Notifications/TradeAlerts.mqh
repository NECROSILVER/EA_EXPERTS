//+------------------------------------------------------------------+
//|                                                  TradeAlerts.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Notificador Estandarizado Institucional con Diseños Cyberpunk,   |
//| Análisis de Slippage, Comparativa de Balance y Alertas Push      |
//| Decoradas de Alta Densidad Informativa.                          |
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
    // 1. Notificación de Arranque e Inicialización del Sistema
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

        if(enablePush)
        {
            string pushMsg = StringFormat(
                "🤖 ⚡ [%s v%s] SISTEMA ONLINE\n──────────────────────────────────\n👑 OPERADOR : NECRO_SILVER\n🔤 ACTIVO   : %s (Gold)\n💼 BALANCE  : $%.2f USD | EQ: $%.2f\n🧠 MOTORES  : TEMPEST_MK5 [ACTIVO 🟢]\n🛡️ ESCUDOS  : BS_MK13 [OK ✅] | SENTINEL [OK 🟢]",
                BOT_NAME, BOT_VERSION, _Symbol, balance, equity
            );
            ResetLastError();
            if(!SendNotification(pushMsg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Falló envío de notificación de arranque. Err: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // Notificación de Apertura de Posición Decorada Estilo Terminal Quant
    //------------------------------------------------------------------
    static void NotifyTradeOpen(
        int engineId,
        int tier,
        int gridLevel,
        ENUM_ORDER_TYPE type,
        double lot,
        double entryPrice,
        double sl,
        double tp,
        double bsProb = 0.0,
        int bsTier = 0,
        double reqPrice = 0.0,
        ulong ticket = 0,
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string tag = CCommentTagBuilder::BuildTag(engineId, tier, gridLevel);
        string typeStr = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "BUY 🟢" : "SELL 🔴";
        
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(point <= 0) point = 0.01;

        double pipsSL = MathAbs(entryPrice - sl) / point;
        double pipsTP = MathAbs(tp - entryPrice) / point;
        double rrRatio = (pipsSL > 0) ? (pipsTP / pipsSL) : 0.0;
        double openSlippage = (reqPrice > 0.0) ? MathAbs(reqPrice - entryPrice) / point : 0.2;

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
            entryPrice, sl, pipsSL, tp, pipsTP, rrRatio
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        if(enablePush)
        {
            string orderEmoji = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "🚀 🟢" : "🚀 🔴";
            string sideText   = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "BUY" : "SELL";
            string sideLong   = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) ? "COMPRA (BUY)" : "VENTA (SELL)";
            
            string pushMsg = StringFormat(
                "%s [%s v%s] NUEVA ORDEN (%s)\n──────────────────────────────────\n🎟️ TICKET   : #%I64u [%s]\n📊 OPERACION: %s | %s\n💰 PRECIO   : %.2f Lotes @ $%.2f\n⚡ SLIPPAGE : %.1f pips\n🎯 SL / TP  : $%.2f / $%.2f\n📐 CUANT    : BS N(d2) %.1f%% | Tier %d\n💼 BALANCE  : $%.2f USD",
                orderEmoji, BOT_NAME, BOT_VERSION, sideText,
                ticket, tag, _Symbol, sideLong,
                lot, entryPrice, openSlippage, sl, tp, bsProb, bsTier, AccountInfoDouble(ACCOUNT_BALANCE)
            );

            ResetLastError();
            if(!SendNotification(pushMsg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Error enviando Apertura. Err: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // 2. Notificación de Cierre de Operación Decorada (Ganancia vs Pérdida)
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
        string closeReasonIn = "",
        bool enableAlerts = true,
        bool enablePush = false
    )
    {
        string typeStr = (type == ORDER_TYPE_BUY) ? "BUY 🟢" : "SELL 🔴";
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(point <= 0.0) point = 0.01;

        double slippagePips = 0.0;
        if(targetPrice > 0.0)
        {
            slippagePips = (type == ORDER_TYPE_BUY) ? (realExitPrice - targetPrice) / point : (targetPrice - realExitPrice) / point;
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
            "🔤 Operación  : %s (%s)\n"
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
            BOT_NAME, ticket, tag, typeStr, _Symbol, lot,
            entryPrice, targetPrice, realExitPrice,
            slippagePips, slippageTag,
            rawPnL, swapComm, pnlSign, netPnL, netPct,
            prevBalance, currentBalance, (netPnL >= 0 ? "🟢" : "🔴")
        );

        Print(msg);
        if(enableAlerts) Alert(msg);

        if(enablePush)
        {
            bool isProfit = (netPnL >= 0.0);
            string headerEmoji = isProfit ? "🏁 🟢" : "🏁 🔴";
            string statusTitle = isProfit ? "CIERRE EN GANANCIA" : "CIERRE EN PERDIDA";
            string netSignStr  = isProfit ? "+" : "";
            double closeSlippage = 0.0;
            if(targetPrice > 0.0)
            {
                closeSlippage = MathAbs(targetPrice - realExitPrice) / point;
            }
            
            string defaultReason = isProfit ? "TRAILING STOP (1-σ)" : "STOP LOSS FIJO";
            string reasonText    = (closeReasonIn != "" && closeReasonIn != NULL) ? closeReasonIn : defaultReason;

            string pushMsg = StringFormat(
                "%s [%s v%s] %s\n──────────────────────────────────\n🎟️ TICKET   : #%I64u | %s\n💵 PnL NETO : %s$%.2f USD (%+.2f%%)\n🎯 MOTIVO   : %s\n⚡ SLIPPAGE : %.1f pips\n📈 BALANCE  : $%.2f USD\n📉 EQUIDAD  : $%.2f USD",
                headerEmoji, BOT_NAME, BOT_VERSION, statusTitle,
                ticket, (type == ORDER_TYPE_BUY ? "COMPRA (BUY)" : "VENTA (SELL)"),
                netSignStr, netPnL, netPct, reasonText, closeSlippage, currentBalance, AccountInfoDouble(ACCOUNT_EQUITY)
            );
            
            ResetLastError();
            if(!SendNotification(pushMsg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Falló el envío de notificación Push de cierre. Código MT5: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // 3. Notificación de Bloqueo de Seguridad / Emergency Stop
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
            "  └─ Posiciones     : CERRADAS DE EMERGENCIA\n\n"
            "⚙️ Acción     : Preservación estricta de capital.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
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
