//+------------------------------------------------------------------+
//|                                   XAUUSD_Liquidity_Scalper.mq5   |
//|                      Liquidity Sweep + Reversal Scalping Strategy |
//|                                       For XAUUSD M5 Timeframe     |
//+------------------------------------------------------------------+
#property copyright "Liquidity Sweep Scalper MT5"
#property version   "1.00"
#property strict
#property description "Scalping strategy based on liquidity sweeps and reversals"
#property description "Targets: PDH/PDL, Asia High/Low, Equal Highs/Lows"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
// Money Management
input double RiskPercent = 0.5;                    // Risk per trade (%)
input double RR = 1.4;                             // Risk:Reward ratio

// Strategy Parameters
input double SweepBuffer = 0.40;                   // Sweep buffer (dollars)
input double SL_Buffer = 0.40;                     // Stop Loss buffer (dollars)
input double EQ_Tolerance = 0.50;                  // Equal highs/lows tolerance (dollars)
input int LookbackEQ_Bars = 60;                    // Lookback bars for EQ levels
input int ConfirmBars = 2;                         // Confirmation bars window
input int MaxSpreadPoints = 36;                    // Max spread in points

// Trading Hours
input int TradeStartHour = 7;                      // Trading window start hour
input int TradeStartMin = 0;                       // Trading window start minute
input int TradeEndHour = 17;                       // Trading window end hour
input int TradeEndMin = 0;                         // Trading window end minute

// Asia Session Parameters
input int AsiaStartHour = 0;                       // Asia session start hour
input int AsiaStartMin = 0;                        // Asia session start minute
input int AsiaEndHour = 6;                         // Asia session end hour
input int AsiaEndMin = 0;                          // Asia session end minute

// Risk Management
input double DailyLossLimitPercent = 2.5;          // Daily loss limit (%)
input int MaxConsecutiveLosses = 3;                // Max consecutive losses

// Rollover Filter
input bool UseRolloverFilter = true;               // Use rollover filter
input int RolloverStartHour = 23;                  // Rollover start hour
input int RolloverStartMin = 55;                   // Rollover start minute
input int RolloverEndHour = 0;                     // Rollover end hour
input int RolloverEndMin = 10;                     // Rollover end minute

// Order Settings
input ulong MagicNumber = 123456;                  // Magic number
input string OrderComment = "LiqSweep";            // Order comment
input int SlippagePoints = 30;                     // Slippage in points
input bool AllowBuy = true;                        // Allow BUY orders
input bool AllowSell = true;                       // Allow SELL orders

// Prop Firm Protection (FundedNext Stellar 2-Step defaults)
input double InitialBalance = 100000.0;            // Initial balance for prop firm
input double DailyLossPct = 0.05;                  // Daily loss limit (5%)
input double MaxLossPct = 0.10;                    // Max total loss (10%)
input double DailyStopNewTradesAt = 0.70;          // Stop new trades at 70% of daily limit
input double DailyCloseAllAt = 0.85;               // Close all at 85% of daily limit
input double MaxLossStopBuffer = 500.0;            // Buffer above max loss floor

// Daily Profit Target and Trade Limits
input bool UseDailyProfitTarget = true;            // Use daily profit target
input double DailyProfitTarget = 1600.0;           // Daily profit target ($)
input int MaxTradesPerDay = 2;                     // Max trades per day
input double MaxSLDistance = 2.0;                  // Max SL distance (dollars)

// HTF Trend Filter
input bool UseTrendFilter = true;                  // Use H1 trend filter
input int FastEMA = 50;                            // Fast EMA period
input int SlowEMA = 200;                           // Slow EMA period

// ATR-Based Buffers
input bool UseATRBuffers = true;                   // Use ATR-based buffers
input int ATRPeriod = 14;                          // ATR period
input double K_sweep = 0.35;                       // ATR multiplier for sweep buffer
input double K_sl = 0.25;                          // ATR multiplier for SL buffer
input double K_maxsl = 1.20;                       // ATR multiplier for max SL distance

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// Trade object
CTrade trade;

// Bar tracking
datetime lastBarTime = 0;

// Liquidity levels
double PDH = 0, PDL = 0;                           // Previous Day High/Low
double AsiaHigh = 0, AsiaLow = 0, AsiaMid = 0;     // Asia session range
bool AsiaRangeValid = false;
datetime lastAsiaReset = 0;

double EQH_Level = 0, EQL_Level = 0;               // Equal Highs/Lows
bool EQH_Valid = false, EQL_Valid = false;

// Sweep state management
bool sweepActive = false;
int sweepDirection = 0;                            // 1 = sweep up (SELL), -1 = sweep down (BUY)
double sweepLevel = 0;
double sweepHigh = 0;
double sweepLow = 0;
int sweepBarsElapsed = 0;

// Daily risk management
datetime currentDay = 0;
double dailyPL = 0;
int consecutiveLosses = 0;
bool dailyTradingBlocked = false;
double dayStartBalance = 0;

// Prop Firm Protection
double peakEquityToday = 0;
bool blockedToday = false;
bool permanentlyBlocked = false;
datetime lastPropFirmCheckDay = 0;

