//+------------------------------------------------------------------+
//|                                   XAUUSD_Liquidity_Scalper.mq4   |
//|                      Liquidity Sweep + Reversal Scalping Strategy |
//|                                       For XAUUSD M5 Timeframe     |
//+------------------------------------------------------------------+
#property copyright "Liquidity Sweep Scalper"
#property version   "1.00"
#property strict
#property description "Scalping strategy based on liquidity sweeps and reversals"
#property description "Targets: PDH/PDL, Asia High/Low, Equal Highs/Lows"

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
input int MagicNumber = 123456;                    // Magic number
input string OrderComment = "LiqSweep";            // Order comment
input int SlippagePoints = 30;                     // Slippage in points

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
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
datetime sweepTime = 0;

// Daily risk management
datetime currentDay = 0;
double dailyPL = 0;
int consecutiveLosses = 0;
bool dailyTradingBlocked = false;
double dayStartBalance = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("EA INITIALIZED: XAUUSD Liquidity Sweep Scalper");
   Print("Symbol: ", Symbol(), " | Timeframe: M5");
   Print("Risk per trade: ", RiskPercent, "% | R:R = ", RR);
   Print("Magic Number: ", MagicNumber);
   Print("========================================");

   // Validate that we're on M5
   if(Period() != PERIOD_M5)
   {
      Print("WARNING: This EA is designed for M5 timeframe. Current: ", Period());
   }

   // Validate symbol
   if(Symbol() != "XAUUSD" && Symbol() != "GOLD")
   {
      Print("WARNING: This EA is optimized for XAUUSD. Current symbol: ", Symbol());
   }

   // Initialize daily tracking
   currentDay = iTime(Symbol(), PERIOD_D1, 0);
   dayStartBalance = AccountBalance();

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
   int currentSpread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(currentSpread > MaxSpreadPoints)
   {
      Print("Spread filter triggered: ", currentSpread, " points (max: ", MaxSpreadPoints, ")");
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
   datetime currentBarTime = Time[0];
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
   datetime now = TimeCurrent();
   int hour = TimeHour(now);
   int minute = TimeMinute(now);

   int nowMinutes = hour * 60 + minute;
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
   datetime now = TimeCurrent();
   int hour = TimeHour(now);
   int minute = TimeMinute(now);

   int nowMinutes = hour * 60 + minute;
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
   datetime today = iTime(Symbol(), PERIOD_D1, 0);

   // Check if new day started
   if(today != currentDay)
   {
      currentDay = today;
      dayStartBalance = AccountBalance();
      dailyPL = 0;
      consecutiveLosses = 0;
      dailyTradingBlocked = false;
      Print("*** NEW DAY STARTED - Daily counters reset ***");
      Print("Day start balance: $", DoubleToString(dayStartBalance, 2));
   }

   // Get previous day's high and low
   double prevHigh = iHigh(Symbol(), PERIOD_D1, 1);
   double prevLow = iLow(Symbol(), PERIOD_D1, 1);

   // Update if changed
   if(prevHigh != PDH || prevLow != PDL)
   {
      PDH = prevHigh;
      PDL = prevLow;
      Print("Updated liquidity levels - PDH: ", DoubleToString(PDH, Digits),
            " | PDL: ", DoubleToString(PDL, Digits));
   }
}

