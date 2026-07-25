//+------------------------------------------------------------------+
//|                                                NewsWatcher.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Escáner del Calendario Económico Nativo MT5 para Detectar       |
//| Eventos de Alto Impacto para el ORO (USD).                       |
//+------------------------------------------------------------------+
#ifndef NEWS_WATCHER_MQH
#define NEWS_WATCHER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

class CVoidNewsWatcher
{
public:
    //------------------------------------------------------------------
    // Retorna un resumen formateado de las noticias de alto impacto (USD) de hoy
    //------------------------------------------------------------------
    static string GetTodayNewsSummary(void)
    {
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);

        datetime startOfDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));
        datetime endOfDay   = startOfDay + 86399;

        MqlCalendarValue values[];
        ArrayFree(values);

        string summary = "";
        int newsCount = 0;

        if(CalendarValueHistory(values, startOfDay, endOfDay, NULL, NULL))
        {
            int total = ArraySize(values);
            for(int i = 0; i < total; i++)
            {
                if(values[i].time <= 0 || values[i].event_id <= 0) continue;

                MqlCalendarEvent event;
                if(CalendarEventById(values[i].event_id, event))
                {
                    if(event.name == "" || event.country_id <= 0) continue;

                    // Filtrar solo eventos de ALTO IMPACTO (Carpeta Roja)
                    if(event.importance == CALENDAR_IMPORTANCE_HIGH)
                    {
                        MqlCalendarCountry country;
                        if(CalendarCountryById(event.country_id, country))
                        {
                            // Filtrar por país "US" o moneda "USD"
                            if(country.code == "US" || country.currency == "USD")
                            {
                                string timeStr = TimeToString(values[i].time, TIME_MINUTES);
                                if(newsCount > 0) summary += " | ";
                                summary += StringFormat("%s [%s] %s", timeStr, country.currency, event.name);
                                newsCount++;
                            }
                        }
                    }
                }
            }
        }

        if(newsCount == 0 || summary == "")
        {
            return "Sin noticias de alto impacto programadas para hoy.";
        }

        return summary;
    }
};

#endif