// Daily Profit Target and Trade Limits
double dayStartEquity = 0;
int tradesOpenedToday = 0;
bool dailyProfitTargetReached = false;

// Dynamic buffers (ATR-based or fixed)
double dynamicSweepBuffer = 0;
double dynamicSL_Buffer = 0;
double dynamicMaxSLDistance = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("EA INITIALIZED: XAUUSD Liquidity Sweep Scalper MT5");
   Print("Symbol: ", _Symbol, " | Timeframe: M5");
   Print("Risk per trade: ", RiskPercent, "% | R:R = ", RR);
   Print("Magic Number: ", MagicNumber);
   Print("========================================");

   // Validate that we're on M5
   if(_Period != PERIOD_M5)
   {
      Print("WARNING: This EA is designed for M5 timeframe. Current: ", _Period);
   }

   // Validate symbol
   if(_Symbol != "XAUUSD" && _Symbol != "GOLD")
   {
      Print("WARNING: This EA is optimized for XAUUSD. Current symbol: ", _Symbol);
   }

   // Setup trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

   // Initialize daily tracking
   datetime timeArray[];
   CopyTime(_Symbol, PERIOD_D1, 0, 1, timeArray);
   currentDay = timeArray[0];
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Initialize prop firm protection
   MqlDateTime dt;
   TimeTradeServer(dt);
   lastPropFirmCheckDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   peakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   blockedToday = false;
   permanentlyBlocked = false;
   tradesOpenedToday = 0;
   dailyProfitTargetReached = false;

   Print("Prop Firm Protection initialized:");
   Print("  Initial Balance: $", DoubleToString(InitialBalance, 2));
   Print("  Daily Loss Limit: ", DoubleToString(DailyLossPct * 100, 2), "% ($", DoubleToString(InitialBalance * DailyLossPct, 2), ")");
   Print("  Max Loss Limit: ", DoubleToString(MaxLossPct * 100, 2), "% ($", DoubleToString(InitialBalance * MaxLossPct, 2), ")");
   Print("  Floor Equity: $", DoubleToString(InitialBalance * (1.0 - MaxLossPct), 2));
   Print("  Current Equity: $", DoubleToString(peakEquityToday, 2));
   Print("  Daily Profit Target: ", UseDailyProfitTarget ? ("$" + DoubleToString(DailyProfitTarget, 2)) : "Disabled");
   Print("  Max Trades Per Day: ", MaxTradesPerDay);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("========================================");
   Print("EA DEINITIALIZED");
   Print("Reason code: ", reason);
   Print("Final daily P/L: ", DoubleToString(dailyPL, 2));
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Execute logic only on new bar (M5)
   if(!IsNewBar()) return;

   // Update dynamic buffers (ATR-based or fixed)
   UpdateDynamicBuffers();

   // Check prop firm protection FIRST (every tick/bar)
   if(!CheckPropFirmProtection())
   {
      return; // Blocked by prop firm protection
   }

   // Check daily profit target and trade limits
   if(!CheckDailyLimits())
   {
      return; // Blocked by daily limits
   }

   // Increment sweep counter if active
   if(sweepActive)
   {
      sweepBarsElapsed++;
   }

   // Update daily risk state and check for new day
   UpdateDailyRiskState();

   // Update all liquidity levels
   UpdateDailyLevels();
   UpdateAsiaLevels();
   UpdateEqualLevels();

   // Check if trading is blocked
   if(dailyTradingBlocked)
   {
      return; // Silent block - already logged when triggered
   }

   // Check trading window
   if(!IsInTradingWindow())
   {
      return; // Outside trading hours
   }

   // Check rollover filter
   if(UseRolloverFilter && IsInRolloverWindow())
   {
      return; // During rollover period
   }

   // Check spread filter
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadPoints > MaxSpreadPoints)
   {
      Print("Spread filter triggered: ", spreadPoints, " points (max: ", MaxSpreadPoints, ")");
      return;
   }

   // Check if already have open position
   if(HasOpenPosition())
   {
      return; // Already in trade - one position at a time
   }

   // Main strategy logic: detect sweeps and confirmations
   DetectSweepAndConfirm();
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime timeArray[];
   CopyTime(_Symbol, PERIOD_M5, 0, 1, timeArray);
   datetime currentBarTime = timeArray[0];

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if within trading time window                               |
//+------------------------------------------------------------------+
bool IsInTradingWindow()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int nowMinutes = dt.hour * 60 + dt.min;
   int startMinutes = TradeStartHour * 60 + TradeStartMin;
   int endMinutes = TradeEndHour * 60 + TradeEndMin;

   if(startMinutes < endMinutes)
   {
      // Normal time window (e.g., 7:00 to 17:00)
      return (nowMinutes >= startMinutes && nowMinutes < endMinutes);
   }
   else
   {
      // Overnight window (e.g., 23:00 to 02:00)
      return (nowMinutes >= startMinutes || nowMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check if within rollover time window                              |
//+------------------------------------------------------------------+
bool IsInRolloverWindow()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int nowMinutes = dt.hour * 60 + dt.min;
   int startMinutes = RolloverStartHour * 60 + RolloverStartMin;
   int endMinutes = RolloverEndHour * 60 + RolloverEndMin;

   if(startMinutes < endMinutes)
   {
      return (nowMinutes >= startMinutes && nowMinutes < endMinutes);
   }
   else
   {
      // Crosses midnight (e.g., 23:55 to 00:10)
      return (nowMinutes >= startMinutes || nowMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Update Previous Day High/Low levels                               |
//+------------------------------------------------------------------+
void UpdateDailyLevels()
{
   datetime timeArray[];
   CopyTime(_Symbol, PERIOD_D1, 0, 1, timeArray);
   datetime today = timeArray[0];

   // Check if new day started
   if(today != currentDay)
   {
      currentDay = today;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyPL = 0;
      consecutiveLosses = 0;
      dailyTradingBlocked = false;
      Print("*** NEW DAY STARTED - Daily counters reset ***");
      Print("Day start balance: $", DoubleToString(dayStartBalance, 2));
   }

   // Get previous day's high and low
   double highArray[], lowArray[];
   CopyHigh(_Symbol, PERIOD_D1, 1, 1, highArray);
   CopyLow(_Symbol, PERIOD_D1, 1, 1, lowArray);

   double prevHigh = highArray[0];
   double prevLow = lowArray[0];

   // Update if changed
   if(prevHigh != PDH || prevLow != PDL)
   {
      PDH = prevHigh;
      PDL = prevLow;
      Print("Updated liquidity levels - PDH: ", DoubleToString(PDH, _Digits),
            " | PDL: ", DoubleToString(PDL, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Update Asia session High/Low levels                               |
//+------------------------------------------------------------------+
void UpdateAsiaLevels()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int nowMinutes = dt.hour * 60 + dt.min;
   int asiaStart = AsiaStartHour * 60 + AsiaStartMin;
   int asiaEnd = AsiaEndHour * 60 + AsiaEndMin;

   bool inAsiaSession = false;
   if(asiaStart < asiaEnd)
   {
      inAsiaSession = (nowMinutes >= asiaStart && nowMinutes < asiaEnd);
   }
   else
   {
      inAsiaSession = (nowMinutes >= asiaStart || nowMinutes < asiaEnd);
   }

   if(inAsiaSession)
   {
      // During Asia session - update running high/low
      datetime timeArray[];
      CopyTime(_Symbol, PERIOD_D1, 0, 1, timeArray);
      datetime asiaDay = timeArray[0];

      // Reset if new day
      if(asiaDay != lastAsiaReset)
      {
         AsiaHigh = 0;
         AsiaLow = 0;
         AsiaRangeValid = false;
         lastAsiaReset = asiaDay;
      }

      double highArray[], lowArray[];
      CopyHigh(_Symbol, PERIOD_M5, 1, 1, highArray);
      CopyLow(_Symbol, PERIOD_M5, 1, 1, lowArray);

      double currentHigh = highArray[0];
      double currentLow = lowArray[0];

      if(AsiaHigh == 0 || currentHigh > AsiaHigh) AsiaHigh = currentHigh;
      if(AsiaLow == 0 || currentLow < AsiaLow) AsiaLow = currentLow;
   }
   else
   {
      // Outside Asia session - finalize range if not already done
      if(!AsiaRangeValid && AsiaHigh > 0 && AsiaLow > 0)
      {
         AsiaMid = (AsiaHigh + AsiaLow) / 2.0;
         AsiaRangeValid = true;
         Print("Asia range FINALIZED - High: ", DoubleToString(AsiaHigh, _Digits),
               " | Low: ", DoubleToString(AsiaLow, _Digits),
               " | Mid: ", DoubleToString(AsiaMid, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Update Equal Highs/Lows levels                                    |
//+------------------------------------------------------------------+
void UpdateEqualLevels()
{
   double highArray[], lowArray[];
   CopyHigh(_Symbol, PERIOD_M5, 1, LookbackEQ_Bars, highArray);
   CopyLow(_Symbol, PERIOD_M5, 1, LookbackEQ_Bars, lowArray);

   // Find Equal Highs (EQH)
   EQH_Valid = false;
   for(int i = 0; i < LookbackEQ_Bars - 1; i++)
   {
      double h1 = highArray[i];
      for(int j = i + 1; j < LookbackEQ_Bars; j++)
      {
         double h2 = highArray[j];
         if(MathAbs(h1 - h2) <= EQ_Tolerance)
         {
            EQH_Level = (h1 + h2) / 2.0;
            EQH_Valid = true;
            break;
         }
      }
      if(EQH_Valid) break;
   }

   // Find Equal Lows (EQL)
   EQL_Valid = false;
   for(int i = 0; i < LookbackEQ_Bars - 1; i++)
   {
      double l1 = lowArray[i];
      for(int j = i + 1; j < LookbackEQ_Bars; j++)
      {
         double l2 = lowArray[j];
         if(MathAbs(l1 - l2) <= EQ_Tolerance)
         {
            EQL_Level = (l1 + l2) / 2.0;
            EQL_Valid = true;
            break;
         }
      }
      if(EQL_Valid) break;
   }
}

//+------------------------------------------------------------------+
//| Detect sweep and confirmation logic                               |
//+------------------------------------------------------------------+
void DetectSweepAndConfirm()
{
   // If we have an active sweep, check for confirmation
   if(sweepActive)
   {
      // Check timeout
      if(sweepBarsElapsed > ConfirmBars)
      {
         Print("Sweep confirmation TIMEOUT (", sweepBarsElapsed, " bars elapsed)");
         sweepActive = false;
         return;
      }

      // Get current bar data for confirmation check
      double highArray[], lowArray[], closeArray[];
      CopyHigh(_Symbol, PERIOD_M5, 1, 1, highArray);
      CopyLow(_Symbol, PERIOD_M5, 1, 1, lowArray);
      CopyClose(_Symbol, PERIOD_M5, 1, 1, closeArray);

      double high1 = highArray[0];
      double low1 = lowArray[0];
      double close1 = closeArray[0];

      if(sweepDirection == 1) // Sweep UP -> looking for SELL confirmation
      {
         Print("DEBUG Sweep: Bar ", sweepBarsElapsed, "/", ConfirmBars,
               " | High[1]=", DoubleToString(high1, _Digits),
               " | Close[1]=", DoubleToString(close1, _Digits),
               " | Need: Close < ", DoubleToString(sweepLevel, _Digits),
               " AND High < ", DoubleToString(sweepHigh, _Digits));

         // Confirmation: closed below level AND high below sweep high (rejection confirmed)
         if(close1 < sweepLevel && high1 < sweepHigh)
         {
            Print("========================================");
            Print(">>> SELL CONFIRMATION DETECTED <<<");
            Print("Close[1]: ", DoubleToString(close1, _Digits), " < SweepLevel: ", DoubleToString(sweepLevel, _Digits));
            Print("High[1]: ", DoubleToString(high1, _Digits), " < SweepHigh: ", DoubleToString(sweepHigh, _Digits));
            Print("========================================");
            OpenTrade(ORDER_TYPE_SELL);
            sweepActive = false;
         }
      }
      else if(sweepDirection == -1) // Sweep DOWN -> looking for BUY confirmation
      {
         Print("DEBUG Sweep: Bar ", sweepBarsElapsed, "/", ConfirmBars,
               " | Low[1]=", DoubleToString(low1, _Digits),
               " | Close[1]=", DoubleToString(close1, _Digits),
               " | Need: Close > ", DoubleToString(sweepLevel, _Digits),
               " AND Low > ", DoubleToString(sweepLow, _Digits));

         // Confirmation: closed above level AND low above sweep low (rejection confirmed)
         if(close1 > sweepLevel && low1 > sweepLow)
         {
            Print("========================================");
            Print(">>> BUY CONFIRMATION DETECTED <<<");
            Print("Close[1]: ", DoubleToString(close1, _Digits), " > SweepLevel: ", DoubleToString(sweepLevel, _Digits));
            Print("Low[1]: ", DoubleToString(low1, _Digits), " > SweepLow: ", DoubleToString(sweepLow, _Digits));
            Print("========================================");
            OpenTrade(ORDER_TYPE_BUY);
            sweepActive = false;
         }
      }

      return; // Don't look for new sweeps while waiting for confirmation
   }

   // Look for new sweep on last closed bar (bar index 1)
   double highArray[], lowArray[], closeArray[];
   datetime timeArray[];
   CopyHigh(_Symbol, PERIOD_M5, 1, 1, highArray);
   CopyLow(_Symbol, PERIOD_M5, 1, 1, lowArray);
   CopyClose(_Symbol, PERIOD_M5, 1, 1, closeArray);
   CopyTime(_Symbol, PERIOD_M5, 1, 1, timeArray);

   double high1 = highArray[0];
   double low1 = lowArray[0];
   double close1 = closeArray[0];

   // === CHECK FOR SWEEP UP (stop hunt above resistance) ===
   // Build array of resistance levels to check
   double levelsUp[10];
   ArrayInitialize(levelsUp, 0);
   int countUp = 0;

   if(PDH > 0) { levelsUp[countUp] = PDH; countUp++; }
   if(AsiaRangeValid && AsiaHigh > 0) { levelsUp[countUp] = AsiaHigh; countUp++; }
   if(EQH_Valid && EQH_Level > 0) { levelsUp[countUp] = EQH_Level; countUp++; }

   for(int i = 0; i < countUp; i++)
   {
      double L = levelsUp[i];

      // Sweep condition: High >= L + buffer AND Close < L (rejection)
      if(high1 >= L + dynamicSweepBuffer && close1 < L)
      {
         sweepActive = true;
         sweepDirection = 1; // SELL setup
         sweepLevel = L;
         sweepHigh = high1;
         sweepLow = low1;
         sweepBarsElapsed = 0; // Reset counter

         // Identify which level was swept
         string levelName = "Unknown";
         if(MathAbs(L - PDH) < 0.01) levelName = "PDH";
         else if(MathAbs(L - AsiaHigh) < 0.01) levelName = "AsiaHigh";
         else if(MathAbs(L - EQH_Level) < 0.01) levelName = "EQH";

         Print("========================================");
         Print("*** SWEEP UP DETECTED ***");
         Print("Level: ", levelName, " at ", DoubleToString(L, _Digits));
         Print("Sweep bar - High[1]: ", DoubleToString(high1, _Digits), " | Low[1]: ", DoubleToString(low1, _Digits), " | Close[1]: ", DoubleToString(close1, _Digits));
         Print("Saved - SweepLevel: ", DoubleToString(sweepLevel, _Digits), " | SweepHigh: ", DoubleToString(sweepHigh, _Digits), " | SweepLow: ", DoubleToString(sweepLow, _Digits));
         Print("Waiting for SELL confirmation (max ", ConfirmBars, " bars)...");
         Print("========================================");

         return; // One sweep at a time
      }
   }

   // === CHECK FOR SWEEP DOWN (stop hunt below support) ===
   // Build array of support levels to check
   double levelsDown[10];
   ArrayInitialize(levelsDown, 0);
   int countDown = 0;

   if(PDL > 0) { levelsDown[countDown] = PDL; countDown++; }
   if(AsiaRangeValid && AsiaLow > 0) { levelsDown[countDown] = AsiaLow; countDown++; }
   if(EQL_Valid && EQL_Level > 0) { levelsDown[countDown] = EQL_Level; countDown++; }

   for(int i = 0; i < countDown; i++)
   {
      double L = levelsDown[i];

      // Sweep condition: Low <= L - buffer AND Close > L (rejection)
      if(low1 <= L - dynamicSweepBuffer && close1 > L)
      {
         sweepActive = true;
         sweepDirection = -1; // BUY setup
         sweepLevel = L;
         sweepHigh = high1;
         sweepLow = low1;
         sweepBarsElapsed = 0; // Reset counter

         // Identify which level was swept
         string levelName = "Unknown";
         if(MathAbs(L - PDL) < 0.01) levelName = "PDL";
         else if(MathAbs(L - AsiaLow) < 0.01) levelName = "AsiaLow";
         else if(MathAbs(L - EQL_Level) < 0.01) levelName = "EQL";

         Print("========================================");
         Print("*** SWEEP DOWN DETECTED ***");
         Print("Level: ", levelName, " at ", DoubleToString(L, _Digits));
         Print("Sweep bar - High[1]: ", DoubleToString(high1, _Digits), " | Low[1]: ", DoubleToString(low1, _Digits), " | Close[1]: ", DoubleToString(close1, _Digits));
         Print("Saved - SweepLevel: ", DoubleToString(sweepLevel, _Digits), " | SweepHigh: ", DoubleToString(sweepHigh, _Digits), " | SweepLow: ", DoubleToString(sweepLow, _Digits));
         Print("Waiting for BUY confirmation (max ", ConfirmBars, " bars)...");
         Print("========================================");

         return; // One sweep at a time
      }
   }
}

//+------------------------------------------------------------------+
//| Open trade with proper SL, TP, and lot sizing                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   // Check if direction is allowed
   if(orderType == ORDER_TYPE_BUY && !AllowBuy)
   {
      Print("BUY signal ignored (AllowBuy=false)");
      return;
   }

   if(orderType == ORDER_TYPE_SELL && !AllowSell)
   {
      Print("SELL signal ignored (AllowSell=false)");
      return;
   }

   // Check HTF trend filter
   if(!CheckTrendFilter(orderType))
   {
      return; // Blocked by trend filter
   }

   double entryPrice = 0;
   double slPrice = 0;
   double tpPrice = 0;
   double risk = 0;

   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calculate entry, SL, and TP based on order type
   if(orderType == ORDER_TYPE_SELL)
   {
      entryPrice = bid;
      slPrice = sweepHigh + dynamicSL_Buffer;
      risk = slPrice - entryPrice;

      if(risk <= 0)
      {
         Print("Invalid risk for SELL: ", risk, ". Trade aborted.");
         return;
      }

      tpPrice = entryPrice - (RR * risk);
   }
   else if(orderType == ORDER_TYPE_BUY)
   {
      entryPrice = ask;
      slPrice = sweepLow - dynamicSL_Buffer;
      risk = entryPrice - slPrice;

      if(risk <= 0)
      {
         Print("Invalid risk for BUY: ", risk, ". Trade aborted.");
         return;
      }

      tpPrice = entryPrice + (RR * risk);
   }
   else
   {
      Print("Invalid order type: ", orderType);
      return;
   }

   // Check max SL distance
   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance > dynamicMaxSLDistance)
   {
      Print("Skipped: SL distance too large (", DoubleToString(slDistance, 2), " > ", DoubleToString(dynamicMaxSLDistance, 2), ")");
      return;
   }

   // Validate minimum stop level
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopLevel = stopLevel * _Point;
   double tpDistance = MathAbs(tpPrice - entryPrice);

   if(slDistance < minStopLevel)
   {
      Print("SL too close to entry. Required: ", minStopLevel, " | Current: ", slDistance);
      return;
   }

   if(tpDistance < minStopLevel)
   {
      Print("TP too close to entry. Required: ", minStopLevel, " | Current: ", tpDistance);
      return;
   }

   // Calculate lot size based on risk
   double lots = CalculateLotSize(entryPrice, slPrice, orderType);
   if(lots <= 0)
   {
      Print("Invalid lot size calculated: ", lots, ". Trade aborted.");
      return;
   }

   // Normalize prices
   slPrice = NormalizeDouble(slPrice, _Digits);
   tpPrice = NormalizeDouble(tpPrice, _Digits);

   // Send market order
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(lots, _Symbol, entryPrice, slPrice, tpPrice, OrderComment);
   }
   else
   {
      result = trade.Sell(lots, _Symbol, entryPrice, slPrice, tpPrice, OrderComment);
   }

   if(result)
   {
      string direction = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;

      // Increment daily trade counter
      tradesOpenedToday++;

      Print("========================================");
      Print("TRADE OPENED SUCCESSFULLY");
      Print("Ticket: ", trade.ResultOrder());
      Print("Direction: ", direction);
      Print("Entry: ", DoubleToString(entryPrice, _Digits));
      Print("Stop Loss: ", DoubleToString(slPrice, _Digits));
      Print("Take Profit: ", DoubleToString(tpPrice, _Digits));
      Print("Lot Size: ", DoubleToString(lots, 2));
      Print("Risk: $", DoubleToString(riskMoney, 2), " (", RiskPercent, "%)");
      Print("Risk/Reward: 1:", RR);
      Print("Trades Opened Today: ", tradesOpenedToday, "/", MaxTradesPerDay);
      Print("========================================");
   }
   else
   {
      Print("========================================");
      Print("ORDER SEND FAILED");
      Print("Error code: ", trade.ResultRetcode());
      Print("Error description: ", trade.ResultRetcodeDescription());
      Print("Entry: ", entryPrice, " | SL: ", slPrice, " | TP: ", tpPrice);
      Print("Lots: ", lots);
      Print("========================================");
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage using OrderCalcProfit |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType)
{
   // Calculate SL distance in price
   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance <= 0)
   {
      Print("ERROR: Invalid SL distance: ", slDistance);
      return 0;
   }

   // Get contract specifications
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Calculate risk amount in account currency
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;

   // Calculate profit/loss for 1 lot using OrderCalcProfit
   double profit1lot = 0;
   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entryPrice, slPrice, profit1lot))
   {
      Print("ERROR: OrderCalcProfit failed. Error: ", GetLastError());
      return 0;
   }

   // Calculate lot size
   double lots = riskMoney / MathAbs(profit1lot);

   // Normalize to lot step
   lots = MathFloor(lots / lotStep) * lotStep;

   // Apply min/max limits
   if(lots < minLot)
   {
      Print("Calculated lot (", lots, ") below minimum. Using min lot: ", minLot);
      lots = minLot;
   }

   if(lots > maxLot)
   {
      Print("Calculated lot (", lots, ") above maximum. Using max lot: ", maxLot);
      lots = maxLot;
   }

   // Validate sufficient margin
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= 0)
   {
      Print("ERROR: No free margin available");
      return 0;
   }

   Print("Lot calculation: Risk=$", DoubleToString(riskMoney, 2),
         " | SL dist=", DoubleToString(slDistance, _Digits),
         " | P/L per lot=$", DoubleToString(profit1lot, 2),
         " | Lots=", DoubleToString(lots, 2));

   return lots;
}

//+------------------------------------------------------------------+
//| Check if position already open with our magic number              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update daily P/L and check risk limits                            |
//+------------------------------------------------------------------+
void UpdateDailyRiskState()
{
   // Calculate today's P/L from closed trades
   double todayPL = 0;
   int tempConsecutiveLosses = 0;
   bool lastWasLoss = true;

   datetime timeArray[];
   CopyTime(_Symbol, PERIOD_D1, 0, 1, timeArray);
   datetime todayStart = timeArray[0];

   // Request history for today
   HistorySelect(todayStart, TimeCurrent());

   // Scan deals from most recent to oldest
   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
         {
            long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

            // Only count exit deals (closing positions)
            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
            {
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
               double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);

               double totalProfit = profit + swap + commission;
               todayPL += totalProfit;

               // Count consecutive losses (from most recent backward)
               if(lastWasLoss)
               {
                  if(totalProfit < -0.01) // Loss
                  {
                     tempConsecutiveLosses++;
                  }
                  else if(totalProfit > 0.01) // Win
                  {
                     lastWasLoss = false;
                  }
               }
            }
         }
      }
   }

   dailyPL = todayPL;
   consecutiveLosses = tempConsecutiveLosses;

   // Check daily loss limit (use day start balance, not current balance)
   double dailyLossLimit = dayStartBalance * DailyLossLimitPercent / 100.0;

   if(dailyPL < -dailyLossLimit && !dailyTradingBlocked)
   {
      dailyTradingBlocked = true;
      Print("========================================");
      Print("DAILY LOSS LIMIT REACHED");
      Print("Daily P/L: $", DoubleToString(dailyPL, 2));
      Print("Limit: $", DoubleToString(-dailyLossLimit, 2), " (", DailyLossLimitPercent, "% of $", DoubleToString(dayStartBalance, 2), ")");
      Print("Trading BLOCKED for remainder of day");
      Print("========================================");
   }

   // Check consecutive losses limit
   if(consecutiveLosses >= MaxConsecutiveLosses && !dailyTradingBlocked)
   {
      dailyTradingBlocked = true;
      Print("========================================");
      Print("MAX CONSECUTIVE LOSSES REACHED");
      Print("Consecutive losses: ", consecutiveLosses);
      Print("Limit: ", MaxConsecutiveLosses);
      Print("Trading BLOCKED for remainder of day");
      Print("========================================");
   }
}

//+------------------------------------------------------------------+
//| Prop Firm Protection Check                                        |
//+------------------------------------------------------------------+
bool CheckPropFirmProtection()
{
   // Check if permanently blocked
   if(permanentlyBlocked)
   {
      return false;
   }

   // Get current server time
   MqlDateTime dt;
   TimeTradeServer(dt);
   datetime currentServerDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));

   // Check if new day started (server time)
   if(currentServerDay != lastPropFirmCheckDay)
   {
      lastPropFirmCheckDay = currentServerDay;
      peakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      blockedToday = false;
      tradesOpenedToday = 0;
      dailyProfitTargetReached = false;

      Print("========================================");
      Print("PROP FIRM: NEW DAY RESET");
      Print("Peak Equity Today: $", DoubleToString(peakEquityToday, 2));
      Print("Day Start Equity: $", DoubleToString(dayStartEquity, 2));
      Print("Blocked Today: ", blockedToday);
      Print("Trades Opened Today: ", tradesOpenedToday);
      Print("========================================");
   }

   // Get current equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Update peak equity
   if(equity > peakEquityToday)
   {
      peakEquityToday = equity;
   }

   // Calculate limits
   double dailyLimit = InitialBalance * DailyLossPct;
   double dailyDD = peakEquityToday - equity;
   double floorEquity = InitialBalance * (1.0 - MaxLossPct);

   // Rule 1: Check if equity breached floor (CRITICAL - close all and block permanently)
   if(equity <= floorEquity)
   {
      Print("========================================");
      Print("CRITICAL: MAX LOSS BREACH PROTECTION TRIGGERED");
      Print("Current Equity: $", DoubleToString(equity, 2));
      Print("Floor Equity: $", DoubleToString(floorEquity, 2));
      Print("Max Loss: ", DoubleToString(MaxLossPct * 100, 2), "%");
      Print("CLOSING ALL POSITIONS AND BLOCKING PERMANENTLY");
      Print("========================================");

      CloseAllPositions("Max Loss Breach");
      permanentlyBlocked = true;
      return false;
   }

   // Rule 2: Check if equity near floor (stop new trades)
   if(equity <= floorEquity + MaxLossStopBuffer)
   {
      if(!blockedToday)
      {
         Print("========================================");
         Print("PROP FIRM: APPROACHING MAX LOSS LIMIT");
         Print("Current Equity: $", DoubleToString(equity, 2));
         Print("Floor + Buffer: $", DoubleToString(floorEquity + MaxLossStopBuffer, 2));
         Print("BLOCKING NEW TRADES");
         Print("========================================");
         blockedToday = true;
      }
      return false;
   }

   // Rule 3: Check daily drawdown close all threshold
   if(dailyDD >= dailyLimit * DailyCloseAllAt)
   {
      Print("========================================");
      Print("PROP FIRM: DAILY CLOSE ALL THRESHOLD REACHED");
      Print("Daily DD: $", DoubleToString(dailyDD, 2), " (", DoubleToString((dailyDD/dailyLimit)*100, 2), "% of limit)");
      Print("Threshold: ", DoubleToString(DailyCloseAllAt * 100, 2), "% of daily limit");
      Print("Peak Equity Today: $", DoubleToString(peakEquityToday, 2));
      Print("Current Equity: $", DoubleToString(equity, 2));
      Print("CLOSING ALL POSITIONS AND BLOCKING FOR TODAY");
      Print("========================================");

      CloseAllPositions("Daily Close All Threshold");
      blockedToday = true;
      return false;
   }

   // Rule 4: Check daily drawdown stop new trades threshold
   if(dailyDD >= dailyLimit * DailyStopNewTradesAt)
   {
      if(!blockedToday)
      {
         Print("========================================");
         Print("PROP FIRM: DAILY STOP NEW TRADES THRESHOLD REACHED");
         Print("Daily DD: $", DoubleToString(dailyDD, 2), " (", DoubleToString((dailyDD/dailyLimit)*100, 2), "% of limit)");
         Print("Threshold: ", DoubleToString(DailyStopNewTradesAt * 100, 2), "% of daily limit");
         Print("Peak Equity Today: $", DoubleToString(peakEquityToday, 2));
         Print("Current Equity: $", DoubleToString(equity, 2));
         Print("BLOCKING NEW TRADES (existing positions remain open)");
         Print("========================================");
         blockedToday = true;
      }
      return false;
   }

   // Check if blocked today for any other reason
   if(blockedToday)
   {
      return false;
   }

   // All checks passed
   return true;
}

//+------------------------------------------------------------------+
//| Close All Positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   int closed = 0;
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(trade.PositionClose(ticket))
            {
               closed++;
               Print("Position closed: Ticket=", ticket, " | Reason: ", reason);
            }
            else
            {
               Print("ERROR: Failed to close position ", ticket, " | Error: ", trade.ResultRetcode());
            }
         }
      }
   }

   if(closed > 0)
   {
      Print("Total positions closed: ", closed, " | Reason: ", reason);
   }
}

