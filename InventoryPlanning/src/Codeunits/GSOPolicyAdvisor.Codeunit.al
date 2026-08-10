namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;

/// <summary>
/// Recommends a reordering policy from the Syntetos-Boylan-Croston demand
/// classification (ADI vs CV²): Lot-for-Lot for intermittent/lumpy demand,
/// Maximum Qty. when there is a reason to cap inventory (shelf life or an
/// existing Maximum Inventory), otherwise Fixed Reorder Qty. Make-to-order
/// items are recommended Order and never auto-flipped.
/// Port of the standalone BC Replenishment Policy Advisor onto the shared engine.
/// </summary>
codeunit 73030590 "GSO Policy Advisor"
{
    Permissions = tabledata Item = rm,
                  tabledata "GSO Setup" = ri,
                  tabledata "GSO Calculation Log" = ri;

    var
        Setup: Record "GSO Setup";
        DemandStats: Codeunit "GSO Demand Statistics";
        SetupLoaded: Boolean;
        ItemNotFoundLbl: Label 'Item not found.';
        NotInventoryLbl: Label 'Not an inventory item: a reordering policy does not apply.';
        ItemBlockedLbl: Label 'Item is blocked.';
        ExcludedLbl: Label 'Item is excluded from inventory planning.';
        MTOLbl: Label 'Make-to-order: keep Reordering Policy = Order so each supply pegs to one demand. Its components are make-to-stock and should be advised individually.';
        InsufficientLbl: Label 'Only %1 day(s) with demand (minimum %2). Not enough sales history to classify the demand pattern.', Comment = '%1 = demand days found, %2 = minimum required';
        LumpyLbl: Label '%1 demand: stock turns over infrequently (ADI %2 >= %3). Lot-for-Lot orders to each demand and holds no standing stock.', Comment = '%1 = pattern, %2 = ADI, %3 = threshold';
        PerishableLbl: Label '%1 demand with a shelf life set. Maximum Qty. caps standing stock so nothing expires. Set Reorder Point and Maximum Inventory.', Comment = '%1 = pattern';
        MaxInvLbl: Label '%1 demand with a Maximum Inventory cap already set. Maximum Qty. refills up to that ceiling at the reorder point.', Comment = '%1 = pattern';
        FixedLbl: Label '%1 demand, no inventory cap. Fixed Reorder Qty. orders a fixed economic quantity (EOQ) at the reorder point. Set Reorder Point and Reorder Quantity.', Comment = '%1 = pattern';
        SmoothTxt: Label 'Smooth';
        ErraticTxt: Label 'Erratic';
        IntermittentTxt: Label 'Intermittent';
        LumpyTxt: Label 'Lumpy';
        UnknownTxt: Label 'Unknown';
        ProgressLbl: Label 'Advising replenishment policy...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';

    /// <summary>
    /// Advises a policy for one item; optionally writes it back (subject to setup).
    /// </summary>
    procedure AdviseForItem(ItemNo: Code[20]; Apply: Boolean; var Pattern: Text[30]; var Note: Text[250]): Enum "GSO Policy Recommendation"
    begin
        exit(RunAdvice(ItemNo, Apply, true, Pattern, Note));
    end;

    /// <summary>
    /// Preview: advises without applying and without logging.
    /// </summary>
    procedure AdvisePreview(ItemNo: Code[20]; var Pattern: Text[30]; var Note: Text[250]): Enum "GSO Policy Recommendation"
    begin
        exit(RunAdvice(ItemNo, false, false, Pattern, Note));
    end;

    local procedure RunAdvice(ItemNo: Code[20]; Apply: Boolean; DoLog: Boolean; var Pattern: Text[30]; var Note: Text[250]): Enum "GSO Policy Recommendation"
    var
        Item: Record Item;
        Recommendation: Enum "GSO Policy Recommendation";
        AvgDemand: Decimal;
        StdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
        Applied: Boolean;
    begin
        EnsureSetup();
        Pattern := '';
        Note := '';

        if not Item.Get(ItemNo) then begin
            Note := ItemNotFoundLbl;
            exit(Recommendation::"Insufficient Data");
        end;

        if Item.Type <> Item.Type::Inventory then begin
            Recommendation := Recommendation::"Insufficient Data";
            Note := NotInventoryLbl;
            LogAdvice(Item, 0, 0, 0, 0, 0, Pattern, Recommendation, false, DoLog, Note);
            exit(Recommendation);
        end;

        if Item.Blocked then begin
            Recommendation := Recommendation::"Insufficient Data";
            Note := ItemBlockedLbl;
            LogAdvice(Item, 0, 0, 0, 0, 0, Pattern, Recommendation, false, DoLog, Note);
            exit(Recommendation);
        end;

        if Item."GSO Exclude From Planning" then begin
            Recommendation := Recommendation::"Insufficient Data";
            Note := ExcludedLbl;
            LogAdvice(Item, 0, 0, 0, 0, 0, Pattern, Recommendation, false, DoLog, Note);
            exit(Recommendation);
        end;

        if Setup."Skip Make-to-Order" and DemandStats.IsMakeToOrder(Item) then begin
            Recommendation := Recommendation::Order;
            Note := MTOLbl;
            LogAdvice(Item, 0, 0, 0, 0, 0, Pattern, Recommendation, false, DoLog, Note);
            exit(Recommendation);
        end;

        DemandStats.ComputeDemandStats(ItemNo, Setup."History Window (Days)", AvgDemand, StdDev, Observations, ADI, CV2);

        if Observations < Setup."Min Demand Observations" then begin
            Recommendation := Recommendation::"Insufficient Data";
            Pattern := UnknownTxt;
            Note := CopyStr(StrSubstNo(InsufficientLbl, Observations, Setup."Min Demand Observations"), 1, MaxStrLen(Note));
            LogAdvice(Item, AvgDemand, Observations, ADI, CV2, 0, Pattern, Recommendation, false, DoLog, Note);
            exit(Recommendation);
        end;

        Pattern := ClassifyPattern(ADI, CV2);
        Recommendation := Recommend(Item, ADI, Pattern, Note);

        // Apply only the three make-to-stock policies; never auto-flip to Order.
        if Apply and Setup."Auto-Update Policy" then
            case Recommendation of
                Recommendation::"Fixed Reorder Qty.":
                    begin
                        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
                        Item.Modify(true);
                        Applied := true;
                    end;
                Recommendation::"Maximum Qty.":
                    begin
                        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Maximum Qty.");
                        Item.Modify(true);
                        Applied := true;
                    end;
                Recommendation::"Lot-for-Lot":
                    begin
                        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Lot-for-Lot");
                        Item.Modify(true);
                        Applied := true;
                    end;
            end;

        LogAdvice(Item, AvgDemand, Observations, ADI, CV2, StdDev, Pattern, Recommendation, Applied, DoLog, Note);
        exit(Recommendation);
    end;

    /// <summary>
    /// Bulk advice for the items filtered on the record passed in.
    /// Commits every 100 items, so callers must tolerate intermediate commits.
    /// </summary>
    procedure AdviseBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        Pattern: Text[30];
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
                AdviseForItem(Item."No.", Apply, Pattern, Note);
                if Done mod 100 = 0 then
                    Commit();
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
        exit(Done);
    end;

    local procedure ClassifyPattern(ADI: Decimal; CV2: Decimal): Text[30]
    begin
        if ADI < Setup."Lumpy ADI Threshold" then begin
            if CV2 < Setup."Erratic CV2 Threshold" then
                exit(SmoothTxt);
            exit(ErraticTxt);
        end;
        if CV2 < Setup."Erratic CV2 Threshold" then
            exit(IntermittentTxt);
        exit(LumpyTxt);
    end;

    local procedure Recommend(Item: Record Item; ADI: Decimal; Pattern: Text[30]; var Note: Text[250]): Enum "GSO Policy Recommendation"
    var
        Recommendation: Enum "GSO Policy Recommendation";
    begin
        if ADI >= Setup."Lumpy ADI Threshold" then begin
            Note := CopyStr(StrSubstNo(LumpyLbl, Pattern, Format(Round(ADI, 0.01), 0, 9), Format(Setup."Lumpy ADI Threshold", 0, 9)), 1, MaxStrLen(Note));
            exit(Recommendation::"Lot-for-Lot");
        end;

        if Setup."Perishable Means Max Qty." and HasShelfLife(Item) then begin
            Note := CopyStr(StrSubstNo(PerishableLbl, Pattern), 1, MaxStrLen(Note));
            exit(Recommendation::"Maximum Qty.");
        end;

        if Item."Maximum Inventory" > 0 then begin
            Note := CopyStr(StrSubstNo(MaxInvLbl, Pattern), 1, MaxStrLen(Note));
            exit(Recommendation::"Maximum Qty.");
        end;

        Note := CopyStr(StrSubstNo(FixedLbl, Pattern), 1, MaxStrLen(Note));
        exit(Recommendation::"Fixed Reorder Qty.");
    end;

    local procedure HasShelfLife(Item: Record Item): Boolean
    begin
        // Standard proxy for shelf life: the Expiration Calculation date formula.
        exit(Format(Item."Expiration Calculation") <> '');
    end;

    local procedure LogAdvice(Item: Record Item; AvgD: Decimal; Obs: Integer; ADI: Decimal; CV2: Decimal; StdDev: Decimal; Pattern: Text[30]; Recommendation: Enum "GSO Policy Recommendation"; Applied: Boolean; DoLog: Boolean; Note: Text[250])
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        if not DoLog then
            exit;
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Policy Advice";
        LogEntry."Item No." := Item."No.";
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Avg Daily Demand" := AvgD;
        LogEntry."Demand Std Dev" := StdDev;
        LogEntry."Demand Observations" := Obs;
        LogEntry."Avg Demand Interval (ADI)" := ADI;
        LogEntry."Demand CV Squared" := CV2;
        LogEntry."Demand Pattern" := Pattern;
        LogEntry."Recommended Policy" := Recommendation;
        LogEntry.Applied := Applied;
        LogEntry."Result Code" := LogEntry."Result Code"::OK;
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
