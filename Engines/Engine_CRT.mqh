//+------------------------------------------------------------------+
//|                                                   Engine_CRT.mqh |
//|                                  Copyright 2026, Proyecto Bot X5 |
//|                                https://github.com/NECROSILVER/EA |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Motor M106 - CRT_SNIPER_MK1 (Candle Range Theory) v7.0           |
//| Caza de manipulación y barrido de liquidez en mechas HTF (H1)     |
//| con seguimiento de extremo real, calibración USD para XAUUSD,    |
//| confirmación estricta de vela M5 cerrada, piso mínimo de SL      |
//| de $1.50 USD y regla de Doble Distancia SL/TP + Medio Lotaje.   |
//+------------------------------------------------------------------+
#ifndef ENGINE_CRT_MQH
#define ENGINE_CRT_MQH

#include <EMPTY_VOID/Engines/IEngine.mqh>
#include <EMPTY_VOID/Core/MagicNumberManager.mqh>

enum ENUM_CRT_STATE {
    CRT_STATE_IDLE,
    CRT_STATE_SWEEP_BUY_PENDING,
    CRT_STATE_SWEEP_SELL_PENDING
};

class CEngine_CRT : public IEngine {
private:
    ENUM_TIMEFRAMES   m_htfTimeframe;
    ENUM_TIMEFRAMES   m_ltfTimeframe;

    double            m_htfHigh;
    double            m_htfLow;
    double            m_htfOpen;
    double            m_htfClose;

    ENUM_CRT_STATE    m_currentState;
    datetime          m_lastHtfBarTime;
    datetime          m_lastLtfBarTime;
    datetime          m_lastTradedHtfTime;

    double            m_sweepExtremePrice; 
    int               m_pendingBarsCount;
    int               m_ema200_handle;

    double            m_crt_rr;
    int               m_crt_sl_buffer;
    double            m_min_sweep_usd;
    double            m_max_sweep_usd;
    double            m_min_sl_dist_usd; // Piso mínimo de SL en USD ($1.50)

    double            m_risk_tier1;
    double            m_risk_tier2;
    double            m_risk_tier3;

    bool              UpdateHTFRange();
    int               GetMacroTrend();
    int               EvaluateCRT_Tier(ENUM_ORDER_TYPE orderType, double sweepDepthUSD);
    double            CalculateLotSize(double sl_dist, int tier);
    bool              CheckOpenPositions();

public:
                      CEngine_CRT();
                     ~CEngine_CRT();

    virtual bool      Init(int engineId, string name) override;
    virtual EngineSignal Evaluate() override;
    virtual void      OnDeinit() override;

    void              SetParameters(double rr, int slBuffer, double minSweepUSD, double maxSweepUSD) {
        m_crt_rr          = rr;
        m_crt_sl_buffer   = slBuffer;
        m_min_sweep_usd   = minSweepUSD;
        m_max_sweep_usd   = maxSweepUSD;
    }
};

CEngine_CRT::CEngine_CRT() {
    m_htfTimeframe      = PERIOD_H1;
    m_ltfTimeframe      = PERIOD_M5;
    m_currentState      = CRT_STATE_IDLE;
    m_lastHtfBarTime    = 0;
    m_lastLtfBarTime    = 0;
    m_lastTradedHtfTime = 0;

    m_sweepExtremePrice = 0.0;
    m_pendingBarsCount  = 0;
    m_ema200_handle     = INVALID_HANDLE;

    m_crt_rr            = 2.5;
    m_crt_sl_buffer     = 20;
    m_min_sweep_usd     = 1.50;
    m_max_sweep_usd     = 15.00;
    m_min_sl_dist_usd   = 1.50; // Mínimo $1.50 USD de Stop Loss para XAUUSD

    m_risk_tier1        = 0.0100; // 1.00%
    m_risk_tier2        = 0.0050; // 0.50%
    m_risk_tier3        = 0.0025; // 0.25%
}

