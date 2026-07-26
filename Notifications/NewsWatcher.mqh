//+------------------------------------------------------------------+
//|                                                NewsWatcher.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Escáner del Calendario Económico Nativo MT5 para Detectar       |
//| Eventos Próximos de Alto Impacto para el ORO (USD).              |
//+------------------------------------------------------------------+
#ifndef NEWS_WATCHER_MQH
#define NEWS_WATCHER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

class CVoidNewsWatcher
{
public:
    //------------------------------------------------------------------
    // Retorna la próxima noticia más cercana de alto impacto (USD)
    // dentro de una ventana de tiempo (por defecto 4 horas)
    //------------------------------------------------------------------
    static string GetTodayNewsSummary(int hoursAhead = 4)
    {
        datetime now = TimeCurrent();
        datetime endWindow = now + (hoursAhead * 3600);

        MqlCalendarValue values[];
        ArrayFree(values);
        string nearestNewsStr = "";
        datetime nearestTime = 0;

        if(CalendarValueHistory(values, now, endWindow, NULL, NULL))
        {
            int total = ArraySize(values);
            for(int i = 0; i < total; i++)
            {
                if(values[i].time < now || values[i].event_id <= 0) continue;

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
                                if(nearestTime == 0 || values[i].time < nearestTime)
                                {
                                    nearestTime = values[i].time;
                                    string timeStr = TimeToString(values[i].time, TIME_MINUTES);
                                    nearestNewsStr = StringFormat("%s [%s] %s", timeStr, country.currency, event.name);
                                }
                            }
                        }
                    }
                }
            }
        }

        if(nearestNewsStr == "")
        {
            return StringFormat("Sin noticias de alto impacto en las próximas %dh.", hoursAhead);
        }

        return nearestNewsStr;
    }
};

#endif
