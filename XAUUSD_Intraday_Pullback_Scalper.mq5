//+------------------------------------------------------------------+
//|                          XAUUSD_Intraday_Pullback_Scalper.mq5    |
//|                                                                  |
//|  Scalping intraday XAUUSD M5 con pullback su EMA20             |
//|  Trend filter H1, prop-safe equity protection                    |
//+------------------------------------------------------------------+
#property copyright "ScaleF Trading"
#property link      ""
#property version   "1.11"
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

//--- Input Group: Display
input group "=== Display ==="
input bool     ShowInfoPanel      = true;     // Show info panel

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

//--- Info panel variables
string         LastStatusMessage  = "Initializing...";
string         TrendStatus        = "Neutral";
color          PanelColor         = clrDarkSlateGray;

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

   //--- Set timer for panel updates (every 1 second)
   EventSetTimer(1);

   //--- Create info panel immediately
   if(ShowInfoPanel)
      UpdateInfoPanel();

   Print("XAUUSD Intraday Pullback Scalper initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Kill timer
   EventKillTimer();

   //--- Release indicator handles
   if(HandleEMA_M5 != INVALID_HANDLE)
      IndicatorRelease(HandleEMA_M5);
   if(HandleATR_M5 != INVALID_HANDLE)
      IndicatorRelease(HandleATR_M5);
   if(HandleFastEMA_H1 != INVALID_HANDLE)
      IndicatorRelease(HandleFastEMA_H1);
   if(HandleSlowEMA_H1 != INVALID_HANDLE)
      IndicatorRelease(HandleSlowEMA_H1);

   //--- Remove info panel objects
   ObjectsDeleteAll(0, "InfoPanel_");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Timer function (updates panel every second)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(ShowInfoPanel)
      UpdateInfoPanel();
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

   //--- Update info panel
   if(ShowInfoPanel)
      UpdateInfoPanel();
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
//| Update info panel on chart                                       |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   //--- Calculate current statistics
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfitPct = ((currentEquity - PeakEquityToday) / InitialBalance) * 100.0;
   double equityDrawdownPct = ((PeakEquityToday - currentEquity) / InitialBalance) * 100.0;
   double totalDrawdownPct = ((InitialBalance - currentEquity) / InitialBalance) * 100.0;

   //--- Get current spread
   double spread = GetSpreadInPoints();

   //--- Check trading session
   bool inSession = IsInTradingSession();

   //--- Get trend direction
   string trendStr = "N/A";
   color trendColor = clrGray;

   if(UseTrendFilter && HandleFastEMA_H1 != INVALID_HANDLE && HandleSlowEMA_H1 != INVALID_HANDLE)
   {
      double fastEMA_h1[], slowEMA_h1[];
      ArraySetAsSeries(fastEMA_h1, true);
      ArraySetAsSeries(slowEMA_h1, true);

      if(CopyBuffer(HandleFastEMA_H1, 0, 0, 1, fastEMA_h1) >= 1 &&
         CopyBuffer(HandleSlowEMA_H1, 0, 0, 1, slowEMA_h1) >= 1)
      {
         if(fastEMA_h1[0] > slowEMA_h1[0])
         {
            trendStr = "BULLISH";
            trendColor = clrLime;
         }
         else
         {
            trendStr = "BEARISH";
            trendColor = clrRed;
         }
      }
   }
   else if(!UseTrendFilter)
   {
      trendStr = "OFF";
      trendColor = clrYellow;
   }

   //--- Determine EA status and reason
   string statusMsg = "";
   color statusColor = clrLime;

   int openPositions = CountOpenPositions();

   if(openPositions > 0)
   {
      statusMsg = "POSITION OPEN";
      statusColor = clrDodgerBlue;
   }
   else if(equityDrawdownPct >= DailyLossPct * 0.85)
   {
      statusMsg = "STOPPED: Daily Loss 85%";
      statusColor = clrRed;
   }
   else if(totalDrawdownPct >= MaxLossPct * 0.85)
   {
      statusMsg = "STOPPED: Total Loss 85%";
      statusColor = clrRed;
   }
   else if(equityDrawdownPct >= DailyLossPct * 0.70)
   {
      statusMsg = "BLOCKED: Daily Loss 70%";
      statusColor = clrOrange;
   }
   else if(totalDrawdownPct >= MaxLossPct * 0.70)
   {
      statusMsg = "BLOCKED: Total Loss 70%";
      statusColor = clrOrange;
   }
   else if(UseDailyProfitTarget && dailyProfitPct >= DailyProfitTarget)
   {
      statusMsg = "TARGET REACHED";
      statusColor = clrGold;
   }
   else if(TradesToday >= MaxTradesPerDay)
   {
      statusMsg = "MAX TRADES REACHED";
      statusColor = clrOrange;
   }
   else if(!inSession)
   {
      statusMsg = "OUT OF SESSION";
      statusColor = clrGray;
   }
   else if(spread > MaxSpreadPoints)
   {
      statusMsg = "SPREAD TOO HIGH";
      statusColor = clrOrange;
   }
   else
   {
      statusMsg = "READY TO TRADE";
      statusColor = clrLime;
   }

   //--- Panel positioning (top right corner)
   int xOffset = 10;
   int yOffset = 20;
   int lineHeight = 18;
   int panelWidth = 300;
   int panelHeight = 290;

   //--- Create background panel
   string panelName = "InfoPanel_Background";
   ObjectDelete(0, panelName); // Delete and recreate to ensure visibility
   ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, xOffset);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, panelName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, panelName, OBJPROP_BACK, true);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, false);

   //--- Create text labels
   int line = 0;
   int labelX = panelWidth - 15; // Position from right edge of panel

   //--- Title
   CreateLabel("InfoPanel_Title", "XAUUSD SCALPER v1.11", xOffset + labelX, yOffset + (line++ * lineHeight) + 8,
               clrWhite, 10, "Arial Bold");
   line++; // Skip line

   //--- Status
   CreateLabel("InfoPanel_StatusLbl", "Status:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_StatusVal", statusMsg, xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8,
               statusColor, 8, "Arial Bold");

   //--- Trend H1
   CreateLabel("InfoPanel_TrendLbl", "Trend H1:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_TrendVal", trendStr, xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8,
               trendColor, 8, "Arial Bold");

   line++; // Skip line

   //--- Equity & Balance
   CreateLabel("InfoPanel_EquityLbl", "Equity:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_EquityVal", DoubleToString(currentEquity, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY),
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, clrAqua, 8, "Arial");

   CreateLabel("InfoPanel_BalanceLbl", "Balance:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_BalanceVal", DoubleToString(InitialBalance, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY),
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, clrAqua, 8, "Arial");

   line++; // Skip line

   //--- Daily profit/loss
   color profitColor = dailyProfitPct >= 0 ? clrLime : clrRed;
   CreateLabel("InfoPanel_DailyPLLbl", "Daily P/L:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_DailyPLVal", (dailyProfitPct >= 0 ? "+" : "") + DoubleToString(dailyProfitPct, 2) + "%",
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, profitColor, 8, "Arial Bold");

   //--- Daily drawdown
   color ddColor = equityDrawdownPct < DailyLossPct * 0.5 ? clrLime :
                   equityDrawdownPct < DailyLossPct * 0.7 ? clrYellow : clrRed;
   CreateLabel("InfoPanel_DailyDDLbl", "Daily DD:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_DailyDDVal", DoubleToString(equityDrawdownPct, 2) + "% / " +
               DoubleToString(DailyLossPct * 100, 1) + "%",
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, ddColor, 8, "Arial");

   //--- Total drawdown
   color totalDDColor = totalDrawdownPct < MaxLossPct * 0.5 ? clrLime :
                        totalDrawdownPct < MaxLossPct * 0.7 ? clrYellow : clrRed;
   CreateLabel("InfoPanel_TotalDDLbl", "Total DD:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_TotalDDVal", DoubleToString(totalDrawdownPct, 2) + "% / " +
               DoubleToString(MaxLossPct * 100, 1) + "%",
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, totalDDColor, 8, "Arial");

   line++; // Skip line

   //--- Trades today
   CreateLabel("InfoPanel_TradesLbl", "Trades:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_TradesVal", IntegerToString(TradesToday) + " / " + IntegerToString(MaxTradesPerDay),
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, clrAqua, 8, "Arial");

   //--- Open positions
   CreateLabel("InfoPanel_PosLbl", "Open Pos:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_PosVal", IntegerToString(openPositions),
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, clrAqua, 8, "Arial");

   //--- Spread
   color spreadColor = spread <= MaxSpreadPoints * 0.7 ? clrLime :
                       spread <= MaxSpreadPoints ? clrYellow : clrRed;
   CreateLabel("InfoPanel_SpreadLbl", "Spread:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_SpreadVal", DoubleToString(spread, 1) + " / " + IntegerToString(MaxSpreadPoints) + " pts",
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, spreadColor, 8, "Arial");

   line++; // Skip line

   //--- Session status
   CreateLabel("InfoPanel_SessionLbl", "Session:", xOffset + labelX, yOffset + (line * lineHeight) + 8,
               clrWhite, 8, "Arial");
   CreateLabel("InfoPanel_SessionVal", inSession ? "ACTIVE" : "CLOSED",
               xOffset + labelX - 65, yOffset + (line++ * lineHeight) + 8, inSession ? clrLime : clrGray, 8, "Arial Bold");

   //--- Redraw chart
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create or update text label                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//+------------------------------------------------------------------+
