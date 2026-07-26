//+------------------------------------------------------------------+
//|                                              Engine_Tempest.mqh  |
//|                                  Copyright 2026, Proyecto Bot X5 |
//+------------------------------------------------------------------+
#ifndef ENGINE_TEMPEST_MQH
#define ENGINE_TEMPEST_MQH

#include <EMPTY_VOID/Engines/IEngine.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>

enum ENUM_GAP_STATE {
    GAP_FVG_BULLISH, GAP_FVG_BEARISH, 
    GAP_IFVG_BULLISH, GAP_IFVG_BEARISH, 
    GAP_INVALIDATED, GAP_EXPIRED
};

enum ENUM_SETUP_TIER {
    TIER_1_OPTIMAL = 1, TIER_2_MEDIUM = 2, TIER_3_SPECULATIVE = 3, TIER_NONE = 0
};

struct SGapStructure {
    ulong             id; 
    ENUM_TIMEFRAMES   timeframe; 
    ENUM_GAP_STATE    state;
    datetime          time_formation; 
    double            price_upper; 
    double            price_lower;
    int               bars_lifetime; 
    bool              is_active;
};

class CEngine_Tempest : public IEngine {
private:
    SGapStructure     m_gaps[];
    ENUM_TIMEFRAMES   m_tracked_tfs[5];
    ulong             m_gap_counter;
    int               m_ema200_handle;
    datetime          m_last_bar_time[5];

    double            m_risk_tier1, m_risk_tier2, m_risk_tier3;

    bool              IsNewBar(ENUM_TIMEFRAMES tf, int index);
    void              DetectNewFVGs(ENUM_TIMEFRAMES tf);
    void              ScanHistoricalGaps();
    void              UpdateGapStates(ENUM_TIMEFRAMES tf);
    int               GetMacroTrend(ENUM_TIMEFRAMES macro_tf);
    void              CleanMemory();
    ENUM_SETUP_TIER   EvaluateTier(SGapStructure &gap, int current_macro_trend);
    double            CalculateLotSize(double sl_dist, ENUM_SETUP_TIER tier);
    bool              CheckOpenPositions();

public:
                      CEngine_Tempest();
                     ~CEngine_Tempest();

    virtual bool      Init(int engineId, string name) override;
    virtual EngineSignal Evaluate() override;
    virtual void      OnDeinit() override;
};

CEngine_Tempest::CEngine_Tempest() {
    m_gap_counter = 0;
    m_ema200_handle = INVALID_HANDLE;
    
    m_tracked_tfs[0] = PERIOD_M5; 
    m_tracked_tfs[1] = PERIOD_M15;
    m_tracked_tfs[2] = PERIOD_M30; 
    m_tracked_tfs[3] = PERIOD_H1; 
    m_tracked_tfs[4] = PERIOD_H4;
    
    m_risk_tier1 = 0.0100;
    m_risk_tier2 = 0.0050;
    m_risk_tier3 = 0.0025;
    
    for(int i = 0; i < 5; i++) m_last_bar_time[i] = 0;
}

CEngine_Tempest::~CEngine_Tempest() {
    ArrayFree(m_gaps);
    if(m_ema200_handle != INVALID_HANDLE) IndicatorRelease(m_ema200_handle);
}

bool CEngine_Tempest::Init(int engineId, string name) {
    this.m_engineId = engineId;     
    this.m_engineName = name;
    
    m_ema200_handle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema200_handle == INVALID_HANDLE) {
        Print("TEMPEST MK5: Error cargando EMA 200");
        return false;
    }

    // Ejecutar escaneo histórico de arranque
    ScanHistoricalGaps();

    Print("Motor TEMPEST MK5 Iniciado. ID: ", m_engineId);
    return true;
}

void CEngine_Tempest::OnDeinit() {
    Print("Motor TEMPEST MK5 Detenido.");
}

bool CEngine_Tempest::IsNewBar(ENUM_TIMEFRAMES tf, int index) {
    datetime current_time = iTime(_Symbol, tf, 0);
    if(current_time != m_last_bar_time[index]) {
        m_last_bar_time[index] = current_time;
        return true;
    }
    return false;
}

