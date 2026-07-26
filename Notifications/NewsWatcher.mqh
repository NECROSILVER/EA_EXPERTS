//+------------------------------------------------------------------+
//|                                                NewsWatcher.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Escáner del Calendario Económico Nativo MT5 para Detectar       |
//| Eventos Próximos de Impacto ALTO y MEDIO para el ORO (USD).      |
//+------------------------------------------------------------------+
#ifndef NEWS_WATCHER_MQH
#define NEWS_WATCHER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

class CVoidNewsWatcher
{
public:
    //------------------------------------------------------------------
    // Retorna la próxima noticia más cercana de impacto ALTO o MEDIO (USD)
    // dentro de una ventana de tiempo (por defecto 6 horas)
    //------------------------------------------------------------------
    static string GetTodayNewsSummary(int hoursAhead = 6)
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

                    // Filtrar por eventos de ALTO (Red) o MEDIO (Orange) impacto
                    if(event.importance == CALENDAR_IMPORTANCE_HIGH || event.importance == CALENDAR_IMPORTANCE_MODERATE)
                    {
                        MqlCalendarCountry country;
                        if(CalendarCountryById(event.country_id, country))
                        {
                            if(country.code == "US" || country.currency == "USD")
                            {
                                if(nearestTime == 0 || values[i].time < nearestTime)
                                {
                                    nearestTime = values[i].time;
                                    string timeStr = TimeToString(values[i].time, TIME_MINUTES);
                                    string impactTag = (event.importance == CALENDAR_IMPORTANCE_HIGH) ? "ALTO" : "MEDIO";
                                    nearestNewsStr = StringFormat("%s [USD] [%s] %s", timeStr, impactTag, event.name);
                                }
                            }
                        }
                    }
                }
            }
        }

        if(nearestNewsStr == "")
        {
            return StringFormat("Sin eventos (Medio/Alto) en las próximas %dh.", hoursAhead);
        }

        return nearestNewsStr;
    }
};

#endif
