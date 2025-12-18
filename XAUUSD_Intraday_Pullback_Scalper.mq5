//+------------------------------------------------------------------+
//|                          XAUUSD_Intraday_Pullback_Scalper.mq5    |
//|                                                                  |
//|  Scalping intraday XAUUSD M5 con pullback su EMA20             |
//|  Trend filter H1, prop-safe equity protection                    |
//+------------------------------------------------------------------+
#property copyright "ScaleF Trading"
#property link      ""
#property version   "1.00"
#property strict

//--- Input Group: Money Management
input group "=== Money Management ==="
input double   RiskPercent        = 1.0;      // Risk per trade (% of equity)
input double   RR                 = 2.0;      // Risk:Reward ratio
input long     MagicNumber        = 100502;   // Magic number
input int      MaxSpreadPoints    = 30;       // Max spread (points)
input int      SlippagePoints     = 10;       // Slippage (points)

//--- Input Group: Trading Sessions
input group "=== Trading Sessions (Server Time) ==="
input bool     UseSession1        = true;     // Enable Session 1
input string   Session1Start      = "08:00";  // Session 1 start
input string   Session1End        = "11:30";  // Session 1 end
input bool     UseSession2        = true;     // Enable Session 2
input string   Session2Start      = "14:00";  // Session 2 start
input string   Session2End        = "16:30";  // Session 2 end

//--- Input Group: Trend Filter (H1)
input group "=== Trend Filter H1 ==="
input bool     UseTrendFilter     = true;     // Use H1 trend filter
input int      FastEMA_H1         = 50;       // Fast EMA H1
input int      SlowEMA_H1         = 200;      // Slow EMA H1

//--- Input Group: Signal M5
input group "=== Signal M5 ==="
input int      EMA_M5             = 20;       // EMA M5 for pullback
input int      ATRPeriod          = 14;       // ATR period
input double   SL_ATR_Mult        = 1.2;      // SL = ATR * multiplier

//--- Input Group: Trade Limits
input group "=== Trade Limits ==="
input int      MaxTradesPerDay    = 5;        // Max trades per day
input int      MinMinutesBetweenTrades = 15;  // Min minutes between trades

//--- Input Group: Prop Protection
input group "=== Prop Protection ==="
input double   DailyLossPct       = 0.05;     // Daily loss limit (5%)
input double   MaxLossPct         = 0.10;     // Max total loss (10%)
input bool     UseDailyProfitTarget = false;  // Use daily profit target
input double   DailyProfitTarget  = 3.0;      // Daily profit target (%)

//--- Global variables
double         InitialBalance;
double         PeakEquityToday;
datetime       LastTradeTime      = 0;
int            TradesToday        = 0;
datetime       CurrentDay         = 0;
datetime       LastBarTime        = 0;