int CEngine_Tempest::GetMacroTrend(ENUM_TIMEFRAMES macro_tf) {
    double ema_values[];
    ArrayResize(ema_values, 2);
    ArraySetAsSeries(ema_values, true);
    if(CopyBuffer(m_ema200_handle, 0, 1, 2, ema_values) < 2) return 0; 
    
    double last_close = iClose(_Symbol, macro_tf, 1);
    bool is_price_above = (last_close > ema_values[0]);
    bool is_price_below = (last_close < ema_values[0]);
    bool is_slope_up = (ema_values[0] > ema_values[1]); 
    bool is_slope_down = (ema_values[0] < ema_values[1]);
    
    if(is_price_above && is_slope_up) return 1;
    if(is_price_below && is_slope_down) return -1;
    return 0;
}

void CEngine_Tempest::ScanHistoricalGaps()
{
    for(int t = 0; t < 5; t++)
    {
        ENUM_TIMEFRAMES tf = m_tracked_tfs[t];
        int lookback = 50; // Escanear las últimas 50 velas al iniciar
        
        for(int bar = lookback; bar >= 1; bar--)
        {
            double candleA_high = iHigh(_Symbol, tf, bar + 2);
            double candleA_low  = iLow(_Symbol, tf, bar + 2);
            double candleC_high = iHigh(_Symbol, tf, bar);
            double candleC_low  = iLow(_Symbol, tf, bar);

            bool isBullishFVG = (candleA_high < candleC_low);
            bool isBearishFVG = (candleA_low > candleC_high);

            if(isBullishFVG || isBearishFVG)
            {
                int size = ArraySize(m_gaps);
                int newIdx = size;
                if(ArrayResize(m_gaps, size + 1) > 0)
                {
                    m_gaps[newIdx].id = ++m_gap_counter;
                    m_gaps[newIdx].timeframe = tf;
                    m_gaps[newIdx].time_formation = iTime(_Symbol, tf, bar + 1);
                    m_gaps[newIdx].is_active = true;
                    m_gaps[newIdx].bars_lifetime = lookback - bar;

                    if(isBullishFVG)
                    {
                        m_gaps[newIdx].state = GAP_FVG_BULLISH;
                        m_gaps[newIdx].price_upper = candleC_low;
                        m_gaps[newIdx].price_lower = candleA_high;
                    }
                    else
                    {
                        m_gaps[newIdx].state = GAP_FVG_BEARISH;
                        m_gaps[newIdx].price_upper = candleA_low;
                        m_gaps[newIdx].price_lower = candleC_high;
                    }

                    // Verificar si en velas posteriores este FVG se invirtió a iFVG
                    double last_close = iClose(_Symbol, tf, bar);
                    if(m_gaps[newIdx].state == GAP_FVG_BEARISH && last_close > m_gaps[newIdx].price_upper)
                    {
                        m_gaps[newIdx].state = GAP_IFVG_BULLISH;
                    }
                    else if(m_gaps[newIdx].state == GAP_FVG_BULLISH && last_close < m_gaps[newIdx].price_lower)
                    {
                        m_gaps[newIdx].state = GAP_IFVG_BEARISH;
                    }
                }
            }
        }
    }
    PrintFormat("TEMPEST MK5 [WARM-UP]: Escaneo histórico completado. %d estructuras cargadas en memoria.", ArraySize(m_gaps));
}

void CEngine_Tempest::DetectNewFVGs(ENUM_TIMEFRAMES tf) {
    double candleA_high = iHigh(_Symbol, tf, 3);
    double candleA_low  = iLow(_Symbol, tf, 3);
    double candleC_high = iHigh(_Symbol, tf, 1);
    double candleC_low  = iLow(_Symbol, tf, 1);
    
    bool isBullishFVG = (candleA_high < candleC_low);
    bool isBearishFVG = (candleA_low > candleC_high);
    
    if(isBullishFVG || isBearishFVG) {
        int size = ArraySize(m_gaps);
        int newIdx = size; // Índice correcto del elemento recién añadido
        
        if(ArrayResize(m_gaps, size + 1) > 0) {
            m_gaps[newIdx].id = ++m_gap_counter;
            m_gaps[newIdx].timeframe = tf;
            m_gaps[newIdx].time_formation = iTime(_Symbol, tf, 2);
            m_gaps[newIdx].is_active = true;
            m_gaps[newIdx].bars_lifetime = 0;
            
            if(isBullishFVG) {
                m_gaps[newIdx].state = GAP_FVG_BULLISH;
                m_gaps[newIdx].price_upper = candleC_low;
                m_gaps[newIdx].price_lower = candleA_high;
            } else {
                m_gaps[newIdx].state = GAP_FVG_BEARISH;
                m_gaps[newIdx].price_upper = candleA_low;
                m_gaps[newIdx].price_lower = candleC_high;
            }
        }
    }
}

