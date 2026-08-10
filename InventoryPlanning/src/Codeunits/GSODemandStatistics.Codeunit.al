namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Purchases.History;

/// <summary>
/// The single demand-statistics engine behind all four calculators. One pass
/// over Item Ledger Entries yields the full superset of statistics the four
/// standalone apps computed separately: average daily demand, standard
/// deviation, observations, ADI and CV². Lead time resolution is
/// replenishment-system aware, with standard deviation from receipt history
/// for purchased items.
///
/// SingleInstance with a short-TTL per-item cache: "Run All" and the planning
/// worksheet ask for the same item's statistics up to four times (safety
/// stock, reorder point, EOQ, advisor); the cache turns that into one ILE
/// scan per item. The cache invalidates after 5 minutes, when the window
/// changes, or via ClearCache.
///
/// Conventions:
/// - Demand is netted per day: sales minus same-day returns. A day whose net
///   demand is zero or negative counts as a zero-demand calendar day.
/// - When "Count Consumption as Demand" is enabled in setup, Consumption and
///   Assembly Consumption entries count as demand alongside sales, so
///   manufactured components get planned from their real usage.
/// - Mean and variance are computed over ALL calendar days in the window
///   (zero-demand days count toward the divisor), so the daily rate lines up
///   with a calendar-day lead time.
/// - CV² is the squared coefficient of variation of the per-day demand SIZES.
/// - Windows are anchored to WorkDate(), which equals today in production but
///   follows the demo date in evaluation companies, so trials see results.
/// - Purchase lead time averages receipts from the trailing two years: enough
///   samples for stability without scanning unbounded history.
/// </summary>
codeunit 73030585 "GSO Demand Statistics"
{
    SingleInstance = true;
    Permissions = tabledata "GSO Setup" = ri,
                  tabledata "Stockkeeping Unit" = r;

    var
        CachedRecentAvg: Dictionary of [Code[20], Decimal];
        CachedSKUCount: Dictionary of [Code[20], Integer];
        CachedAvg: Dictionary of [Code[20], Decimal];
        CachedStdDev: Dictionary of [Code[20], Decimal];
        CachedObs: Dictionary of [Code[20], Integer];
        CachedADI: Dictionary of [Code[20], Decimal];
        CachedCV2: Dictionary of [Code[20], Decimal];
        CachedLTAvg: Dictionary of [Code[20], Decimal];
        CachedLTStd: Dictionary of [Code[20], Decimal];
        CacheWindowDays: Integer;
        CacheIncludeConsumption: Boolean;
        CacheCreatedAt: DateTime;
        BackDaysFormulaLbl: Label '<-%1D>', Locked = true, Comment = '%1 = number of days; language-independent date formula';
        TrendUpLbl: Label 'Warning: trailing %1-day demand runs %2%% above the full-window average — history-based values lag an upward trend.', Comment = '%1 = recent window days, %2 = deviation percent';
        TrendDownLbl: Label 'Warning: trailing %1-day demand runs %2%% below the full-window average — history may overstate future demand (phase-out?).', Comment = '%1 = recent window days, %2 = deviation percent';
        SKUNoteLbl: Label 'Note: %1 stockkeeping unit(s) exist for this item; standard planning reads SKU values at those locations, not these item-card values.', Comment = '%1 = number of stockkeeping units';

    /// <summary>
    /// Computes all demand statistics for an item over the given history window.
    /// Served from the per-item cache when the same item and window were
    /// computed within the last 5 minutes.
    /// </summary>
    /// <param name="ItemNo">The item to analyse.</param>
    /// <param name="WindowDays">History window in calendar days, ending on the work date.</param>
    /// <param name="AvgDemand">Out: mean daily demand over all calendar days.</param>
    /// <param name="StdDev">Out: standard deviation of daily demand (sample, n-1).</param>
    /// <param name="Observations">Out: number of days that had net demand.</param>
    /// <param name="ADI">Out: average demand interval (calendar days / demand days).</param>
    /// <param name="CV2">Out: squared coefficient of variation of per-day demand sizes.</param>
    procedure ComputeDemandStats(ItemNo: Code[20]; WindowDays: Integer; var AvgDemand: Decimal; var StdDev: Decimal; var Observations: Integer; var ADI: Decimal; var CV2: Decimal)
    var
        Setup: Record "GSO Setup";
        ItemLedgerEntry: Record "Item Ledger Entry";
        GSOMath: Codeunit "GSO Math";
        DailyDemand: Dictionary of [Date, Decimal];
        WindowStart: Date;
        RecentStart: Date;
        SumRecentQty: Decimal;
        CalendarDays: Integer;
        SellingDays: Integer;
        SumQty: Decimal;
        SumSqQty: Decimal;
        Mean: Decimal;
        Variance: Decimal;
        MeanSize: Decimal;
        SumSqDiff: Decimal;
        Qty: Decimal;
        DemandDate: Date;
    begin
        AvgDemand := 0;
        StdDev := 0;
        Observations := 0;
        ADI := 0;
        CV2 := 0;

        Setup.GetSetup();
        EnsureCacheValid(WindowDays, Setup."Include Consumption Demand");

        if CachedAvg.ContainsKey(ItemNo) then begin
            AvgDemand := CachedAvg.Get(ItemNo);
            StdDev := CachedStdDev.Get(ItemNo);
            Observations := CachedObs.Get(ItemNo);
            ADI := CachedADI.Get(ItemNo);
            CV2 := CachedCV2.Get(ItemNo);
            exit;
        end;

        WindowStart := CalcDate(StrSubstNo(BackDaysFormulaLbl, WindowDays), WorkDate());
        CalendarDays := WorkDate() - WindowStart + 1;
        if CalendarDays <= 0 then
            exit;

        ItemLedgerEntry.SetCurrentKey("Item No.", "Posting Date");
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Posting Date", WindowStart, WorkDate());
        if Setup."Include Consumption Demand" then
            ItemLedgerEntry.SetFilter("Entry Type", '%1|%2|%3',
                ItemLedgerEntry."Entry Type"::Sale,
                ItemLedgerEntry."Entry Type"::Consumption,
                ItemLedgerEntry."Entry Type"::"Assembly Consumption")
        else
            ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Sale);
        ItemLedgerEntry.SetLoadFields("Posting Date", Quantity);
        if ItemLedgerEntry.FindSet() then
            repeat
                // Outbound entries post negative; flip so demand is positive.
                // Returns/reversals post positive and flip to negative, netting
                // against the same day's demand instead of being ignored.
                Qty := -ItemLedgerEntry.Quantity;
                if DailyDemand.ContainsKey(ItemLedgerEntry."Posting Date") then
                    DailyDemand.Set(ItemLedgerEntry."Posting Date", DailyDemand.Get(ItemLedgerEntry."Posting Date") + Qty)
                else
                    DailyDemand.Add(ItemLedgerEntry."Posting Date", Qty);
            until ItemLedgerEntry.Next() = 0;

        // A day whose net demand is zero or negative (returns exceeded sales)
        // is a zero-demand calendar day, not a selling day. The trailing
        // sub-window feeds the trend diagnostic.
        RecentStart := WorkDate() - RecentWindowDays(WindowDays) + 1;
        foreach DemandDate in DailyDemand.Keys() do begin
            Qty := DailyDemand.Get(DemandDate);
            if Qty > 0 then begin
                SellingDays += 1;
                SumQty += Qty;
                SumSqQty += Qty * Qty;
                if DemandDate >= RecentStart then
                    SumRecentQty += Qty;
            end;
        end;

        if SellingDays > 0 then begin
            Observations := SellingDays;

            // Daily mean/variance over all calendar days (zero days count).
            Mean := SumQty / CalendarDays;
            if CalendarDays > 1 then
                Variance := (SumSqQty - CalendarDays * Mean * Mean) / (CalendarDays - 1)
            else
                Variance := 0;
            if Variance < 0 then
                Variance := 0;
            AvgDemand := Mean;
            StdDev := GSOMath.Sqrt(Variance);

            // ADI: mean calendar days between demand days.
            ADI := CalendarDays / SellingDays;

            // CV²: variability of demand sizes on the days demand occurs.
            MeanSize := SumQty / SellingDays;
            if MeanSize > 0 then begin
                foreach DemandDate in DailyDemand.Keys() do begin
                    Qty := DailyDemand.Get(DemandDate);
                    if Qty > 0 then
                        SumSqDiff += Power(Qty - MeanSize, 2);
                end;
                CV2 := (SumSqDiff / SellingDays) / Power(MeanSize, 2);
            end;
        end;

        CachedAvg.Set(ItemNo, AvgDemand);
        CachedStdDev.Set(ItemNo, StdDev);
        CachedObs.Set(ItemNo, Observations);
        CachedADI.Set(ItemNo, ADI);
        CachedCV2.Set(ItemNo, CV2);
        CachedRecentAvg.Set(ItemNo, SumRecentQty / RecentWindowDays(WindowDays));
    end;

    /// <summary>
    /// Resolves the replenishment lead time for an item: purchase receipt
    /// history first for purchased items (with standard deviation), the item's
    /// Lead Time Calculation as fallback and for produced/assembled items, then
    /// the setup fallback. Used by BOTH safety stock and reorder point so the
    /// two always agree on the lead time for an item.
    /// </summary>
    /// <param name="Item">The item to resolve lead time for.</param>
    /// <param name="FallbackDays">Used when no other source yields a value.</param>
    /// <param name="LeadTimeDays">Out: resolved lead time in days.</param>
    /// <param name="LeadTimeStdDev">Out: std deviation of receipt lead times (purchase only).</param>
    /// <param name="LeadTimeSource">Out: human-readable source of the value.</param>
    procedure ComputeLeadTime(Item: Record Item; FallbackDays: Integer; var LeadTimeDays: Decimal; var LeadTimeStdDev: Decimal; var LeadTimeSource: Text[50])
    var
        PurchaseHistoryLbl: Label 'Purchase receipt history';
        ItemLeadTimeLbl: Label 'Item Lead Time Calculation';
        ManufacturingLbl: Label 'Item Lead Time Calculation (manufacturing)';
        AssemblyLbl: Label 'Item Lead Time Calculation (assembly)';
        SetupFallbackLbl: Label 'Setup fallback';
    begin
        LeadTimeDays := 0;
        LeadTimeStdDev := 0;
        LeadTimeSource := '';

        case Item."Replenishment System" of
            Item."Replenishment System"::Purchase:
                begin
                    ComputePurchaseLeadTime(Item."No.", LeadTimeDays, LeadTimeStdDev);
                    if LeadTimeDays > 0 then
                        LeadTimeSource := PurchaseHistoryLbl
                    else begin
                        LeadTimeDays := DaysFromDateFormula(Item."Lead Time Calculation");
                        LeadTimeStdDev := 0;
                        if LeadTimeDays > 0 then
                            LeadTimeSource := ItemLeadTimeLbl;
                    end;
                end;
            Item."Replenishment System"::"Prod. Order":
                begin
                    LeadTimeDays := DaysFromDateFormula(Item."Lead Time Calculation");
                    if LeadTimeDays > 0 then
                        LeadTimeSource := ManufacturingLbl;
                end;
            Item."Replenishment System"::Assembly:
                begin
                    LeadTimeDays := DaysFromDateFormula(Item."Lead Time Calculation");
                    if LeadTimeDays > 0 then
                        LeadTimeSource := AssemblyLbl;
                end;
        end;

        if LeadTimeDays <= 0 then begin
            LeadTimeDays := FallbackDays;
            LeadTimeStdDev := 0;
            LeadTimeSource := SetupFallbackLbl;
        end;
    end;

    /// <summary>
    /// Mean and standard deviation of order-to-receipt days over posted
    /// purchase receipt lines for the item from the trailing two years.
    /// Cached per item alongside the demand statistics.
    /// </summary>
    procedure ComputePurchaseLeadTime(ItemNo: Code[20]; var AvgLeadTime: Decimal; var StdDev: Decimal)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        GSOMath: Codeunit "GSO Math";
        SumLT: Decimal;
        SumSqLT: Decimal;
        n: Integer;
        LTDays: Decimal;
        Mean: Decimal;
        Variance: Decimal;
    begin
        AvgLeadTime := 0;
        StdDev := 0;

        if CachedLTAvg.ContainsKey(ItemNo) then begin
            AvgLeadTime := CachedLTAvg.Get(ItemNo);
            StdDev := CachedLTStd.Get(ItemNo);
            exit;
        end;

        PurchRcptLine.SetRange("No.", ItemNo);
        PurchRcptLine.SetRange(Type, PurchRcptLine.Type::Item);
        PurchRcptLine.SetFilter("Posting Date", '>=%1', CalcDate('<-2Y>', WorkDate()));
        PurchRcptLine.SetLoadFields("Order Date", "Posting Date");
        if PurchRcptLine.FindSet() then
            repeat
                if (PurchRcptLine."Order Date" <> 0D) and (PurchRcptLine."Posting Date" <> 0D) then begin
                    LTDays := PurchRcptLine."Posting Date" - PurchRcptLine."Order Date";
                    if LTDays >= 0 then begin
                        SumLT += LTDays;
                        SumSqLT += LTDays * LTDays;
                        n += 1;
                    end;
                end;
            until PurchRcptLine.Next() = 0;

        if n > 0 then begin
            Mean := SumLT / n;
            if n > 1 then
                Variance := (SumSqLT - n * Mean * Mean) / (n - 1)
            else
                Variance := 0;
            if Variance < 0 then
                Variance := 0;

            AvgLeadTime := Mean;
            StdDev := GSOMath.Sqrt(Variance);
        end;

        CachedLTAvg.Set(ItemNo, AvgLeadTime);
        CachedLTStd.Set(ItemNo, StdDev);
    end;

    /// <summary>
    /// Days represented by a date formula, evaluated from the work date.
    /// Empty formula = 0.
    /// </summary>
    procedure DaysFromDateFormula(DF: DateFormula): Decimal
    var
        BaseDate: Date;
    begin
        if Format(DF) = '' then
            exit(0);
        BaseDate := WorkDate();
        exit(CalcDate(DF, BaseDate) - BaseDate);
    end;

    /// <summary>
    /// Single source of truth for "is this item make-to-order": Make-to-Order
    /// manufacturing policy or Order reordering policy — supply pegs to a single
    /// demand, so there is no stock level for a reorder point to defend.
    /// </summary>
    procedure IsMakeToOrder(Item: Record Item): Boolean
    begin
        if Item."Manufacturing Policy" = Item."Manufacturing Policy"::"Make-to-Order" then
            exit(true);
        if Item."Reordering Policy" = Item."Reordering Policy"::Order then
            exit(true);
        exit(false);
    end;

    /// <summary>
    /// Clears the statistics cache. Call after posting demand or changing
    /// setup when a recalculation must see the change immediately.
    /// </summary>
    procedure ClearCache()
    begin
        Clear(CachedAvg);
        Clear(CachedStdDev);
        Clear(CachedObs);
        Clear(CachedADI);
        Clear(CachedCV2);
        Clear(CachedRecentAvg);
        Clear(CachedSKUCount);
        Clear(CachedLTAvg);
        Clear(CachedLTStd);
        CacheCreatedAt := CurrentDateTime();
    end;

    /// <summary>
    /// The trailing sub-window used by the trend diagnostic: a quarter of the
    /// history window, never less than 30 days, never more than the window.
    /// </summary>
    procedure RecentWindowDays(WindowDays: Integer): Integer
    var
        RecentDays: Integer;
    begin
        RecentDays := WindowDays div 4;
        if RecentDays < 30 then
            RecentDays := 30;
        if RecentDays > WindowDays then
            RecentDays := WindowDays;
        exit(RecentDays);
    end;

    /// <summary>
    /// Percent deviation of the trailing sub-window's daily demand from the
    /// full-window average: +50 means recent demand runs 50% above the
    /// average the calculators use. 0 when there is no usable history.
    /// </summary>
    procedure ComputeTrendPct(ItemNo: Code[20]; WindowDays: Integer): Decimal
    var
        AvgDemand: Decimal;
        StdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
    begin
        ComputeDemandStats(ItemNo, WindowDays, AvgDemand, StdDev, Observations, ADI, CV2);
        if AvgDemand <= 0 then
            exit(0);
        if not CachedRecentAvg.ContainsKey(ItemNo) then
            exit(0);
        exit((CachedRecentAvg.Get(ItemNo) - AvgDemand) / AvgDemand * 100);
    end;

    /// <summary>
    /// Number of Stockkeeping Units defined for the item (cached). Standard
    /// planning reads SKU values where they exist, so item-card parameters are
    /// dead letters at those locations — the calculators say so in their notes.
    /// </summary>
    procedure GetSKUCount(ItemNo: Code[20]): Integer
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        SKUCount: Integer;
    begin
        if CachedSKUCount.ContainsKey(ItemNo) then
            exit(CachedSKUCount.Get(ItemNo));
        StockkeepingUnit.SetRange("Item No.", ItemNo);
        SKUCount := StockkeepingUnit.Count();
        CachedSKUCount.Set(ItemNo, SKUCount);
        exit(SKUCount);
    end;

    /// <summary>
    /// Advisory text every calculator appends to its note: a demand-trend
    /// warning when the trailing sub-window deviates beyond the threshold
    /// (0 disables), and a note when SKUs make item-card values inert.
    /// Diagnoses honestly; solving these is what per-location planning tools
    /// are for.
    /// </summary>
    procedure BuildAdvisoryText(ItemNo: Code[20]; WindowDays: Integer; TrendThresholdPct: Decimal): Text
    var
        Advisory: Text;
        TrendPct: Decimal;
        SKUCount: Integer;
    begin
        if TrendThresholdPct > 0 then begin
            TrendPct := ComputeTrendPct(ItemNo, WindowDays);
            if Abs(TrendPct) >= TrendThresholdPct then
                if TrendPct > 0 then
                    Advisory += ' ' + StrSubstNo(TrendUpLbl, RecentWindowDays(WindowDays), Format(Round(Abs(TrendPct), 1), 0, 9))
                else
                    Advisory += ' ' + StrSubstNo(TrendDownLbl, RecentWindowDays(WindowDays), Format(Round(Abs(TrendPct), 1), 0, 9));
        end;
        SKUCount := GetSKUCount(ItemNo);
        if SKUCount > 0 then
            Advisory += ' ' + StrSubstNo(SKUNoteLbl, SKUCount);
        exit(Advisory);
    end;

    local procedure EnsureCacheValid(WindowDays: Integer; IncludeConsumption: Boolean)
    begin
        if (CacheCreatedAt = 0DT) or
           (CurrentDateTime() - CacheCreatedAt > 5 * 60000) or
           (CacheWindowDays <> WindowDays) or
           (CacheIncludeConsumption <> IncludeConsumption)
        then begin
            ClearCache();
            CacheWindowDays := WindowDays;
            CacheIncludeConsumption := IncludeConsumption;
        end;
    end;
}
