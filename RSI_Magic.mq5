//+------------------------------------------------------------------+
//|                                                    RSI_Magic.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "RSI Magic EA"
#property link        ""
#property version     "1.00"
#property description "RSI crossover strategy with PROP protection"

#include <Trade\Trade.mqh>

//--- Money Management
input group "Money Management"
input double   RiskPercent          = 1.0;       // Risk per trade (% of equity)
input double   RR                   = 1.5;       // Risk/Reward ratio
input ulong    MagicNumber          = 777001;    // Magic Number
input int      MaxSpreadPoints      = 30;        // Max spread (points)
input int      SlippagePoints       = 10;        // Slippage (points)

//--- RSI
input group "RSI"
input int      RSI_Period           = 5;         // RSI Period
input double   RSI_Overbought       = 90.0;      // RSI Overbought level
input double   RSI_Oversold         = 10.0;      // RSI Oversold level

//--- Entry/Exit
input group "Entry/Exit"
input double   SL_Buffer_Price      = 0.10;      // SL Buffer (price, e.g. 0.10 for XAU)
input int      MaxBarsInTrade       = 3;         // Max bars in trade (time stop)
input bool     OneTradeAtATime      = true;      // One trade at a time

//--- Sessions
input group "Sessions (Server Time)"
input bool     UseSession1          = true;      // Use Session 1
input string   Session1Start        = "08:00";   // Session 1 Start
input string   Session1End          = "11:30";   // Session 1 End
input bool     UseSession2          = true;      // Use Session 2
input string   Session2Start        = "14:00";   // Session 2 Start
input string   Session2End          = "16:30";   // Session 2 End

//--- PROP Protection
input group "PROP Protection"
input double   InitialBalanceForRules = 100000.0;  // Initial balance for rules
input double   DailyLossPct           = 0.05;      // Daily loss % (5%)
input double   MaxLossPct             = 0.10;      // Max loss % (10%)
input double   DailyStopNewTradesAt   = 0.70;     // Stop new trades at % of daily limit
input double   DailyCloseAllAt        = 0.85;     // Close all at % of daily limit
input double   MaxLossStopBuffer      = 500.0;    // Buffer above floor equity
input bool     UseDailyProfitTarget   = false;    // Use daily profit target
input double   DailyProfitTargetPct   = 1.0;      // Daily profit target %

//--- Display
input group "Display"
input bool     ShowInfoPanel         = true;      // Show info panel

//--- Global variables
CTrade trade;
int rsiHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
datetime dailyResetTime = 0;
double peakEquityToday = 0;
double startBalanceToday = 0;
bool permanentlyBlocked = false;
bool dailyBlocked = false;
bool targetReachedToday = false;

//--- Diagnostic counters
int countTimeBlock = 0;
int countSpreadBlock = 0;
int countPropBlock = 0;
int countHasPositionBlock = 0;
int countNoSignalBlock = 0;
datetime lastDailyReport = 0;

//--- Panel objects
string panelPrefix = "RSI_Magic_Panel_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

   // Create RSI indicator
   rsiHandle = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create RSI indicator");
      return INIT_FAILED;
   }

   // Initialize daily tracking
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   dailyResetTime = StructToTime(dt);

   peakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
   startBalanceToday = AccountInfoDouble(ACCOUNT_BALANCE);

   // Create info panel
   if(ShowInfoPanel)
      CreateInfoPanel();

   Print("RSI_Magic initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handle
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);

   // Delete panel objects
   DeleteInfoPanel();

   Print("RSI_Magic deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check daily reset
   CheckDailyReset();

   // Update peak equity
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > peakEquityToday)
      peakEquityToday = currentEquity;

   // Check PROP protection rules
   CheckPropProtection();

   // Check time stop for open positions
   CheckTimeStop();

   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
   bool isNewBar = (currentBarTime != lastBarTime);

   if(isNewBar)
   {
      lastBarTime = currentBarTime;

      // Check for entry signals
      CheckForEntry();

      // Daily diagnostic report (at 01:00)
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour == 1 && dt.min == 0 && TimeCurrent() - lastDailyReport > 3600)
      {
         PrintDailyReport();
         lastDailyReport = TimeCurrent();
      }
   }

   // Update panel
   if(ShowInfoPanel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Check daily reset at 00:00 server time                          |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayMidnight = StructToTime(dt);

   if(todayMidnight > dailyResetTime)
   {
      dailyResetTime = todayMidnight;
      peakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
      startBalanceToday = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyBlocked = false;
      targetReachedToday = false;

      // Reset diagnostic counters
      countTimeBlock = 0;
      countSpreadBlock = 0;
      countPropBlock = 0;
      countHasPositionBlock = 0;
      countNoSignalBlock = 0;

      Print("DAILY RESET: New day started");
   }
}