//+------------------------------------------------------------------+
//| Update Asia session High/Low levels                               |
//+------------------------------------------------------------------+
void UpdateAsiaLevels()
{
   datetime now = TimeCurrent();
   int hour = TimeHour(now);
   int minute = TimeMinute(now);

   int nowMinutes = hour * 60 + minute;
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
      datetime asiaDay = iTime(Symbol(), PERIOD_D1, 0);

      // Reset if new day
      if(asiaDay != lastAsiaReset)
      {
         AsiaHigh = 0;
         AsiaLow = 0;
         AsiaRangeValid = false;
         lastAsiaReset = asiaDay;
      }

      double currentHigh = iHigh(Symbol(), PERIOD_M5, 1);
      double currentLow = iLow(Symbol(), PERIOD_M5, 1);

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
         Print("Asia range FINALIZED - High: ", DoubleToString(AsiaHigh, Digits),
               " | Low: ", DoubleToString(AsiaLow, Digits),
               " | Mid: ", DoubleToString(AsiaMid, Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Update Equal Highs/Lows levels                                    |
//+------------------------------------------------------------------+
void UpdateEqualLevels()
{
   // Find Equal Highs (EQH)
   EQH_Valid = false;
   for(int i = 1; i < LookbackEQ_Bars - 1; i++)
   {
      double h1 = iHigh(Symbol(), PERIOD_M5, i);
      for(int j = i + 1; j < LookbackEQ_Bars; j++)
      {
         double h2 = iHigh(Symbol(), PERIOD_M5, j);
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
   for(int i = 1; i < LookbackEQ_Bars - 1; i++)
   {
      double l1 = iLow(Symbol(), PERIOD_M5, i);
      for(int j = i + 1; j < LookbackEQ_Bars; j++)
      {
         double l2 = iLow(Symbol(), PERIOD_M5, j);
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
      int barsElapsed = iBarShift(Symbol(), PERIOD_M5, sweepTime, false);

      // Guard against invalid bar shift
      if(barsElapsed == -1)
      {
         Print("Sweep invalidated: iBarShift=-1");
         sweepActive = false;
         return;
      }

      if(barsElapsed > ConfirmBars)
      {
         // Timeout - invalidate sweep
         Print("Sweep confirmation TIMEOUT (", barsElapsed, " bars elapsed)");
         sweepActive = false;
         return;
      }

      // Check for confirmation on last closed bar
      double close1 = iClose(Symbol(), PERIOD_M5, 1);

      if(sweepDirection == 1) // Sweep UP -> looking for SELL confirmation
      {
         if(close1 < sweepLow)
         {
            Print(">>> SELL CONFIRMATION DETECTED <<<");
            Print("Close[1]: ", DoubleToString(close1, Digits), " < SweepLow: ", DoubleToString(sweepLow, Digits));
            OpenTrade(OP_SELL);
            sweepActive = false;
         }
      }
      else if(sweepDirection == -1) // Sweep DOWN -> looking for BUY confirmation
      {
         if(close1 > sweepHigh)
         {
            Print(">>> BUY CONFIRMATION DETECTED <<<");
            Print("Close[1]: ", DoubleToString(close1, Digits), " > SweepHigh: ", DoubleToString(sweepHigh, Digits));
            OpenTrade(OP_BUY);
            sweepActive = false;
         }
      }

      return; // Don't look for new sweeps while waiting for confirmation
   }

   // Look for new sweep on last closed bar (bar index 1)
   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   double low1 = iLow(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   // === CHECK FOR SWEEP UP (stop hunt above resistance) ===
   // Build array of resistance levels to check
   double levelsUp[10];
   int countUp = 0;

   if(PDH > 0) { levelsUp[countUp] = PDH; countUp++; }
   if(AsiaRangeValid && AsiaHigh > 0) { levelsUp[countUp] = AsiaHigh; countUp++; }
   if(EQH_Valid && EQH_Level > 0) { levelsUp[countUp] = EQH_Level; countUp++; }

   for(int i = 0; i < countUp; i++)
   {
      double L = levelsUp[i];

      // Sweep condition: High >= L + buffer AND Close < L (rejection)
      if(high1 >= L + SweepBuffer && close1 < L)
      {
         sweepActive = true;
         sweepDirection = 1; // SELL setup
         sweepLevel = L;
         sweepHigh = high1;
         sweepLow = low1;
         sweepTime = iTime(Symbol(), PERIOD_M5, 1);

         // Identify which level was swept
         string levelName = "Unknown";
         if(MathAbs(L - PDH) < 0.01) levelName = "PDH";
         else if(MathAbs(L - AsiaHigh) < 0.01) levelName = "AsiaHigh";
         else if(MathAbs(L - EQH_Level) < 0.01) levelName = "EQH";

         Print("*** SWEEP UP DETECTED ***");
         Print("Level: ", levelName, " at ", DoubleToString(L, Digits));
         Print("High: ", DoubleToString(high1, Digits), " | Close: ", DoubleToString(close1, Digits));
         Print("Waiting for SELL confirmation...");

         return; // One sweep at a time
      }
   }

   // === CHECK FOR SWEEP DOWN (stop hunt below support) ===
   // Build array of support levels to check
   double levelsDown[10];
   int countDown = 0;

   if(PDL > 0) { levelsDown[countDown] = PDL; countDown++; }
   if(AsiaRangeValid && AsiaLow > 0) { levelsDown[countDown] = AsiaLow; countDown++; }
   if(EQL_Valid && EQL_Level > 0) { levelsDown[countDown] = EQL_Level; countDown++; }

   for(int i = 0; i < countDown; i++)
   {
      double L = levelsDown[i];

      // Sweep condition: Low <= L - buffer AND Close > L (rejection)
      if(low1 <= L - SweepBuffer && close1 > L)
      {
         sweepActive = true;
         sweepDirection = -1; // BUY setup
         sweepLevel = L;
         sweepHigh = high1;
         sweepLow = low1;
         sweepTime = iTime(Symbol(), PERIOD_M5, 1);

         // Identify which level was swept
         string levelName = "Unknown";
         if(MathAbs(L - PDL) < 0.01) levelName = "PDL";
         else if(MathAbs(L - AsiaLow) < 0.01) levelName = "AsiaLow";
         else if(MathAbs(L - EQL_Level) < 0.01) levelName = "EQL";

         Print("*** SWEEP DOWN DETECTED ***");
         Print("Level: ", levelName, " at ", DoubleToString(L, Digits));
         Print("Low: ", DoubleToString(low1, Digits), " | Close: ", DoubleToString(close1, Digits));
         Print("Waiting for BUY confirmation...");

         return; // One sweep at a time
      }
   }
}

//+------------------------------------------------------------------+
//| Open trade with proper SL, TP, and lot sizing                     |
//+------------------------------------------------------------------+
void OpenTrade(int orderType)
{
   // Refresh market data
   RefreshRates();

   double entryPrice = 0;
   double slPrice = 0;
   double tpPrice = 0;
   double risk = 0;

   // Calculate entry, SL, and TP based on order type
   if(orderType == OP_SELL)
   {
      entryPrice = Bid;
      slPrice = sweepHigh + SL_Buffer;
      risk = slPrice - entryPrice;

      if(risk <= 0)
      {
         Print("Invalid risk for SELL: ", risk, ". Trade aborted.");
         return;
      }

      tpPrice = entryPrice - (RR * risk);
   }
   else if(orderType == OP_BUY)
   {
      entryPrice = Ask;
      slPrice = sweepLow - SL_Buffer;
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

   // Validate minimum stop level
   double minStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double slDistance = MathAbs(entryPrice - slPrice);
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
   double lots = CalculateLotSize(entryPrice, slPrice);
   if(lots <= 0)
   {
      Print("Invalid lot size calculated: ", lots, ". Trade aborted.");
      return;
   }

   // Normalize prices
   slPrice = NormalizeDouble(slPrice, Digits);
   tpPrice = NormalizeDouble(tpPrice, Digits);

   // Send market order
   int ticket = OrderSend(
      Symbol(),           // Symbol
      orderType,          // Order type (OP_BUY or OP_SELL)
      lots,               // Lot size
      entryPrice,         // Entry price
      SlippagePoints,     // Slippage
      slPrice,            // Stop Loss
      tpPrice,            // Take Profit
      OrderComment,       // Comment
      MagicNumber,        // Magic number
      0,                  // Expiration (0 = GTC)
      clrNONE             // Arrow color
   );

   if(ticket > 0)
   {
      string direction = (orderType == OP_BUY) ? "BUY" : "SELL";
      double riskMoney = AccountBalance() * RiskPercent / 100.0;

      Print("========================================");
      Print("TRADE OPENED SUCCESSFULLY");
      Print("Ticket: ", ticket);
      Print("Direction: ", direction);
      Print("Entry: ", DoubleToString(entryPrice, Digits));
      Print("Stop Loss: ", DoubleToString(slPrice, Digits));
      Print("Take Profit: ", DoubleToString(tpPrice, Digits));
      Print("Lot Size: ", DoubleToString(lots, 2));
      Print("Risk: $", DoubleToString(riskMoney, 2), " (", RiskPercent, "%)");
      Print("Risk/Reward: 1:", RR);
      Print("========================================");
   }
   else
   {
      int error = GetLastError();
      Print("========================================");
      Print("ORDER SEND FAILED");
      Print("Error code: ", error);
      Print("Error description: ", ErrorDescription(error));
      Print("Entry: ", entryPrice, " | SL: ", slPrice, " | TP: ", tpPrice);
      Print("Lots: ", lots);
      Print("========================================");
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                        |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice)
{
   // Calculate SL distance in price
   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance <= 0)
   {
      Print("ERROR: Invalid SL distance: ", slDistance);
      return 0;
   }

   // Get contract specifications
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(tickValue <= 0 || tickSize <= 0)
   {
      Print("ERROR: Invalid tick value (", tickValue, ") or tick size (", tickSize, ")");
      return 0;
   }

   // Calculate risk amount in account currency
   double riskMoney = AccountBalance() * RiskPercent / 100.0;

   // Calculate value per point move
   // For XAUUSD: tickValue is the value of 1 tick (usually 0.01) per lot
   double valuePerPoint = tickValue / tickSize;

   // Calculate lot size
   // lots = riskMoney / (slDistance * valuePerPoint)
   double lots = riskMoney / (slDistance * valuePerPoint);

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
   double requiredMargin = MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lots;
   double freeMargin = AccountFreeMargin();

   if(requiredMargin > freeMargin)
   {
      Print("ERROR: Insufficient margin. Required: ", requiredMargin, " | Available: ", freeMargin);
      return 0;
   }

   Print("Lot calculation: Risk=$", DoubleToString(riskMoney, 2),
         " | SL dist=", DoubleToString(slDistance, Digits),
         " | Lots=", DoubleToString(lots, 2));

   return lots;
}

//+------------------------------------------------------------------+
//| Check if position already open with our magic number              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
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

   datetime todayStart = iTime(Symbol(), PERIOD_D1, 0);

   // Scan history from most recent to oldest
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         // Only count trades closed today
         if(OrderCloseTime() >= todayStart)
         {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            todayPL += profit;

            // Count consecutive losses (from most recent backward)
            if(lastWasLoss)
            {
               if(profit < -0.01) // Loss (small epsilon for floating point)
               {
                  tempConsecutiveLosses++;
               }
               else if(profit > 0.01) // Win
               {
                  lastWasLoss = false; // Stop counting
               }
            }
         }
         else
         {
            break; // Older than today, stop scanning
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
//| Get human-readable error description                              |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
   string errorMsg = "";

   switch(errorCode)
   {
      case 0:    errorMsg = "No error"; break;
      case 1:    errorMsg = "No error returned"; break;
      case 2:    errorMsg = "Common error"; break;
      case 3:    errorMsg = "Invalid trade parameters"; break;
      case 4:    errorMsg = "Trade server is busy"; break;
      case 5:    errorMsg = "Old version of the client terminal"; break;
      case 6:    errorMsg = "No connection with trade server"; break;
      case 7:    errorMsg = "Not enough rights"; break;
      case 8:    errorMsg = "Too frequent requests"; break;
      case 9:    errorMsg = "Malfunctional trade operation"; break;
      case 64:   errorMsg = "Account disabled"; break;
      case 65:   errorMsg = "Invalid account"; break;
      case 128:  errorMsg = "Trade timeout"; break;
      case 129:  errorMsg = "Invalid price"; break;
      case 130:  errorMsg = "Invalid stops"; break;
      case 131:  errorMsg = "Invalid trade volume"; break;
      case 132:  errorMsg = "Market is closed"; break;
      case 133:  errorMsg = "Trade is disabled"; break;
      case 134:  errorMsg = "Not enough money"; break;
      case 135:  errorMsg = "Price changed"; break;
      case 136:  errorMsg = "Off quotes"; break;
      case 137:  errorMsg = "Broker is busy"; break;
      case 138:  errorMsg = "Requote"; break;
      case 139:  errorMsg = "Order is locked"; break;
      case 140:  errorMsg = "Long positions only allowed"; break;
      case 141:  errorMsg = "Too many requests"; break;
      case 145:  errorMsg = "Modification denied because order too close to market"; break;
      case 146:  errorMsg = "Trade context is busy"; break;
      case 147:  errorMsg = "Expirations are denied by broker"; break;
      case 148:  errorMsg = "Amount of open and pending orders has reached the limit"; break;
      case 149:  errorMsg = "Hedging is prohibited"; break;
      case 150:  errorMsg = "Prohibited by FIFO rules"; break;
      default:   errorMsg = "Unknown error"; break;
   }

   return errorMsg;
}
//+------------------------------------------------------------------+
