/// <summary>
/// Reorder point = (average daily demand x lead time) + safety stock, capped
/// at Maximum Inventory when one is set so the parameter pair stays valid for
/// the Maximum Qty. policy.
/// Port of the standalone BC Reorder Point Calculator onto the shared engine.
/// </summary>
codeunit 70455013 "GSO Reorder Point"
{
    Permissions = tabledata Item = rm,
                  tabledata "GSO Setup" = ri,
                  tabledata "GSO Calculation Log" = ri;

    var
        Setup: Record "GSO Setup";
        DemandStats: Codeunit "GSO Demand Statistics";
        SetupLoaded: Boolean;
        ItemBlockedLbl: Label 'Item is blocked.';
        NotInventoryLbl: Label 'Not an inventory item: a reorder point does not apply.';
        ExcludedLbl: Label 'Item is excluded from inventory planning.';
        MTOSkippedLbl: Label 'Make-to-order item. Reorder point does not apply: supply is created per demand.';
        InsufficientDataLbl: Label 'Only %1 demand observations found (minimum %2). No reliable demand rate.', Comment = '%1 = observations found, %2 = minimum required';
        NoLeadTimeLbl: Label 'No lead time available: no receipt history, no Lead Time Calculation, and the setup fallback is 0.';
        WithSSLbl: Label 'Covers expected demand during lead time, on top of the safety stock buffer.';
        WithoutSSLbl: Label 'Covers expected demand during lead time (no safety stock buffer).';
        MaxInvCapLbl: Label 'Capped at Maximum Inventory (%1): the uncapped reorder point %2 would make the Maximum Qty. parameter pair invalid.', Comment = '%1 = maximum inventory, %2 = uncapped reorder point';
        FormulaLbl: Label 'ROP = (D %1/day x LT %2 d) + SS %3 = %4. Lead time from %5; n=%6 obs.', Comment = '%1 = avg daily demand, %2 = lead time days, %3 = safety stock, %4 = reorder point, %5 = lead time source, %6 = observations';
        ProgressLbl: Label 'Calculating Reorder Point...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';

    /// <summary>
    /// Calculates the reorder point for one item; optionally writes it to the item.
    /// Pass SafetyStockOverride less than 0 to use the item's stored safety stock.
    /// </summary>
    procedure CalculateForItem(ItemNo: Code[20]; Apply: Boolean; SafetyStockOverride: Decimal; var ResultCode: Enum "GSO Result Code"; var Note: Text[250]): Decimal
    begin
        exit(RunCalc(ItemNo, Apply, true, SafetyStockOverride, true, ResultCode, Note));
    end;

    /// <summary>
    /// As CalculateForItem, with control over the "Set Policy When None"
    /// default: Run All passes false when the policy advisor has just
    /// recommended something other than Fixed Reorder Qty., so a single run
    /// never stamps a policy its own advice contradicts.
    /// </summary>
    procedure CalculateForItem(ItemNo: Code[20]; Apply: Boolean; SafetyStockOverride: Decimal; AllowPolicyDefault: Boolean; var ResultCode: Enum "GSO Result Code"; var Note: Text[250]): Decimal
    begin
        exit(RunCalc(ItemNo, Apply, true, SafetyStockOverride, AllowPolicyDefault, ResultCode, Note));
    end;

    /// <summary>
    /// Preview: calculates without applying and without logging.
    /// </summary>
    procedure CalculatePreview(ItemNo: Code[20]; var ResultCode: Enum "GSO Result Code"; var Note: Text[250]): Decimal
    begin
        exit(RunCalc(ItemNo, false, false, -1, true, ResultCode, Note));
    end;

    local procedure RunCalc(ItemNo: Code[20]; Apply: Boolean; DoLog: Boolean; SafetyStockOverride: Decimal; AllowPolicyDefault: Boolean; var ResultCode: Enum "GSO Result Code"; var Note: Text[250]): Decimal
    var
        Item: Record Item;
        AvgDemand: Decimal;
        DemandStdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
        LeadTimeDays: Decimal;
        LeadTimeStdDev: Decimal;
        LeadTimeSource: Text[50];
        SafetyStock: Decimal;
        ReorderPoint: Decimal;
        UncappedROP: Decimal;
        PreviousRP: Decimal;
        Applied: Boolean;
        CapNote: Text;
    begin
        EnsureSetup();

        if not Item.Get(ItemNo) then
            exit(0);

        if Item.Type <> Item.Type::Inventory then begin
            ResultCode := ResultCode::"Not an Inventory Item";
            Note := NotInventoryLbl;
            LogResult(Item, 0, 0, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        if Item.Blocked then begin
            ResultCode := ResultCode::"Item Blocked";
            Note := ItemBlockedLbl;
            LogResult(Item, 0, 0, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        if Item."GSO Exclude From Planning" then begin
            ResultCode := ResultCode::Excluded;
            Note := ExcludedLbl;
            LogResult(Item, 0, 0, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        if Setup."Skip Make-to-Order" and DemandStats.IsMakeToOrder(Item) then begin
            ResultCode := ResultCode::"Make-to-Order Skipped";
            Note := MTOSkippedLbl;
            LogResult(Item, 0, 0, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        DemandStats.ComputeDemandStats(ItemNo, Setup."History Window (Days)", AvgDemand, DemandStdDev, Observations, ADI, CV2);
        if Observations < Setup."Min Demand Observations" then begin
            ResultCode := ResultCode::"Insufficient Demand Data";
            Note := CopyStr(StrSubstNo(InsufficientDataLbl, Observations, Setup."Min Demand Observations"), 1, MaxStrLen(Note));
            LogResult(Item, AvgDemand, Observations, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        DemandStats.ComputeLeadTime(Item, Setup."Default Lead Time (Days)", LeadTimeDays, LeadTimeStdDev, LeadTimeSource);
        if LeadTimeDays <= 0 then begin
            ResultCode := ResultCode::"No Lead Time Data";
            Note := NoLeadTimeLbl;
            LogResult(Item, AvgDemand, Observations, 0, '', 0, 0, Item."Reorder Point", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        if Setup."Include Safety Stock" then begin
            if SafetyStockOverride >= 0 then
                SafetyStock := SafetyStockOverride
            else
                SafetyStock := Item."Safety Stock Quantity";
        end else
            SafetyStock := 0;

        ReorderPoint := (AvgDemand * LeadTimeDays) + SafetyStock;
        if Setup."Round Up Results" then
            ReorderPoint := Round(ReorderPoint, 1, '>');

        ResultCode := ResultCode::OK;
        if (Item."Maximum Inventory" > 0) and (ReorderPoint > Item."Maximum Inventory") then begin
            UncappedROP := ReorderPoint;
            ReorderPoint := Item."Maximum Inventory";
            ResultCode := ResultCode::"Cap Applied";
            CapNote := ' ' + StrSubstNo(MaxInvCapLbl, Format(Item."Maximum Inventory", 0, 9), Format(UncappedROP, 0, 9));
        end;

        PreviousRP := Item."Reorder Point";
        if Apply and Setup."Apply Reorder Point" then begin
            Item.Validate("Reorder Point", ReorderPoint);
            if AllowPolicyDefault and Setup."Set Policy When None" and (Item."Reordering Policy" = Item."Reordering Policy"::" ") then
                Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
            Item.Modify(true);
            Applied := true;
        end;

        Note := CopyStr(
            BuildReason(SafetyStock) + ' ' +
            StrSubstNo(FormulaLbl,
                Format(Round(AvgDemand, 0.01), 0, 9), Format(Round(LeadTimeDays, 0.01), 0, 9),
                Format(Round(SafetyStock, 0.01), 0, 9), Format(ReorderPoint, 0, 9),
                LeadTimeSource, Observations) + CapNote +
            DemandStats.BuildAdvisoryText(ItemNo, Setup."History Window (Days)", Setup."Trend Warning Threshold %"),
            1, MaxStrLen(Note));

        LogResult(Item, AvgDemand, Observations, LeadTimeDays, LeadTimeSource, SafetyStock, ReorderPoint, PreviousRP, Applied, DoLog, ResultCode, Note);
        exit(ReorderPoint);
    end;

    /// <summary>
    /// Bulk calculation for the items filtered on the record passed in.
    /// Commits every 100 items, so callers must tolerate intermediate commits.
    /// </summary>
    procedure CalculateBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        ResultCode: Enum "GSO Result Code";
        Note: Text[250];
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        EnsureSetup();
        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetRange("GSO Exclude From Planning", false);
        Total := Item.Count();
        if Total = 0 then
            exit(0);

        if GuiAllowed() then begin
            ProgressDialog.Open(ProgressLbl);
            ProgressDialog.Update(2, Format(Total));
        end;

        if Item.FindSet() then
            repeat
                Done += 1;
                if GuiAllowed() then
                    ProgressDialog.Update(1, Format(Done));
                CalculateForItem(Item."No.", Apply, -1, ResultCode, Note);
                if Done mod 100 = 0 then
                    Commit();
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
        exit(Done);
    end;

    local procedure BuildReason(SafetyStock: Decimal): Text
    begin
        if SafetyStock > 0 then
            exit(WithSSLbl);
        exit(WithoutSSLbl);
    end;

    local procedure LogResult(Item: Record Item; AvgD: Decimal; Obs: Integer; LeadTime: Decimal; LeadTimeSource: Text[50]; SafetyStock: Decimal; Result: Decimal; PrevResult: Decimal; Applied: Boolean; DoLog: Boolean; ResultCode: Enum "GSO Result Code"; Note: Text[250])
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        if not DoLog then
            exit;
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Reorder Point";
        LogEntry."Item No." := Item."No.";
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Avg Daily Demand" := AvgD;
        LogEntry."Demand Observations" := Obs;
        LogEntry."Lead Time (Days)" := LeadTime;
        LogEntry."Lead Time Source" := LeadTimeSource;
        // Safety stock used is recorded in Raw Result for the ROP row:
        // Result = demand-during-LT + safety stock; Raw Result = the SS component.
        LogEntry."Raw Result" := SafetyStock;
        LogEntry.Result := Result;
        LogEntry."Previous Value" := PrevResult;
        LogEntry.Applied := Applied;
        LogEntry."Result Code" := ResultCode;
        LogEntry.Note := Note;
        LogEntry.Insert(true);
    end;

    local procedure EnsureSetup()
    begin
        if not SetupLoaded then begin
            Setup.GetSetup();
            SetupLoaded := true;
        end;
    end;
}