//+------------------------------------------------------------------+
//| Check PROP protection rules                                      |
//+------------------------------------------------------------------+
void CheckPropProtection()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floorEquity = InitialBalanceForRules * (1.0 - MaxLossPct);
   double dailyLimit = InitialBalanceForRules * DailyLossPct;
   double dailyDD = peakEquityToday - currentEquity;

   // Rule 1: Max loss reached - permanent block
   if(currentEquity <= floorEquity)
   {
      if(!permanentlyBlocked)
      {
         CloseAllPositions();
         permanentlyBlocked = true;
         Print("PROP PROTECTION: MAX LOSS REACHED - PERMANENTLY BLOCKED");
      }
      return;
   }

   // Rule 2: Close to floor - block new trades
   if(currentEquity <= floorEquity + MaxLossStopBuffer)
   {
      if(!dailyBlocked)
      {
         dailyBlocked = true;
         Print("PROP PROTECTION: Near floor equity - new trades blocked");
      }
   }

   // Rule 3: Daily DD close all threshold
   if(dailyDD >= dailyLimit * DailyCloseAllAt)
   {
      CloseAllPositions();
      if(!dailyBlocked)
      {
         dailyBlocked = true;
         Print("PROP PROTECTION: Daily DD close-all threshold reached");
      }
      return;
   }

   // Rule 4: Daily DD stop new trades threshold
   if(dailyDD >= dailyLimit * DailyStopNewTradesAt)
   {
      if(!dailyBlocked)
      {
         dailyBlocked = true;
         Print("PROP PROTECTION: Daily DD stop-new-trades threshold reached");
      }
   }

   // Rule 5: Daily profit target
   if(UseDailyProfitTarget && !targetReachedToday)
   {
      double dailyProfit = currentEquity - (InitialBalanceForRules + (AccountInfoDouble(ACCOUNT_BALANCE) - startBalanceToday));
      double dailyProfitPct = (dailyProfit / InitialBalanceForRules) * 100.0;

      if(dailyProfitPct >= DailyProfitTargetPct)
      {
         CloseAllPositions();
         targetReachedToday = true;
         dailyBlocked = true;
         Print("PROP PROTECTION: Daily profit target reached: ", dailyProfitPct, "%");
      }
   }
}

//+------------------------------------------------------------------+
//| Check time stop for open positions                              |
//+------------------------------------------------------------------+
void CheckTimeStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      // Count bars since position opened
      int barIndex = iBarShift(_Symbol, PERIOD_M1, openTime);
      if(barIndex >= MaxBarsInTrade)
      {
         double positionVolume = PositionGetDouble(POSITION_VOLUME);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         bool closed = false;
         if(posType == POSITION_TYPE_BUY)
            closed = trade.Sell(positionVolume, _Symbol, 0, 0, 0, "TIME-STOP");
         else
            closed = trade.Buy(positionVolume, _Symbol, 0, 0, 0, "TIME-STOP");

         if(closed)
            Print("TIME-STOP close after ", barIndex, " bars. Ticket: ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for entry signals                                         |
//+------------------------------------------------------------------+
void CheckForEntry()
{
   // Check if trading is allowed
   string whyNot = "";
   if(!CanTrade(whyNot))
   {
      // Update diagnostic counters based on reason
      if(StringFind(whyNot, "session") >= 0)
         countTimeBlock++;
      else if(StringFind(whyNot, "Spread") >= 0)
         countSpreadBlock++;
      else if(StringFind(whyNot, "blocked") >= 0 || StringFind(whyNot, "PROP") >= 0)
         countPropBlock++;
      else if(StringFind(whyNot, "position") >= 0)
         countHasPositionBlock++;

      return;
   }

   // Get RSI values
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)
   {
      Print("ERROR: Failed to copy RSI buffer");
      return;
   }

   double rsi1 = rsi[1];
   double rsi2 = rsi[2];

   // Get price data
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(_Symbol, PERIOD_M1, 0, 3, high) < 3) return;
   if(CopyLow(_Symbol, PERIOD_M1, 0, 3, low) < 3) return;
   if(CopyClose(_Symbol, PERIOD_M1, 0, 3, close) < 3) return;

   // Check for SELL signal: RSI[1] > Overbought AND RSI[2] <= Overbought
   if(rsi1 > RSI_Overbought && rsi2 <= RSI_Overbought)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = high[1] + SL_Buffer_Price;
      double slDistance = sl - entry;
      double tp = entry - (RR * slDistance);

      OpenTrade(ORDER_TYPE_SELL, entry, sl, tp);
      return;
   }

   // Check for BUY signal: RSI[1] < Oversold AND RSI[2] >= Oversold
   if(rsi1 < RSI_Oversold && rsi2 >= RSI_Oversold)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = low[1] - SL_Buffer_Price;
      double slDistance = entry - sl;
      double tp = entry + (RR * slDistance);

      OpenTrade(ORDER_TYPE_BUY, entry, sl, tp);
      return;
   }

   // No signal
   countNoSignalBlock++;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                     |
