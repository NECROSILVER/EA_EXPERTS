//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Panel de Control Visual (HUD Dashboard) con Estética Cyberpunk   |
//| Neón de Alto Contraste para la Arquitectura EMPTY_VOID v2.0.    |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_MQH
#define DASHBOARD_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/ProfitTracker/ProfitTracker.mqh>
#include <EMPTY_VOID/Notifications/NewsWatcher.mqh>
#include <EMPTY_VOID/Security/VoidSecurityHub.mqh>

#define HUD_PREFIX "EV_HUD_"
#define HUD_FONT   "Trebuchet MS"

class CVoidDashboard
{
private:
    // Auxiliar para crear o actualizar rectángulos de fondo
    static void CreateOrUpdateRect(
        string name, 
        int x, 
        int y, 
        int width, 
        int height, 
        color bgColor, 
        color borderColor, 
        int borderWidth = 1,
        int corner = 0
    )
    {
        string objName = HUD_PREFIX + name;
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        }

        ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
        ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
        ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
        ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, borderWidth);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }

    // Auxiliar para crear o actualizar etiquetas de texto
    static void CreateOrUpdateLabel(
        string name, 
        string text, 
        int x, 
        int y, 
        int fontSize, 
        bool bold, 
        color textColor,
        int corner = 0
    )
    {
        string objName = HUD_PREFIX + name;
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        }

        ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetString(0, objName, OBJPROP_FONT, HUD_FONT);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }

