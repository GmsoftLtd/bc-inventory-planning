namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;

/// <summary>
/// Economic Order Quantity via the Wilson formula: EOQ = sqrt(2DS/H), with a
/// months-of-demand cap and respect for the item's order modifiers (Minimum
/// and Maximum Order Quantity, Order Multiple) when writing Reorder Quantity.
/// Port of the standalone BC EOQ Calculator onto the shared engine.
/// </summary>
codeunit 73030584 "GSO EOQ"
{
    Permissions = tabledata Item = rm,
                  tabledata "GSO Setup" = ri,
                  tabledata "GSO Calculation Log" = ri;

    var
        Setup: Record "GSO Setup";
        DemandStats: Codeunit "GSO Demand Statistics";
        GSOMath: Codeunit "GSO Math";
        SetupLoaded: Boolean;
        ItemBlockedLbl: Label 'Item is blocked.';
        NotInventoryLbl: Label 'Not an inventory item: an order quantity does not apply.';
        ExcludedLbl: Label 'Item is excluded from inventory planning.';
        InsufficientObsLbl: Label 'Found %1 observations, need %2.', Comment = '%1 = observations found, %2 = minimum required';
        ZeroDemandLbl: Label 'Annual demand is zero or negative.';
        ZeroUnitCostLbl: Label 'Unit cost is zero. Cannot compute holding cost.';
        ZeroOrderingCostLbl: Label 'Ordering cost is zero in Setup.';
        ZeroResultLbl: Label 'Calculated EOQ is zero after capping and rounding. Nothing was written.';
        CapAppliedLbl: Label 'Raw EOQ %1 capped to %2 (%3 months of demand).', Comment = '%1 = raw EOQ, %2 = capped EOQ, %3 = months cap';
        MinOrderQtyLbl: Label 'Raised to Minimum Order Quantity %1.', Comment = '%1 = minimum order quantity';
        MaxOrderQtyLbl: Label 'Reduced to Maximum Order Quantity %1.', Comment = '%1 = maximum order quantity';
        ProgressLbl: Label 'Calculating EOQ...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';

    /// <summary>
    /// Calculates EOQ for one item; optionally writes it to the configured target field.
    /// Returns true when a usable quantity was produced.
    /// </summary>
    procedure Calculate(var Item: Record Item; Apply: Boolean; var ResultCode: Enum "GSO Result Code"; var AppliedQty: Decimal): Boolean
    begin
        exit(RunCalc(Item, Apply, true, true, ResultCode, AppliedQty));
    end;

    /// <summary>
    /// As Calculate, with control over the "Set Policy When None" default:
    /// Run All passes false when the policy advisor has just recommended
    /// something other than Fixed Reorder Qty.
    /// </summary>
    procedure Calculate(var Item: Record Item; Apply: Boolean; AllowPolicyDefault: Boolean; var ResultCode: Enum "GSO Result Code"; var AppliedQty: Decimal): Boolean
    begin
        exit(RunCalc(Item, Apply, true, AllowPolicyDefault, ResultCode, AppliedQty));
    end;

    /// <summary>
    /// Preview: calculates without applying and without logging.
    /// </summary>
    procedure CalculatePreview(var Item: Record Item; var ResultCode: Enum "GSO Result Code"; var AppliedQty: Decimal): Boolean
    begin
        exit(RunCalc(Item, false, false, true, ResultCode, AppliedQty));
    end;

    local procedure RunCalc(var Item: Record Item; Apply: Boolean; DoLog: Boolean; AllowPolicyDefault: Boolean; var ResultCode: Enum "GSO Result Code"; var AppliedQty: Decimal): Boolean
    var
        AnnualDemand: Decimal;
        ObsCount: Integer;
        UnitCost: Decimal;
        HoldingCost: Decimal;
        OrderingCost: Decimal;
        RawEOQ: Decimal;
        CappedEOQ: Decimal;
        PreviousValue: Decimal;
        Applied: Boolean;
        Notes: Text[250];
    begin
        EnsureSetup();
        AppliedQty := 0;

        if not CheckEligible(Item, ResultCode, Notes) then begin
            LogResult(Item."No.", 0, 0, 0, 0, 0, 0, 0, 0, false, DoLog, ResultCode, Notes);
            exit(false);
        end;

        if not CheckInputs(Item, DoLog, ObsCount, AnnualDemand, UnitCost, HoldingCost, OrderingCost, ResultCode) then
            exit(false);

        RawEOQ := GSOMath.Sqrt((2 * AnnualDemand * OrderingCost) / HoldingCost);

        ResultCode := ResultCode::OK;
        CappedEOQ := CapAndRound(RawEOQ, AnnualDemand, ResultCode, Notes);

        if Setup."EOQ Write Target" = Setup."EOQ Write Target"::"Reorder Quantity" then
            CappedEOQ := ApplyOrderModifiers(Item, CappedEOQ, ResultCode, Notes);

        if CappedEOQ <= 0 then begin
            ResultCode := ResultCode::"Zero Result";
            LogResult(Item."No.", ObsCount, AnnualDemand, UnitCost, HoldingCost, OrderingCost, RawEOQ, 0, 0, false, DoLog, ResultCode, ZeroResultLbl);
            exit(false);
        end;

        AppliedQty := CappedEOQ;

        if Apply and Setup."Apply EOQ" then begin
            ApplyToItem(Item, CappedEOQ, AllowPolicyDefault, PreviousValue);
            Applied := true;
        end;

        Notes := CopyStr(
            Notes + DemandStats.BuildAdvisoryText(Item."No.", Setup."History Window (Days)", Setup."Trend Warning Threshold %"),
            1, MaxStrLen(Notes));
        LogResult(Item."No.", ObsCount, AnnualDemand, UnitCost, HoldingCost, OrderingCost, RawEOQ, CappedEOQ, PreviousValue, Applied, DoLog, ResultCode, Notes);
        exit(true);
    end;

    /// <summary>
    /// False, with the result code and note set, when an order quantity does
    /// not apply to the item.
    /// </summary>
    local procedure CheckEligible(Item: Record Item; var ResultCode: Enum "GSO Result Code"; var Notes: Text[250]): Boolean
    begin
        case true of
            Item.Type <> Item.Type::Inventory:
                begin
                    ResultCode := ResultCode::"Not an Inventory Item";
                    Notes := NotInventoryLbl;
                end;
            Item.Blocked:
                begin
                    ResultCode := ResultCode::"Item Blocked";
                    Notes := ItemBlockedLbl;
                end;
            Item."GSO Exclude From Planning":
                begin
                    ResultCode := ResultCode::Excluded;
                    Notes := ExcludedLbl;
                end;
            else
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Annual demand and costs for the formula. Logs and returns false when
    /// any of them is missing or zero.
    /// </summary>
    local procedure CheckInputs(Item: Record Item; DoLog: Boolean; var ObsCount: Integer; var AnnualDemand: Decimal; var UnitCost: Decimal; var HoldingCost: Decimal; var OrderingCost: Decimal; var ResultCode: Enum "GSO Result Code"): Boolean
    var
        Notes: Text[250];
    begin
        GetAnnualDemand(Item."No.", AnnualDemand, ObsCount);

        if ObsCount < Setup."Min Demand Observations" then begin
            ResultCode := ResultCode::"Insufficient Demand Data";
            Notes := CopyStr(StrSubstNo(InsufficientObsLbl, ObsCount, Setup."Min Demand Observations"), 1, MaxStrLen(Notes));
            LogResult(Item."No.", ObsCount, AnnualDemand, 0, 0, 0, 0, 0, 0, false, DoLog, ResultCode, Notes);
            exit(false);
        end;

        if AnnualDemand <= 0 then begin
            ResultCode := ResultCode::"Zero Demand";
            LogResult(Item."No.", ObsCount, 0, 0, 0, 0, 0, 0, 0, false, DoLog, ResultCode, ZeroDemandLbl);
            exit(false);
        end;

        UnitCost := GetUnitCost(Item);
        if UnitCost <= 0 then begin
            ResultCode := ResultCode::"Zero Unit Cost";
            LogResult(Item."No.", ObsCount, AnnualDemand, 0, 0, Setup."Ordering Cost", 0, 0, 0, false, DoLog, ResultCode, ZeroUnitCostLbl);
            exit(false);
        end;
        HoldingCost := UnitCost * Setup."Holding Rate";

        OrderingCost := Setup."Ordering Cost";
        if OrderingCost <= 0 then begin
            ResultCode := ResultCode::"Zero Ordering Cost";
            LogResult(Item."No.", ObsCount, AnnualDemand, UnitCost, HoldingCost, 0, 0, 0, 0, false, DoLog, ResultCode, ZeroOrderingCostLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Caps the raw EOQ at Max EOQ Months of demand (0 = no cap), then rounds
    /// it up to whole units or to five decimals per setup.
    /// </summary>
    local procedure CapAndRound(RawEOQ: Decimal; AnnualDemand: Decimal; var ResultCode: Enum "GSO Result Code"; var Notes: Text[250]): Decimal
    var
        EOQ: Decimal;
    begin
        EOQ := RawEOQ;
        if (Setup."Max EOQ Months" > 0) and (EOQ > (AnnualDemand * Setup."Max EOQ Months" / 12)) then begin
            EOQ := AnnualDemand * Setup."Max EOQ Months" / 12;
            ResultCode := ResultCode::"Cap Applied";
            Notes := CopyStr(StrSubstNo(CapAppliedLbl, Format(RawEOQ, 0, 9), Format(Round(EOQ, 0.00001), 0, 9), Setup."Max EOQ Months"), 1, MaxStrLen(Notes));
        end;

        if Setup."Round Up Results" then
            exit(Round(EOQ, 1, '>'));
        exit(Round(EOQ, 0.00001));
    end;

    /// <summary>
    /// Bulk calculation for the items filtered on the record passed in.
    /// Commits every 100 items, so callers must tolerate intermediate commits.
    /// </summary>
    procedure CalculateBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        ResultCode: Enum "GSO Result Code";
        AppliedQty: Decimal;
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

        OpenProgress(ProgressDialog, Total);

        if Item.FindSet() then
            repeat
                Done += 1;
                UpdateProgress(ProgressDialog, Done);
                Calculate(Item, Apply, ResultCode, AppliedQty);
                if Done mod 100 = 0 then
                    Commit();
            until Item.Next() = 0;

        CloseProgress(ProgressDialog);
        exit(Done);
    end;

    local procedure OpenProgress(var ProgressDialog: Dialog; Total: Integer)
    begin
        if not GuiAllowed() then
            exit;
        ProgressDialog.Open(ProgressLbl);
        ProgressDialog.Update(2, Format(Total));
    end;

    local procedure UpdateProgress(var ProgressDialog: Dialog; Done: Integer)
    begin
        if GuiAllowed() then
            ProgressDialog.Update(1, Format(Done));
    end;

    local procedure CloseProgress(var ProgressDialog: Dialog)
    begin
        if GuiAllowed() then
            ProgressDialog.Close();
    end;

    /// <summary>
    /// Clamps the quantity to the item's order modifiers in the order the
    /// planning engine applies them: raise to Minimum Order Quantity, round up
    /// to the Order Multiple, then reduce to Maximum Order Quantity (rounded
    /// down to the multiple so the result stays orderable).
    /// </summary>
    local procedure ApplyOrderModifiers(Item: Record Item; Qty: Decimal; var ResultCode: Enum "GSO Result Code"; var Notes: Text[250]): Decimal
    begin
        if (Item."Minimum Order Quantity" > 0) and (Qty < Item."Minimum Order Quantity") then begin
            Qty := Item."Minimum Order Quantity";
            ResultCode := ResultCode::"Cap Applied";
            Notes := CopyStr(Notes + ' ' + StrSubstNo(MinOrderQtyLbl, Format(Item."Minimum Order Quantity", 0, 9)), 1, MaxStrLen(Notes));
        end;

        if Item."Order Multiple" > 0 then
            Qty := Round(Qty / Item."Order Multiple", 1, '>') * Item."Order Multiple";

        if (Item."Maximum Order Quantity" > 0) and (Qty > Item."Maximum Order Quantity") then begin
            if Item."Order Multiple" > 0 then
                Qty := Round(Item."Maximum Order Quantity" / Item."Order Multiple", 1, '<') * Item."Order Multiple"
            else
                Qty := Item."Maximum Order Quantity";
            ResultCode := ResultCode::"Cap Applied";
            Notes := CopyStr(Notes + ' ' + StrSubstNo(MaxOrderQtyLbl, Format(Item."Maximum Order Quantity", 0, 9)), 1, MaxStrLen(Notes));
        end;

        exit(Qty);
    end;

    local procedure GetAnnualDemand(ItemNo: Code[20]; var AnnualDemand: Decimal; var ObsCount: Integer)
    var
        AvgDemand: Decimal;
        StdDev: Decimal;
        ADI: Decimal;
        CV2: Decimal;
    begin
        // Annualised from the shared engine's calendar-day average, so all four
        // calculators agree on what "demand" means. (The standalone EOQ app
        // counted ILE rows as observations; the consolidated app counts demand
        // days, consistent with the other calculators.)
        DemandStats.ComputeDemandStats(ItemNo, Setup."History Window (Days)", AvgDemand, StdDev, ObsCount, ADI, CV2);
        AnnualDemand := AvgDemand * 365;
    end;

    local procedure GetUnitCost(Item: Record Item): Decimal
    begin
        case Setup."Cost Source" of
            Setup."Cost Source"::"Last Direct Cost":
                exit(Item."Last Direct Cost");
            Setup."Cost Source"::"Standard Cost":
                exit(Item."Standard Cost");
            Setup."Cost Source"::"Unit Cost":
                exit(Item."Unit Cost");
        end;
        exit(Item."Last Direct Cost");
    end;

    local procedure ApplyToItem(var Item: Record Item; NewQty: Decimal; AllowPolicyDefault: Boolean; var PreviousValue: Decimal)
    begin
        case Setup."EOQ Write Target" of
            Setup."EOQ Write Target"::"Reorder Quantity":
                begin
                    PreviousValue := Item."Reorder Quantity";
                    Item.Validate("Reorder Quantity", NewQty);
                    if AllowPolicyDefault and Setup."Set Policy When None" and (Item."Reordering Policy" = Item."Reordering Policy"::" ") then
                        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
                    Item.Modify(true);
                end;
            Setup."EOQ Write Target"::"Order Multiple":
                begin
                    PreviousValue := Item."Order Multiple";
                    Item.Validate("Order Multiple", NewQty);
                    Item.Modify(true);
                end;
        end;
    end;

    local procedure LogResult(ItemNo: Code[20]; ObsCount: Integer; AnnualDemand: Decimal; UnitCost: Decimal; HoldingCost: Decimal; OrderingCost: Decimal; RawEOQ: Decimal; AppliedQty: Decimal; PreviousValue: Decimal; Applied: Boolean; DoLog: Boolean; ResultCode: Enum "GSO Result Code"; Notes: Text[250])
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        if not DoLog then
            exit;
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::EOQ;
        LogEntry."Item No." := ItemNo;
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Demand Observations" := ObsCount;
        LogEntry."Annual Demand" := AnnualDemand;
        LogEntry."Unit Cost" := UnitCost;
        LogEntry."Holding Cost" := HoldingCost;
        LogEntry."Ordering Cost" := OrderingCost;
        LogEntry."Raw Result" := RawEOQ;
        LogEntry.Result := AppliedQty;
        LogEntry."Previous Value" := PreviousValue;
        LogEntry.Applied := Applied;
        LogEntry."Result Code" := ResultCode;
        LogEntry.Note := Notes;
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
