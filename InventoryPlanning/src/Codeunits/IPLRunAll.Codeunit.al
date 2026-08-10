/// <summary>
/// Orchestrates the four calculators in dependency order for one item or a
/// filtered set: policy advice first (classification), then safety stock, then
/// reorder point (fed the freshly computed safety stock, not the stale stored
/// value), then EOQ. When the advisor recommends anything other than Fixed
/// Reorder Qty., the "Set Policy When None" default is suppressed for that
/// item so a single run never stamps a policy its own advice contradicts.
/// When the item ends the run on the Maximum Qty. policy, a Maximum Inventory
/// of reorder point + EOQ (the classic order-up-to level) is proposed and
/// applied, completing the min/max parameter pair the policy needs.
/// Also builds and applies Planning Worksheet proposals.
/// </summary>
codeunit 70455016 "IPL Run All"
{
    Permissions = tabledata Item = rm,
                  tabledata "IPL Setup" = ri,
                  tabledata "IPL Calculation Log" = ri;

    var
        Setup: Record "IPL Setup";
        SetupLoaded: Boolean;
        ProgressLbl: Label 'Calculating planning parameters...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';
        MaxInvFormulaLbl: Label 'Maximum Inventory = ROP %1 + EOQ %2 = %3. Order-up-to level for the Maximum Qty. policy.', Comment = '%1 = reorder point, %2 = EOQ, %3 = maximum inventory';

    /// <summary>
    /// Runs all four calculators for one item in dependency order.
    /// </summary>
    procedure RunForItem(ItemNo: Code[20]; Apply: Boolean)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        Recommendation: Enum "IPL Policy Recommendation";
        SSCode: Enum "IPL Result Code";
        ROPCode: Enum "IPL Result Code";
        EOQCode: Enum "IPL Result Code";
        Pattern: Text[30];
        Note: Text[250];
        SafetyStock: Decimal;
        SSOverride: Decimal;
        ROPValue: Decimal;
        EOQQty: Decimal;
        EOQOk: Boolean;
        AllowPolicyDefault: Boolean;
    begin
        if not Item.Get(ItemNo) then
            exit;
        EnsureSetup();

        Recommendation := PolicyAdvisor.AdviseForItem(ItemNo, Apply, Pattern, Note);
        // Only stamp Fixed Reorder Qty. on blank-policy items when the advisor
        // agrees (or could not classify); a Lot-for-Lot or Maximum Qty. advice
        // must not be contradicted by the ROP/EOQ apply path in the same run.
        AllowPolicyDefault := Recommendation in [Recommendation::"Fixed Reorder Qty.", Recommendation::"Insufficient Data"];

        SafetyStock := SafetyStockCalc.CalculateForItem(ItemNo, 0, Apply, SSCode, Note);
        if SSCode = SSCode::OK then
            SSOverride := SafetyStock
        else
            SSOverride := -1;
        ROPValue := ReorderPointCalc.CalculateForItem(ItemNo, Apply, SSOverride, AllowPolicyDefault, ROPCode, Note);
        Item.Get(ItemNo); // refresh after possible writes
        EOQOk := EOQCalc.Calculate(Item, Apply, AllowPolicyDefault, EOQCode, EOQQty);

        if Apply then
            if TryApplyMaxInventory(ItemNo, ROPValue, ROPCode, EOQOk, EOQQty) then
                if ROPCode = ROPCode::"Cap Applied" then begin
                    // The ROP had been capped at the OLD Maximum Inventory,
                    // which this run just raised. One cheap (cached) recalc
                    // lands the pair consistent within a single run.
                    ROPValue := ReorderPointCalc.CalculateForItem(ItemNo, Apply, SSOverride, AllowPolicyDefault, ROPCode, Note);
                    TryApplyMaxInventory(ItemNo, ROPValue, ROPCode, EOQOk, EOQQty);
                end;
    end;

    /// <summary>
    /// Writes Maximum Inventory = ROP + EOQ for items on the Maximum Qty.
    /// policy when both components are usable. Returns true when a new value
    /// was written.
    /// </summary>
    local procedure TryApplyMaxInventory(ItemNo: Code[20]; ROPValue: Decimal; ROPCode: Enum "IPL Result Code"; EOQOk: Boolean; EOQQty: Decimal): Boolean
    var
        Item: Record Item;
        NewMax: Decimal;
        PreviousMax: Decimal;
    begin
        if not Setup."Apply Maximum Inventory" then
            exit(false);
        if not (ROPCode in [ROPCode::OK, ROPCode::"Cap Applied"]) then
            exit(false);
        if (not EOQOk) or (EOQQty <= 0) or (ROPValue <= 0) then
            exit(false);
        if not Item.Get(ItemNo) then
            exit(false);
        if Item."Reordering Policy" <> Item."Reordering Policy"::"Maximum Qty." then
            exit(false);

        NewMax := ROPValue + EOQQty;
        PreviousMax := Item."Maximum Inventory";
        if NewMax = PreviousMax then
            exit(false);

        Item.Validate("Maximum Inventory", NewMax);
        Item.Modify(true);
        LogMaxInventory(ItemNo, ROPValue, EOQQty, NewMax, PreviousMax);
        exit(true);
    end;

    local procedure LogMaxInventory(ItemNo: Code[20]; ROPValue: Decimal; EOQQty: Decimal; NewMax: Decimal; PreviousMax: Decimal)
    var
        LogEntry: Record "IPL Calculation Log";
    begin
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Maximum Inventory";
        LogEntry."Item No." := ItemNo;
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Raw Result" := ROPValue;
        LogEntry.Result := NewMax;
        LogEntry."Previous Value" := PreviousMax;
        LogEntry.Applied := true;
        LogEntry."Result Code" := LogEntry."Result Code"::OK;
        LogEntry.Note := CopyStr(
            StrSubstNo(MaxInvFormulaLbl, Format(ROPValue, 0, 9), Format(EOQQty, 0, 9), Format(NewMax, 0, 9)),
            1, MaxStrLen(LogEntry.Note));
        LogEntry.Insert(true);
    end;

    local procedure EnsureSetup()
    begin
        if not SetupLoaded then begin
            Setup.GetSetup();
            SetupLoaded := true;
        end;
    end;

    /// <summary>
    /// Runs all four calculators for every item in the filter.
    /// Commits every 100 items, so callers must tolerate intermediate commits.
    /// </summary>
    procedure RunBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetRange("IPL Exclude From Planning", false);
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
                RunForItem(Item."No.", Apply);
                if Done mod 100 = 0 then
                    Commit();
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
        exit(Done);
    end;

    /// <summary>
    /// Fills the worksheet buffer with a preview proposal for every item in the
    /// filter. Nothing is written to items and nothing is logged.
    /// </summary>
    procedure BuildProposals(var Proposal: Record "IPL Planning Proposal"; var ItemFilter: Record Item)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        SSCode: Enum "IPL Result Code";
        ROPCode: Enum "IPL Result Code";
        EOQCode: Enum "IPL Result Code";
        Pattern: Text[30];
        Note: Text[250];
        DummyNote: Text[250];
        EOQQty: Decimal;
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        Proposal.Reset();
        Proposal.DeleteAll();

        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetRange("IPL Exclude From Planning", false);
        Total := Item.Count();
        if Total = 0 then
            exit;

        if GuiAllowed() then begin
            ProgressDialog.Open(ProgressLbl);
            ProgressDialog.Update(2, Format(Total));
        end;

        if Item.FindSet() then
            repeat
                Done += 1;
                if GuiAllowed() then
                    ProgressDialog.Update(1, Format(Done));

                Proposal.Init();
                Proposal."Item No." := Item."No.";
                Proposal.Description := Item.Description;
                Proposal."Current Safety Stock" := Item."Safety Stock Quantity";
                Proposal."Current Reorder Point" := Item."Reorder Point";
                Proposal."Current Reorder Quantity" := Item."Reorder Quantity";
                Proposal."Current Maximum Inventory" := Item."Maximum Inventory";
                Proposal."Current Policy" := CopyStr(Format(Item."Reordering Policy"), 1, MaxStrLen(Proposal."Current Policy"));

                Proposal."Recommended Policy" := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);
                Proposal."Demand Pattern" := Pattern;
                Proposal.Note := Note;

                Proposal."Proposed Safety Stock" := SafetyStockCalc.CalculatePreview(Item."No.", SSCode, DummyNote);
                Proposal."SS Result Code" := SSCode;

                Proposal."Proposed Reorder Point" := ReorderPointCalc.CalculatePreview(Item."No.", ROPCode, DummyNote);
                Proposal."ROP Result Code" := ROPCode;

                if EOQCalc.CalculatePreview(Item, EOQCode, EOQQty) then
                    Proposal."Proposed EOQ" := EOQQty;
                Proposal."EOQ Result Code" := EOQCode;

                // Order-up-to preview for items on (or advised toward) Maximum Qty.
                if ((Item."Reordering Policy" = Item."Reordering Policy"::"Maximum Qty.") or
                    (Proposal."Recommended Policy" = Proposal."Recommended Policy"::"Maximum Qty.")) and
                   (ROPCode in [ROPCode::OK, ROPCode::"Cap Applied"]) and
                   (EOQCode in [EOQCode::OK, EOQCode::"Cap Applied"]) and
                   (Proposal."Proposed EOQ" > 0)
                then
                    Proposal."Proposed Maximum Inventory" := Proposal."Proposed Reorder Point" + Proposal."Proposed EOQ";

                Proposal.Selected :=
                    (SSCode in [SSCode::OK, SSCode::"Cap Applied"]) or
                    (ROPCode in [ROPCode::OK, ROPCode::"Cap Applied"]) or
                    (EOQCode in [EOQCode::OK, EOQCode::"Cap Applied"]);
                Proposal.Insert();
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
    end;

    /// <summary>
    /// Applies the selected proposals: runs the calculators with Apply for each
    /// selected item, so writes go through the same validated, logged path as a
    /// direct run (never copied blindly from the preview).
    /// </summary>
    procedure ApplySelected(var Proposal: Record "IPL Planning Proposal"): Integer
    var
        Applied: Integer;
    begin
        Proposal.Reset();
        Proposal.SetRange(Selected, true);
        if Proposal.FindSet() then
            repeat
                RunForItem(Proposal."Item No.", true);
                Applied += 1;
            until Proposal.Next() = 0;
        exit(Applied);
    end;
}