//+------------------------------------------------------------------+
//| Update Dynamic Buffers (ATR-based or fixed)                      |
//+------------------------------------------------------------------+
void UpdateDynamicBuffers()
{
   if(!UseATRBuffers)
   {
      // Use fixed values from inputs
      dynamicSweepBuffer = SweepBuffer;
      dynamicSL_Buffer = SL_Buffer;
      dynamicMaxSLDistance = MaxSLDistance;
      return;
   }

   // Calculate ATR on M5
   double atrArray[];
   ArraySetAsSeries(atrArray, true);

   int atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator handle");
      // Fallback to fixed values
      dynamicSweepBuffer = SweepBuffer;
      dynamicSL_Buffer = SL_Buffer;
      dynamicMaxSLDistance = MaxSLDistance;
      return;
   }

   if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) <= 0)
   {
      Print("ERROR: Failed to copy ATR buffer");
      // Fallback to fixed values
      dynamicSweepBuffer = SweepBuffer;
      dynamicSL_Buffer = SL_Buffer;
      dynamicMaxSLDistance = MaxSLDistance;
      return;
   }

   double atr = atrArray[0];

   // Calculate dynamic buffers based on ATR
   dynamicSweepBuffer = atr * K_sweep;
   dynamicSL_Buffer = atr * K_sl;
   dynamicMaxSLDistance = atr * K_maxsl;

   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Check HTF Trend Filter (H1 EMA)                                  |