void CEngine_Tempest::UpdateGapStates(ENUM_TIMEFRAMES tf)
{
    int totalGaps = ArraySize(m_gaps);
    if(totalGaps == 0) return;

    double last_close = iClose(_Symbol, tf, 1);
    for(int i = 0; i < totalGaps; i++) 
    {
        if(i >= ArraySize(m_gaps)) break; // Resguardo contra desbordamiento
        if(!m_gaps[i].is_active || m_gaps[i].timeframe != tf) continue;
        
        m_gaps[i].bars_lifetime++;
        if(m_gaps[i].bars_lifetime > 20) { 
            m_gaps[i].is_active = false; 
            continue; 
        }
        
        if(m_gaps[i].state == GAP_FVG_BEARISH && last_close > m_gaps[i].price_upper) {
            m_gaps[i].state = GAP_IFVG_BULLISH;
        }
        else if(m_gaps[i].state == GAP_FVG_BULLISH && last_close < m_gaps[i].price_lower) {
            m_gaps[i].state = GAP_IFVG_BEARISH;
        }
    }
}

ENUM_SETUP_TIER CEngine_Tempest::EvaluateTier(SGapStructure &gap, int current_macro_trend) {
    if((gap.timeframe == PERIOD_M5 || gap.timeframe == PERIOD_M15) && 
       ((gap.state == GAP_IFVG_BULLISH && current_macro_trend == 1) || (gap.state == GAP_IFVG_BEARISH && current_macro_trend == -1))) {
        return TIER_1_OPTIMAL;
    }
    if((gap.timeframe == PERIOD_M15 || gap.timeframe == PERIOD_M30) && current_macro_trend == 0) return TIER_2_MEDIUM;
    if(gap.timeframe == PERIOD_M5 && 
       ((gap.state == GAP_IFVG_BULLISH && current_macro_trend == -1) || (gap.state == GAP_IFVG_BEARISH && current_macro_trend == 1))) {
        return TIER_3_SPECULATIVE;
    }
    return TIER_NONE;
}

double CEngine_Tempest::CalculateLotSize(double sl_dist, ENUM_SETUP_TIER tier) {
    if(sl_dist <= 0 || tier == TIER_NONE) return 0.0;
    
    double risk_pct = (tier == TIER_1_OPTIMAL) ? m_risk_tier1 : ((tier == TIER_2_MEDIUM) ? m_risk_tier2 : m_risk_tier3);
    double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * risk_pct;
    
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tick_value == 0 || tick_size == 0) return 0.01;
    double raw_lot = risk_money / ((sl_dist / tick_size) * tick_value);
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double normalized_lot = MathRound(raw_lot / step_lot) * step_lot;
    if(normalized_lot < min_lot) normalized_lot = min_lot;
    if(normalized_lot > max_lot) normalized_lot = max_lot;
    
    return normalized_lot;
}

void CEngine_Tempest::CleanMemory()
{
    int total = ArraySize(m_gaps);
    if(total == 0) return;

    SGapStructure tempGaps[];
    int activeCount = 0;

    for(int i = 0; i < total; i++)
    {
        if(m_gaps[i].is_active)
        {
            ArrayResize(tempGaps, activeCount + 1);
            tempGaps[activeCount] = m_gaps[i];
            activeCount++;
        }
    }

    // Redimensionar m_gaps al tamaño activo real antes de copiar
    ArrayResize(m_gaps, activeCount);
    if(activeCount > 0)
    {
        ArrayCopy(m_gaps, tempGaps);
    }
    ArrayFree(tempGaps);
}

bool CEngine_Tempest::CheckOpenPositions() {
    ulong magic = CMagicNumberManager::GetMagicNumber(m_engineId);
    for(int p = PositionsTotal() - 1; p >= 0; p--) {
        ulong ticket = PositionGetTicket(p); 
        if(ticket == 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            return true;
        }
    }
    return false;
}