CEngine_CRT::~CEngine_CRT() {
    if(m_ema200_handle != INVALID_HANDLE) IndicatorRelease(m_ema200_handle);
}

bool CEngine_CRT::Init(int engineId, string name) {
    this.m_engineId   = engineId;
    this.m_engineName = (name != "" && name != NULL) ? name : "CORTEX_MK6";

    m_ema200_handle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema200_handle == INVALID_HANDLE) {
        Print("CRT SNIPER M106: Error cargando EMA 200 en H1");
        return false;
    }

    UpdateHTFRange();
    PrintFormat("Motor CRT_SNIPER_MK1 (M106) v7.0 Iniciado. ID: %d", m_engineId);
    return true;
}

void CEngine_CRT::OnDeinit() {
    if(m_ema200_handle != INVALID_HANDLE) {
        IndicatorRelease(m_ema200_handle);
        m_ema200_handle = INVALID_HANDLE;
    }
    PrintFormat("Motor CRT_SNIPER_MK1 (ID: %d) Detenido y liberado.", m_engineId);
}

bool CEngine_CRT::UpdateHTFRange() {
    datetime currentHtfTime = iTime(_Symbol, m_htfTimeframe, 1);
    if(currentHtfTime != m_lastHtfBarTime) {
        m_htfHigh   = iHigh(_Symbol, m_htfTimeframe, 1);
        m_htfLow    = iLow(_Symbol, m_htfTimeframe, 1);
        m_htfOpen   = iOpen(_Symbol, m_htfTimeframe, 1);
        m_htfClose  = iClose(_Symbol, m_htfTimeframe, 1);

        m_lastHtfBarTime    = currentHtfTime;
        m_currentState      = CRT_STATE_IDLE;
        m_sweepExtremePrice = 0.0;
        m_pendingBarsCount  = 0;
        return true;
    }
    return false;
}

int CEngine_CRT::GetMacroTrend() {
    double ema_values[];
    ArrayResize(ema_values, 2);
    ArraySetAsSeries(ema_values, true);
    if(CopyBuffer(m_ema200_handle, 0, 1, 2, ema_values) < 2) return 0;

    double last_close = iClose(_Symbol, PERIOD_H1, 1);
    if(last_close > ema_values[0] && ema_values[0] > ema_values[1]) return 1;
    if(last_close < ema_values[0] && ema_values[0] < ema_values[1]) return -1;
    return 0;
}

int CEngine_CRT::EvaluateCRT_Tier(ENUM_ORDER_TYPE orderType, double sweepDepthUSD) {
    int trend = GetMacroTrend();
    if((orderType == ORDER_TYPE_BUY && trend == 1) || (orderType == ORDER_TYPE_SELL && trend == -1)) {
        if(sweepDepthUSD <= (m_min_sweep_usd * 3.0)) return 1;
        return 2;
    }
    if(trend == 0) return 2;
    return 3;
}

bool CEngine_CRT::CheckOpenPositions() {
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

double CEngine_CRT::CalculateLotSize(double sl_dist, int tier) {
    if(sl_dist <= 0 || tier <= 0) return 0.01;

    double risk_pct = (tier == 1) ? m_risk_tier1 : ((tier == 2) ? m_risk_tier2 : m_risk_tier3);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Normalización de Cuenta Cent (si el contrato o la moneda indican cuenta Cent)
    double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    if(contractSize > 0 && contractSize < 100) {
        accountBalance = accountBalance / 100.0;
    }

    double risk_money = accountBalance * risk_pct;

    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tick_value == 0 || tick_size == 0) return 0.01;
    double raw_lot = risk_money / ((sl_dist / tick_size) * tick_value);

    double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(step_lot <= 0.0) step_lot = 0.01;
    double normalized_lot = MathRound(raw_lot / step_lot) * step_lot;
    if(normalized_lot < min_lot) normalized_lot = min_lot;
    if(normalized_lot > max_lot) normalized_lot = max_lot;

    return normalized_lot;
}

