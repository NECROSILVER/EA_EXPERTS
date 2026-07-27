//+------------------------------------------------------------------+
//|                                                NewsWatcher.mqh   |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Módulo SENTINEL_MK1: Escudo de Noticias Cuantitativo de Alto     |
//| Impacto (USD) con Alerta Push Temprana a 12 Horas y             |
//| Congelamiento Preventivo de Entrada para ORO (XAUUSD).           |
//+------------------------------------------------------------------+
#ifndef NEWS_WATCHER_MQH
#define NEWS_WATCHER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

#include <EMPTY_VOID/Core/Config.mqh>
#include <EMPTY_VOID/Core/VoidState.mqh>

class CVoidNewsWatcher
{
public:
    //------------------------------------------------------------------
    // Filtro estricto de noticias macro relevantes para el ORO (XAUUSD)
    //------------------------------------------------------------------
    static bool IsGoldRelevantNews(string newsName, ENUM_CALENDAR_EVENT_IMPORTANCE importance)
    {
        string upperName = newsName;
        StringToUpper(upperName);

        if(importance < CALENDAR_IMPORTANCE_MODERATE) return false;

        if(StringFind(upperName, "CPI") >= 0 || StringFind(upperName, "IPC") >= 0) return true;
        if(StringFind(upperName, "NFP") >= 0 || StringFind(upperName, "NON-FARM") >= 0) return true;
        if(StringFind(upperName, "PAYROLL") >= 0 || StringFind(upperName, "NOMINAS") >= 0) return true;
        if(StringFind(upperName, "FOMC") >= 0 || StringFind(upperName, "FED") >= 0) return true;
        if(StringFind(upperName, "INTEREST RATE") >= 0 || StringFind(upperName, "TASA") >= 0) return true;
        if(StringFind(upperName, "GDP") >= 0 || StringFind(upperName, "PIB") >= 0) return true;
        if(StringFind(upperName, "RETAIL SALES") >= 0 || StringFind(upperName, "VENTAS MINORISTAS") >= 0) return true;
        if(StringFind(upperName, "PPI") >= 0 || StringFind(upperName, "IPP") >= 0) return true;
        if(StringFind(upperName, "POWELL") >= 0) return true;
        if(StringFind(upperName, "UNEMPLOYMENT") >= 0 || StringFind(upperName, "DESEMPLEO") >= 0) return true;

        if(importance == CALENDAR_IMPORTANCE_HIGH)
        {
            if(StringFind(upperName, "ISM") >= 0 || StringFind(upperName, "PMI") >= 0) return true;
        }

        return false;
    }

    //------------------------------------------------------------------
    // 1. Evalúa si el bloqueo defensivo por noticia (LOCKOUT) está activo
    //------------------------------------------------------------------
    static bool IsNewsLockoutActive(int preMins = 30, int postMins = 30)
    {
        datetime now = TimeCurrent();
        datetime fromTime = now - (postMins * 60);
        datetime toTime   = now + (preMins * 60);

        MqlCalendarValue values[];
        ArrayFree(values);

        if(CalendarValueHistory(values, fromTime, toTime, NULL, NULL))
        {
            int total = ArraySize(values);
            for(int i = 0; i < total; i++)
            {
                if(values[i].event_id <= 0 || values[i].time <= 0) continue;

                MqlCalendarEvent event;
                if(CalendarEventById(values[i].event_id, event))
                {
                    if(IsGoldRelevantNews(event.name, (ENUM_CALENDAR_EVENT_IMPORTANCE)event.importance))
                    {
                        MqlCalendarCountry country;
                        if(CalendarCountryById(event.country_id, country))
                        {
                            if(country.code == "US" || country.currency == "USD")
                            {
                                datetime eventTime = values[i].time;
                                datetime lockStart = eventTime - (preMins * 60);
                                datetime lockEnd   = eventTime + (postMins * 60);

                                if(now >= lockStart && now <= lockEnd)
                                {
                                    return true; // Bloqueo activo
                                }
                            }
                        }
                    }
                }
            }
        }
        return false;
    }