public:
    //------------------------------------------------------------------
    // Inicializa la estructura del Dashboard en el gráfico
    //------------------------------------------------------------------
    static bool Init(string symbol = NULL, int corner = 0, int x = 15, int y = 25)
    {
        // 1. Marcos y fondo sólido Cyberpunk
        CreateOrUpdateRect("FrameOuter", x - 12, y - 12, 660, 360, C'0,240,255', C'0,240,255', 2, corner);
        CreateOrUpdateRect("FrameInner", x - 10, y - 10, 656, 356, C'255,0,200', C'255,0,200', 1, corner);
        CreateOrUpdateRect("BG",         x - 8,  y - 8,  652, 352, C'10,2,16',  C'0,200,255', 1, corner);

        // 2. Renderizar contenido inicial
        Update(0.0, 0.0, true, symbol);
        ChartRedraw(0);
        return true;
    }

    //------------------------------------------------------------------
    // Actualiza los valores en vivo del Dashboard
    //------------------------------------------------------------------
    static void Update(
        double currentSpread = 0.0, 
        double emaSpread = 0.0, 
        bool isSpreadSafe = true, 
        string symbol = NULL
    )
    {
        string sym = (symbol == NULL || symbol == "") ? _Symbol : symbol;
        int x = 15;
        int y = 25;
        int lineHeight = 16;
        int corner = 0;

        // --- CABECERA PRINCIPAL ---
        CreateOrUpdateLabel("Title", StringFormat("🏦 %s DESTRUCTIVE_CORE v%s", BOT_NAME, BOT_VERSION), x, y, 10, true, C'0,240,255', corner);
        CreateOrUpdateLabel("LogoText", "NECRO_SILVER", x + 510, y, 9, true, C'255,0,255', corner);
        y += lineHeight + 1;

        CreateOrUpdateLabel("Creator", "👤 CREADOR: NECRO_SILVER | SÍMBOLO: " + sym, x, y, 9, true, C'255,0,255', corner);
        y += lineHeight + 4;

        CreateOrUpdateLabel("Div0", "------------------------------------------------------------------------------------------------------------", x, y, 8, false, C'0,200,255', corner);
        y += lineHeight + 2;

        // --- SECCIÓN 1: [ METRICAS FINANCIERAS & TELEMETRIA ] ---
        CreateOrUpdateLabel("Sec1_Header", "[ 📊 TELEMETRÍA DE CUENTA Y RENDIMIENTO ]", x, y, 9, true, C'255,0,255', corner);
        y += lineHeight + 2;

        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        double floatPnL = CVoidProfitTracker::GetFloatingPnL(sym);
        double closed   = CVoidProfitTracker::GetClosedProfit(sym);
        double drawdown = CVoidProfitTracker::GetBotDrawdownPct(sym);
        int openCount   = CVoidProfitTracker::GetOpenPositionsCount(sym);

        // Fila 1: Balance y Equidad
        string balStr = StringFormat("BALANCE: $%.2f USD | EQUIDAD: $%.2f USD", balance, equity);
        CreateOrUpdateLabel("BalEq", balStr, x + 10, y, 8, true, C'0,240,255', corner);

        string openStr = StringFormat("Posiciones Bot: %d activas", openCount);
        CreateOrUpdateLabel("OpenCount", openStr, x + 380, y, 8, true, C'0,255,140', corner);
        y += lineHeight;

        // Fila 2: Flotante Bot y Closed Profit
        color pnlClr = (floatPnL >= 0.0) ? C'0,255,140' : C'255,60,80';
        string floatStr = StringFormat("Flotante Bot: %s$%.2f USD", (floatPnL >= 0.0 ? "+" : ""), floatPnL);
        CreateOrUpdateLabel("FloatPnL", floatStr, x + 10, y, 8, true, pnlClr, corner);

        color closedClr = (closed >= 0.0) ? C'0,255,140' : C'255,60,80';
        string closedStr = StringFormat("Ganancia Cerrada: %s$%.2f USD", (closed >= 0.0 ? "+" : ""), closed);
        CreateOrUpdateLabel("ClosedProfit", closedStr, x + 380, y, 8, true, closedClr, corner);
        y += lineHeight;

        // Fila 3: Drawdown %
        color ddClr = (drawdown > 5.0) ? C'255,60,80' : C'255,200,0';
        string ddStr = StringFormat("EA Drawdown Flotante: %.2f%%", drawdown);
        CreateOrUpdateLabel("Drawdown", ddStr, x + 10, y, 8, true, ddClr, corner);

        string clockStr = StringFormat("Hora Broker: %s", TimeToString(TimeCurrent(), TIME_SECONDS));
        CreateOrUpdateLabel("Clock", clockStr, x + 380, y, 8, false, C'180,190,210', corner);
        y += lineHeight + 4;

        CreateOrUpdateLabel("Div1", "------------------------------------------------------------------------------------------------------------", x, y, 8, false, C'0,200,255', corner);
        y += lineHeight + 2;

        // --- SECCIÓN 2: [ ESCUDOS Y SEGURIDAD CUANTITATIVA ] ---
        CreateOrUpdateLabel("Sec2_Header", "[ 🛡️ ESCUDOS DE SEGURIDAD & BLACK-SCHOLES MK13 ]", x, y, 9, true, C'255,0,255', corner);
        y += lineHeight + 2;

        // Estado del Spread
        color spreadClr = isSpreadSafe ? C'0,255,140' : C'255,60,80';
        string spreadStateStr = isSpreadSafe ? "SEGURO & OPTIMO" : "EXPANDIDO (PAUSA)";
        string spreadStr = StringFormat("Escudo Spread: %s (Actual: %.0f | EMA: %.1f)", spreadStateStr, currentSpread, emaSpread);
        CreateOrUpdateLabel("SpreadShield", spreadStr, x + 10, y, 8, true, spreadClr, corner);
        y += lineHeight;

        string bsStatusStr = "Modelo Black-Scholes MK13: [ACTIVO & OPERATIVO]";
        CreateOrUpdateLabel("BSStatus", bsStatusStr, x + 10, y, 8, true, C'0,240,255', corner);
        y += lineHeight + 4;

        CreateOrUpdateLabel("Div2", "------------------------------------------------------------------------------------------------------------", x, y, 8, false, C'0,200,255', corner);
        y += lineHeight + 2;

        // --- SECCIÓN 3: [ CALENDARIO ECONÓMICO Y NOTICIAS ] ---
        CreateOrUpdateLabel("Sec3_Header", "[ 📰 ESCUDO DE NOTICIAS DE ALTO IMPACTO (USD) ]", x, y, 9, true, C'255,0,255', corner);
        y += lineHeight + 2;

        string newsSum = CVoidNewsWatcher::GetTodayNewsSummary();
        CreateOrUpdateLabel("NewsSummary", "Hoy: " + newsSum, x + 10, y, 8, false, C'255,200,0', corner);
    }

    //------------------------------------------------------------------
    // Destruye todos los objetos gráficos creados por el Dashboard
    //------------------------------------------------------------------
    static void Destroy()
    {
        ObjectsDeleteAll(0, HUD_PREFIX);
        ChartRedraw(0);
    }
};

#endif