EngineSignal CEngine_CRT::Evaluate() {
    EngineSignal signal;
    UpdateHTFRange();

    if(m_lastHtfBarTime == m_lastTradedHtfTime) return signal;
    if(CheckOpenPositions()) return signal;

    // PUNTO 1: Detección estricta de Apertura de Nueva Vela M5
    datetime currentLtfTime = iTime(_Symbol, m_ltfTimeframe, 0);
    bool isNewM5Bar = false;
    if(currentLtfTime != m_lastLtfBarTime) {
        m_lastLtfBarTime = currentLtfTime;
        isNewM5Bar = true;
    }

    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tick_size   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double min_lot     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    if(m_currentState == CRT_STATE_IDLE) {
        double sweepUpUSD   = current_ask - m_htfHigh;
        double sweepDownUSD = m_htfLow - current_bid;

        if(sweepUpUSD >= m_min_sweep_usd && sweepUpUSD <= m_max_sweep_usd) {
            m_currentState      = CRT_STATE_SWEEP_SELL_PENDING;
            m_sweepExtremePrice = current_ask;
            m_pendingBarsCount  = 0;
            PrintFormat("🎯 [CRT SNIPER M106]: Barrido Superior H1 Detectado en Ask: %.2f | Profundidad: $%.2f USD | Esperando confirmación M5...", current_ask, sweepUpUSD);
        }
        else if(sweepDownUSD >= m_min_sweep_usd && sweepDownUSD <= m_max_sweep_usd) {
            m_currentState      = CRT_STATE_SWEEP_BUY_PENDING;
            m_sweepExtremePrice = current_bid;
            m_pendingBarsCount  = 0;
            PrintFormat("🎯 [CRT SNIPER M106]: Barrido Inferior H1 Detectado en Bid: %.2f | Profundidad: $%.2f USD | Esperando confirmación M5...", current_bid, sweepDownUSD);
        }
    }

    if(m_currentState != CRT_STATE_IDLE && isNewM5Bar) {
        m_pendingBarsCount++;
    }

    // PUNTO 1: Evaluación de confirmación ÚNICAMENTE cuando abre una nueva vela M5
    if(m_currentState == CRT_STATE_SWEEP_SELL_PENDING) {
        if(current_ask > m_sweepExtremePrice) m_sweepExtremePrice = current_ask;

        double currentSweepUSD = current_ask - m_htfHigh;

        if(isNewM5Bar) {
            double lastM5Close = iClose(_Symbol, m_ltfTimeframe, 1); // Vela M5 cerrada

            if(lastM5Close < m_htfHigh) {
                double sweepDepthUSD = m_sweepExtremePrice - m_htfHigh;
                int assignedTier     = EvaluateCRT_Tier(ORDER_TYPE_SELL, sweepDepthUSD);

                signal.hasSignal    = true;
                signal.orderType    = ORDER_TYPE_SELL;
                signal.tierLevel    = assignedTier;
                signal.entryPrice   = current_bid;
                signal.proximityPct = 100.0;
                signal.direction    = "SELL";

                // REGLA DE DOBLE DISTANCIA EN SL/TP Y MEDIO LOTE
                double raw_sl_price = m_sweepExtremePrice + (tick_size * m_crt_sl_buffer);
                double sl_dist_base = MathAbs(raw_sl_price - current_bid);
                if(sl_dist_base < m_min_sl_dist_usd) sl_dist_base = m_min_sl_dist_usd; // Piso de $1.50 USD

                double sl_dist_final = sl_dist_base * 2.0; // Doble distancia SL
                double tp_dist_final = (sl_dist_base * m_crt_rr) * 2.0; // Doble distancia TP

                signal.stopLoss   = current_bid + sl_dist_final;
                signal.takeProfit = current_bid - tp_dist_final;

                double rawLot = CalculateLotSize(sl_dist_base, signal.tierLevel);
                double finalLot = NormalizeDouble(rawLot * 0.5, 2); // Medio lote
                if(finalLot < min_lot) finalLot = min_lot;
                signal.baseLot  = finalLot;

                m_lastTradedHtfTime     = m_lastHtfBarTime;
                m_currentState          = CRT_STATE_IDLE;
                m_pendingBarsCount      = 0;
                return signal;
            }
        }

        if(currentSweepUSD > m_max_sweep_usd || m_pendingBarsCount > 4) {
            m_currentState      = CRT_STATE_IDLE;
            m_pendingBarsCount  = 0;
            m_sweepExtremePrice = 0.0;
            return signal;
        }
    }
    else if(m_currentState == CRT_STATE_SWEEP_BUY_PENDING) {
        if(current_bid < m_sweepExtremePrice) m_sweepExtremePrice = current_bid;

        double currentSweepUSD = m_htfLow - current_bid;

        if(isNewM5Bar) {
            double lastM5Close = iClose(_Symbol, m_ltfTimeframe, 1); // Vela M5 cerrada

            if(lastM5Close > m_htfLow) {
                double sweepDepthUSD = m_htfLow - m_sweepExtremePrice;
                int assignedTier     = EvaluateCRT_Tier(ORDER_TYPE_BUY, sweepDepthUSD);

                signal.hasSignal    = true;
                signal.orderType    = ORDER_TYPE_BUY;
                signal.tierLevel    = assignedTier;
                signal.entryPrice   = current_ask;
                signal.proximityPct = 100.0;
                signal.direction    = "BUY";

                // REGLA DE DOBLE DISTANCIA EN SL/TP Y MEDIO LOTE
                double raw_sl_price = m_sweepExtremePrice - (tick_size * m_crt_sl_buffer);
                double sl_dist_base = MathAbs(current_ask - raw_sl_price);
                if(sl_dist_base < m_min_sl_dist_usd) sl_dist_base = m_min_sl_dist_usd; // Piso de $1.50 USD

                double sl_dist_final = sl_dist_base * 2.0; // Doble distancia SL
                double tp_dist_final = (sl_dist_base * m_crt_rr) * 2.0; // Doble distancia TP

                signal.stopLoss   = current_ask - sl_dist_final;
                signal.takeProfit = current_ask + tp_dist_final;

                double rawLot = CalculateLotSize(sl_dist_base, signal.tierLevel);
                double finalLot = NormalizeDouble(rawLot * 0.5, 2); // Medio lote
                if(finalLot < min_lot) finalLot = min_lot;
                signal.baseLot  = finalLot;

                m_lastTradedHtfTime     = m_lastHtfBarTime;
                m_currentState          = CRT_STATE_IDLE;
                m_pendingBarsCount      = 0;
                return signal;
            }
        }

        if(currentSweepUSD > m_max_sweep_usd || m_pendingBarsCount > 4) {
            m_currentState      = CRT_STATE_IDLE;
            m_pendingBarsCount  = 0;
            m_sweepExtremePrice = 0.0;
            return signal;
        }
    }

    double distUpperUSD = MathAbs(current_ask - m_htfHigh);
    double distLowerUSD = MathAbs(current_bid - m_htfLow);

    double proxUpper = MathMax(0.0, MathMin(99.0, (1.0 - (distUpperUSD / 15.0)) * 100.0));
    double proxLower = MathMax(0.0, MathMin(99.0, (1.0 - (distLowerUSD / 15.0)) * 100.0));

    if(proxUpper > proxLower) {
        signal.proximityPct = NormalizeDouble(proxUpper, 0);
        signal.direction    = "SELL_SETUP";
    } else {
        signal.proximityPct = NormalizeDouble(proxLower, 0);
        signal.direction    = "BUY_SETUP";
    }

    return signal;
}

#endif