//+------------------------------------------------------------------+
bool CheckTrendFilter(ENUM_ORDER_TYPE orderType)
{
   if(!UseTrendFilter)
   {
      return true; // Filter disabled
   }

   // Get EMA values on H1
   double fastEmaArray[], slowEmaArray[];
   ArraySetAsSeries(fastEmaArray, true);
   ArraySetAsSeries(slowEmaArray, true);

   int fastHandle = iMA(_Symbol, PERIOD_H1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int slowHandle = iMA(_Symbol, PERIOD_H1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create EMA indicator handles");
      return true; // Allow trade if indicator fails
   }

   if(CopyBuffer(fastHandle, 0, 0, 1, fastEmaArray) <= 0 ||
      CopyBuffer(slowHandle, 0, 0, 1, slowEmaArray) <= 0)
   {
      Print("ERROR: Failed to copy EMA buffers");
      IndicatorRelease(fastHandle);
      IndicatorRelease(slowHandle);
      return true; // Allow trade if copy fails
   }

   double fastEma = fastEmaArray[0];
   double slowEma = slowEmaArray[0];

   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);

   // Check trend alignment
   if(orderType == ORDER_TYPE_BUY)
   {
      if(fastEma <= slowEma)
      {
         Print("BUY blocked by trend filter: EMA", FastEMA, "(H1)=", DoubleToString(fastEma, _Digits),
               " <= EMA", SlowEMA, "(H1)=", DoubleToString(slowEma, _Digits));
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(fastEma >= slowEma)
      {
         Print("SELL blocked by trend filter: EMA", FastEMA, "(H1)=", DoubleToString(fastEma, _Digits),
               " >= EMA", SlowEMA, "(H1)=", DoubleToString(slowEma, _Digits));
         return false;
      }
   }

   return true; // Trend aligned with trade direction
}

//+------------------------------------------------------------------+
//| Check Daily Profit Target and Trade Limits                       |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   // Check if daily profit target already reached
   if(dailyProfitTargetReached)
   {
      return false;
   }

   // Get current equity
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Calculate today's profit
   double profitToday = currentEquity - dayStartEquity;

   // Check daily profit target
   if(UseDailyProfitTarget && profitToday >= DailyProfitTarget)
   {
      Print("========================================");
      Print("DAILY PROFIT TARGET REACHED");
      Print("Target: $", DoubleToString(DailyProfitTarget, 2));
      Print("Profit Today: $", DoubleToString(profitToday, 2));
      Print("Day Start Equity: $", DoubleToString(dayStartEquity, 2));
      Print("Current Equity: $", DoubleToString(currentEquity, 2));
      Print("CLOSING ALL POSITIONS AND BLOCKING FOR TODAY");
      Print("========================================");

      CloseAllPositions("Daily Profit Target Reached");
      dailyProfitTargetReached = true;
      return false;
   }

   // Check max trades per day
   if(tradesOpenedToday >= MaxTradesPerDay)
   {
      // Silent block - only log once when first blocked
      static bool maxTradesLoggedToday = false;
      if(!maxTradesLoggedToday)
      {
         Print("========================================");
         Print("MAX TRADES PER DAY REACHED");
         Print("Trades Today: ", tradesOpenedToday, "/", MaxTradesPerDay);
         Print("No new trades until tomorrow");
         Print("========================================");
         maxTradesLoggedToday = true;
      }
      return false;
   }

   // All checks passed
   return true;
}
//+------------------------------------------------------------------+