int            HandleEMA_M5;
int            HandleATR_M5;
int            HandleFastEMA_H1;
int            HandleSlowEMA_H1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Store initial balance
   InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   PeakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- Create indicator handles
   HandleEMA_M5 = iMA(_Symbol, PERIOD_M5, EMA_M5, 0, MODE_EMA, PRICE_CLOSE);
   if(HandleEMA_M5 == INVALID_HANDLE)
   {
      Print("Error creating EMA M5 handle");
      return(INIT_FAILED);
   }

   HandleATR_M5 = iATR(_Symbol, PERIOD_M5, ATRPeriod);
   if(HandleATR_M5 == INVALID_HANDLE)
   {
      Print("Error creating ATR M5 handle");
      return(INIT_FAILED);
   }

   if(UseTrendFilter)
   {
      HandleFastEMA_H1 = iMA(_Symbol, PERIOD_H1, FastEMA_H1, 0, MODE_EMA, PRICE_CLOSE);
      if(HandleFastEMA_H1 == INVALID_HANDLE)
      {
         Print("Error creating Fast EMA H1 handle");
         return(INIT_FAILED);
      }

      HandleSlowEMA_H1 = iMA(_Symbol, PERIOD_H1, SlowEMA_H1, 0, MODE_EMA, PRICE_CLOSE);
      if(HandleSlowEMA_H1 == INVALID_HANDLE)
      {
         Print("Error creating Slow EMA H1 handle");
         return(INIT_FAILED);
      }
   }

   Print("XAUUSD Intraday Pullback Scalper initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(HandleEMA_M5 != INVALID_HANDLE)
      IndicatorRelease(HandleEMA_M5);
   if(HandleATR_M5 != INVALID_HANDLE)
      IndicatorRelease(HandleATR_M5);
   if(HandleFastEMA_H1 != INVALID_HANDLE)
      IndicatorRelease(HandleFastEMA_H1);
   if(HandleSlowEMA_H1 != INVALID_HANDLE)
      IndicatorRelease(HandleSlowEMA_H1);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new day and reset daily counters at 00:00 server time
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                  IntegerToString(dt.mon) + "." +
                                  IntegerToString(dt.day));

   if(today != CurrentDay)
   {
      CurrentDay = today;
      TradesToday = 0;
      PeakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
      Print("New day started. Counters reset. Peak equity: ", PeakEquityToday);
   }

   //--- Update peak equity
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > PeakEquityToday)
      PeakEquityToday = currentEquity;

   //--- Prop protection: check drawdown levels
   double equityDrawdownPct = (PeakEquityToday - currentEquity) / InitialBalance;
   double totalDrawdownPct = (InitialBalance - currentEquity) / InitialBalance;

   //--- Close all positions at 85% of daily loss (4.25% from peak)
   if(equityDrawdownPct >= DailyLossPct * 0.85)
   {
      Print("WARNING: Daily drawdown at 85% threshold (",
            DoubleToString(equityDrawdownPct * 100, 2), "%). Closing all positions.");
      CloseAllPositions();
      return;
   }

   //--- Close all positions at 85% of max loss (8.5% total)
   if(totalDrawdownPct >= MaxLossPct * 0.85)
   {
      Print("CRITICAL: Total drawdown at 85% threshold (",
            DoubleToString(totalDrawdownPct * 100, 2), "%). Closing all positions.");
      CloseAllPositions();
      return;
   }

   //--- Stop new trades at 70% of daily loss (3.5% from peak)
   bool canOpenNewTrades = true;
   if(equityDrawdownPct >= DailyLossPct * 0.70)
   {
      canOpenNewTrades = false;
      Print("WARNING: Daily drawdown at 70% threshold. No new trades allowed.");
   }

   //--- Stop new trades at 70% of max loss (7% total)
   if(totalDrawdownPct >= MaxLossPct * 0.70)
   {
      canOpenNewTrades = false;
      Print("WARNING: Total drawdown at 70% threshold. No new trades allowed.");
   }

   //--- Check daily profit target
   if(UseDailyProfitTarget)
   {
      double profitToday = (currentEquity - PeakEquityToday) / InitialBalance;
      if(profitToday >= DailyProfitTarget / 100.0)
      {
         Print("Daily profit target reached (",
               DoubleToString(profitToday * 100, 2), "%). No more trades today.");
         CloseAllPositions();
         return;
      }
   }

   //--- Check for new bar on M5
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBarTime == LastBarTime)
      return; // No new bar

   LastBarTime = currentBarTime;

   //--- Don't trade if conditions not met
   if(!canOpenNewTrades)
      return;

   //--- Check if we already have a position
   if(CountOpenPositions() > 0)
      return; // One trade at a time

   //--- Check max trades per day
   if(TradesToday >= MaxTradesPerDay)
      return;

   //--- Check minimum time between trades
   if(LastTradeTime > 0)
   {
      int minutesSinceLastTrade = (int)((TimeCurrent() - LastTradeTime) / 60);
      if(minutesSinceLastTrade < MinMinutesBetweenTrades)
         return;
   }

   //--- Check if in trading session
   if(!IsInTradingSession())
      return;

   //--- Check spread
   double spread = GetSpreadInPoints();
   if(spread > MaxSpreadPoints)
   {
      Print("Spread too high: ", spread, " points");
      return;
   }

   //--- Get indicator values
   double ema_m5[], atr_m5[];
   ArraySetAsSeries(ema_m5, true);
   ArraySetAsSeries(atr_m5, true);

   if(CopyBuffer(HandleEMA_M5, 0, 0, 3, ema_m5) < 3)
      return;
   if(CopyBuffer(HandleATR_M5, 0, 0, 1, atr_m5) < 1)
      return;

   //--- Get price data
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(_Symbol, PERIOD_M5, 0, 3, close) < 3)
      return;
   if(CopyHigh(_Symbol, PERIOD_M5, 0, 3, high) < 3)
      return;
   if(CopyLow(_Symbol, PERIOD_M5, 0, 3, low) < 3)
      return;

   //--- Get trend direction from H1
   int trendDirection = 0; // 0 = no filter, 1 = bullish, -1 = bearish

   if(UseTrendFilter)
   {
      double fastEMA_h1[], slowEMA_h1[];
      ArraySetAsSeries(fastEMA_h1, true);
      ArraySetAsSeries(slowEMA_h1, true);

      if(CopyBuffer(HandleFastEMA_H1, 0, 0, 1, fastEMA_h1) < 1)
         return;
      if(CopyBuffer(HandleSlowEMA_H1, 0, 0, 1, slowEMA_h1) < 1)
         return;

      if(fastEMA_h1[0] > slowEMA_h1[0])
         trendDirection = 1; // Bullish
      else
         trendDirection = -1; // Bearish
   }

   //--- Calculate SL distance
   double atr = atr_m5[0];
   double slDistance = atr * SL_ATR_Mult;

   //--- Check minimum stop level
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDistance < minStopLevel)
   {
      Print("SL distance too small: ", slDistance, " vs min ", minStopLevel);
      return;
   }

   //--- BUY conditions
   bool buySignal = false;
   if(trendDirection >= 0) // Bullish or no filter
   {
      // Pullback reclaim: Close[2] was below EMA20, Close[1] broke above EMA20
      bool pullbackReclaim = (close[2] < ema_m5[2]) && (close[1] > ema_m5[1]);

      // Micro breakout confirmation: Close[1] > High[2]
      bool microBreakout = (close[1] > high[2]);

      buySignal = pullbackReclaim && microBreakout;
   }

   //--- SELL conditions
   bool sellSignal = false;
   if(trendDirection <= 0) // Bearish or no filter
   {
      // Pullback reclaim: Close[2] was above EMA20, Close[1] broke below EMA20
      bool pullbackReclaim = (close[2] > ema_m5[2]) && (close[1] < ema_m5[1]);

      // Micro breakout confirmation: Close[1] < Low[2]
      bool microBreakout = (close[1] < low[2]);

      sellSignal = pullbackReclaim && microBreakout;
   }

   //--- Open BUY position
   if(buySignal)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - slDistance;
      double tp = ask + (slDistance * RR);

      double lotSize = CalculateLotSize(slDistance, true);
      if(lotSize > 0)
      {
         if(OpenPosition(ORDER_TYPE_BUY, lotSize, ask, sl, tp))
         {
            TradesToday++;
            LastTradeTime = TimeCurrent();
            Print("BUY opened: Lot=", lotSize, " SL=", sl, " TP=", tp);
         }
      }
   }

   //--- Open SELL position
   if(sellSignal)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + slDistance;
      double tp = bid - (slDistance * RR);

      double lotSize = CalculateLotSize(slDistance, false);
      if(lotSize > 0)
      {
         if(OpenPosition(ORDER_TYPE_SELL, lotSize, bid, sl, tp))
         {
            TradesToday++;
            LastTradeTime = TimeCurrent();
            Print("SELL opened: Lot=", lotSize, " SL=", sl, " TP=", tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading sessions                 |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int currentMinutes = dt.hour * 60 + dt.min;

   //--- Parse session times
   string parts[];
   int session1StartMin = 0, session1EndMin = 0;
   int session2StartMin = 0, session2EndMin = 0;

   if(UseSession1)
   {
      StringSplit(Session1Start, ':', parts);
      if(ArraySize(parts) == 2)
         session1StartMin = (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);

      StringSplit(Session1End, ':', parts);
      if(ArraySize(parts) == 2)
         session1EndMin = (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);

      if(currentMinutes >= session1StartMin && currentMinutes <= session1EndMin)
         return true;
   }

   if(UseSession2)
   {
      StringSplit(Session2Start, ':', parts);
      if(ArraySize(parts) == 2)
         session2StartMin = (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);

      StringSplit(Session2End, ':', parts);
      if(ArraySize(parts) == 2)
         session2EndMin = (int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]);

      if(currentMinutes >= session2StartMin && currentMinutes <= session2EndMin)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get spread in points                                             |
//+------------------------------------------------------------------+
double GetSpreadInPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance, bool isBuy)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (RiskPercent / 100.0);

   //--- Calculate loss per 1 lot to SL
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slPrice = isBuy ? (price - slDistance) : (price + slDistance);

   double lossPerLot = 0;
   if(!OrderCalcProfit(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       _Symbol,
                       1.0, // 1 lot
                       price,
                       slPrice,
                       lossPerLot))
   {
      Print("Error calculating profit for lot sizing");
      return 0;
   }

   lossPerLot = MathAbs(lossPerLot);

   if(lossPerLot <= 0)
   {
      Print("Invalid loss per lot calculation");
      return 0;
   }

   //--- Calculate required lots
   double lots = riskAmount / lossPerLot;

   //--- Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);

   return lots;
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE orderType, double lots, double price, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = SlippagePoints;
   request.magic = MagicNumber;
   request.comment = "Pullback Scalper";

   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError(), " RetCode: ", result.retcode);
      return false;
   }

   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      Print("Order failed. RetCode: ", result.retcode);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};

            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = SlippagePoints;
            request.magic = MagicNumber;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               request.type = ORDER_TYPE_SELL;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            else
            {
               request.type = ORDER_TYPE_BUY;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            }

            OrderSend(request, result);
         }
      }
   }
}
//+------------------------------------------------------------------+
