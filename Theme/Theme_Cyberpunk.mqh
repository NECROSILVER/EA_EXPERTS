//+------------------------------------------------------------------+
//|                                          Theme_Cyberpunk.mqh     |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Gestor de Tema Estético Cyberpunk Neón para el gráfico de MT5.   |
//+------------------------------------------------------------------+
#ifndef THEME_CYBERPUNK_MQH
#define THEME_CYBERPUNK_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

class CVoidThemeManager
{
public:
    // Aplica la paleta visual Cyberpunk Neón de alto contraste en el gráfico de MT5
    static void ApplyCyberpunkTheme(long chartId)
    {
        // 1. Configurar Modo de Gráfico (Velas Japonesas)
        ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);

        // 1. Color de fondo y texto
        ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, C'0,0,0');       // Negro Puro
        ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, C'0,240,255');   // Cian Neón Texto

        // 2. Bordes y mechas (Outlines)
        ChartSetInteger(chartId, CHART_COLOR_CHART_UP, C'0,229,255');     // Borde Velas Alcistas (Cian)
        ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, C'180,0,180');   // Borde Velas Bajistas (Magenta)

        // 3. Cuerpos "Huecos" (Mismo color que el fondo)
        ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, C'0,0,0');  
        ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, C'0,0,0'); 

        // 4. Barras de Volumen e Indicadores
        ChartSetInteger(chartId, CHART_COLOR_VOLUME, C'0,255,102');       // Verde Neón
        ChartSetInteger(chartId, CHART_COLOR_CHART_LINE, C'0,240,255');   // Línea de Precio

        // 5. Líneas Bid y Ask
        ChartSetInteger(chartId, CHART_COLOR_BID, C'0,240,255');          // Línea Bid (Cian)
        ChartSetInteger(chartId, CHART_COLOR_ASK, C'255,0,200');          // Línea Ask (Magenta Neón)

        // 6. Configuración de Cuadrícula y Elementos Visuales
        ChartSetInteger(chartId, CHART_SHOW_GRID, false);                // Cuadrícula Desactivada
        ChartSetInteger(chartId, CHART_SHOW_PERIOD_SEP, true);           // Separadores de Período
        ChartSetInteger(chartId, CHART_SHOW_VOLUMES, CHART_VOLUME_TICK); // Mostrar Volúmenes Tick

        ChartRedraw(chartId);
    }
};

#endif
