/// <summary>
/// Safety stock from historical demand and lead-time variability using the
/// Z-score method: SS = Z x sqrt(LT x sigmaD² + D² x sigmaLT²).
/// Port of the standalone BC Safety Stock Calculator onto the shared engine.
/// </summary>
codeunit 50512 "IPL Safety Stock"
{
    Permissions = tabledata Item = rm,
                  tabledata "IPL Calculation Log" = ri;

    var
        Setup: Record "IPL Setup";
        DemandStats: Codeunit "IPL Demand Statistics";
        IPLMath: Codeunit "IPL Math";
        SetupLoaded: Boolean;
        ItemBlockedLbl: Label 'Item is blocked.';
        InsufficientDataLbl: Label 'Only %1 demand observations found (minimum %2).', Comment = '%1 = observations found, %2 = minimum required';
        NoLeadTimeLbl: Label 'No historical lead time and no Lead Time Calculation on item.';
        NoBufferLbl: Label 'No buffer needed: demand and lead time are perfectly stable over the history window.';
        BothVaryLbl: Label 'Buffer covers demand and lead-time variability at %1%% service level.', Comment = '%1 = service level percent';
        DemandVariesLbl: Label 'Buffer covers demand variability over a stable lead time at %1%% service level.', Comment = '%1 = service level percent';
        LeadVariesLbl: Label 'Buffer covers lead-time variability over stable demand at %1%% service level.', Comment = '%1 = service level percent';
        StatsLbl: Label 'Z=%1; LT=%2 d (s=%3); D=%4/d (s=%5); n=%6 obs.', Comment = '%1 = Z-score, %2 = lead time days, %3 = lead time std dev, %4 = avg daily demand, %5 = demand std dev, %6 = observations';
        PurchaseHistorySrcLbl: Label 'Purchase receipt history';
        ItemLeadTimeSrcLbl: Label 'Item Lead Time Calculation';
        ProgressLbl: Label 'Calculating Safety Stock...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';

    /// <summary>
    /// Calculates safety stock for one item; optionally writes it to the item.
    /// </summary>
    procedure CalculateForItem(ItemNo: Code[20]; ServiceLevelPct: Decimal; Apply: Boolean; var ResultCode: Enum "IPL Result Code"; var Note: Text[250]): Decimal
    begin
        exit(RunCalc(ItemNo, ServiceLevelPct, Apply, true, ResultCode, Note));
    end;

    /// <summary>
    /// Preview: calculates without applying and without logging.
    /// </summary>
    procedure CalculatePreview(ItemNo: Code[20]; var ResultCode: Enum "IPL Result Code"; var Note: Text[250]): Decimal
    begin
        exit(RunCalc(ItemNo, 0, false, false, ResultCode, Note));
    end;

    local procedure RunCalc(ItemNo: Code[20]; ServiceLevelPct: Decimal; Apply: Boolean; DoLog: Boolean; var ResultCode: Enum "IPL Result Code"; var Note: Text[250]): Decimal
    var
        Item: Record Item;
        AvgDemand: Decimal;
        DemandStdDev: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
        AvgLeadTime: Decimal;
        LeadTimeStdDev: Decimal;
        LeadTimeSource: Text[50];
        ZScore: Decimal;
        SafetyStock: Decimal;
        PreviousSS: Decimal;
        Applied: Boolean;
    begin
        EnsureSetup();
        if (ServiceLevelPct <= 0) or (ServiceLevelPct > 100) then
            ServiceLevelPct := Setup."Default Service Level %";

        if not Item.Get(ItemNo) then
            exit(0);

        if Item.Blocked then begin
            ResultCode := ResultCode::"Item Blocked";
            Note := ItemBlockedLbl;
            LogResult(Item, ServiceLevelPct, 0, 0, 0, 0, 0, 0, '', 0, Item."Safety Stock Quantity", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        DemandStats.ComputeDemandStats(ItemNo, Setup."History Window (Days)", AvgDemand, DemandStdDev, Observations, ADI, CV2);
        if Observations < Setup."Min Demand Observations" then begin
            ResultCode := ResultCode::"Insufficient Demand Data";
            Note := CopyStr(StrSubstNo(InsufficientDataLbl, Observations, Setup."Min Demand Observations"), 1, MaxStrLen(Note));
            LogResult(Item, ServiceLevelPct, 0, AvgDemand, DemandStdDev, Observations, 0, 0, '', 0, Item."Safety Stock Quantity", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        DemandStats.ComputePurchaseLeadTime(ItemNo, AvgLeadTime, LeadTimeStdDev);
        if AvgLeadTime > 0 then
            LeadTimeSource := PurchaseHistorySrcLbl
        else begin
            AvgLeadTime := DemandStats.DaysFromDateFormula(Item."Lead Time Calculation");
            LeadTimeStdDev := 0;
            if AvgLeadTime > 0 then
                LeadTimeSource := ItemLeadTimeSrcLbl;
        end;
        if AvgLeadTime <= 0 then begin
            ResultCode := ResultCode::"No Lead Time Data";
            Note := NoLeadTimeLbl;
            LogResult(Item, ServiceLevelPct, 0, AvgDemand, DemandStdDev, Observations, 0, 0, '', 0, Item."Safety Stock Quantity", false, DoLog, ResultCode, Note);
            exit(0);
        end;

        ZScore := IPLMath.ZScore(ServiceLevelPct);
        SafetyStock := ZScore * IPLMath.Sqrt(
            (AvgLeadTime * Power(DemandStdDev, 2)) +
            (Power(AvgDemand, 2) * Power(LeadTimeStdDev, 2)));

        if Setup."Round Up Results" then
            SafetyStock := Round(SafetyStock, 1, '>');

        PreviousSS := Item."Safety Stock Quantity";
        if Apply and Setup."Apply Safety Stock" then begin
            Item.Validate("Safety Stock Quantity", SafetyStock);
            Item.Modify(true);
            Applied := true;
        end;

        ResultCode := ResultCode::OK;
        Note := CopyStr(
            BuildReason(SafetyStock, ServiceLevelPct, DemandStdDev, LeadTimeStdDev) + ' ' +
            StrSubstNo(StatsLbl,
                Format(Round(ZScore, 0.0001), 0, 9), Format(Round(AvgLeadTime, 0.01), 0, 9),
                Format(Round(LeadTimeStdDev, 0.01), 0, 9), Format(Round(AvgDemand, 0.01), 0, 9),
                Format(Round(DemandStdDev, 0.01), 0, 9), Observations),
            1, MaxStrLen(Note));

        LogResult(Item, ServiceLevelPct, ZScore, AvgDemand, DemandStdDev, Observations, AvgLeadTime, LeadTimeStdDev, LeadTimeSource, SafetyStock, PreviousSS, Applied, DoLog, ResultCode, Note);
        exit(SafetyStock);
    end;

    /// <summary>
    /// Bulk calculation for the items filtered on the record passed in.
    /// </summary>
    procedure CalculateBulk(var ItemFilter: Record Item; ServiceLevelPct: Decimal; Apply: Boolean): Integer
    var
        Item: Record Item;
        ResultCode: Enum "IPL Result Code";
        Note: Text[250];
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        EnsureSetup();
        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
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
                CalculateForItem(Item."No.", ServiceLevelPct, Apply, ResultCode, Note);
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
        exit(Done);
    end;

    local procedure BuildReason(SafetyStock: Decimal; ServiceLevelPct: Decimal; DemandStdDev: Decimal; LeadTimeStdDev: Decimal): Text
    begin
        if SafetyStock <= 0 then
            exit(NoBufferLbl);
        case true of
            (DemandStdDev > 0) and (LeadTimeStdDev > 0):
                exit(StrSubstNo(BothVaryLbl, Format(ServiceLevelPct, 0, 9)));
            DemandStdDev > 0:
                exit(StrSubstNo(DemandVariesLbl, Format(ServiceLevelPct, 0, 9)));
            LeadTimeStdDev > 0:
                exit(StrSubstNo(LeadVariesLbl, Format(ServiceLevelPct, 0, 9)));
            else
                exit('');
        end;
    end;

    local procedure LogResult(Item: Record Item; SLPct: Decimal; Z: Decimal; AvgD: Decimal; SDD: Decimal; Obs: Integer; AvgLT: Decimal; SDL: Decimal; LTSource: Text[50]; Result: Decimal; PrevResult: Decimal; Applied: Boolean; DoLog: Boolean; ResultCode: Enum "IPL Result Code"; Note: Text[250])
    var
        LogEntry: Record "IPL Calculation Log";
    begin
        if not DoLog then
            exit;
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Safety Stock";
        LogEntry."Item No." := Item."No.";
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Service Level %" := SLPct;
        LogEntry."Z Score" := Z;
        LogEntry."Avg Daily Demand" := AvgD;
        LogEntry."Demand Std Dev" := SDD;
        LogEntry."Demand Observations" := Obs;
        LogEntry."Lead Time (Days)" := AvgLT;
        LogEntry."Lead Time Std Dev" := SDL;
        LogEntry."Lead Time Source" := LTSource;
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
