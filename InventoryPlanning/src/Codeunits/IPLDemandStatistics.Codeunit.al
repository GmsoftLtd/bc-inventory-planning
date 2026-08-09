/// <summary>
/// The single demand-statistics engine behind all four calculators. One pass
/// over Item Ledger Entries yields the full superset of statistics the four
/// standalone apps computed separately: average daily demand, standard
/// deviation, observations, ADI and CV². Lead time resolution is
/// replenishment-system aware, with standard deviation from receipt history
/// for purchased items.
///
/// Conventions preserved from the standalone apps:
/// - Sales post negative on the ILE; quantities are flipped to positive demand.
/// - Mean and variance are computed over ALL calendar days in the window
///   (zero-demand days count toward the divisor), so the daily rate lines up
///   with a calendar-day lead time.
/// - CV² is the squared coefficient of variation of the per-day demand SIZES.
/// - Purchase lead time averages ALL receipt history, not just the demand
///   window: supplier performance is more stable with more samples.
/// </summary>
codeunit 50510 "IPL Demand Statistics"
{
    /// <summary>
    /// Computes all demand statistics for an item over the given history window.
    /// </summary>
    /// <param name="ItemNo">The item to analyse.</param>
    /// <param name="WindowDays">History window in calendar days, ending today.</param>
    /// <param name="AvgDemand">Out: mean daily demand over all calendar days.</param>
    /// <param name="StdDev">Out: standard deviation of daily demand (sample, n-1).</param>
    /// <param name="Observations">Out: number of days that had demand.</param>
    /// <param name="ADI">Out: average demand interval (calendar days / demand days).</param>
    /// <param name="CV2">Out: squared coefficient of variation of per-day demand sizes.</param>
    procedure ComputeDemandStats(ItemNo: Code[20]; WindowDays: Integer; var AvgDemand: Decimal; var StdDev: Decimal; var Observations: Integer; var ADI: Decimal; var CV2: Decimal)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        IPLMath: Codeunit "IPL Math";
        DailyDemand: Dictionary of [Date, Decimal];
        WindowStart: Date;
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

        WindowStart := CalcDate(StrSubstNo('<-%1D>', WindowDays), Today());
        CalendarDays := Today() - WindowStart + 1;
        if CalendarDays <= 0 then
            exit;

        ItemLedgerEntry.SetCurrentKey("Item No.", "Posting Date");
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Posting Date", WindowStart, Today());
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Sale);
        ItemLedgerEntry.SetLoadFields("Posting Date", Quantity);
        if not ItemLedgerEntry.FindSet() then
            exit;

        repeat
            Qty := -ItemLedgerEntry.Quantity;
            if Qty > 0 then
                if DailyDemand.ContainsKey(ItemLedgerEntry."Posting Date") then
                    DailyDemand.Set(ItemLedgerEntry."Posting Date", DailyDemand.Get(ItemLedgerEntry."Posting Date") + Qty)
                else
                    DailyDemand.Add(ItemLedgerEntry."Posting Date", Qty);
        until ItemLedgerEntry.Next() = 0;

        SellingDays := DailyDemand.Count();
        if SellingDays = 0 then
            exit;

        foreach DemandDate in DailyDemand.Keys() do begin
            Qty := DailyDemand.Get(DemandDate);
            SumQty += Qty;
            SumSqQty += Qty * Qty;
        end;

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
        StdDev := IPLMath.Sqrt(Variance);

        // ADI: mean calendar days between demand days.
        ADI := CalendarDays / SellingDays;

        // CV²: variability of demand sizes on the days demand occurs.
        MeanSize := SumQty / SellingDays;
        if MeanSize > 0 then begin
            foreach DemandDate in DailyDemand.Keys() do
                SumSqDiff += Power(DailyDemand.Get(DemandDate) - MeanSize, 2);
            CV2 := (SumSqDiff / SellingDays) / Power(MeanSize, 2);
        end;
    end;

    /// <summary>
    /// Resolves the replenishment lead time for an item: purchase receipt
    /// history first for purchased items (with standard deviation), the item's
    /// Lead Time Calculation as fallback and for produced/assembled items, then
    /// the setup fallback.
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
        ManufacturingLbl: Label 'Manufacturing lead time';
        AssemblyLbl: Label 'Assembly lead time';
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
            LeadTimeSource := SetupFallbackLbl;
        end;
    end;

    /// <summary>
    /// Mean and standard deviation of order-to-receipt days over all posted
    /// purchase receipt lines for the item.
    /// </summary>
    procedure ComputePurchaseLeadTime(ItemNo: Code[20]; var AvgLeadTime: Decimal; var StdDev: Decimal)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        IPLMath: Codeunit "IPL Math";
        SumLT: Decimal;
        SumSqLT: Decimal;
        n: Integer;
        LTDays: Decimal;
        Mean: Decimal;
        Variance: Decimal;
    begin
        AvgLeadTime := 0;
        StdDev := 0;

        PurchRcptLine.SetCurrentKey("No.");
        PurchRcptLine.SetRange("No.", ItemNo);
        PurchRcptLine.SetRange(Type, PurchRcptLine.Type::Item);
        PurchRcptLine.SetLoadFields("Order Date", "Posting Date");
        if not PurchRcptLine.FindSet() then
            exit;

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

        if n = 0 then
            exit;

        Mean := SumLT / n;
        if n > 1 then
            Variance := (SumSqLT - n * Mean * Mean) / (n - 1)
        else
            Variance := 0;
        if Variance < 0 then
            Variance := 0;

        AvgLeadTime := Mean;
        StdDev := IPLMath.Sqrt(Variance);
    end;

    /// <summary>
    /// Days represented by a date formula, evaluated from today. Empty formula = 0.
    /// </summary>
    procedure DaysFromDateFormula(DF: DateFormula): Decimal
    var
        BaseDate: Date;
    begin
        if Format(DF) = '' then
            exit(0);
        BaseDate := Today();
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
}