//+------------------------------------------------------------------+
bool CanTrade(string &reason)
{
   // Check permanent block
   if(permanentlyBlocked)
   {
      reason = "PROP MAX LOSS - permanently blocked";
      return false;
   }

   // Check daily block
   if(dailyBlocked)
   {
      reason = "PROP daily blocked";
      return false;
   }

   // Check target reached
   if(targetReachedToday)
   {
      reason = "Daily profit target reached";
      return false;
   }

   // Check session
   if(!IsInSession())
   {
      reason = "Out of session";
      return false;
   }

   // Check spread
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadPoints > MaxSpreadPoints)
   {
      reason = "Spread too high: " + IntegerToString(spreadPoints);
      return false;
   }

   // Check if already in position
   if(OneTradeAtATime && HasOpenPosition())
   {
      reason = "Already in position (OneTradeAtATime)";
      return false;
   }

   reason = "OK";
   return true;
}

//+------------------------------------------------------------------+
//| Check if current time is in trading session                     |
//+------------------------------------------------------------------+
bool IsInSession()
{
   if(!UseSession1 && !UseSession2)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentMinutes = dt.hour * 60 + dt.min;

   if(UseSession1)
   {
      int s1Start = TimeStringToMinutes(Session1Start);
      int s1End = TimeStringToMinutes(Session1End);
      if(currentMinutes >= s1Start && currentMinutes <= s1End)
         return true;
   }

   if(UseSession2)
   {
      int s2Start = TimeStringToMinutes(Session2Start);
      int s2End = TimeStringToMinutes(Session2End);
      if(currentMinutes >= s2Start && currentMinutes <= s2End)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Convert time string to minutes                                  |
//+------------------------------------------------------------------+
int TimeStringToMinutes(string timeStr)
{
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   if(count != 2) return 0;

   int hours = (int)StringToInteger(parts[0]);
   int minutes = (int)StringToInteger(parts[1]);
   return hours * 60 + minutes;
}

//+------------------------------------------------------------------+
//| Check if has open position                                      |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Open trade with calculated lot size                             |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType, double entry, double sl, double tp)
{
   // Calculate lot size based on risk
   double lots = CalculateLotSize(orderType, entry, sl);
   if(lots <= 0)
   {
      Print("ERROR: Invalid lot size calculated: ", lots);
      return;
   }

   // Normalize prices
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   // Open position
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(lots, _Symbol, 0, sl, tp, "RSI_Magic_BUY");
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      result = trade.Sell(lots, _Symbol, 0, sl, tp, "RSI_Magic_SELL");
   }

   if(result)
   {
      Print("Trade opened: ", EnumToString(orderType), " Lots: ", lots, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("ERROR: Failed to open trade. Error: ", GetLastError());
      Print("Trade details: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                     |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType, double entry, double sl)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (RiskPercent / 100.0);

   // Calculate loss per 1 lot
   double lossPerLot = 0;
   double priceOpen = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!OrderCalcProfit(orderType, _Symbol, 1.0, priceOpen, sl, lossPerLot))
   {
      Print("ERROR: OrderCalcProfit failed");
      return 0;
   }

   lossPerLot = MathAbs(lossPerLot);
   if(lossPerLot <= 0)
   {
      Print("ERROR: Invalid loss per lot: ", lossPerLot);
      return 0;
   }

   // Calculate lots
   double lots = riskAmount / lossPerLot;

   // Normalize to volume step
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volumeMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / volumeStep) * volumeStep;
   lots = MathMax(lots, volumeMin);
   lots = MathMin(lots, volumeMax);

   return lots;
}

//+------------------------------------------------------------------+
//| Close all positions with this magic number                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      trade.PositionClose(ticket);
      Print("Position closed by PROP protection. Ticket: ", ticket);
   }
}

//+------------------------------------------------------------------+
//| Print daily diagnostic report                                   |
//+------------------------------------------------------------------+
void PrintDailyReport()
{
   Print("DAILY BLOCKS: time=", countTimeBlock,
         " spread=", countSpreadBlock,
         " prop=", countPropBlock,
         " hasPosition=", countHasPositionBlock,
         " noSignal=", countNoSignalBlock);
}

//+------------------------------------------------------------------+
//| Create info panel                                               |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   int xOffset = 10;
   int yOffset = 20;
   int lineHeight = 18;
   int panelWidth = 350;

   // Create background
   string bgName = panelPrefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, xOffset);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 320);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   // Create labels
   string labels[] = {
      "Status", "ServerTime", "InSession", "Spread",
      "RSI_1", "Signal", "TradesToday", "DailyDD",
      "TotalDD", "ProfitToday", "WhyNot", "Blank1", "Blank2"
   };

   for(int i = 0; i < ArraySize(labels); i++)
   {
      string labelName = panelPrefix + labels[i];
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xOffset + 5);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yOffset + 5 + (i * lineHeight));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labels[i] + ": Loading...");
   }
}

