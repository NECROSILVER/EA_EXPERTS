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
            ResetLastError();
            if(!SendNotification(msg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Falló envío de notificación de arranque. Err: %d", BOT_NAME, GetLastError());
            }
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
    // 2. Notificación de Cierre de Operación (Con Slippage y Comparativa)
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
            string pushMsg = StringFormat(
                "🏁 [%s] CIERRE %s\nTicket: #%I64u | Tag: %s\nPnL Neto: %s$%.2f USD (%+.2f%%)\nBalance: $%.2f USD",
                BOT_NAME, (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), ticket, tag, pnlSign, netPnL, netPct, currentBalance
            );
            
            ResetLastError();
            if(!SendNotification(pushMsg))
            {
                PrintFormat("❌ [%s PUSH ERROR]: Falló el envío de notificación Push de cierre. Código MT5: %d", BOT_NAME, GetLastError());
            }
        }
    }

    //------------------------------------------------------------------
    // 3. Notificación Dedicada de Calendario Diario de Noticias
    //------------------------------------------------------------------
    static void NotifyNewsCalendar(
        string dateStr,
        int totalEvents,
        string eventsSchedule,
        bool enablePush = false
    )
    {
        string msg = StringFormat(
            "📰 [%s] │ CALENDARIO DE NOTICIAS (USD)\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "📅 Fecha           : %s\n"
            "📊 Total Eventos   : %d Programados para hoy\n\n"
            "🕒 Cronograma de Eventos Impacto (USD):\n"
            "%s\n\n"
            "⚠️ Nota: Los horarios corresponden a la hora oficial del servidor Bróker.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, dateStr, totalEvents, eventsSchedule
        );

        Print(msg);
        if(enablePush) SendNotification(msg);
    }

    //------------------------------------------------------------------
    // 4. Notificación de Alerta de Noticia Próxima / En Curso
    //------------------------------------------------------------------
    static void NotifyNewsWarning(
        string impactStr,
        string windowStr,
        string eventName,
        string eventTime,
        bool enablePush = false
    )
    {
        string msg = StringFormat(
            "⚠️ [%s] │ PRECAUCIÓN DE NOTICIA EN CURSO\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "🔴 Impacto    : %s\n"
            "⏱️ Ventana   : %s\n"
            "💵 Divisa     : USD (Afecta directamente al ORO)\n\n"
            "📰 Evento     : %s\n"
            "🕒 Hora Evento: %s (Broker Time)\n"
            "🛡️ Estado EA  : Escudo de Spread en máxima alerta.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            BOT_NAME, impactStr, windowStr, eventName, eventTime
        );

        Print(msg);
        if(enablePush) SendNotification(msg);
    }

    //------------------------------------------------------------------
    // 5. Notificación de Bloqueo de Seguridad / Emergency Stop
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