EngineSignal CEngine_Tempest::Evaluate() {
    EngineSignal signal;

    for(int i = 0; i < 5; i++) {
        if(IsNewBar(m_tracked_tfs[i], i)) {
            DetectNewFVGs(m_tracked_tfs[i]);
            UpdateGapStates(m_tracked_tfs[i]);
        }
    }
    
    CleanMemory();
    if(CheckOpenPositions()) return signal;

    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_stop_dist = stops_level * tick_size;
    
    int cached_macro_trend = GetMacroTrend(PERIOD_H1);
    
    double highestProximity = 0.0;
    string activeBias = "NONE";

    for(int i = 0; i < ArraySize(m_gaps); i++) 
    {
        if(!m_gaps[i].is_active) continue;
        
        // Calcular la distancia del precio a los límites de la zona
        if(m_gaps[i].state == GAP_IFVG_BULLISH || m_gaps[i].state == GAP_FVG_BULLISH) 
        {
            double dist = MathAbs(current_ask - m_gaps[i].price_upper);
            double maxDist = 10.0; // Rango de tolerancia de 10 pips en Oro
            double prox = MathMax(0.0, MathMin(99.0, (1.0 - (dist / maxDist)) * 100.0));
            if(prox > highestProximity) {
                highestProximity = prox;
                activeBias = "BUY";
            }
        }
        else if(m_gaps[i].state == GAP_IFVG_BEARISH || m_gaps[i].state == GAP_FVG_BEARISH) 
        {
            double dist = MathAbs(current_bid - m_gaps[i].price_lower);
            double maxDist = 10.0; // Rango de tolerancia de 10 pips en Oro
            double prox = MathMax(0.0, MathMin(99.0, (1.0 - (dist / maxDist)) * 100.0));
            if(prox > highestProximity) {
                highestProximity = prox;
                activeBias = "SELL";
            }
        }
        
        // Disparo de entrada estricto únicamente para iFVG calificados por Tier
        ENUM_SETUP_TIER tier = EvaluateTier(m_gaps[i], cached_macro_trend);
        if(tier == TIER_NONE) continue;

        if(m_gaps[i].state == GAP_IFVG_BULLISH && current_ask <= m_gaps[i].price_upper && current_ask >= m_gaps[i].price_lower)
        {
            signal.hasSignal    = true;
            signal.orderType    = ORDER_TYPE_BUY;
            signal.tierLevel    = (int)tier;
            signal.entryPrice   = current_ask;
            signal.proximityPct = 100.0;
            signal.direction    = "BUY";
            
            signal.stopLoss = m_gaps[i].price_lower - (tick_size * Inp_Tempest_SL_Buffer);
            double sl_dist = MathAbs(current_ask - signal.stopLoss);
            if(sl_dist < min_stop_dist) { sl_dist = min_stop_dist; signal.stopLoss = current_ask - sl_dist; }
            
            double tp_dist = sl_dist * Inp_Tempest_RR;
            if(tp_dist < min_stop_dist) tp_dist = min_stop_dist;
            signal.takeProfit = current_ask + tp_dist;
            
            signal.baseLot = CalculateLotSize(sl_dist, tier);
            m_gaps[i].is_active = false;
            return signal;
        }
        else if(m_gaps[i].state == GAP_IFVG_BEARISH && current_bid >= m_gaps[i].price_lower && current_bid <= m_gaps[i].price_upper)
        {
            signal.hasSignal    = true;
            signal.orderType    = ORDER_TYPE_SELL;
            signal.tierLevel    = (int)tier;
            signal.entryPrice   = current_bid;
            signal.proximityPct = 100.0;
            signal.direction    = "SELL";
            
            signal.stopLoss = m_gaps[i].price_upper + (tick_size * Inp_Tempest_SL_Buffer);
            double sl_dist = MathAbs(signal.stopLoss - current_bid);
            if(sl_dist < min_stop_dist) { sl_dist = min_stop_dist; signal.stopLoss = current_bid + sl_dist; }
            
            double tp_dist = sl_dist * Inp_Tempest_RR;
            if(tp_dist < min_stop_dist) tp_dist = min_stop_dist;
            signal.takeProfit = current_bid - tp_dist;
            
            signal.baseLot = CalculateLotSize(sl_dist, tier);
            m_gaps[i].is_active = false;
            return signal;
        }
    }

    signal.proximityPct = NormalizeDouble(highestProximity, 0);
    signal.direction    = activeBias;
    return signal;
}

#endif