//+------------------------------------------------------------------+
//| Update info panel                                               |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   if(!ShowInfoPanel) return;

   // Get current data
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floorEquity = InitialBalanceForRules * (1.0 - MaxLossPct);
   double dailyLimit = InitialBalanceForRules * DailyLossPct;
   double dailyDD = peakEquityToday - currentEquity;
   double dailyDDPct = (dailyDD / InitialBalanceForRules) * 100.0;
   double totalDD = InitialBalanceForRules - currentEquity;
   double totalDDPct = (totalDD / InitialBalanceForRules) * 100.0;

   double profitToday = currentEquity - (InitialBalanceForRules + (AccountInfoDouble(ACCOUNT_BALANCE) - startBalanceToday));
   double profitTodayPct = (profitToday / InitialBalanceForRules) * 100.0;

   bool inSession = IsInSession();
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Get RSI
   double rsi[];
   ArraySetAsSeries(rsi, true);
   double rsi1 = 0;
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) >= 2)
   {
      rsi1 = rsi[1];
   }

   // Determine status
   string status = "READY";
   if(permanentlyBlocked)
      status = "BLOCKED MAX LOSS";
   else if(targetReachedToday)
      status = "TARGET REACHED";
   else if(dailyBlocked)
      status = "BLOCKED DAILY";
   else if(HasOpenPosition())
      status = "POSITION OPEN";
   else if(!inSession)
      status = "OUT OF SESSION";
   else if(spreadPoints > MaxSpreadPoints)
      status = "SPREAD TOO HIGH";

   // Determine signal
   string signal = "none";
   string whyNot = "";
   if(CanTrade(whyNot))
   {
      double rsi2Val = 0;
      double rsiArr[];
      ArraySetAsSeries(rsiArr, true);
      if(CopyBuffer(rsiHandle, 0, 0, 3, rsiArr) >= 3)
      {
         rsi1 = rsiArr[1];
         rsi2Val = rsiArr[2];

         if(rsi1 > RSI_Overbought && rsi2Val <= RSI_Overbought)
            signal = "SELL";
         else if(rsi1 < RSI_Oversold && rsi2Val >= RSI_Oversold)
            signal = "BUY";
      }
   }

   // Count trades today (simplified - count closed deals)
   int tradesToday = 0;
   // This would require HistorySelect and deal counting - simplified for now

   // Update labels
   ObjectSetString(0, panelPrefix + "Status", OBJPROP_TEXT, "Status: " + status);
   ObjectSetString(0, panelPrefix + "ServerTime", OBJPROP_TEXT, "Server: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   ObjectSetString(0, panelPrefix + "InSession", OBJPROP_TEXT, "InSession: " + (inSession ? "1" : "0"));
   ObjectSetString(0, panelPrefix + "Spread", OBJPROP_TEXT, StringFormat("Spread: %d pts", spreadPoints));
   ObjectSetString(0, panelPrefix + "RSI_1", OBJPROP_TEXT, StringFormat("RSI[1]: %.1f (OB:%.0f OS:%.0f)", rsi1, RSI_Overbought, RSI_Oversold));
   ObjectSetString(0, panelPrefix + "Signal", OBJPROP_TEXT, "Signal: " + signal);
   ObjectSetString(0, panelPrefix + "TradesToday", OBJPROP_TEXT, StringFormat("Trades today: %d", tradesToday));
   ObjectSetString(0, panelPrefix + "DailyDD", OBJPROP_TEXT, StringFormat("Daily DD: %.2f%% / %.2f%%", dailyDDPct, DailyLossPct * 100));
   ObjectSetString(0, panelPrefix + "TotalDD", OBJPROP_TEXT, StringFormat("Total DD: %.2f%% (Floor: %.2f)", totalDDPct, floorEquity));
   ObjectSetString(0, panelPrefix + "ProfitToday", OBJPROP_TEXT, StringFormat("Profit today: %.2f%%", profitTodayPct));
   ObjectSetString(0, panelPrefix + "WhyNot", OBJPROP_TEXT, "Why not: " + whyNot);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Delete info panel                                               |
//+------------------------------------------------------------------+
void DeleteInfoPanel()
{
   string labels[] = {
      "BG", "Status", "ServerTime", "InSession", "Spread",
      "RSI_1", "Signal", "TradesToday", "DailyDD",
      "TotalDD", "ProfitToday", "WhyNot", "Blank1", "Blank2"
   };

   for(int i = 0; i < ArraySize(labels); i++)
   {
      string objName = panelPrefix + labels[i];
      ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