    //------------------------------------------------------------------
    // 2. Escaneo y envío de Alerta Push Temprana (12 Horas) estilo Terminal Quant
    //------------------------------------------------------------------
    static void ProcessAdvanceNewsPush(int advanceHours = 12, bool enablePush = true, int preMins = 30, int postMins = 30)
    {
        datetime now = TimeCurrent();
        datetime endWindow = now + (advanceHours * 3600);

        MqlCalendarValue values[];
        ArrayFree(values);

        if(CalendarValueHistory(values, now, endWindow, NULL, NULL))
        {
            int total = ArraySize(values);
            for(int i = 0; i < total; i++)
            {
                if(values[i].time <= now || values[i].event_id <= 0) continue;

                MqlCalendarEvent event;
                if(CalendarEventById(values[i].event_id, event))
                {
                    if(IsGoldRelevantNews(event.name, (ENUM_CALENDAR_EVENT_IMPORTANCE)event.importance))
                    {
                        MqlCalendarCountry country;
                        if(CalendarCountryById(event.country_id, country))
                        {
                            if(country.code == "US" || country.currency == "USD")
                            {
                                string stateKey = StringFormat("NewsNotified_%I64u", values[i].event_id);

                                if(!CVoidState::HasState(stateKey))
                                {
                                    string eventTimeStr = TimeToString(values[i].time, TIME_MINUTES);
                                    double hoursLeft = (double)(values[i].time - now) / 3600.0;

                                    if(enablePush)
                                    {
                                        double bal = AccountInfoDouble(ACCOUNT_BALANCE);
                                        double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
                                        string pushMsg = StringFormat(
                                            "📰 🚨 [SENTINEL_MK1] ALERTA MACRO (XAUUSD)\n──────────────────────────────────\n📢 EVENTO   : %s\n🔥 IMPACTO  : 🔴 ALTO [Catalizador Oro]\n⏰ HORARIO  : %s UTC (en %.1fh)\n🛡️ PROTOCOLO: LOCKOUT [-%dm / +%dm]\n💼 BALANCE  : $%.2f USD | EQ: $%.2f",
                                            event.name, eventTimeStr, hoursLeft, preMins, postMins, bal, eq
                                        );

                                        ResetLastError();
                                        if(!SendNotification(pushMsg))
                                        {
                                            PrintFormat("❌ [%s PUSH ERROR]: Falló envío Alerta Noticias 12h. Err: %d", BOT_NAME, GetLastError());
                                        }
                                        else
                                        {
                                            PrintFormat("📱 [%s SENTINEL_MK1]: Alerta Push 12h enviada con éxito para evento '%s' a las %s.",
                                                        BOT_NAME, event.name, eventTimeStr);
                                        }
                                    }

                                    // Registrar persistencia para enviar UNA SOLA VEZ por evento
                                    CVoidState::SetState(stateKey, 1.0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    //------------------------------------------------------------------
    // 3. Obtiene la próxima noticia de ALTO impacto USD relevante para la telemetría
    //------------------------------------------------------------------
    static bool GetNextHighImpactNews(int advanceHours, string &outName, double &outHoursLeft)
    {
        outName = "Sin eventos < 12h";
        outHoursLeft = 99.0;

        datetime now = TimeCurrent();
        datetime endWindow = now + (advanceHours * 3600);

        MqlCalendarValue values[];
        ArrayFree(values);

        datetime nearestTime = 0;
        string nearestName = "";

        if(CalendarValueHistory(values, now, endWindow, NULL, NULL))
        {
            int total = ArraySize(values);
            for(int i = 0; i < total; i++)
            {
                if(values[i].time <= now || values[i].event_id <= 0) continue;

                MqlCalendarEvent event;
                if(CalendarEventById(values[i].event_id, event))
                {
                    if(IsGoldRelevantNews(event.name, (ENUM_CALENDAR_EVENT_IMPORTANCE)event.importance))
                    {
                        MqlCalendarCountry country;
                        if(CalendarCountryById(event.country_id, country))
                        {
                            if(country.code == "US" || country.currency == "USD")
                            {
                                if(nearestTime == 0 || values[i].time < nearestTime)
                                {
                                    nearestTime = values[i].time;
                                    nearestName = event.name;
                                }
                            }
                        }
                    }
                }
            }
        }

        if(nearestTime > 0)
        {
            outName = nearestName;
            outHoursLeft = (double)(nearestTime - now) / 3600.0;
            return true;
        }

        return false;
    }

    //------------------------------------------------------------------
    // Retorna el resumen de noticias para StartupReport
    //------------------------------------------------------------------
    static string GetTodayNewsSummary(int hoursAhead = 6)
    {
        string name = "";
        double hoursLeft = 0.0;
        if(GetNextHighImpactNews(hoursAhead, name, hoursLeft))
        {
            return StringFormat("%s en %.1fh", name, hoursLeft);
        }
        return StringFormat("Sin eventos (Alto) en las próximas %dh.", hoursAhead);
    }
};

#endif
